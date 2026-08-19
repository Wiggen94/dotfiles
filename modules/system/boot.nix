# Boot loader, kernel, plymouth, zram, tmpfs, OOM, sysctl
{
  config,
  pkgs,
  lib,
  inputs,
  hostName,
  ...
}:
{

  # Boot loader
  boot.loader.systemd-boot.enable = true;

  # Use latest stable kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "ntsync" ];

  # Plymouth boot splash (Catppuccin theme)
  boot.plymouth = {
    enable = true;
    theme = "catppuccin-mocha";
    themePackages = [
      (pkgs.catppuccin-plymouth.override { variant = "mocha"; })
    ];
  };
  boot.initrd.systemd.enable = true; # Required for smooth plymouth

  # Memory management (zram, OOM, swappiness) is owned by omarchy's tuning.nix
  # — see modules/omarchy.nix.

  # Use tmpfs for /tmp (faster, auto-clears on reboot)
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "50%"; # Up to 50% of RAM

  # quiet and splash for clean Plymouth boot; nosgx silences the SGX-disabled boot message
  boot.kernelParams = [
    "quiet"
    "splash"
    "nosgx"
  ];

  # Kernel tuning for performance
  boot.kernel.sysctl = {
    # Network performance - BBR congestion control + TCP fastopen
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_fastopen" = 3; # Enable for both client and server

    # Increase inotify limits (for IDEs, file watchers)
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 1024;
  };
}
