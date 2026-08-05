#!/usr/bin/env bash
# waydroid-nvidia-setup — provision an initialised Waydroid install for the
# NVIDIA/Venus stack. Run as root AFTER `waydroid init`. Safe to re-run.
#
#   waydroid-nvidia-setup [--refresh <hz>] [--size <WxH>] [--density <dpi>]
#                         [--multi-windows] [--mouse-fix] [--device-spoof]
#                         [--hwui-gl] [--arm-translation] [--no-hwcomposer]
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
#
# --size <WxH>: initial guest display size (persist.waydroid.width/height). The
# guest hwcomposer also follows xdg_toplevel configure events, so a *floating*
# window can be drag-resized and the display follows; this only sets the size it
# starts at. Omit to let the display follow the window/output.
#
# --multi-windows: give each Android app its own toplevel window instead of one
# Android desktop in a single surface — much better behaved under a tiling WM,
# and it sidesteps single-surface resize negotiation entirely. Written to
# waydroid.cfg rather than set with `waydroid prop set`, which needs a running
# session and would be lost on the next `waydroid upgrade`.
#
# --mouse-fix: makes click-and-drag register as a touch gesture (scroll/swipe)
# instead of mouse-style click-drag (text selection, carousels ignoring drag).
# fake_touch is NOT a boolean despite its name — it is a comma-separated,
# wildcard-capable list of package names to treat as touch
# (docs.waydro.id/usage/waydroid-prop-options); "*" applies to every app. An
# upstream fork script sets it to the literal string "1", which matches no
# package and silently does nothing — confirmed independently by
# github.com/waydroid/waydroid/issues/1613. cursor_on_subsurface=false is set
# alongside it, matching upstream's own mouse-fix. Pointer speed is a guest
# setting, not a prop: use `waydroid-nvidia-tweak --mouse`.
#
# --device-spoof: present as a real phone (default HUAWEI P30 Pro) instead of
# 'waydroid'/'unknown', which apps like AnTuTu treat as an instant emulator
# tell. Override any field with SPOOF_MODEL / SPOOF_BRAND / SPOOF_DEVICE /
# SPOOF_HARDWARE / SPOOF_PLATFORM / SPOOF_SOC / SPOOF_CHIPNAME / SPOOF_BOARD /
# SPOOF_API_LEVEL.
#
# --hwui-gl: route app rendering through GL (skiagl) instead of Vulkan (skiavk).
# A fallback for apps that misrender on Venus — notably WebView/Chrome, whose
# Vulkan draw functor is the usual culprit. Still GPU-accelerated (GL goes
# through ANGLE), but it gives up the direct Vulkan path, so only reach for it
# when a specific app needs it. Try `waydroid-nvidia-tweak --webview-gl` first:
# that fixes WebView alone and leaves everything else on Vulkan.
#
# --arm-translation: install Intel libhoudini so ARM-only apps run (a large share
# of the Play Store is ARM-only). Unpacks into /var/lib/waydroid/overlay/system,
# which the container overlays onto the guest's /system, and sets the abilist /
# native-bridge properties. Proprietary Intel code, hash-pinned from the same
# archive waydroid_script uses. Translated ARM32 apps land on the 32-bit Venus
# driver and ANGLE this stack already installs, so they stay GPU-accelerated.
# Omitting the flag removes both the files and the properties again.
#
# --density <dpi>: Android display density (ro.sf.lcd_density) — the actual
# "scaling" knob. Resizing the window changes the display *resolution* (more or
# less workspace at the same pixel size); density is what makes everything
# bigger or smaller. 160 is 1x/mdpi, 240 is phone-like. SurfaceFlinger logs
# "ro.sf.lcd_density must be defined as a build property" when unset, which is
# cosmetic, but this silences it.
set -euo pipefail

die() { echo "waydroid-nvidia-setup: $*" >&2; exit 1; }
note() { echo "   $*"; }

[ "$(id -u)" = 0 ] || die "must run as root"

REFRESH=""
SIZE=""
DENSITY=""
MULTI_WINDOWS=0
MOUSE_FIX=0
DEVICE_SPOOF=0
HWUI_GL=0
ARM_TRANSLATION=0
SKIP_HWC=0
while [ $# -gt 0 ]; do
    case "$1" in
        --refresh) REFRESH="${2:?--refresh needs a value}"; shift 2 ;;
        --size) SIZE="${2:?--size needs WxH}"; shift 2 ;;
        --density) DENSITY="${2:?--density needs a dpi value}"; shift 2 ;;
        --multi-windows) MULTI_WINDOWS=1; shift ;;
        --mouse-fix) MOUSE_FIX=1; shift ;;
        --device-spoof) DEVICE_SPOOF=1; shift ;;
        --hwui-gl) HWUI_GL=1; shift ;;
        --arm-translation) ARM_TRANSLATION=1; shift ;;
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

# ARM translation lives in the system overlay, not nv/guest: it has to appear as
# part of the guest's /system, which is where the container's overlayfs lowerdir
# points. Only houdini's own paths are touched, so anything else in the overlay
# (gapps and friends) is left alone.
HOUDINI="${WAYDROID_NVIDIA_HOUDINI_SRC:?WAYDROID_NVIDIA_HOUDINI_SRC must be set by the wrapper}"
OVERLAY_SYSTEM=/var/lib/waydroid/overlay/system
HOUDINI_PATHS=(
    bin/arm bin/arm64 bin/houdini bin/houdini64
    etc/binfmt_misc etc/init/houdini.rc
    lib/arm lib/libhoudini.so
    lib64/arm64 lib64/libhoudini.so
)

if [ "$ARM_TRANSLATION" = 1 ]; then
    echo "== installing ARM translation (libhoudini) into $OVERLAY_SYSTEM"
    [ -d "$HOUDINI/system" ] || die "$HOUDINI/system missing (broken houdini package?)"
    for rel in "${HOUDINI_PATHS[@]}"; do
        rm -rf "$OVERLAY_SYSTEM/$rel"
    done
    install -d -m 0755 "$OVERLAY_SYSTEM"
    cp -r --no-preserve=ownership "$HOUDINI/system/." "$OVERLAY_SYSTEM/"
    # Store files come out read-only; the guest only reads them, but a re-run
    # has to be able to replace them.
    chmod -R u+w "$OVERLAY_SYSTEM"
    note "libhoudini installed (ARM + ARM64 translation)"
elif [ -e "$OVERLAY_SYSTEM/lib/libhoudini.so" ]; then
    echo "== removing ARM translation (--arm-translation not given)"
    for rel in "${HOUDINI_PATHS[@]}"; do
        rm -rf "$OVERLAY_SYSTEM/$rel"
    done
    note "libhoudini removed"
fi

echo "== writing waydroid.cfg properties"
REFRESH="$REFRESH" NVNODE="$NVNODE" SIZE="$SIZE" DENSITY="$DENSITY" \
MULTI_WINDOWS="$MULTI_WINDOWS" MOUSE_FIX="$MOUSE_FIX" DEVICE_SPOOF="$DEVICE_SPOOF" \
HWUI_GL="$HWUI_GL" ARM_TRANSLATION="$ARM_TRANSLATION" \
python3 - "$CFG" <<'EOF'
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

# Initial guest display size. The hwcomposer also honours xdg_toplevel
# configure, so a floating window stays resizable regardless of this.
size = os.environ.get("SIZE", "")
if size:
    w, _, h = size.lower().partition("x")
    if not (w.isdigit() and h.isdigit()):
        sys.exit("--size must look like 1280x800")
    props["persist.waydroid.width"] = w
    props["persist.waydroid.height"] = h
else:
    for k in ("persist.waydroid.width", "persist.waydroid.height"):
        if cp.has_option("properties", k):
            print("   clearing {} (display follows the window)".format(k))
            cp.remove_option("properties", k)

# One toplevel per Android app. Cleared rather than set to "false" when off, so
# the image default applies and the config stays minimal.
if os.environ.get("MULTI_WINDOWS") == "1":
    props["persist.waydroid.multi_windows"] = "true"
elif cp.has_option("properties", "persist.waydroid.multi_windows"):
    print("   clearing persist.waydroid.multi_windows (single-window mode)")
    cp.remove_option("properties", "persist.waydroid.multi_windows")

# Makes click-and-drag register as touch (scroll/swipe) instead of mouse-style
# click-drag (text selection, carousels ignoring drag). "*" is the documented
# wildcard for every package (docs.waydro.id/usage/waydroid-prop-options) — the
# literal value "1" some scripts use matches no package and does nothing.
if os.environ.get("MOUSE_FIX") == "1":
    props["persist.waydroid.cursor_on_subsurface"] = "false"
    props["persist.waydroid.fake_touch"] = "*"
elif any(cp.has_option("properties", k) for k in
         ("persist.waydroid.cursor_on_subsurface", "persist.waydroid.fake_touch")):
    print("   clearing mouse-fix properties")
    for k in ("persist.waydroid.cursor_on_subsurface", "persist.waydroid.fake_touch"):
        cp.remove_option("properties", k)

# GL instead of Vulkan for app rendering. Still GPU (GL runs on ANGLE), but it
# gives up the direct Vulkan path, so it is opt-in per the --hwui-gl docs.
if os.environ.get("HWUI_GL") == "1":
    props["debug.hwui.renderer"] = "skiagl"
    print("   app rendering forced to GL (skiagl) instead of Vulkan")

# Present as a real phone: 'waydroid' and 'unknown' are instant emulator tells.
if os.environ.get("DEVICE_SPOOF") == "1":
    model = os.environ.get("SPOOF_MODEL") or "VOG-AL10"
    brand = os.environ.get("SPOOF_BRAND") or "HUAWEI"
    device = os.environ.get("SPOOF_DEVICE") or "HWVOG"
    hw = os.environ.get("SPOOF_HARDWARE") or "kirin980"
    platform = os.environ.get("SPOOF_PLATFORM") or "kirin980"
    soc = os.environ.get("SPOOF_SOC") or "Kirin 980"
    chip = os.environ.get("SPOOF_CHIPNAME") or "kirin980"
    board = os.environ.get("SPOOF_BOARD") or "VOG"
    api = os.environ.get("SPOOF_API_LEVEL") or "28"
    spoof = {
        "ro.product.brand": brand, "ro.product.manufacturer": brand,
        "ro.product.model": model, "ro.product.device": device,
        "ro.product.name": model, "ro.product.board": board,
        "ro.product.first_api_level": api,
        "ro.system.build.product": model,
        "ro.system.build.flavor": "{}-user".format(device),
        "ro.build.fingerprint":
            "{0}/{1}/{2}:10/{0}{1}/10.1.0.162C00:user/release-keys".format(
                brand, model, device),
        "ro.system.build.description":
            "{}-user 10 {}{} release-keys".format(model, brand, model),
        "ro.build.display.id": "{} 10.1.0.162(C00E160R1P8)".format(model),
        "ro.build.tags": "release-keys", "ro.build.type": "user",
        "ro.debuggable": "0",
        "ro.hardware": hw, "ro.board.platform": platform,
        "ro.soc.model": soc, "ro.hardware.chipname": chip,
    }
    # API 30+ reads per-partition namespaces too; a mismatch is itself a tell.
    for part in ("system", "vendor", "odm", "system_ext"):
        spoof.update({
            "ro.product.{}.brand".format(part): brand,
            "ro.product.{}.manufacturer".format(part): brand,
            "ro.product.{}.model".format(part): model,
            "ro.product.{}.device".format(part): device,
            "ro.product.{}.name".format(part): model,
        })
    props.update(spoof)
    print("   spoofing device identity as {} {} (SoC: {})".format(brand, model, soc))
    # Each field defaults independently, so overriding only brand/model leaves a
    # HUAWEI codename and SoC attached to, say, a Samsung model — an
    # inconsistency that defeats the point of spoofing at all.
    defaults = {"SPOOF_DEVICE": "HWVOG", "SPOOF_HARDWARE": "kirin980",
                "SPOOF_PLATFORM": "kirin980", "SPOOF_CHIPNAME": "kirin980",
                "SPOOF_BOARD": "VOG"}
    if (os.environ.get("SPOOF_BRAND") or os.environ.get("SPOOF_MODEL")):
        stale = [k for k, v in defaults.items() if not os.environ.get(k)]
        if stale:
            print("   WARNING: still using HUAWEI defaults for {} —".format(
                ", ".join(sorted(stale))))
            print("   a mismatched identity is itself an emulator tell.")

# ARM translation: the abilist tells Android which ABIs apps may target, and
# the native-bridge properties point the runtime at libhoudini.
arm_props = {
    "ro.product.cpu.abilist": "x86_64,x86,arm64-v8a,armeabi-v7a,armeabi",
    "ro.product.cpu.abilist32": "x86,armeabi-v7a,armeabi",
    "ro.product.cpu.abilist64": "x86_64,arm64-v8a",
    "ro.dalvik.vm.native.bridge": "libhoudini.so",
    "ro.enable.native.bridge.exec": "1",
    "ro.dalvik.vm.isa.arm": "x86",
    "ro.dalvik.vm.isa.arm64": "x86_64",
}
if os.environ.get("ARM_TRANSLATION") == "1":
    props.update(arm_props)
    print("   ARM translation properties set (abilist + native bridge)")
elif any(cp.has_option("properties", k) for k in arm_props):
    print("   clearing ARM translation properties")
    for k in arm_props:
        cp.remove_option("properties", k)

# Density is the scaling knob; resizing only changes usable resolution.
density = os.environ.get("DENSITY", "")
if density:
    if not density.isdigit():
        sys.exit("--density must be a number, e.g. 160 or 240")
    props["ro.sf.lcd_density"] = density

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
