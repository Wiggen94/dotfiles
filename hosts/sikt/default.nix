# Work laptop configuration (Sikt)
# Intel graphics, dual USB-C external monitors
{ config, pkgs, lib, ... }:

{
  # Laptop power management
  services.thermald.enable = true;
  services.power-profiles-daemon.enable = true;

  # Laptop-specific packages
  environment.systemPackages = with pkgs; [
    powertop  # Power consumption analyzer
  ];

  # Laptop lid settings with external monitor awareness
  # When lid is closed with external monitors: don't suspend (Hyprland handles display)
  # When lid is closed without external monitors: suspend
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "ignore";  # Don't suspend when plugged in with lid closed
    HandleLidSwitchDocked = "ignore";  # Don't suspend when docked (external monitors = docked)
  };

  # Note: Lid switch display handling is done by Hyprland (bindl in hyprland.conf)
  # using the lid-handler script which disables eDP-1 when external monitors present

  # Stricter firewall for work - disable non-essential services
  networking.firewall = {
    enable = true;
    # Only allow essential ports for work
    allowedTCPPorts = [ ];  # No VNC
    allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];  # KDE Connect
    allowedUDPPortRanges = [ { from = 1714; to = 1764; } ];  # KDE Connect
    allowedUDPPorts = [ 51820 ];  # WireGuard for VPN
    checkReversePath = "loose";   # Required for WireGuard
    # Block all incoming by default, only allow established connections
    extraCommands = ''
      # Drop invalid packets
      iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
    '';
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
