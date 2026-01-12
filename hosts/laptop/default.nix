# Laptop-specific configuration
# Intel + NVIDIA hybrid graphics, 2560x1440@60Hz
{ config, pkgs, lib, ... }:

{
  # Laptop power management
  services.thermald.enable = true;
  services.power-profiles-daemon.enable = true;

  # TLP for better battery life (alternative to power-profiles-daemon)
  # Uncomment if you prefer TLP over power-profiles-daemon
  # services.tlp.enable = true;
  # services.power-profiles-daemon.enable = false;

  # Laptop-specific packages
  environment.systemPackages = with pkgs; [
    powertop  # Power consumption analyzer
  ];

  # Laptop lid settings
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "ignore";  # Don't suspend when plugged in with lid closed
  };

  # Low battery notification service
  systemd.user.services.low-battery-notify = {
    description = "Low battery notification";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "low-battery-check" ''
        BATTERY_PATH="/sys/class/power_supply/BAT0"
        [ -d "$BATTERY_PATH" ] || BATTERY_PATH="/sys/class/power_supply/BAT1"
        [ -d "$BATTERY_PATH" ] || exit 0

        CAPACITY=$(cat "$BATTERY_PATH/capacity")
        STATUS=$(cat "$BATTERY_PATH/status")

        if [ "$STATUS" = "Discharging" ]; then
          if [ "$CAPACITY" -le 10 ]; then
            ${pkgs.libnotify}/bin/notify-send -u critical "Battery Critical" "Battery at $CAPACITY% - plug in now!"
          elif [ "$CAPACITY" -le 20 ]; then
            ${pkgs.libnotify}/bin/notify-send -u normal "Battery Low" "Battery at $CAPACITY%"
          fi
        fi
      '';
    };
    wantedBy = [];
  };

  systemd.user.timers.low-battery-notify = {
    description = "Check battery level every 2 minutes";
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "2min";
    };
    wantedBy = [ "timers.target" ];
  };
}
