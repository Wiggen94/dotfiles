#!/usr/bin/env bash
# waydroid-nvidia-setup — provision an initialised Waydroid install for the
# NVIDIA/Venus stack. Run as root AFTER `waydroid init`. Safe to re-run.
#
#   waydroid-nvidia-setup [--refresh <hz>]
#
# Ported from upstream packaging/aur/waydroid-nvidia-bin/waydroid-nvidia-setup:
# guest payload comes from the Nix store, the SELinux and ABRT steps are dropped
# (neither exists on NixOS), and ANGLE plus the patched surfaceflinger are
# treated as optional because upstream does not distribute them prebuilt.
#
# What it does:
#   1. validates the guest payload and the three host prerequisites that each
#      guard a known SurfaceFlinger crash loop,
#   2. installs the payload into /var/lib/waydroid/nv/guest, where the patched
#      container config generator bind-mounts it from,
#   3. writes the stack's properties into waydroid.cfg and regenerates the
#      container config via `waydroid upgrade -o`.
#
# --refresh <hz>: match your monitor's refresh rate (e.g. 144/240). Above 240 Hz
# the vsync-snap window needs the patched surfaceflinger, which is only applied
# when that binary is actually part of the payload.
set -euo pipefail

die() { echo "waydroid-nvidia-setup: $*" >&2; exit 1; }
note() { echo "   $*"; }

[ "$(id -u)" = 0 ] || die "must run as root"

REFRESH=""
while [ $# -gt 0 ]; do
    case "$1" in
        --refresh) REFRESH="${2:?--refresh needs a value}"; shift 2 ;;
        *) die "unknown argument: $1" ;;
    esac
done

CFG=/var/lib/waydroid/waydroid.cfg
GUEST="${WAYDROID_NVIDIA_GUEST_SRC:?WAYDROID_NVIDIA_GUEST_SRC must be set by the wrapper}"
NV_GUEST=/var/lib/waydroid/nv/guest

[ -f "$CFG" ] || die "waydroid is not initialized — run 'waydroid init -s GAPPS' first"
[ -d "$GUEST" ] || die "$GUEST missing (broken waydroid-nvidia-guest package?)"

# Payload this stack cannot work without.
REQUIRED_LIBS=(
    vendor/lib/hw/vulkan.virtio.so
    vendor/lib64/hw/vulkan.virtio.so
    vendor/lib64/libgbm_mesa_wrapper.so
    vendor/lib64/hw/hwcomposer.waydroid.so
)
# Payload upstream builds only on its self-hosted runner and does not ship.
# ANGLE absent  -> GLES falls back to software rendering (Vulkan still native).
# surfaceflinger absent -> no >240 Hz vsync-snap override.
OPTIONAL_LIBS=(
    vendor/lib/egl/libEGL_angle.so
    vendor/lib/egl/libGLESv1_CM_angle.so
    vendor/lib/egl/libGLESv2_angle.so
    vendor/lib64/egl/libEGL_angle.so
    vendor/lib64/egl/libGLESv1_CM_angle.so
    vendor/lib64/egl/libGLESv2_angle.so
)
OPTIONAL_BINS=(system/bin/surfaceflinger)

verify_android_elf() {
    local file="$1" abi="$2" expected_soname="${3:-}"
    local expected_class expected_machine header dynamic actual_soname
    case "$abi" in
        x86)
            expected_class=ELF32
            expected_machine="Intel 80386"
            ;;
        x86_64)
            expected_class=ELF64
            expected_machine="Advanced Micro Devices X86-64"
            ;;
        *) die "internal error: unsupported Android ABI '$abi'" ;;
    esac

    [ -f "$file" ] || die "required guest payload missing: $file"
    header=$(LC_ALL=C readelf -hW -- "$file" 2>/dev/null) || \
        die "$file is not a complete ELF file"
    if ! grep -Eq "^[[:space:]]*Class:[[:space:]]+${expected_class}[[:space:]]*$" <<<"$header" ||
       ! grep -Eq "^[[:space:]]*Machine:[[:space:]]+${expected_machine}[[:space:]]*$" <<<"$header" ||
       ! grep -Eq '^[[:space:]]*Type:[[:space:]]+DYN([[:space:]]|$)' <<<"$header"; then
        die "$file is not an $expected_class/$expected_machine shared object"
    fi

    if [ -n "$expected_soname" ]; then
        dynamic=$(LC_ALL=C readelf -dW -- "$file" 2>/dev/null) ||
            die "cannot read the dynamic section from $file"
        actual_soname=$(sed -n 's/.*(SONAME).*Library soname: \[\([^]]*\)\].*/\1/p' <<<"$dynamic")
        [ "$actual_soname" = "$expected_soname" ] ||
            die "$file has SONAME '${actual_soname:-<missing>}' (expected '$expected_soname')"
    fi
}

abi_for() {
    case "$1" in
        vendor/lib/*) echo x86 ;;
        vendor/lib64/*) echo x86_64 ;;
        *) die "internal error: guest library has no ABI path: $1" ;;
    esac
}

soname_for() {
    case "$1" in
        */hw/vulkan.virtio.so) echo libvulkan_virtio.so ;;
        *) basename -- "$1" ;;
    esac
}

echo "== validating guest payload"
INSTALL_LIBS=()
for rel in "${REQUIRED_LIBS[@]}"; do
    verify_android_elf "$GUEST/$rel" "$(abi_for "$rel")" "$(soname_for "$rel")"
    INSTALL_LIBS+=("$rel")
done

HAVE_ANGLE=1
for rel in "${OPTIONAL_LIBS[@]}"; do
    if [ -f "$GUEST/$rel" ]; then
        verify_android_elf "$GUEST/$rel" "$(abi_for "$rel")" "$(soname_for "$rel")"
        INSTALL_LIBS+=("$rel")
    else
        HAVE_ANGLE=0
    fi
done

INSTALL_BINS=()
HAVE_SF=1
for rel in "${OPTIONAL_BINS[@]}"; do
    if [ -f "$GUEST/$rel" ]; then
        verify_android_elf "$GUEST/$rel" x86_64
        INSTALL_BINS+=("$rel")
    else
        HAVE_SF=0
    fi
done

note "required payload verified (ELF headers, ABI types, SONAMEs)"
if [ "$HAVE_ANGLE" = 1 ]; then
    note "ANGLE present — GLES is translated to Vulkan on the GPU"
else
    note "ANGLE NOT installed — GLES apps fall back to software rendering."
    note "Vulkan-native apps are unaffected. Build ANGLE to fix this; see"
    note "docs/superpowers/specs/2026-08-05-waydroid-nvidia-design.md (phase 3)."
fi
[ "$HAVE_SF" = 1 ] || note "patched surfaceflinger NOT installed — no >240 Hz vsync-snap override"

# Upstream gpu.py blacklists nvidia during auto-detection, so an NVIDIA-only
# host gets no /dev/dri node in the container and SurfaceFlinger crash-loops.
# An explicit drm_device is trusted by the patched gpu.py.
NVNODE=""
for uevent in /sys/class/drm/renderD*/device/uevent; do
    [ -e "$uevent" ] || continue
    if grep -qx "DRIVER=nvidia" "$uevent"; then
        NVNODE="/dev/dri/$(basename "${uevent%/device/uevent}")"
        break
    fi
done
[ -n "$NVNODE" ] || die "no NVIDIA render node found under /dev/dri (is the NVIDIA driver loaded?)"
echo "== NVIDIA render node: $NVNODE"

# Without modeset the driver exposes no dma_buf support at all (no
# VK_EXT_external_memory_dma_buf, zero exportable modifiers), and the guest can
# only crash-loop wrapping its first buffer.
MODESET=$(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null || echo missing)
[ "$MODESET" = "Y" ] || die "nvidia-drm.modeset is not enabled (got: $MODESET).
Set hardware.nvidia.modesetting.enable = true and reboot."
echo "== nvidia-drm.modeset: Y"

# This stack hooks the AIDL minigbm gralloc; a pre-minigbm vendor image hands
# SurfaceFlinger buffers our driver never sees, which crash-loops it. System and
# vendor images version independently and `upgrade -o` never refreshes them, so a
# migrated install can carry an ancient vendor.
VIMG=/var/lib/waydroid/images/vendor.img
[ -f "$VIMG" ] || die "$VIMG missing — run 'waydroid init' first"
VMNT=$(mktemp -d)
mount -o loop,ro "$VIMG" "$VMNT" || { rmdir "$VMNT"; die "cannot inspect $VIMG (mount failed)"; }
HAVE_MINIGBM=0
[ -f "$VMNT/lib64/hw/gralloc.minigbm_gbm_mesa.so" ] && HAVE_MINIGBM=1
umount "$VMNT"; rmdir "$VMNT"
[ "$HAVE_MINIGBM" = 1 ] || die "vendor image is too old (no minigbm_gbm_mesa gralloc).
Run 'waydroid init -f' to fetch current images (apps/data are kept), then re-run this setup."
echo "== vendor image: minigbm AIDL gralloc present"

# Rebuilt from scratch so the installed tree always mirrors the payload — a
# stale library left behind here would still be bind-mounted into the guest.
echo "== installing guest driver stack into $NV_GUEST"
rm -rf "$NV_GUEST"
install -d -m 0755 "$NV_GUEST"
for rel in "${INSTALL_LIBS[@]}"; do
    install -Dm 0644 "$GUEST/$rel" "$NV_GUEST/$rel"
done
# surfaceflinger is a 64-bit system executable, not an app-ABI library.
for rel in "${INSTALL_BINS[@]}"; do
    install -Dm 0755 "$GUEST/$rel" "$NV_GUEST/$rel"
done
note "${#INSTALL_LIBS[@]} libraries, ${#INSTALL_BINS[@]} binaries installed"

echo "== writing waydroid.cfg properties"
REFRESH="$REFRESH" NVNODE="$NVNODE" HAVE_ANGLE="$HAVE_ANGLE" HAVE_SF="$HAVE_SF" \
python3 - "$CFG" <<'EOF'
import configparser, os, sys

cfg_path = sys.argv[1]
cp = configparser.ConfigParser()
cp.optionxform = str  # waydroid props are case-sensitive
cp.read(cfg_path)
if not cp.has_section("properties"):
    cp.add_section("properties")

have_angle = os.environ["HAVE_ANGLE"] == "1"
have_sf = os.environ["HAVE_SF"] == "1"

# Installing this stack obsoletes any old gralloc override: the classic
# software-rendering workaround (ro.hardware.gralloc=default) or a migrated
# gralloc.gbm.legacy blocks the guest's minigbm selection and crash-loops
# SurfaceFlinger. Remove them, loudly.
for k in list(cp["properties"].keys()):
    if k == "ro.hardware.gralloc" or k.startswith("gralloc."):
        print("   removing stale gralloc override: {} = {}".format(
            k, cp["properties"][k]))
        cp.remove_option("properties", k)

props = {
    "ro.hardware.vulkan": "virtio",
    "mesa.vn.debug": "vtest",
    "mesa.vtest.socket.name": "/dev/venus/venus.sock",
    "debug.hwui.renderer": "skiavk",
    "debug.sf.nobootanimation": "1",
    "persist.waydroid.use_subsurface": "true",
    "ro.surface_flinger.vsync_event_phase_offset_ns": "0",
    "ro.surface_flinger.vsync_sf_event_phase_offset_ns": "0",
    "ro.surface_flinger.max_frame_buffer_acquired_buffers": "3",
    "ro.surface_flinger.has_wide_color_display": "false",
    "ro.surface_flinger.use_color_management": "false",
}

if have_angle:
    props["ro.hardware.egl"] = "angle"
    # SurfaceFlinger's compositor goes through GL, i.e. ANGLE -> Vulkan.
    props["debug.renderengine.backend"] = "skiaglthreaded"
else:
    # Upstream's skiaglthreaded would land on SwiftShader without ANGLE, putting
    # composition on the CPU. Composite through Venus/Vulkan instead.
    props["debug.renderengine.backend"] = "skiavkthreaded"
    if cp.has_option("properties", "ro.hardware.egl"):
        print("   removing ro.hardware.egl (ANGLE is not installed)")
        cp.remove_option("properties", "ro.hardware.egl")

refresh = os.environ.get("REFRESH", "")
if refresh:
    props["persist.waydroid.refresh_rate"] = refresh
    if int(refresh) > 240:
        # Stock SF's vsync snap window collapses timeslots above ~240 Hz; only
        # the patched surfaceflinger reads this override (1 ms).
        if have_sf:
            props["debug.sf.snap_to_same_vsync_within_ns"] = "1000000"
        else:
            print("   {} Hz needs the patched surfaceflinger for the vsync-snap "
                  "override, which is not installed — skipping".format(refresh))

for k, v in props.items():
    cp.set("properties", k, v)

cp.set("waydroid", "suspend_action", "none")
# Explicit drm_device bypasses upstream gpu.py's nvidia blacklist.
cp.set("waydroid", "drm_device", os.environ["NVNODE"])
# Enables NVIDIA Venus mode in the waydroid patch: strict bind-mounts at
# container start plus a socket preflight at session start.
cp.set("waydroid", "nvidia_venus_socket", "/run/waydroid-venus/venus.sock")
# Path-preserving dual-ABI mount layout under nv/guest.
cp.set("waydroid", "nvidia_guest_layout", "2")

with open(cfg_path, "w") as f:
    cp.write(f)
print("   properties written (RenderEngine: {})".format(
    props["debug.renderengine.backend"]))
EOF

echo "== regenerating container config (waydroid upgrade -o)"
waydroid upgrade -o

cat <<'EOF'

Done. The container and render server are managed declaratively — verify with:
  systemctl status waydroid-container.service
  systemctl --user status wd-venus.service

Then start a session:
  waydroid session start          # or: waydroid show-full-ui

Confirm GPU acceleration inside the guest — the GLES line should name Venus on
your NVIDIA GPU:
  waydroid shell dumpsys SurfaceFlinger | grep -i gles
EOF
