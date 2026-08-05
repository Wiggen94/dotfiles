#!/usr/bin/env bash
# waydroid-nvidia-probe — start a Waydroid session, capture guest and host logs,
# then stop it. Bounded and self-terminating, so a crash-looping guest cannot
# saturate the CPU indefinitely or lock you out of your desktop.
#
#   waydroid-nvidia-probe [--seconds N] [--keep]
#
#   --seconds N  how long to watch the guest boot (default 90)
#   --keep       leave the session running afterwards
#
# Run as your normal user. It asks for sudo once up front — before anything is
# started — because `waydroid logcat` requires root and the sudo credential
# cache is per-tty, so it cannot be acquired later from inside a systemd unit.
#
# Let it finish. Interrupting stops the session mid-boot, which looks like a
# failure in the logs: Android needs ~30-60s to reach boot_completed, and much
# longer on first boot while it optimises the GAPPS packages.
#
# Logs go to a fresh directory per run under /tmp/waydroid-probe, with
# `latest` symlinked to the most recent.
set -euo pipefail

CAPTURE=90
KEEP=0
BASE=/tmp/waydroid-probe

die() { echo "waydroid-nvidia-probe: $*" >&2; exit 1; }

[ "$(id -u)" != 0 ] || die "run as your normal user, not root
(the session must start in your Wayland session; it elevates for logcat itself)"

while [ $# -gt 0 ]; do
    case "$1" in
        --seconds) CAPTURE="${2:?--seconds needs a value}"; shift 2 ;;
        --keep) KEEP=1; shift ;;
        -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
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

# A fresh directory per run. Some captured files end up owned by root, so
# reusing one directory makes the next run fail on truncation.
mkdir -p "$BASE"
OUT=$(mktemp -d "$BASE/run-XXXXXX")
ln -sfn "$OUT" "$BASE/latest"

# Hard backstop, independent of this script and of the terminal: even if
# everything below wedges, systemd tears the session unit down.
BUDGET=$((CAPTURE + 180))
systemctl --user reset-failed wd-probe.service 2>/dev/null || true
echo "== starting session (hard stop after ${BUDGET}s)"
systemd-run --user --unit=wd-probe --collect --quiet \
    --property=RuntimeMaxSec="$BUDGET" \
    --setenv=WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
    --setenv=XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    waydroid session start \
    || die "could not launch the session unit"

collect() {
    echo "== collecting host-side logs"
    journalctl --user -u wd-venus.service --since "-15min" --no-pager >"$OUT/venus.log" 2>&1 || true
    sudo -n tail -200 /var/lib/waydroid/waydroid.log >"$OUT/session.log" 2>&1 || true

    {
        echo "boot_completed = ${BOOT:-<never>}   (1 = Android finished booting)"
        echo "logcat         = $(wc -l <"$OUT/logcat.log" 2>/dev/null || echo 0) lines"
        echo
        echo "--- renderer in use ---"
        cat "$OUT/surfaceflinger.txt" 2>/dev/null || echo "(not captured)"
        echo
        echo "--- guest graphics errors ---"
        grep -aiE "venus|angle|gralloc|vulkan|vtest|surfaceflinger|minigbm" "$OUT/logcat.log" 2>/dev/null \
            | grep -aiE " [EF] |error|fail|fatal|abort|denied" | head -30 || true
        echo
        echo "--- guest crashes ---"
        grep -aiE "FATAL EXCEPTION|beginning of crash|died|signal [0-9]+ \(SIG" "$OUT/logcat.log" 2>/dev/null \
            | head -15 || true
        echo
        echo "--- host render server ---"
        grep -aiE "error|fail|alloc" "$OUT/venus.log" 2>/dev/null | tail -15 || true
    } >"$OUT/summary.txt"
}

stop_session() {
    if [ "$KEEP" = 1 ]; then
        echo "== leaving the session running (--keep); stop it with: waydroid session stop"
    else
        echo "== stopping session"
        waydroid session stop >>"$OUT/session.log" 2>&1 || true
        systemctl --user stop wd-probe.service 2>/dev/null || true
    fi
    echo "   logs: $OUT (also $BASE/latest)"
}
trap 'echo; echo "!! interrupted — the guest was stopped mid-boot, so these logs are incomplete"; stop_session' INT TERM
trap stop_session EXIT

echo "== waiting for the container to report RUNNING"
for _ in $(seq 60); do
    sleep 1
    waydroid status 2>/dev/null | grep -q RUNNING && break
done
waydroid status 2>/dev/null | grep -q RUNNING \
    && echo "   container is up" \
    || echo "   never reached RUNNING — capturing anyway"

# logcat streams in the background so boot can be polled while it runs.
echo "== capturing guest log for up to ${CAPTURE}s (do not interrupt)"
sudo -n timeout "$CAPTURE" waydroid logcat >"$OUT/logcat.log" 2>&1 &
LOGCAT_PID=$!

# sys.boot_completed is the only trustworthy "Android finished booting" signal:
# `waydroid status` showing RUNNING only means the container started.
BOOT=""
for i in $(seq $((CAPTURE / 5))); do
    sleep 5
    BOOT=$(sudo -n waydroid prop get sys.boot_completed 2>/dev/null | tr -d '\r\n' || true)
    if [ "$BOOT" = "1" ]; then
        echo "   boot_completed after ~$((i * 5))s"
        break
    fi
    if ! kill -0 "$LOGCAT_PID" 2>/dev/null; then
        echo "   logcat ended early at ~$((i * 5))s — the container probably died"
        break
    fi
    printf '   %ss…\n' "$((i * 5))"
done

[ "$BOOT" = "1" ] || echo "   boot_completed never became 1"

echo "== collecting renderer state"
sudo -n timeout 25 waydroid shell dumpsys SurfaceFlinger 2>/dev/null \
    | grep -iaE "gles|vulkan|renderengine|graphicsapi" | head -15 >"$OUT/surfaceflinger.txt" 2>&1 || true

wait "$LOGCAT_PID" 2>/dev/null || true
collect
cat "$OUT/summary.txt"
