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
  # — see modules/omarchy.nix. Two deliberate overrides, desktop only.
  #
  # `desktop` is the only host with no disk swap: laptop and sikt each declare a
  # swap partition in their hardware-configuration.nix, desktop declares
  # `swapDevices = [ ]`. So omarchy's zram at 100% of RAM was the *entire* swap
  # tier, which bites in two ways — both measured 2026-09-16 while gaming:
  #
  #   1. zram holds its pages in RAM. At the observed 2.47x zstd ratio, evicting
  #      10 GB returns only ~6 GB and keeps ~4 GB, so under real pressure reclaim
  #      can thrash without ever recovering RAM. Diablo IV ended up with 4 GB of
  #      its working set in zram, faulting it back at ~150/s while the kernel
  #      kept pushing more out — continuous micro-stutter.
  #   2. Nothing sits below zram, so the step after "zram-backed RAM exhausted"
  #      is systemd-oomd killing a process (tuning.nix arms it on app.slice with
  #      ManagedOOMSwap = kill), not spilling to disk.
  #
  # Halving zram caps how much RAM it can hold hostage; the swapfile gives
  # genuinely cold pages somewhere to go that is not RAM, and is the OOM
  # backstop. Priority 10 keeps it strictly below zram's 100, so it is overflow
  # only — hot anon pages still land in zram (~10us/fault) and reach the NVMe
  # (~100us/fault) only once zram is full.
  #
  # swappiness stays at omarchy's 150: the kernel has no per-device swappiness,
  # and zram is still the first tier every eviction goes to.
  zramSwap.memoryPercent = lib.mkIf (hostName == "desktop") 50;

  # nixpkgs' mkswap-* service detects a btrfs parent and creates this with
  # `btrfs filesystem mkswapfile`, which sets NODATACOW — and therefore opts the
  # file out of the fs-wide compress=zstd:3 — on its own. No dedicated nocow
  # subvolume needed. Verified prerequisites on nvme0n1p2: single data profile,
  # no subvolumes, no snapshots (btrfs refuses a swapfile on a snapshotted
  # subvolume). swapDevices is a list option, so this concatenates with the
  # empty list in hosts/desktop/hardware-configuration.nix rather than clashing.
  swapDevices = lib.optionals (hostName == "desktop") [
    {
      device = "/swapfile";
      size = 16 * 1024; # MiB
      priority = 10; # below zram's 100
    }
  ];

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
