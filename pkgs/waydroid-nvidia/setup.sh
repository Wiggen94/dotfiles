#!/usr/bin/env bash
# waydroid-nvidia-setup — provision an initialised Waydroid install for the
# NVIDIA/Venus stack. Run as root AFTER `waydroid init`. Safe to re-run.
#
#   waydroid-nvidia-setup [--refresh <hz>] [--no-hwcomposer]
#
# Ported from upstream packaging/aur/waydroid-nvidia-bin/waydroid-nvidia-setup:
# the guest payload comes from the Nix store, and the SELinux and ABRT steps are
# dropped (neither exists on NixOS). Otherwise this is upstream's logic,
# including the three environment checks that each guard a known crash loop.
#
# What it does:
#   1. validates the guest payload and the host prerequisites,
#   2. installs the payload into /var/lib/waydroid/nv/guest, where the patched
#      container config generator bind-mounts it from,
#   3. writes the stack's properties into waydroid.cfg and regenerates the
#      container config via `waydroid upgrade -o`.
#
# --refresh <hz>: match your monitor's refresh rate (e.g. 144/240). Above 240 Hz
# this also enables the vsync-snap window that the patched surfaceflinger reads.
set -euo pipefail

die() { echo "waydroid-nvidia-setup: $*" >&2; exit 1; }
note() { echo "   $*"; }

[ "$(id -u)" = 0 ] || die "must run as root"

REFRESH=""
SKIP_HWC=0
while [ $# -gt 0 ]; do
    case "$1" in
        --refresh) REFRESH="${2:?--refresh needs a value}"; shift 2 ;;
        # Debug lever: leave upstream's patched hwcomposer out and use the
        # image's. The composer service is what imports gralloc buffers as
        # EGLImages, which has been a crash site, so being able to swap it
        # without rebuilding is worth keeping.
        --no-hwcomposer) SKIP_HWC=1; shift ;;
        *) die "unknown argument: $1" ;;
    esac
done

CFG=/var/lib/waydroid/waydroid.cfg
GUEST="${WAYDROID_NVIDIA_GUEST_SRC:?WAYDROID_NVIDIA_GUEST_SRC must be set by the wrapper}"
NV_GUEST=/var/lib/waydroid/nv/guest

[ -f "$CFG" ] || die "waydroid is not initialized — run 'waydroid init -s GAPPS' first"
[ -d "$GUEST" ] || die "$GUEST missing (broken waydroid-nvidia-guest package?)"

# Upstream ships all of this in the release, so all of it is required. ANGLE in
# particular is NOT optional: this image's surfaceflinger has no Vulkan
# RenderEngine (it rejects debug.renderengine.backend=skiavk* outright), so GL is
# the only compositor path and ANGLE is what puts it on the GPU. The image's own
# ANGLE crashes in eglCreateImageKHR on this stack, hence upstream's build.
GUEST_LIBS=(
    vendor/lib/hw/vulkan.virtio.so
    vendor/lib/egl/libEGL_angle.so
    vendor/lib/egl/libGLESv1_CM_angle.so
    vendor/lib/egl/libGLESv2_angle.so
    vendor/lib64/hw/vulkan.virtio.so
    vendor/lib64/egl/libEGL_angle.so
    vendor/lib64/egl/libGLESv1_CM_angle.so
    vendor/lib64/egl/libGLESv2_angle.so
    vendor/lib64/libgbm_mesa_wrapper.so
)
# Bind-mounts for payload that is not installed are skipped by our 0002 patch,
# so omitting this falls back to the image's hwcomposer.
[ "$SKIP_HWC" = 1 ] || GUEST_LIBS+=(vendor/lib64/hw/hwcomposer.waydroid.so)
GUEST_BINS=(system/bin/surfaceflinger)

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

echo "== validating dual-ABI guest payload"
for rel in "${GUEST_LIBS[@]}"; do
    verify_android_elf "$GUEST/$rel" "$(abi_for "$rel")" "$(soname_for "$rel")"
done
for rel in "${GUEST_BINS[@]}"; do
    verify_android_elf "$GUEST/$rel" x86_64
done
note "complete ELF headers, ABI types and library SONAMEs verified"
[ "$SKIP_HWC" = 0 ] || note "patched hwcomposer SKIPPED (--no-hwcomposer) — using the image's copy"

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
for rel in "${GUEST_LIBS[@]}"; do
    install -Dm 0644 "$GUEST/$rel" "$NV_GUEST/$rel"
done
# surfaceflinger is a 64-bit system executable, not an app-ABI library.
for rel in "${GUEST_BINS[@]}"; do
    install -Dm 0755 "$GUEST/$rel" "$NV_GUEST/$rel"
done
note "${#GUEST_LIBS[@]} libraries, ${#GUEST_BINS[@]} binaries installed"

echo "== writing waydroid.cfg properties"
REFRESH="$REFRESH" NVNODE="$NVNODE" python3 - "$CFG" <<'EOF'
import configparser, os, sys

cfg_path = sys.argv[1]
cp = configparser.ConfigParser()
cp.optionxform = str  # waydroid props are case-sensitive
cp.read(cfg_path)
if not cp.has_section("properties"):
    cp.add_section("properties")

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
    "ro.hardware.egl": "angle",
    "ro.hardware.vulkan": "virtio",
    "mesa.vn.debug": "vtest",
    "mesa.vtest.socket.name": "/dev/venus/venus.sock",
    "debug.hwui.renderer": "skiavk",
    # SurfaceFlinger's compositor goes through GL, i.e. ANGLE -> Vulkan -> Venus.
    # A Vulkan RenderEngine is not an option: this image's surfaceflinger is
    # built without one and rejects the value ("Unrecognized RenderEngineType
    # skiavkthreaded; ignoring!"), then silently falls back to SkiaGL on
    # llvmpipe — CPU compositing, and a SIGSEGV once it asks the vtest gralloc
    # for an RGBA_FP16 buffer.
    "debug.renderengine.backend": "skiaglthreaded",
    "debug.sf.nobootanimation": "1",
    "persist.waydroid.use_subsurface": "true",
    "ro.surface_flinger.vsync_event_phase_offset_ns": "0",
    "ro.surface_flinger.vsync_sf_event_phase_offset_ns": "0",
    "ro.surface_flinger.max_frame_buffer_acquired_buffers": "3",
    "ro.surface_flinger.has_wide_color_display": "false",
    "ro.surface_flinger.use_color_management": "false",
}

refresh = os.environ.get("REFRESH", "")
if refresh:
    props["persist.waydroid.refresh_rate"] = refresh
    if int(refresh) > 240:
        # Stock SF's vsync snap window collapses timeslots above ~240 Hz; the
        # patched surfaceflinger reads this override (1 ms).
        props["debug.sf.snap_to_same_vsync_within_ns"] = "1000000"

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
print("   properties written (EGL: angle, RenderEngine: skiaglthreaded)")
EOF

echo "== regenerating container config (waydroid upgrade -o)"
waydroid upgrade -o

cat <<'EOF'

Done. The container and render server are managed declaratively — verify with:
  systemctl status waydroid-container.service
  systemctl --user status wd-venus.service

Then start a session:
  waydroid session start          # or: waydroid show-full-ui

Or capture a bounded, self-stopping diagnostic run:
  waydroid-nvidia-probe --seconds 90

Confirm GPU acceleration inside the guest — the GLES line should name ANGLE on
Venus on your NVIDIA GPU:
  sudo waydroid shell dumpsys SurfaceFlinger | grep -i gles
EOF
