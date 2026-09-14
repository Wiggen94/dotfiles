# Waydroid with NVIDIA GPU acceleration
#
# Desktop-only: the stack requires the Wayland compositor to run on the NVIDIA
# GPU, which rules out the hybrid Intel+NVIDIA laptop (upstream documents
# crashes there) and the Intel-only work laptop.
#
# Design + phasing: docs/superpowers/specs/2026-08-05-waydroid-nvidia-design.md
{
  config,
  lib,
  pkgs,
  ...
}:
let
  wdn = pkgs.callPackage ../../pkgs/waydroid-nvidia { };
  hostLib = "${wdn.host}/lib/waydroid-nvidia";
in
{
  virtualisation.waydroid = {
    enable = true;
    # Patched waydroid: emits this stack's bind-mounts, trusts an explicit
    # drm_device, preflights the Venus socket, supports suspend_action=none.
    package = wdn.waydroid-patched;
  };

  environment.systemPackages = [
    wdn.setup
    wdn.tweak
    wdn.probe
    wdn.host # virgl_test_server / virgl_render_server, for debugging by hand
  ];

  # Venus vtest render server: replays the guest's Vulkan stream on the real
  # GPU. Must be running before a session starts — the patched session manager
  # preflights this socket and refuses to start without it.
  systemd.user.services.wd-venus = {
    description = "Venus render server for waydroid-nvidia";
    wantedBy = [ "default.target" ];

    environment = {
      RENDER_SERVER_EXEC_PATH = "${hostLib}/virgl_render_server";
      # libvirglrenderer.so.1 ships beside the binaries rather than in lib/, so
      # this cannot use makeLibraryPath. The binaries' runpath already covers
      # both entries; this keeps virgl_render_server working when the server
      # execs it.
      LD_LIBRARY_PATH = "${hostLib}:${pkgs.vulkan-loader}/lib";
      # The renderer allocates NVIDIA block-linear buffers through gbm. Set
      # explicitly rather than relying on session variables, which systemd user
      # units do not reliably inherit.
      GBM_BACKEND = "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    };

    serviceConfig = {
      ExecStart = "${hostLib}/virgl_test_server --venus --multi-clients --socket-path /run/waydroid-venus/venus.sock";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  # Socket directory the container bind-mounts as /dev/venus. Sticky
  # world-writable like /tmp, because the server runs as the desktop user rather
  # than root and chmods the socket itself after bind.
  systemd.tmpfiles.rules = [
    "d /run/waydroid-venus 1777 root root -"
  ];

  # The render server needs CPU-mappable gralloc buffers (cursors, screenshots)
  # via /dev/udmabuf, which is root-only by default. uaccess grants the active
  # seat user access by ACL, the same mechanism as /dev/dri render nodes.
  #
  # Redundant on systemd 261, whose own 70-uaccess.rules tags udmabuf — but it
  # does so for libcamera's software ISP, an unrelated reason that could go
  # away. This states the requirement explicitly so it cannot regress silently.
  services.udev.extraRules = ''
    SUBSYSTEM=="misc", KERNEL=="udmabuf", TAG+="uaccess"
  '';

  assertions = [
    {
      assertion = config.hardware.nvidia.modesetting.enable;
      # Without modeset the driver exposes no dma_buf support at all, so the
      # guest can only crash-loop on its first buffer.
      message = "waydroid-nvidia requires hardware.nvidia.modesetting.enable = true";
    }
  ];

  # Fail loudly when the GPU render node has been renumbered out from under
  # the provisioned config, instead of booting to a black screen.
  #
  # `waydroid-nvidia-setup` pins the NVIDIA node into waydroid.cfg's
  # drm_device (upstream's gpu.py blacklists nvidia during auto-detection, so
  # an explicit pin is the only way this stack gets a node at all), and
  # `waydroid upgrade -o` bakes that value into the container's config_nodes.
  # Both are resolved once, at provisioning time — nothing re-checks them per
  # session. So anything that renumbers /dev/dri silently invalidates them.
  #
  # Observed 2026-09-14: Waydroid was provisioned 2026-08-06 while the Intel
  # iGPU still had a DRM node, which put the RTX 5070 Ti at renderD129. The
  # Windows VM passthrough work (modules/system/vm-passthrough.nix, landed
  # 2026-08-12) then bound the iGPU to vfio-pci, it stopped exposing a DRM
  # node, and the NVIDIA card slid down to renderD128. The pinned renderD129
  # no longer existed.
  #
  # That failed as a *black screen*, not an error: the generated mount entry
  # carries lxc's `optional` flag, so the missing node only produced one
  # buried "Failed to mount" line in waydroid.log while the container still
  # reached RUNNING and `waydroid status` still reported a healthy session.
  # The guest simply had no render node, so SurfaceFlinger's RenderEngine
  # SIGABRTed every 5s forever. Dropping `optional` upstream-side would be the
  # direct fix, but that flag is applied by waydroid's own node generator to
  # every entry, so suppressing it for this one node means another patch to
  # carry. Checking before the container starts costs nothing and puts the
  # explanation in `systemctl status` where it will actually be found.
  systemd.services.waydroid-container.serviceConfig.ExecStartPre = [
    (pkgs.writeShellScript "waydroid-drm-preflight" ''
      set -u
      CFG=/var/lib/waydroid/waydroid.cfg
      NODES=/var/lib/waydroid/lxc/waydroid/config_nodes

      # Nothing provisioned yet — `waydroid init` hasn't run. Not our problem.
      [ -e "$CFG" ] || exit 0

      # Same detection `waydroid-nvidia-setup` uses, so the two can't disagree
      # about what the right answer is.
      live=""
      for uevent in /sys/class/drm/renderD*/device/uevent; do
        [ -e "$uevent" ] || continue
        if grep -qx "DRIVER=nvidia" "$uevent"; then
          live="/dev/dri/$(basename "''${uevent%/device/uevent}")"
          break
        fi
      done
      if [ -z "$live" ]; then
        echo "no NVIDIA render node under /dev/dri — is the NVIDIA driver loaded?" >&2
        exit 1
      fi

      stale=0
      pinned=$(sed -n 's/^[[:space:]]*drm_device[[:space:]]*=[[:space:]]*//p' "$CFG" | tail -n1)
      if [ -z "$pinned" ]; then
        # Not fatal on its own: auto-detection may still find a non-NVIDIA
        # node. It just can't find this one, so say so.
        echo "warning: no drm_device pinned in $CFG; auto-detection blacklists nvidia" >&2
      elif [ "$pinned" != "$live" ]; then
        echo "waydroid.cfg pins drm_device=$pinned but the live NVIDIA render node is $live" >&2
        stale=1
      fi

      # The pin is only advisory once config_nodes exists — this is the file
      # that actually decides what gets bind-mounted, so check it directly
      # rather than trusting that it was regenerated from the pin.
      if [ -e "$NODES" ]; then
        mounted=$(sed -n 's#^lxc\.mount\.entry = \(/dev/dri/renderD[0-9]*\) .*#\1#p' "$NODES" | tail -n1)
        if [ -z "$mounted" ]; then
          echo "$NODES bind-mounts no /dev/dri render node at all" >&2
          stale=1
        elif [ "$mounted" != "$live" ]; then
          echo "container config bind-mounts $mounted but the live NVIDIA render node is $live" >&2
          stale=1
        fi
      fi

      [ "$stale" -eq 0 ] || {
        echo "The GPU render node was renumbered after Waydroid was provisioned, so the" >&2
        echo "container would start with no usable /dev/dri node and SurfaceFlinger would" >&2
        echo "crash-loop, showing only a black screen. Re-run provisioning to re-detect it:" >&2
        echo "  sudo waydroid-nvidia-setup --refresh 240 [other flags you use]" >&2
        echo "Omitting a flag CLEARS its effect, so pass the full set — check the current" >&2
        echo "[properties] in $CFG to see which are active." >&2
        exit 1
      }
      exit 0
    '')
  ];

  # Guards against a confirmed container/kernel bug: the waydroid container's
  # binfmt_misc mount is not properly isolated from the host's namespace, so
  # when --arm-translation registers houdini's ARM interpreters, arm_exe/
  # arm_dyn/arm64_exe leak straight onto the HOST's shared binfmt_misc table
  # (confirmed by finding them in /proc/sys/fs/binfmt_misc on the host, which
  # a properly namespaced mount would never expose). That leak is what causes
  # host-wide execve() to fail for everything — grep, sleep, iptables,
  # whatever — for as long as the leaked entries remain, observed up to 22
  # minutes with no other symptom (no PID/memory/disk exhaustion; every file
  # involved was intact throughout). Manually clearing the leaked entries
  # produces instant, complete recovery — confirmed twice, independently, by
  # a live root-shell test and a separate background monitor recovering in
  # the same second. See docs/superpowers/specs/2026-08-05-waydroid-nvidia-design.md.
  #
  # This is not NVIDIA-specific and not particular to this patched waydroid —
  # github.com/waydroid/waydroid/issues/2221 reports the identical pattern
  # (whole-system freeze, ARM translation enabled, forced reboot) on
  # completely different hardware (Intel GPU) and distro (Pop!_OS).
  #
  # The isolated act of registering these patterns does NOT reproduce the
  # leak/freeze on its own (tested directly, 60s clean) — something about the
  # full container boot context is also required. So this runs continuously
  # from boot rather than being triggered around container start, and it must
  # survive the exact failure it exists to catch: detection (`[ -e file ]`)
  # and remediation (`echo -1 > file`) are both pure shell builtins that never
  # fork, so this keeps working even during a total host-wide execve() stall.
  #
  # Poll interval: it's the *presence* of the leaked entries that destabilizes
  # host execve(), not this guard's act of clearing them (confirmed live:
  # stopping the guard entirely still produced a full freeze, ~15s after the
  # leak appeared — clearing sooner shrinks the exposure window rather than
  # causing it). At the old 1s interval, that window was still long enough to
  # transiently fail an unrelated concurrent exec — observed live as
  # virgl_render_server failing to spawn with ENOENT despite the binary
  # existing, right as the guard's own clear fired. 20ms cuts that exposure
  # window by ~50x versus 1s, so keep it — do NOT "fix" the guard's CPU use by
  # lengthening the interval. The cost that made 20ms look expensive was
  # forking `sleep` 50x/second, and the loop now idles on a shell builtin
  # instead (see `idle` below), so the short interval is nearly free.
  systemd.services.waydroid-binfmt-guard = {
    description = "Clear ARM binfmt_misc entries leaked from the waydroid container onto the host";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 1;
      ExecStart = pkgs.writeShellScript "waydroid-binfmt-guard" ''
        set -u
        LOG=/var/log/waydroid-binfmt-guard.log
        # Idle between polls without forking. `sleep 0.02` spawned a process
        # 50x/second for the life of the machine, which cost ~7h of CPU per
        # 1.5 days of uptime — the fork, not the 20ms interval, was the
        # expense. `read -t` is a bash builtin, so the same interval now costs
        # essentially nothing. Fd 9 is opened read-write on a fifo so the
        # shell holds both ends itself: there is no writer to send data and no
        # EOF to race, so the read can only ever end in its timeout. The fifo
        # is unlinked immediately — the open fd keeps it alive, and nothing
        # else should be able to poke at it.
        FIFO=/run/waydroid-binfmt-guard.fifo
        rm -f "$FIFO"
        if mkfifo -m 600 "$FIFO" 2>/dev/null && exec 9<>"$FIFO"; then
          rm -f "$FIFO"
          idle() { read -r -t 0.02 -u 9 _ 2>/dev/null || true; }
        else
          # Fifo unavailable (read-only /run, no coreutils): fall back to the
          # old forking sleep rather than spinning. Correctness is unchanged;
          # only the CPU cost regresses.
          idle() { sleep 0.02 2>/dev/null || true; }
        fi
        # An explicit array, not a space-separated string relying on word
        # splitting: unquoted `for e in $ENTRIES` has been observed to fail
        # to split at all in some shell environments, silently turning the
        # whole loop into one no-op iteration. Array iteration doesn't depend
        # on IFS, so it can't have that failure mode.
        ENTRIES=(arm_exe arm_dyn arm64_exe arm64_dyn)
        while true; do
          for e in "''${ENTRIES[@]}"; do
            f=/proc/sys/fs/binfmt_misc/$e
            if [ -e "$f" ]; then
              echo -1 > "$f" 2>/dev/null
              # printf's %(...)T is a builtin timestamp: no `date` fork, so
              # the log line still gets written during the total execve()
              # stall this guard exists to break.
              { printf '%(%T)T cleared leaked host binfmt_misc entry: %s\n' -1 "$e"; } >> "$LOG" 2>/dev/null || true
            fi
          done
          # Builtin wait (see `idle` above), so unlike the `sleep` this
          # replaced it cannot itself be a casualty of the execve() freeze
          # being cleared. On the fallback path `sleep` failing just makes
          # the loop spin, which reacts faster rather than slower.
          idle
        done
      '';
    };
  };
}
