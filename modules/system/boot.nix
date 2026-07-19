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

  # Zram - compressed swap in RAM for emergency overflow
  # Prevents hard freezes when memory fills up during gaming
  zramSwap = {
    enable = true;
    memoryPercent = 15; # ~5GB compressed swap on 32GB system (sufficient for gaming)
  };

  # Early OOM killer - prevents system freezes when RAM fills up
  # More responsive than kernel OOM, kills least important process first
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
    enableNotifications = true;
  };

  # Resolve conflict between earlyoom and smartd
  services.systembus-notify.enable = lib.mkForce true;

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

    # High swappiness is correct for zram (compression is fast, unlike disk)
    "vm.swappiness" = 180;
    # Disable swap readahead — no benefit for zram (no seek penalty)
    "vm.page-cluster" = 0;

    # Better SSD performance - don't cache directory entries as long
    "vm.vfs_cache_pressure" = 50;

    # Increase inotify limits (for IDEs, file watchers)
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 1024;
  };
}
