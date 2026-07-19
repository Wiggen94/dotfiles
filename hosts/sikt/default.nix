# Work laptop configuration (Sikt)
# Intel graphics, dual USB-C external monitors
#
# Shared laptop config (thermald/power-profiles/upower, powertop, lid suspend,
# low-battery notifier) lives in modules/common.nix under `isLaptopHost`.
{ config, pkgs, lib, ... }:

{
  # Docked lid behaviour: don't suspend when external monitors are attached
  # (docked). The base lid keys (suspend / ignore-on-external-power) come from
  # common.nix; this merges the docked case on top.
  # Lid switch display handling is done by Hyprland (bindl in hyprland.conf)
  # using the lid-handler script which disables eDP-1 when external monitors present.
  services.logind.settings.Login.HandleLidSwitchDocked = "ignore";

  # Stricter firewall for work - disable non-essential services.
  # KDE Connect ranges, WireGuard port, and checkReversePath="loose" are already
  # set in common.nix; here we only drop the extra TCP ports (VNC/Cerebro/etc)
  # and add the invalid-packet rule.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = lib.mkForce [ ];  # No VNC/Cerebro/Hermes - override common.nix
    extraCommands = ''
      # Drop invalid packets
      iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
    '';
  };
}
