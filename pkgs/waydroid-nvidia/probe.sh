#!/usr/bin/env bash
# waydroid-nvidia-probe — start a Waydroid session, capture guest and host logs,
# then stop it. Bounded and self-terminating, so a crash-looping guest cannot
# saturate the CPU indefinitely or lock you out of your desktop.
#
#   waydroid-nvidia-probe [--seconds N] [--keep]
#
# Run as your normal user. It asks for sudo once up front — before anything is
# started — because `waydroid logcat` requires root and the sudo credential
# cache is per-tty, so it cannot be acquired later from inside a systemd unit.
#
# Writes:
#   /tmp/waydroid-probe/session.log   host-side session/container output
#   /tmp/waydroid-probe/logcat.log    guest Android log
#   /tmp/waydroid-probe/venus.log     wd-venus (host render server) journal
#   /tmp/waydroid-probe/summary.txt   the lines that usually explain a failure
set -euo pipefail

SECONDS_TO_CAPTURE=60
KEEP=0
OUT=/tmp/waydroid-probe

die() { echo "waydroid-nvidia-probe: $*" >&2; exit 1; }

[ "$(id -u)" != 0 ] || die "run as your normal user, not root
(the session must start in your Wayland session; it elevates for logcat itself)"

while [ $# -gt 0 ]; do
    case "$1" in
        --seconds) SECONDS_TO_CAPTURE="${2:?--seconds needs a value}"; shift 2 ;;
        --keep) KEEP=1; shift ;;
        -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
done

: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    WAYLAND_DISPLAY=$(cd "$XDG_RUNTIME_DIR" && ls -1 wayland-[0-9]* 2>/dev/null | head -1) \
        || die "no Wayland socket in $XDG_RUNTIME_DIR — are you in a Wayland session?"
fi
[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] || die "no Wayland socket at $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
export XDG_RUNTIME_DIR WAYLAND_DISPLAY

# Prime sudo now: once a crash-looping guest is running, the desktop may be too
# unresponsive to type a password into.
echo "== sudo is needed for 'waydroid logcat' (guest log)"
sudo -v || die "sudo authentication failed"

mkdir -p "$OUT"
: > "$OUT/session.log"
: > "$OUT/logcat.log"

# Hard backstop, independent of this script and of the terminal: even if
# everything below wedges, systemd tears the unit down.
BUDGET=$((SECONDS_TO_CAPTURE + 150))
systemctl --user reset-failed wd-probe.service 2>/dev/null || true
echo "== starting session (hard stop after ${BUDGET}s)"
systemd-run --user --unit=wd-probe --collect --quiet \
    --property=RuntimeMaxSec="$BUDGET" \
    --setenv=WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
    --setenv=XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    waydroid session start \
    || die "could not launch the session unit"

stop_session() {
    echo "== stopping session"
    waydroid session stop >>"$OUT/session.log" 2>&1 || true
    systemctl --user stop wd-probe.service 2>/dev/null || true
}
[ "$KEEP" = 1 ] || trap stop_session EXIT

echo "== waiting for the container to report RUNNING"
booted=0
for _ in $(seq 60); do
    sleep 1
    if waydroid status 2>/dev/null | grep -q RUNNING; then booted=1; break; fi
done
[ "$booted" = 1 ] && echo "   session is up" || echo "   never reached RUNNING — capturing anyway"

echo "== capturing guest logcat for ${SECONDS_TO_CAPTURE}s"
sudo -n timeout "$SECONDS_TO_CAPTURE" waydroid logcat >"$OUT/logcat.log" 2>&1 || true

# sys.boot_completed is the only reliable "Android actually finished booting"
# signal; RUNNING only means the container started.
BOOT_COMPLETED=$(sudo -n waydroid prop get sys.boot_completed 2>/dev/null | tr -d '\r\n' || true)

echo "== collecting SurfaceFlinger renderer"
sudo -n timeout 20 waydroid shell dumpsys SurfaceFlinger 2>/dev/null \
    | grep -iE "gles|vulkan|renderengine" | head -20 >"$OUT/surfaceflinger.txt" 2>&1 || true

journalctl --user -u wd-venus.service --since "-10min" --no-pager >"$OUT/venus.log" 2>&1 || true

{
    echo "boot_completed = ${BOOT_COMPLETED:-<unset>}"
    echo
    echo "--- guest errors (venus / angle / gralloc / surfaceflinger / vulkan) ---"
    grep -iE "venus|angle|gralloc|surfaceflinger|vulkan|vtest" "$OUT/logcat.log" 2>/dev/null \
        | grep -iE "\b(E|F)\b|error|fail|fatal|abort|denied" | head -40
    echo
    echo "--- host render server ---"
    grep -iE "error|fail|alloc|disconnect" "$OUT/venus.log" 2>/dev/null | tail -20
    echo
    echo "--- SurfaceFlinger renderer ---"
    cat "$OUT/surfaceflinger.txt" 2>/dev/null
} >"$OUT/summary.txt"

cat "$OUT/summary.txt"

cat <<EOF

Full logs in $OUT:
  logcat.log ($(wc -l <"$OUT/logcat.log" 2>/dev/null || echo 0) lines), session.log, venus.log, surfaceflinger.txt
EOF
