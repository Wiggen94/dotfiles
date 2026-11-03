#!/usr/bin/env bash
# waydroid-nvidia-setup — provision Waydroid for NVIDIA GPUs. Run as root. Runs `waydroid init` first when
# Waydroid is not initialized yet. Safe to re-run (it is also the remedy after an NVIDIA driver update).
#
#   waydroid-nvidia-setup [-s VANILLA|GAPPS|FOSS] [--mode nvidia-prolapse] [--native-gl on|off] [--refresh <hz>|auto]
#                         [--size <WxH>] [--density <dpi>] [--multi-windows] [--mouse-fix] [--device-spoof]
#                         [--hwui-gl] [--arm-translation]
#   waydroid-nvidia-setup --restore-official-vendor
#
# -s, --system-type VANILLA|GAPPS|FOSS: the Android system image `waydroid init` downloads when Waydroid is not
# initialized yet (the same values as `waydroid init -s`; GAPPS = with Google apps). Without it, Waydroid's default
# (VANILLA, no Google apps). On an initialized Waydroid it only checks that the installed system image is that type,
# and says how to switch if not; it never re-initializes over your install.
#
# What it does:
#   1. checks the host: NVIDIA render node, nvidia-drm.modeset=Y, an initialized Waydroid (official system image);
#   2. writes the non-mode properties into waydroid.cfg [properties] (renderer, vsync phase offsets),
#      suspend_action = none, drm_device = the NVIDIA render node;
#   3. selects the driver mode: --mode, else the cfg's nvidia_driver_mode, else nvidia-prolapse;
#      nvidia_native_gl: --native-gl, else the cfg's value, else off (ANGLE). An explicit choice in the cfg is kept;
#   4. nvidia-prolapse: installs this release's nvidia-prolapse VENDOR image (every guest component built from source
#      as a vendor module; packaging/native/vendor_image.py): checks it against its OTA channel and the release
#      bundle, runs the install-time gate on this GPU and kernel module (CI-built test programs, the bionic runtime
#      taken from your system.img, logs in /var/lib/waydroid-nvidia/gate-*), keeps your official vendor.img as the
#      backup, puts ours next to your official system.img, points vendor_ota at this release's channel (Waydroid's
#      updater then never replaces it; system OTAs stay official), and activates it (waydroid.cfg, `waydroid upgrade
#      -o`, container unit check). An image already gated on the loaded module is not gated again.
#      This build packages nvidia-prolapse only: --mode venus and --mode glibc-shim are rejected with the reason
#      rather than accepted and left to fail later;
#   5. stops the Waydroid container for the switch, then enables and starts waydroid-container.service.
# Any failure stops with the reason and the remedy and puts the previous image and configuration back.
# --restore-official-vendor puts the official vendor image back and returns waydroid.cfg to stock Waydroid (no
# nvidia_* keys).
#
# The display refresh rate needs no option: hwcomposer reports the fastest current mode of your outputs.
# --refresh <hz> (1-1000) is an override that pins the rate hwcomposer reports (persist.waydroid.refresh_rate,
# e.g. half your monitor's rate); --refresh auto removes an override set earlier.
#
# The guest properties below are ours, layered on top of the mode selection. They are written into waydroid.cfg
# rather than set with `waydroid prop set`, which needs a running session and would be lost on the next
# `waydroid upgrade`. Each one clears its own properties again when omitted.
#
# --size <WxH>: initial guest display size (persist.waydroid.width/height). The guest hwcomposer also follows
# xdg_toplevel configure events, so a *floating* window can be drag-resized and the display follows; this only sets
# the size it starts at. Omit to let the display follow the window/output.
#
# --density <dpi>: Android display density (ro.sf.lcd_density) — the actual "scaling" knob. Resizing the window
# changes the display *resolution* (more or less workspace at the same pixel size); density is what makes everything
# bigger or smaller. 160 is 1x/mdpi, 240 is phone-like. SurfaceFlinger logs
# "ro.sf.lcd_density must be defined as a build property" when unset, which is cosmetic, but this silences it.
#
# --multi-windows: give each Android app its own toplevel window instead of one Android desktop in a single
# surface — much better behaved under a tiling WM, and it sidesteps single-surface resize negotiation entirely.
#
# --mouse-fix: makes click-and-drag register as a touch gesture (scroll/swipe) instead of mouse-style click-drag
# (text selection, carousels ignoring drag). fake_touch is NOT a boolean despite its name — it is a
# comma-separated, wildcard-capable list of package names to treat as touch
# (docs.waydro.id/usage/waydroid-prop-options); "*" applies to every app. An upstream fork script sets it to the
# literal string "1", which matches no package and silently does nothing — confirmed independently by
# github.com/waydroid/waydroid/issues/1613. Pointer speed is a guest setting, not a prop: use
# `waydroid-nvidia-tweak --mouse`.
#
# --device-spoof: present as a real phone (default HUAWEI P30 Pro) instead of 'waydroid'/'unknown', which apps like
# AnTuTu treat as an instant emulator tell. Override any field with SPOOF_MODEL / SPOOF_BRAND / SPOOF_DEVICE /
# SPOOF_HARDWARE / SPOOF_PLATFORM / SPOOF_SOC / SPOOF_CHIPNAME / SPOOF_BOARD / SPOOF_API_LEVEL — override them
# together, or the identity is a mix and tells more than it hides.
#
# --hwui-gl: route app rendering through GL (skiagl) instead of Vulkan (skiavk). A fallback for apps that misrender
# on the in-guest driver — notably WebView/Chrome, whose Vulkan draw functor is the usual culprit. Still
# GPU-accelerated (GL goes through ANGLE), but it gives up the direct Vulkan path, so only reach for it when a
# specific app needs it. Try `waydroid-nvidia-tweak --webview-gl` first: that fixes WebView alone and leaves
# everything else on Vulkan.
#
# --arm-translation: install Intel libhoudini so ARM-only apps run (a large share of the Play Store is ARM-only).
# Unpacks into /var/lib/waydroid/overlay/system, which the container overlays onto the guest's /system, and sets the
# abilist / native-bridge properties. Proprietary Intel code, hash-pinned from the same archive waydroid_script
# uses. Omitting the flag removes both the files and the properties again.
#
# Ported from upstream packaging/aur/waydroid-nvidia-bin/waydroid-nvidia-setup: the guest payload, the driver
# tooling and the vendor image come from the Nix store, all via the environment the wrapper exports.
set -euo pipefail
# Tool output parsed here and in every child (readelf, debugfs, lxc-info, systemctl, ...) is the untranslated text
export LC_ALL=C
unset LANGUAGE

die() { echo "waydroid-nvidia-setup: $*" >&2; exit 1; }
say() { echo "== $*"; }

REFRESH="" MODE_ARG="" GL_ARG="" RESTORE=0 SYSTEM_TYPE=""
SIZE="" DENSITY="" MULTI_WINDOWS=0 MOUSE_FIX=0 DEVICE_SPOOF=0 HWUI_GL=0 ARM_TRANSLATION=0
while [ $# -gt 0 ]; do
    case "$1" in
        --restore-official-vendor) RESTORE=1; shift ;;
        -s|--system-type|--system_type)
            SYSTEM_TYPE="${2:?$1 needs VANILLA, GAPPS or FOSS}"; SYSTEM_TYPE="${SYSTEM_TYPE^^}"
            [[ "$SYSTEM_TYPE" =~ ^(VANILLA|GAPPS|FOSS)$ ]] ||
                die "$1 takes VANILLA, GAPPS (with Google apps) or FOSS, as 'waydroid init -s' does"
            shift 2 ;;
        --refresh) REFRESH="${2:?--refresh needs a value}"; shift 2
                   [[ "$REFRESH" == auto || ( "$REFRESH" =~ ^[0-9]+$ && "$REFRESH" -ge 1 && "$REFRESH" -le 1000 ) ]] ||
                       die "--refresh takes a number of Hz (1-1000) or auto" ;;
        --mode) MODE_ARG="${2:?--mode needs nvidia-prolapse}"; shift 2
                [[ "$MODE_ARG" =~ ^(nvidia-prolapse|glibc-shim|venus)$ ]] || die "--mode is nvidia-prolapse" ;;
        # Only nvidia-prolapse is packaged here: no Venus renderer is installed and glibc-shim needs the host's
        # 32-bit NVIDIA libraries inside the guest.
        venus|glibc-shim)
            die "--mode $1 is not available in this build; only nvidia-prolapse is packaged" ;;
        --native-gl) GL_ARG="${2:?--native-gl needs on or off}"; shift 2
                     [[ "$GL_ARG" =~ ^(on|off)$ ]] || die "--native-gl is on or off" ;;
        --size) SIZE="${2:?--size needs WxH}"; shift 2 ;;
        --density) DENSITY="${2:?--density needs a dpi value}"; shift 2 ;;
        --multi-windows) MULTI_WINDOWS=1; shift ;;
        --mouse-fix) MOUSE_FIX=1; shift ;;
        --device-spoof) DEVICE_SPOOF=1; shift ;;
        --hwui-gl) HWUI_GL=1; shift ;;
        --arm-translation) ARM_TRANSLATION=1; shift ;;
        -h|--help) awk '/^# waydroid-nvidia-setup/ { on = 1 } /^set -euo pipefail/ { exit } on' "$0"; exit 0 ;;
        *) die "unknown argument: $1 (see --help)" ;;
    esac
done
# Only nvidia-prolapse is packaged here: no Venus renderer is installed and glibc-shim needs the host's 32-bit
# NVIDIA libraries inside the guest.
case "${MODE_ARG:-}" in
    venus|glibc-shim)
        die "--mode $MODE_ARG is not available in this build; only nvidia-prolapse is packaged" ;;
esac
# After the argument checks, not before: --help and the rejected modes above are answers a non-root caller should
# still get, and upstream's ordering hid them behind the root error.
[ "$(id -u)" = 0 ] || die "must run as root (sudo waydroid-nvidia-setup)"

CFG=/var/lib/waydroid/waydroid.cfg
LIB="${WAYDROID_NVIDIA_LIB:?WAYDROID_NVIDIA_LIB must be set by the wrapper}"
GUEST="${WAYDROID_NVIDIA_GUEST_SRC:?WAYDROID_NVIDIA_GUEST_SRC must be set by the wrapper}"
VENDOR="${WAYDROID_NVIDIA_VENDOR_SRC:?WAYDROID_NVIDIA_VENDOR_SRC must be set by the wrapper}"
NATIVE=$LIB/native
BUNDLE=$NATIVE/release
NV_GUEST=/var/lib/waydroid/nv/guest
VENDOR_TOOL="python3 $NATIVE/packaging/native/vendor_image.py"
[ -d "$GUEST" ] || die "$GUEST missing (broken package?)"
if [ "$RESTORE" = 1 ]; then
    [ -z "$MODE_ARG$GL_ARG$REFRESH$SYSTEM_TYPE$SIZE$DENSITY" ] &&
        [ "$MULTI_WINDOWS$MOUSE_FIX$DEVICE_SPOOF$HWUI_GL$ARM_TRANSLATION" = 00000 ] ||
        die "--restore-official-vendor takes no other option"
fi

lxc_state() {   # call as state=$(lxc_state): a failure then stops the setup
    local out
    out=$(lxc-info -P /var/lib/waydroid/lxc -n waydroid -sH 2>&1) ||
        die "lxc-info cannot read the Waydroid container: $out
Remedy: sudo waydroid upgrade -o (regenerates /var/lib/waydroid/lxc/waydroid/config for this LXC), then re-run this
setup; if LXC still rejects the config, report this message"
    echo "$out"
}
WAS_ACTIVE=0
systemctl is-active --quiet waydroid-container.service && WAS_ACTIVE=1
stop_container() {
    local state
    state=$(lxc_state)
    if [ "$state" != STOPPED ] || systemctl is-active --quiet waydroid-container.service; then
        say "stopping the Waydroid container for the switch (a running session ends)"
        systemctl stop waydroid-container.service
        for _ in $(seq 30); do state=$(lxc_state); [ "$state" = STOPPED ] && break; sleep 1; done
        [ "$state" = STOPPED ] ||
            die "the Waydroid container did not stop; stop it (waydroid session stop; systemctl stop waydroid-container) and re-run"
    fi
}
restart() {   # after a failure: back to the state we found
    if [ "$WAS_ACTIVE" = 1 ]; then say "starting waydroid-container.service again"; systemctl start waydroid-container.service; fi
}
RENDER_UNIT=sys-subsystem-waydroid_nvidia-render.device
render_unit_up() {
    # The unit exists only if a udev rule tags the NVIDIA render node with SYSTEMD_ALIAS=/sys/subsystem/
    # waydroid_nvidia/render. Upstream's 70-waydroid-nvidia-gpu.rules does; this config has no equivalent, so the
    # unit is absent and the container's ordering dependency on it (which the NixOS module declares) is simply a
    # no-op. Nothing here depends on it for the container to start, so a missing unit is reported, not fatal.
    if [ "$(systemctl show -p LoadState --value "$RENDER_UNIT" 2>/dev/null)" = not-found ]; then
        say "note: no udev rule names $NVNODE as $RENDER_UNIT, so the container cannot be made to wait for the"
        say "      GPU at boot; the container starts on its own and may race the NVIDIA modules' init"
        return 0
    fi
    # A rule installed after the node appeared applies from the node's next uevent, so replay one, then wait for
    # systemd to see the unit (a device unit's start job waits until the device appears, up to
    # DefaultDeviceTimeoutSec).
    systemctl is-active --quiet "$RENDER_UNIT" && return 0
    udevadm trigger --action=change "/sys/class/drm/${NVNODE#/dev/dri/}" ||
        die "udevadm trigger on $NVNODE failed (see above)"
    systemctl start "$RENDER_UNIT" && systemctl is-active --quiet "$RENDER_UNIT" ||
        die "$NVNODE did not become the systemd device $RENDER_UNIT (check: udevadm info $NVNODE | grep -E 'TAGS|SYSTEMD_ALIAS')"
    say "NVIDIA render node $NVNODE is $RENDER_UNIT (the container waits for it at boot)"
}
start() {
    render_unit_up
    say "enabling and starting waydroid-container.service"
    systemctl enable --now waydroid-container.service
}
is_our_image() {   # the booted vendor.img carries the nvidia-prolapse identity props
    python3 -I -c 'import configparser,os,subprocess,sys
c=configparser.ConfigParser(); c.read(sys.argv[1])
img=os.path.join(c.get("waydroid","images_path",fallback="/var/lib/waydroid/images"),"vendor.img")
out=subprocess.run(["debugfs","-R","cat /build.prop",img],capture_output=True).stdout.decode(errors="replace")
sys.exit(0 if "\nro.vendor.nvidia_prolapse.version=" in "\n"+out else 1)' "$CFG"
}

if [ "$RESTORE" = 1 ]; then
    [ -f "$CFG" ] || die "$CFG missing: Waydroid is not initialized, nothing to restore"
    stop_container
    $VENDOR_TOOL restore-official || { restart; die "the official vendor image was not restored (see above)"; }
    say "returning waydroid.cfg to stock Waydroid (no nvidia_* keys)"
    python3 -I - "$CFG" <<'EOF'
import configparser, sys
cp = configparser.ConfigParser()
cp.optionxform = str
cp.read(sys.argv[1])
for k in [k for k in cp["waydroid"] if k.startswith("nvidia_")]:
    print("   removing " + k + " = " + cp["waydroid"][k], file=sys.stderr)
    del cp["waydroid"][k]
with open(sys.argv[1], "w") as f:
    cp.write(f)
EOF
    waydroid upgrade -o || die "'waydroid upgrade -o' failed (see above)"
    restart
    echo "Done: the official vendor image is back and waydroid.cfg is stock Waydroid's."
    exit 0
fi
if [ ! -f "$CFG" ]; then
    if [ -n "$SYSTEM_TYPE" ]; then
        say "Waydroid is not initialized: running 'waydroid init -s $SYSTEM_TYPE' (official LineageOS 20 images)"
        waydroid init -s "$SYSTEM_TYPE" || die "waydroid init -s $SYSTEM_TYPE failed (see above)"
    else
        say "Waydroid is not initialized: running 'waydroid init' (official LineageOS 20 images without Google apps;
   for Google apps press Ctrl+C now and run 'sudo waydroid-nvidia-setup -s GAPPS' instead)"
        waydroid init || die "waydroid init failed (see above)"
    fi
    [ -f "$CFG" ] || die "waydroid init wrote no $CFG"
    # init leaves the nvidia-prolapse vendor image to this setup (it said so above): it is installed below
elif [ -n "$SYSTEM_TYPE" ]; then
    # system_ota = <channel>/<rom>/waydroid_<arch>/<system type>.json (upstream init), "None" for preinstalled images
    SYSTEM_OTA=$(python3 -I -c 'import configparser,sys; c=configparser.ConfigParser(); c.read(sys.argv[1]); print(c.get("waydroid","system_ota",fallback=""))' "$CFG")
    CURRENT_TYPE=$(basename -- "$SYSTEM_OTA" .json)
    if [ "$CURRENT_TYPE" = "$SYSTEM_TYPE" ]; then
        say "Waydroid is initialized with the $SYSTEM_TYPE system image"
    elif [[ "$SYSTEM_OTA" != */*.json ]]; then
        die "-s $SYSTEM_TYPE: Waydroid is initialized from images it does not download (system_ota = ${SYSTEM_OTA:-unset}
in $CFG), so the system type is whatever system.img is installed there. Without -s this setup keeps it."
    else
        printf -v SWITCH '  %-34s %s\n  %-34s %s' "sudo waydroid init -f -s $SYSTEM_TYPE" \
            "(downloads the $SYSTEM_TYPE images; apps and data are kept)" \
            "sudo waydroid-nvidia-setup" "(installs the nvidia-prolapse vendor image again)"
        die "-s $SYSTEM_TYPE: Waydroid is already initialized with the $CURRENT_TYPE system image (system_ota = $SYSTEM_OTA).
This setup does not re-initialize an existing install. To switch to $SYSTEM_TYPE:
$SWITCH
Or keep $CURRENT_TYPE: run this setup without -s."
    fi
fi
for tool in readelf debugfs python3 unshare lxc-info; do
    command -v "$tool" >/dev/null 2>&1 || die "$tool is required"
done

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
    vendor/lib64/hw/hwcomposer.waydroid.so
)
GUEST_BINS=(system/bin/surfaceflinger)

verify_android_elf() {
    local file="$1" abi="$2" expected_soname="${3:-}"
    local expected_class expected_machine header dynamic actual_soname
    case "$abi" in
        x86) expected_class=ELF32; expected_machine="Intel 80386" ;;
        x86_64) expected_class=ELF64; expected_machine="Advanced Micro Devices X86-64" ;;
        *) die "internal error: unsupported Android ABI '$abi'" ;;
    esac
    [ -f "$file" ] || die "required guest payload missing: $file (reinstall the package)"
    header=$(readelf -hW -- "$file" 2>/dev/null) || die "$file is not a complete ELF file"
    if ! grep -Eq "^[[:space:]]*Class:[[:space:]]+${expected_class}[[:space:]]*$" <<<"$header" ||
       ! grep -Eq "^[[:space:]]*Machine:[[:space:]]+${expected_machine}[[:space:]]*$" <<<"$header" ||
       ! grep -Eq '^[[:space:]]*Type:[[:space:]]+DYN([[:space:]]|$)' <<<"$header"; then
        die "$file is not an $expected_class/$expected_machine shared object"
    fi
    if [ -n "$expected_soname" ]; then
        dynamic=$(readelf -dW -- "$file" 2>/dev/null) || die "cannot read the dynamic section from $file"
        actual_soname=$(sed -n 's/.*(SONAME).*Library soname: \[\([^]]*\)\].*/\1/p' <<<"$dynamic")
        [ "$actual_soname" = "$expected_soname" ] ||
            die "$file has SONAME '${actual_soname:-<missing>}' (expected '$expected_soname')"
    fi
}

NVNODE=""
for uevent in /sys/class/drm/renderD*/device/uevent; do
    [ -e "$uevent" ] || continue
    if grep -qx "DRIVER=nvidia" "$uevent"; then NVNODE="/dev/dri/$(basename "${uevent%/device/uevent}")"; break; fi
done
[ -n "$NVNODE" ] || die "no NVIDIA render node under /dev/dri (is the NVIDIA driver loaded? nvidia-drm.modeset=1?)"
say "NVIDIA render node: $NVNODE"

# nvidia-drm.modeset=1 is required: without it the driver exposes no dma-buf support (no
# VK_EXT_external_memory_dma_buf, zero exportable modifiers) and the guest crash-loops on its first buffer.
MODESET=$(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null || echo missing)
[ "$MODESET" = "Y" ] || die "nvidia-drm.modeset is not enabled (got: $MODESET).
Add nvidia_drm.modeset=1 to your kernel parameters or modprobe.d and reboot."
say "nvidia-drm.modeset: Y"

say "writing waydroid.cfg"
MODE=$(REFRESH="$REFRESH" NVNODE="$NVNODE" MODE_ARG="$MODE_ARG" GL_ARG="$GL_ARG" \
       SIZE="$SIZE" DENSITY="$DENSITY" MULTI_WINDOWS="$MULTI_WINDOWS" MOUSE_FIX="$MOUSE_FIX" \
       DEVICE_SPOOF="$DEVICE_SPOOF" HWUI_GL="$HWUI_GL" ARM_TRANSLATION="$ARM_TRANSLATION" \
       python3 -I - "$CFG" <<'EOF'
import configparser, os, sys
cfg_path = sys.argv[1]
cp = configparser.ConfigParser()
cp.optionxform = str  # waydroid props are case-sensitive
cp.read(cfg_path)
for section in ("waydroid", "properties"):
    if not cp.has_section(section):
        cp.add_section(section)
w, props = cp["waydroid"], cp["properties"]
props_before = dict(props)
log = lambda text: print("   " + text, file=sys.stderr)
# Old gralloc overrides (the software-rendering workaround ro.hardware.gralloc=default, gralloc.gbm.legacy of
# migrated installs) block the guest's minigbm selection and crash-loop SurfaceFlinger (issue #1).
for k in list(props):
    if k == "ro.hardware.gralloc" or k.startswith("gralloc."):
        log("removing stale gralloc override: {} = {}".format(k, props[k]))
        del props[k]
# The Venus stack this package used to provision wrote [waydroid] keys that v0.2.0 reads as retired path keys and
# refuses the whole configuration over (nvidia_native.driver_mode), so the container would not start at all after
# the switch. Removing them is the migration; they are never written back.
for k in ("nvidia_native_root", "nvidia_rust_driver_root", "nvidia_glibc_shim_root", "nvidia_venus_socket"):
    if k in w:
        log("removing retired nvidia_* key: {} = {}".format(k, w[k]))
        del w[k]
values = {
    "debug.hwui.renderer": "skiavk",
    "debug.renderengine.backend": "skiaglthreaded",
    "debug.sf.nobootanimation": "1",
    "persist.waydroid.use_subsurface": "true",
    "ro.surface_flinger.vsync_event_phase_offset_ns": "0",
    "ro.surface_flinger.vsync_sf_event_phase_offset_ns": "0",
    "ro.surface_flinger.max_frame_buffer_acquired_buffers": "3",
}
# debug.sf.snap_to_same_vsync_within_ns is derived at every container start from the refresh rate
# hwcomposer reports (nvidia_native.session_properties); a value from an earlier setup would be ignored.
if props.pop("debug.sf.snap_to_same_vsync_within_ns", None) is not None:
    log("removing debug.sf.snap_to_same_vsync_within_ns (now set at every container start for your display)")
refresh = os.environ.get("REFRESH", "")
if refresh == "auto":
    if props.pop("persist.waydroid.refresh_rate", None) is not None:
        log("removing the refresh override persist.waydroid.refresh_rate (hwcomposer follows your outputs)")
elif refresh:
    values["persist.waydroid.refresh_rate"] = refresh
elif "persist.waydroid.refresh_rate" in props:
    log("keeping the refresh override persist.waydroid.refresh_rate = {} (--refresh auto removes it)".format(
        props["persist.waydroid.refresh_rate"]))
for k, v in values.items():
    props[k] = v

# Ours, and only now: upstream writes debug.hwui.renderer = skiavk above, so a --hwui-gl applied any earlier would
# be overwritten without a word.
if os.environ.get("HWUI_GL") == "1":
    props["debug.hwui.renderer"] = "skiagl"
    log("app rendering forced to GL (skiagl) instead of Vulkan")

size = os.environ.get("SIZE", "")
if size:
    width, _, height = size.lower().partition("x")
    if not (width.isdigit() and height.isdigit()):
        sys.exit("--size must look like 1280x800")
    props["persist.waydroid.width"] = width
    props["persist.waydroid.height"] = height
else:
    for k in ("persist.waydroid.width", "persist.waydroid.height"):
        if cp.has_option("properties", k):
            log("clearing {} (display follows the window)".format(k))
            cp.remove_option("properties", k)

if os.environ.get("MULTI_WINDOWS") == "1":
    props["persist.waydroid.multi_windows"] = "true"
elif cp.has_option("properties", "persist.waydroid.multi_windows"):
    log("clearing persist.waydroid.multi_windows (single-window mode)")
    cp.remove_option("properties", "persist.waydroid.multi_windows")

if os.environ.get("MOUSE_FIX") == "1":
    props["persist.waydroid.cursor_on_subsurface"] = "false"
    props["persist.waydroid.fake_touch"] = "*"
elif any(cp.has_option("properties", k) for k in
         ("persist.waydroid.cursor_on_subsurface", "persist.waydroid.fake_touch")):
    log("clearing mouse-fix properties")
    for k in ("persist.waydroid.cursor_on_subsurface", "persist.waydroid.fake_touch"):
        cp.remove_option("properties", k)

# Present as a real phone: 'waydroid' and 'unknown' are instant emulator tells.
# The property names --device-spoof writes. Fixed regardless of which SPOOF_* values are in play, which is what lets
# the clearing branch below remove them exactly. Kept as a named constant so the set-path and the clear-path cannot
# drift apart; the assert inside the set-path enforces that.
SPOOF_KEYS = [
    "ro.product.brand", "ro.product.manufacturer", "ro.product.model",
    "ro.product.device", "ro.product.name", "ro.product.board",
    "ro.product.first_api_level", "ro.system.build.product",
    "ro.system.build.flavor", "ro.build.fingerprint",
    "ro.system.build.description", "ro.build.display.id", "ro.build.tags",
    "ro.build.type", "ro.debuggable", "ro.hardware", "ro.board.platform",
    "ro.soc.model", "ro.hardware.chipname",
] + [
    "ro.product.{}.{}".format(part, field)
    for part in ("system", "vendor", "odm", "system_ext")
    for field in ("brand", "manufacturer", "model", "device", "name")
]
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
    # Fails the run rather than silently leaving a key that the clearing branch would then be unable to remove.
    assert sorted(spoof) == sorted(SPOOF_KEYS), (
        "SPOOF_KEYS is out of sync with the spoof properties: {}".format(
            sorted(set(spoof) ^ set(SPOOF_KEYS))))
    props.update(spoof)
    log("spoofing device identity as {} {} (SoC: {})".format(brand, model, soc))
    # Each field defaults independently, so overriding only brand/model leaves a HUAWEI codename and SoC attached
    # to, say, a Samsung model — an inconsistency that defeats the point of spoofing at all.
    defaults = {"SPOOF_DEVICE": "HWVOG", "SPOOF_HARDWARE": "kirin980",
                "SPOOF_PLATFORM": "kirin980", "SPOOF_CHIPNAME": "kirin980",
                "SPOOF_BOARD": "VOG"}
    if (os.environ.get("SPOOF_BRAND") or os.environ.get("SPOOF_MODEL")):
        stale = [k for k, v in defaults.items() if not os.environ.get(k)]
        if stale:
            log("WARNING: still using HUAWEI defaults for {} —".format(", ".join(sorted(stale))))
            log("a mismatched identity is itself an emulator tell.")
elif any(cp.has_option("properties", k) for k in SPOOF_KEYS):
    # Every other flag here clears its own properties when omitted, and the docs promise exactly that. This
    # branch was missing once, so --device-spoof could not be taken back off: re-running setup without the flag
    # left the identity in place, because cp.read() preserves the existing [properties] section.
    #
    # That is not cosmetic. The spoof rewrites ro.build.fingerprint, and Android binds keystore/gatekeeper state to
    # the device identity — so a spoof applied on top of an existing /data crash-loops
    # android.hardware.gatekeeper@1.0-service once a second, system_server blocks waiting on that HAL, and the
    # session never reaches boot-complete. Observed 2026-09-14: the guest hung at "starting waydroid session" and
    # dropping the flag did not recover it. The keys are fixed regardless of which SPOOF_* values produced them,
    # so removal is exact.
    log("clearing device-spoof properties")
    for k in SPOOF_KEYS:
        cp.remove_option("properties", k)

# ARM translation: the abilist tells Android which ABIs apps may target, and the native-bridge properties point the
# runtime at libhoudini.
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
    log("ARM translation properties set (abilist + native bridge)")
elif any(cp.has_option("properties", k) for k in arm_props):
    log("clearing ARM translation properties")
    for k in arm_props:
        cp.remove_option("properties", k)

# Density is the scaling knob; resizing only changes usable resolution.
density = os.environ.get("DENSITY", "")
if density:
    if not density.isdigit():
        sys.exit("--density must be a number, e.g. 160 or 240")
    props["ro.sf.lcd_density"] = density

w["suspend_action"] = "none"
# Explicit drm_device bypasses upstream gpu.py's nvidia blacklist, so the render node is bind-mounted on
# NVIDIA-only hosts.
w["drm_device"] = os.environ["NVNODE"]
mode = os.environ.get("MODE_ARG") or w.get("nvidia_driver_mode")
if mode == "rust-driver":
    log("nvidia_driver_mode = rust-driver is the development name of nvidia-prolapse")
    mode = "nvidia-prolapse"
if not mode:
    mode = "nvidia-prolapse"
    log("no nvidia_driver_mode in the cfg: using the default nvidia-prolapse")
elif mode not in ("nvidia-prolapse", "glibc-shim", "venus"):
    sys.exit("waydroid-nvidia-setup: unknown nvidia_driver_mode = {!r} in {}; use --mode "
             "nvidia-prolapse|glibc-shim|venus".format(mode, cfg_path))
# nvidia_native_gl is written by the activation below (vendor_image.py --native-gl), so a failed activation leaves
# the previous value
gl = os.environ.get("GL_ARG") or (w.get("nvidia_native_gl") if w.get("nvidia_native_gl") in ("on", "off") else "off")
if mode == "venus" and gl == "on":
    sys.exit("waydroid-nvidia-setup: venus has no GL driver of its own (GLES is ANGLE on Venus): use --native-gl off")
# nvidia_guest_layout is not written: this build installs the vendor image, which binds nothing from
# /var/lib/waydroid/nv/guest, and vendor_image.py drops the key for the same reason.
log("nvidia_driver_mode = {}, nvidia_native_gl = {} (activated below)".format(mode, gl))
with open(cfg_path, "w") as f:
    cp.write(f)
print(mode, int(dict(props) != props_before))
EOF
) || exit 1
read -r MODE PROPS_CHANGED <<<"$MODE"

# ARM translation lives in the system overlay, not nv/guest: it has to appear as part of the guest's /system, which
# is where the container's overlayfs lowerdir points. Only houdini's own paths are touched, so anything else in the
# overlay (gapps and friends) is left alone.
HOUDINI="${WAYDROID_NVIDIA_HOUDINI_SRC:?WAYDROID_NVIDIA_HOUDINI_SRC must be set by the wrapper}"
OVERLAY_SYSTEM=/var/lib/waydroid/overlay/system
HOUDINI_PATHS=(
    bin/arm bin/arm64 bin/houdini bin/houdini64
    etc/binfmt_misc etc/init/houdini.rc
    lib/arm lib/libhoudini.so
    lib64/arm64 lib64/libhoudini.so
)
if [ "$ARM_TRANSLATION" = 1 ]; then
    say "installing ARM translation (libhoudini) into $OVERLAY_SYSTEM"
    [ -d "$HOUDINI/system" ] || die "$HOUDINI/system missing (broken houdini package?)"
    for rel in "${HOUDINI_PATHS[@]}"; do
        rm -rf "$OVERLAY_SYSTEM/$rel"
    done
    install -d -m 0755 "$OVERLAY_SYSTEM"
    cp -r --no-preserve=ownership "$HOUDINI/system/." "$OVERLAY_SYSTEM/"
    # Store files come out read-only; the guest only reads them, but a re-run has to be able to replace them.
    chmod -R u+w "$OVERLAY_SYSTEM"
    say "libhoudini installed (ARM + ARM64 translation)"
elif [ -e "$OVERLAY_SYSTEM/lib/libhoudini.so" ]; then
    say "removing ARM translation (--arm-translation not given)"
    for rel in "${HOUDINI_PATHS[@]}"; do
        rm -rf "$OVERLAY_SYSTEM/$rel"
    done
    say "libhoudini removed"
fi

install_guest_stack() {   # validate the layout-2 guest files (ANGLE, hwcomposer, SurfaceFlinger; the Venus driver)
    local rel abi soname
    say "validating the guest payload (both ABIs)"
    for rel in "${GUEST_LIBS[@]}"; do
        case "$rel" in vendor/lib/*) abi=x86 ;; vendor/lib64/*) abi=x86_64 ;; esac
        case "$rel" in */hw/vulkan.virtio.so) soname=libvulkan_virtio.so ;; *) soname=$(basename -- "$rel") ;; esac
        verify_android_elf "$GUEST/$rel" "$abi" "$soname"
    done
    for rel in "${GUEST_BINS[@]}"; do verify_android_elf "$GUEST/$rel" x86_64; done
    echo "   ELF headers, ABIs and SONAMEs verified"
}
copy_guest_stack() {      # ... and install them into $NV_GUEST
    local rel
    say "installing the guest stack into $NV_GUEST"
    install -d -m 0755 "$NV_GUEST"
    for rel in "${GUEST_LIBS[@]}"; do install -Dm 0644 "$GUEST/$rel" "$NV_GUEST/$rel"; done
    for rel in "${GUEST_BINS[@]}"; do install -Dm 0755 "$GUEST/$rel" "$NV_GUEST/$rel"; done
}

if [ "$MODE" = glibc-shim ]; then
    GL=$(python3 -I -c 'import configparser,sys; c=configparser.ConfigParser(); c.read(sys.argv[1]); print(c.get("waydroid","nvidia_native_gl",fallback="off"))' "$CFG")
    [ -z "$GL_ARG" ] || GL=$GL_ARG
    [[ "$GL" =~ ^(on|off)$ ]] || GL=off
    [ -f "$BUNDLE/BUILD-RECORD.json" ] || die "$BUNDLE missing: the release bundle is not installed (reinstall the package)"
    install_guest_stack
    command -v getconf >/dev/null 2>&1 || die "getconf is required (glibc)"
    say "checking this host's NVIDIA driver against the glibc-shim build of this release (nothing changes yet)"
    python3 -I "$NATIVE/packaging/native/glibc_shim.py" check --bundle "$BUNDLE" --native-gl "$GL" ||
        die "glibc-shim mode cannot run on this driver (reason above); nothing was changed"
    stop_container
    if is_our_image; then
        say "putting the official vendor image back (glibc-shim runs on it)"
        $VENDOR_TOOL restore-official || { restart; die "the official vendor image was not restored (see above)"; }
    fi
    copy_guest_stack
    say "staging glibc-shim mode"
    TAG=$(sed -n 's/^waydroid-nvidia packaged install \(.*\)$/\1/p' "$NATIVE/PACKAGED" 2>/dev/null || true)
    python3 -I "$NATIVE/packaging/native/glibc_shim.py" stage --bundle "$BUNDLE" --native-gl "$GL" ${TAG:+--tag "$TAG"} ||
        { restart; die "glibc-shim mode was not staged (see above)"; }
    say "activating glibc-shim mode"
    python3 "$NATIVE/dev/driver-mode" apply glibc-shim --native-gl "$GL" || { restart; die "glibc-shim mode not activated (see above)"; }
    start
    if [ "$GL" = on ]; then GLES="NVIDIA's own"; else GLES="ANGLE on NVIDIA's Vulkan driver"; fi
    cat <<DONE

Done (glibc-shim mode: your host's NVIDIA driver inside Android; GLES: $GLES). As your desktop user:
  waydroid session start
After an NVIDIA driver update and reboot, run this setup again: glibc-shim is staged for the driver version it
checked, and the container refuses to start with another one.
Back to the default mode: sudo waydroid-nvidia-setup --mode nvidia-prolapse
DONE
    exit 0
fi

if [ "$MODE" = venus ]; then
    install_guest_stack

    # The stack hooks the AIDL minigbm gralloc; pre-minigbm vendor images give SurfaceFlinger buffers our
    # driver never sees (issue #1: system and vendor images version independently).
    IMAGES=$(python3 -I -c 'import configparser,sys; c=configparser.ConfigParser(); c.read(sys.argv[1]); print(c.get("waydroid","images_path",fallback="/var/lib/waydroid/images"))' "$CFG")
    VIMG=$IMAGES/vendor.img
    [ -f "$VIMG" ] || die "$VIMG missing: run 'waydroid init' first"
    debugfs -R "stat /lib64/hw/gralloc.minigbm_gbm_mesa.so" "$VIMG" 2>/dev/null | grep -q '^Inode:' ||
        die "vendor image is too old (no minigbm_gbm_mesa gralloc).
Run 'waydroid init -f' to fetch current images (apps/data are kept), then re-run this setup."
    say "vendor image: minigbm AIDL gralloc present"

    stop_container
    if is_our_image; then
        say "putting the official vendor image back (venus runs on it)"
        $VENDOR_TOOL restore-official || { restart; die "the official vendor image was not restored (see above)"; }
    fi
    copy_guest_stack
    say "activating venus mode"
    python3 "$NATIVE/dev/driver-mode" apply venus --native-gl off || { restart; die "venus mode not activated (see above)"; }
    start
    cat <<'EOF'

Done (venus mode). As your desktop user, start the Venus render server, re-login once (udev rule for
/dev/udmabuf), then start the session:
  systemctl --user enable --now wd-venus.service
  waydroid session start
EOF
    exit 0
fi

# ---------------------------------------------------------------- nvidia-prolapse: our vendor image
[ -f "$BUNDLE/BUILD-RECORD.json" ] || die "$BUNDLE missing: the nvidia-prolapse release is not installed (reinstall the package)"
shopt -s nullglob
ZIPS=("$VENDOR"/waydroid-nvidia-vendor-x86_64-*.zip) CHANNELS=("$VENDOR"/waydroid-nvidia-vendor-ota-*.json)
shopt -u nullglob
[ ${#ZIPS[@]} -eq 1 ] && [ ${#CHANNELS[@]} -eq 1 ] ||
    die "$VENDOR must hold exactly one vendor image zip and one channel JSON (has ${#ZIPS[@]} and ${#CHANNELS[@]}); reinstall the package"
stop_container
GLOPT=()
[ -z "$GL_ARG" ] || GLOPT=(--native-gl "$GL_ARG")
if ! $VENDOR_TOOL install --zip "${ZIPS[0]}" --channel "${CHANNELS[0]}" "${GLOPT[@]}"; then
    restart
    die "the nvidia-prolapse vendor image was not installed; the previous image and configuration are back.
The reason is printed above (a failing gate case names its log in /var/lib/waydroid-nvidia/gate-*). Report it
(docs/troubleshooting.md, "Reporting a problem") and run this setup again once it is fixed; to go back to stock
Waydroid meanwhile: sudo waydroid-nvidia-setup --restore-official-vendor"
fi
start
GLES=$(python3 -I -c 'import configparser,sys; c=configparser.ConfigParser(); c.read(sys.argv[1]); print("nvrm" if c.get("waydroid","nvidia_native_gl",fallback="off")=="on" else "ANGLE on our Vulkan")' "$CFG")
cat <<EOF

Done (nvidia-prolapse vendor image, GLES: $GLES). As your desktop user:
  waydroid session start          (or launch Waydroid from the app menu)
Check: sudo waydroid shell dumpsys SurfaceFlinger | grep GLES
After an NVIDIA driver update and reboot, run this setup again: the image is gated on the kernel module it
ran on, and the container refuses to start with another one. Waydroid system OTAs stay official; the vendor
image only changes with this package (waydroid.cfg vendor_ota points at this release).
Official vendor image and stock configuration back: sudo waydroid-nvidia-setup --restore-official-vendor
EOF
