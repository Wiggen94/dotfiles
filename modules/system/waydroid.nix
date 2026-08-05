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

  # TEMPORARY DEBUG AID — remove once the --arm-translation investigation is
  # done. Logs to /var/log, not /tmp, specifically so it survives the reboots
  # this bug tends to require, and starts on boot so it's already running
  # before testing begins rather than needing to be restarted by hand each
  # time. Two things per tick: an active exec probe of a few common binaries
  # (the actual observed symptom is "file exists but cannot execute: required
  # file not found" for things like grep/sleep, not deletion — a plain
  # existence check would miss that), and a watch for any GC/rebuild activity
  # that might correlate.
  systemd.services.wd-freeze-watch = {
    description = "TEMP: watch for transient exec failures during waydroid-nvidia --arm-translation testing";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 1;
      ExecStart = pkgs.writeShellScript "wd-freeze-watch" ''
        set -u
        OUT=/var/log/wd-freeze-watch.log
        while true; do
          ts=$(date +%T.%3N)
          avail=$(${pkgs.coreutils}/bin/df --output=avail / | tail -1 | tr -d ' ')
          for bin in grep sleep ls cat; do
            path=$(${pkgs.coreutils}/bin/command -v "$bin" 2>/dev/null || true)
            if [ -n "$path" ]; then
              if ! "$path" --version >/dev/null 2>/tmp/wd-probe-err; then
                echo "$ts EXEC-FAIL $bin ($path): $(cat /tmp/wd-probe-err 2>/dev/null)" >> "$OUT"
              fi
            else
              echo "$ts NOT-ON-PATH $bin" >> "$OUT"
            fi
          done
          gc=$(${pkgs.systemd}/bin/journalctl --since "-2s" --no-pager 2>/dev/null \
            | ${pkgs.gnugrep}/bin/grep -icE "collect-garbage|deleting unused|nix-daemon.*delet|nh-clean|nixos-rebuild|switch-to-configuration" || true)
          if [ "''${gc:-0}" -gt 0 ]; then
            echo "$ts GC-ACTIVITY:" >> "$OUT"
            ${pkgs.systemd}/bin/journalctl --since "-2s" --no-pager 2>/dev/null \
              | ${pkgs.gnugrep}/bin/grep -iE "collect-garbage|deleting unused|nix-daemon.*delet|nh-clean|nixos-rebuild|switch-to-configuration" >> "$OUT"
          fi
          echo "$ts heartbeat avail=''${avail}K" >> "$OUT"
          ${pkgs.coreutils}/bin/sleep 2
        done
      '';
    };
  };
}
