# Desktop-specific configuration
# RTX 5070 Ti, 5120x1440@240Hz ultrawide, 4TB games drive
{
  pkgs,
  ...
}:

{
  # Autologin on boot only — after logout, tuigreet login screen is shown.
  # Use start-hyprland (the nixpkgs watchdog wrapper) instead of Hyprland directly,
  # otherwise Hyprland prints a "started without using start-hyprland" warning.
  services.greetd.settings.initial_session = {
    command = "${pkgs.hyprland}/bin/start-hyprland";
    user = "gjermund";
  };

  # Always run at full speed (desktop is always plugged in)
  powerManagement.cpuFreqGovernor = "performance";

  # NFS client support
  boot.supportedFilesystems = [ "nfs" ];

  # Mount 4TB games drive (desktop-only)
  fileSystems."/home/gjermund/games" = {
    device = "/dev/disk/by-uuid/1c7bdee1-0f6d-4181-a13b-a8ee7237949a";
    fsType = "btrfs";
    options = [
      "noatime"
      "compress=zstd"
      "nofail"
    ];
  };

  # Mount NFS share from NAS
  fileSystems."/zfs" = {
    device = "192.168.0.207:/share";
    fsType = "nfs";
    options = [
      "defaults"
      "nofail"
    ];
  };

  # BEES deduplication for games drive (saves ~15-25GB on Proton prefixes)
  services.beesd.filesystems.games = {
    spec = "UUID=1c7bdee1-0f6d-4181-a13b-a8ee7237949a";
    hashTableSizeMB = 1024; # 1GB hash table for 3.7TB drive
    extraOptions = [
      "--loadavg-target"
      "2.0"
    ];
  };

  # Automated backups with rsync
  systemd.services.backup-home = {
    description = "Backup home directory to backup drive";
    # Only run when the backup drive is actually mounted. The /backup fs uses
    # `nofail`, so if the drive is absent /backup would be a plain dir on the
    # root fs — without these guards rsync would fill root with a silent fake
    # backup while the real drive holds stale data.
    unitConfig = {
      RequiresMountsFor = "/backup";
      ConditionPathIsMountPoint = "/backup";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.rsync}/bin/rsync -aAXv --delete --exclude='.cache' --exclude='games' /home/gjermund/ /backup/home/";
    };
  };

  systemd.timers.backup-home = {
    description = "Daily home backup";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true; # Run if missed (e.g., system was off)
    };
  };
}
