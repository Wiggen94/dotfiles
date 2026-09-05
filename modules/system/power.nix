# Laptop power management + low-battery notifier (laptop + sikt)
{
  config,
  pkgs,
  lib,
  inputs,
  hostName,
  ...
}:
let
  isLaptopHost = hostName != "desktop";
in
{

  # ═══════════════════════════════════════════════════════════════════════════
  # LAPTOP-ONLY (laptop + sikt): power management + low-battery notifier.
  # Desktop is a plugged-in workstation and skips all of this.
  # ═══════════════════════════════════════════════════════════════════════════
  services.thermald.enable = lib.mkIf isLaptopHost true;
  services.power-profiles-daemon.enable = lib.mkIf isLaptopHost true;
  services.upower.enable = lib.mkIf isLaptopHost true; # Battery info for Quickshell bar

  # Suspend on lid close, but not when on external power (lid closed while
  # plugged in). sikt additionally sets HandleLidSwitchDocked in its host file.
  services.logind.settings.Login = lib.mkIf isLaptopHost {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "ignore";
  };

  systemd.user.services.low-battery-notify = lib.mkIf isLaptopHost {
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
    wantedBy = [ ];
  };

  systemd.user.timers.low-battery-notify = lib.mkIf isLaptopHost {
    description = "Check battery level every 2 minutes";
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "2min";
    };
    wantedBy = [ "timers.target" ];
  };
}
