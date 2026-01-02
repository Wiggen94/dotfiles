# Desktop-specific configuration
# RTX 5070 Ti, 5120x1440@240Hz ultrawide, 4TB games drive
{ config, pkgs, lib, ... }:

{
  # Mount 4TB games drive (desktop-only)
  fileSystems."/home/gjermund/games" = {
    device = "/dev/disk/by-uuid/1c7bdee1-0f6d-4181-a13b-a8ee7237949a";
    fsType = "btrfs";
    options = [ "defaults" "nofail" ];
  };

  # Automated backups with rsync
  # DISABLED: Backup drive not detected since Dec 29 - re-enable when fixed
  # systemd.services.backup-home = {
  #   description = "Backup home directory to backup drive";
  #   serviceConfig = {
  #     Type = "oneshot";
  #     ExecStart = "${pkgs.rsync}/bin/rsync -aAXv --delete --exclude='.cache' --exclude='games' /home/gjermund/ /backup/home/";
  #   };
  # };

  # systemd.timers.backup-home = {
  #   description = "Daily home backup";
  #   wantedBy = [ "timers.target" ];
  #   timerConfig = {
  #     OnCalendar = "daily";
  #     Persistent = true;  # Run if missed (e.g., system was off)
  #   };
  # };
}
