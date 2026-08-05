#!/usr/bin/env bash
# waydroid-nvidia-fetch-payload — download the Waydroid guest driver payload
# from upstream CI into the local payload directory.
#
#   waydroid-nvidia-fetch-payload [--run <id> | --latest]
#
# Run as your normal user: the artifacts are auth-gated, so this needs your own
# `gh` credentials. It elevates with sudo only to install the files.
#
# The payload is not vendored in nix-config because the two Venus drivers are
# 54 MB and upstream rebuilds them weekly — that would grow git history
# permanently. Host and guest halves must come from the SAME upstream build;
# mixing them across upstream's Venus fixes yields
# VTEST_CLIENT_ERROR_COMMAND_DISPATCH and a crash loop.
#
# CI artifacts expire 90 days after their run. When the pinned run expires, use
# --latest, and bump ciRunId/upstreamRev in default.nix along with the vendored
# host binaries in prebuilt/host (they must match).
set -euo pipefail

REPO=CinQwQeggs01/waydroid-nvidia
DEST="${WAYDROID_NVIDIA_PAYLOAD_DIR:?must be set by the wrapper}"
RUN="${WAYDROID_NVIDIA_CI_RUN:?must be set by the wrapper}"
REV="${WAYDROID_NVIDIA_REV:-unknown}"

ARTIFACTS=(
    guest-vulkan-virtio-x86
    guest-vulkan-virtio-x86_64
    guest-gralloc
    guest-hwcomposer
)

die() { echo "waydroid-nvidia-fetch-payload: $*" >&2; exit 1; }

[ "$(id -u)" != 0 ] || die "run as your normal user, not root — this needs your gh credentials
(it will prompt for sudo only to install the files)"

while [ $# -gt 0 ]; do
    case "$1" in
        --run) RUN="${2:?--run needs a run id}"; shift 2 ;;
        --latest) RUN=latest; shift ;;
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
done

command -v gh >/dev/null || die "gh is required"
gh auth status >/dev/null 2>&1 || die "gh is not authenticated — run: gh auth login"

if [ "$RUN" = latest ]; then
    echo "== resolving latest successful build run"
    RUN=$(gh api "repos/$REPO/actions/runs?status=success&per_page=1" \
        --jq '.workflow_runs[0].id') || die "could not query CI runs"
    [ -n "$RUN" ] || die "no successful CI run found"
fi

HEAD_SHA=$(gh api "repos/$REPO/actions/runs/$RUN" --jq '.head_sha' 2>/dev/null) \
    || die "cannot read CI run $RUN (does it exist?)"
echo "== CI run $RUN (upstream ${HEAD_SHA:0:7})"

if [ "$RUN" = "${WAYDROID_NVIDIA_CI_RUN}" ] && [ "${HEAD_SHA:0:7}" != "$REV" ]; then
    echo "   WARNING: run head ${HEAD_SHA:0:7} does not match the pinned rev $REV" >&2
fi
if [ "$RUN" != "${WAYDROID_NVIDIA_CI_RUN}" ]; then
    cat >&2 <<EOF
   WARNING: this is not the run pinned in default.nix (${WAYDROID_NVIDIA_CI_RUN}).
   The vendored host binaries in pkgs/waydroid-nvidia/prebuilt/host are from the
   pinned run. A guest payload from a different build may not match the host
   renderer — update both together.
EOF
fi

# Expired artifacts still appear in the API but cannot be downloaded, so check
# before spending time on it.
EXPIRED=$(gh api "repos/$REPO/actions/runs/$RUN/artifacts" \
    --jq '[.artifacts[] | select(.expired) | .name] | join(", ")')
[ -z "$EXPIRED" ] || die "artifacts have expired: $EXPIRED
CI artifacts are kept 90 days. Re-run with --latest to use a current build."

WORK=$(mktemp -d)
# shellcheck disable=SC2064  # WORK must expand now, not at trap time
trap "rm -rf '$WORK'" EXIT

for a in "${ARTIFACTS[@]}"; do
    echo "== downloading $a"
    gh run download "$RUN" -R "$REPO" -n "$a" -D "$WORK/payload" \
        || die "failed to download $a from run $RUN"
done

# Artifacts already carry Android-relative paths (vendor/lib64/...), and they
# unpack into a shared tree, so a single install pass preserves the layout.
mapfile -t FILES < <(cd "$WORK/payload" && find . -type f -printf '%P\n' | sort)
[ "${#FILES[@]}" -gt 0 ] || die "downloaded payload is empty"

# Replaced wholesale rather than merged: switching runs must not leave a driver
# from the previous build behind, because a mixed payload fails the same way a
# mismatched host/guest pair does. ANGLE lives in a sibling directory precisely
# so that this wipe cannot destroy a 16 GB build's output.
case "$DEST" in
    /var/lib/waydroid-nvidia/*/) die "refusing to wipe '$DEST' (trailing slash)" ;;
    /var/lib/waydroid-nvidia/?*) : ;;
    *) die "refusing to wipe '$DEST' — expected a path under /var/lib/waydroid-nvidia" ;;
esac
echo "== installing into $DEST (sudo)"
sudo rm -rf -- "$DEST"
for rel in "${FILES[@]}"; do
    sudo install -Dm644 "$WORK/payload/$rel" "$DEST/$rel"
done
printf '%s\n' "run=$RUN" "head=$HEAD_SHA" | sudo tee "$DEST/.provenance" >/dev/null

for rel in "${FILES[@]}"; do
    printf '   %s\n' "$rel"
done

cat <<EOF

Payload installed. Now provision Waydroid with it:
  sudo waydroid-nvidia-setup --refresh 240
EOF
