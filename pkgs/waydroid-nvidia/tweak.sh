#!/usr/bin/env bash
# waydroid-nvidia-tweak — guest tweaks that need a running session.
#
#   waydroid-nvidia-tweak [--webview-gl] [--mouse] [--settings] [--all]
#
# Ported from the CinQwQeggs01 fork's scripts/waydroid-guest-customize.sh, which
# real upstream does not carry. Two deliberate differences:
#
#   * it drives the guest with `waydroid shell` instead of adb over TCP — no adb
#     dependency, no listening port, nothing to connect,
#   * it does NOT touch debug.hwui.renderer. Upstream's --webview-gl sets
#     skiagl globally, which would move *all* app rendering off Vulkan/Venus.
#     Fixing WebView alone is enough; if you really want GL everywhere, that is
#     `waydroid-nvidia-setup --hwui-gl`, where it persists properly.
#
# Anything set here lives in guest state (/data and the settings DB), so it
# survives session restarts but not `waydroid init -f`. Properties belong in
# waydroid-nvidia-setup instead.
set -euo pipefail

die() { echo "waydroid-nvidia-tweak: $*" >&2; exit 1; }
step() { echo "== $*"; }
note() { echo "   $*"; }

[ "$(id -u)" = 0 ] || die "must run as root (the guest shell needs it)"

DO_WEBVIEW=0
DO_MOUSE=0
DO_SETTINGS=0

[ $# -gt 0 ] || die "nothing to do — pass --webview-gl, --mouse, --settings or --all"

while [ $# -gt 0 ]; do
    case "$1" in
        --webview-gl) DO_WEBVIEW=1; shift ;;
        --mouse) DO_MOUSE=1; shift ;;
        --settings) DO_SETTINGS=1; shift ;;
        --all) DO_WEBVIEW=1; DO_MOUSE=1; DO_SETTINGS=1; shift ;;
        -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
done

waydroid status 2>/dev/null | grep -q "Session:.*RUNNING" \
    || die "no running session — start one first:
  waydroid session start    (or: waydroid show-full-ui)"

gsh() { waydroid shell -- "$@"; }

if [ "$DO_WEBVIEW" = 1 ]; then
    step "WebView/Chrome: disable the Vulkan draw functor"
    # WebView's Vulkan path is the usual suspect for blank or corrupt web views
    # on Venus. These command-line files are read at WebView startup; /data
    # persists, so this survives session restarts.
    FLAGS='_ --disable-features=WebViewDrawFunctorVulkan,WebViewVulkan,Vulkan,DefaultANGLEVulkan,VulkanFromANGLE'
    for f in /data/local/tmp/webview-command-line /data/local/tmp/chrome-command-line; do
        gsh sh -c "printf '%s\\n' '$FLAGS' > $f && chmod 644 $f" \
            || die "could not write $f in the guest"
        note "wrote $f"
    done
    gsh am force-stop com.google.android.webview >/dev/null 2>&1 || true
    note "WebView restarted; app rendering stays on Vulkan (see --hwui-gl if not enough)"
fi

if [ "$DO_MOUSE" = 1 ]; then
    step "pointer speed for games"
    # The fake_touch/cursor properties are the actual mouse fix and belong to
    # waydroid-nvidia-setup --mouse-fix; only pointer speed is guest state.
    gsh settings put system pointer_speed -4 >/dev/null 2>&1 || true
    note "pointer_speed = -4"
    grep -q "fake_touch" /var/lib/waydroid/waydroid.cfg 2>/dev/null \
        || note "NOTE: run 'waydroid-nvidia-setup --mouse-fix' for the relative-motion properties"
fi

if [ "$DO_SETTINGS" = 1 ]; then
    step "system settings tweaks"
    # Hide developer settings, allow sideloading, and stop the package verifier
    # from phoning home on every install.
    gsh settings put global development_settings_enabled 0 >/dev/null 2>&1 || true
    gsh settings put secure install_non_market_apps 1 >/dev/null 2>&1 || true
    gsh settings put global package_verifier_enable 0 >/dev/null 2>&1 || true
    gsh settings put global verifier_verify_adb_installs 0 >/dev/null 2>&1 || true
    gsh settings put global adb_enabled 1 >/dev/null 2>&1 || true
    note "dev settings hidden, sideloading allowed, package verifier off"
fi

cat <<'EOF'

Done. Restart the session if anything looks half-applied:
  waydroid session stop && waydroid show-full-ui
EOF
