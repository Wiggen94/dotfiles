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

  # Automated backups with btrbk
  services.btrbk = {
    instances.home = {
      onCalendar = "daily";
      settings = {
        snapshot_preserve_min = "2d";
        snapshot_preserve = "7d 4w 2m";
        target_preserve_min = "2d";
        target_preserve = "7d 4w 2m";

        volume."/" = {
          subvolume.home = {
            snapshot_dir = "/backup/.snapshots";
            target = "/backup/home";
          };
        };
      };
    };
  };
}
