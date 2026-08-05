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
  # Pacing uses real `sleep` in the normal case (efficient — this idles for
  # the vast majority of every boot, since arm-translation is off by default)
  # and falls back to a builtin busy-wait only if `sleep` itself starts
  # failing — which is exactly when tighter, guaranteed-working polling
  # matters most anyway.
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
              { echo "$(date +%T 2>/dev/null) cleared leaked host binfmt_misc entry: $e"; } >> "$LOG" 2>/dev/null || true
            fi
          done
          sleep 1 2>/dev/null || { SECONDS=0; while (( SECONDS < 1 )); do :; done; }
        done
      '';
    };
  };
}
