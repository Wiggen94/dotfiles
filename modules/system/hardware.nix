# Bluetooth, firmware, sensors, disk health, graphics, kvikk layout, udev
{
  config,
  pkgs,
  lib,
  inputs,
  hostName,
  ...
}:
let
  isWorkHost = hostName == "sikt";
in
{

  # Kvikk — Carpalx-optimized Scandinavian keyboard layout (for training).
  # Registers into the xkb dataset so libxkbcommon/Hyprland can select it.
  # Selected via Hyprland input.kb_layout in home.nix (toggle with Super+Space).
  services.xserver.xkb.extraLayouts.kvikk = {
    description = "Kvikk (Carpalx-optimized Scandinavian)";
    languages = [ "nor" ];
    symbolsFile = ../kvikk;
  };

  # SSD health - periodic TRIM for NVMe longevity and performance
  services.fstrim.enable = true;

  # Btrfs integrity - monthly scrub to detect silent data corruption
  services.btrfs.autoScrub = {
    enable = (hostName == "desktop");
    interval = "monthly";
    fileSystems = [
      "/"
      "/home/gjermund/games"
    ];
  };

  # Balance IRQs across CPU cores for better multi-threaded performance
  services.irqbalance.enable = true;

  # Firmware updates via LVFS (fwupdmgr refresh && fwupdmgr get-updates)
  services.fwupd.enable = true;

  # Hardware sensors (for btop, sensors command)
  # hardware.sensor.iio - moved to laptop config (not present on desktop)

  # Enable Bluetooth
  hardware.bluetooth.enable = true;
  hardware.ledger.enable = !isWorkHost; # Ledger hardware wallet udev rules (disabled on work hosts)
  services.blueman.enable = true;

  # All available firmware (broader hardware support)
  hardware.enableAllFirmware = true;

  # Hardware monitoring (lm_sensors package provides 'sensors' command)
  hardware.fancontrol.enable = false;

  # SMART disk monitoring - alerts on disk health issues
  services.smartd = {
    enable = true;
    autodetect = true;
    notifications.wall.enable = true; # Broadcast warnings to terminals
  };

  # Lemokey keyboard HID access for Lemokey Launcher
  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", TAG+="uaccess", TAG+="udev-acl"
  '';

  # Shared graphics enablement (host GPU files add driver-specific
  # extraPackages and session variables on top of this).
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true; # 32-bit libs for Steam/Wine
}
