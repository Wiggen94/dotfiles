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

  # SMART disk monitoring - alerts on disk health issues
  services.smartd = {
    enable = true;
    autodetect = true;
    notifications.wall.enable = true; # Broadcast warnings to terminals
  };

  # Lemokey keyboard HID access for Lemokey Launcher
  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", TAG+="uaccess", TAG+="udev-acl"
  ''
  # Stable name for the Intel iGPU's DRM node. /dev/dri/cardN numbering is not
  # stable — a kernel/udev bump renamed it card2 -> card1 on this host, which
  # left Hyprland's AQ_DRM_DEVICES (see modules/home/_common.nix) pointing at a
  # node that no longer existed -> Aquamarine finds no GPU -> compositor aborts
  # -> login locked out. A /dev/dri/by-path symlink can't be used directly:
  # Aquamarine splits AQ_DRM_DEVICES on ':' and the PCI path contains colons.
  # This colon-free symlink is keyed by PCI slot (fixed) and Aquamarine
  # canonicalizes it to the real node before matching.
  + lib.optionalString (hostName == "laptop") ''
    SUBSYSTEM=="drm", KERNEL=="card[0-9]*", ENV{DEVTYPE}=="drm_minor", ENV{ID_PATH}=="pci-0000:00:02.0", SYMLINK+="dri/igpu"
  '';

  # brightnessctl's udev rule (chgrp video + chmod g+w on backlight sysfs
  # nodes) only takes effect if the package is registered here — being in
  # environment.systemPackages alone does not install its udev rules.
  services.udev.packages = [ pkgs.brightnessctl ];

  # Shared graphics enablement (host GPU files add driver-specific
  # extraPackages and session variables on top of this).
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true; # 32-bit libs for Steam/Wine
}
