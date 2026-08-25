# Work laptop configuration (Sikt)
# Intel graphics, dual USB-C external monitors
#
# Shared laptop config (thermald/power-profiles-daemon/upower, lid suspend,
# low-battery notifier) lives in modules/system/power.nix under `isLaptopHost`.
{
  config,
  pkgs,
  lib,
  ...
}:

{
  environment.systemPackages = [
    pkgs.geteduroam # GUI client to configure eduroam wifi
  ];

  # wpa_supplicant's systemd unit is sandboxed with RootDirectory=/run/wpa_supplicant
  # and no bind mount for /home, so an 802-1x ca-cert/ca-path pointing under
  # $HOME (as both the GNOME CAT installer and geteduroam write by default) is
  # invisible to it - EAP-TTLS fails with "unable to get local issuer
  # certificate". /etc/ is bind-mounted read-only into that sandbox, so the CA
  # bundle needs to live there instead; NetworkManager connection profiles then
  # get pointed at this path via `nmcli connection modify ... 802-1x.ca-cert`.
  environment.etc."eduroam-ca.pem".source = ./certs/eduroam-ca-bundle.pem;

  # Docked lid behaviour: don't suspend when external monitors are attached
  # (docked). The base lid keys (suspend / ignore-on-external-power) come from
  # common.nix; this merges the docked case on top.
  # Lid switch display handling is done by Hyprland (bindl in hyprland.conf)
  # using the lid-handler script which disables eDP-1 when external monitors present.
  services.logind.settings.Login.HandleLidSwitchDocked = "ignore";

  # omarchy's system module enables systemd-resolved on every host; the work
  # laptop deliberately runs without it (DHCP/default DNS — see
  # modules/system/networking.nix).
  services.resolved.enable = lib.mkForce false;

  # Stricter firewall for work - disable non-essential services.
  # KDE Connect ranges, WireGuard port, and checkReversePath="loose" are already
  # set in common.nix; here we only drop the extra TCP ports (VNC/Cerebro/etc)
  # and add the invalid-packet rule.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = lib.mkForce [ ]; # No VNC/Cerebro - override common.nix
    extraCommands = ''
      # Drop invalid packets
      iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
    '';
  };

  # EduVPN installs a policy-routing rule at priority 3 -
  # `not from all fwmark 0xca94 lookup 51860` -> `default dev eduVPN` - which
  # swallows *everything* into the tunnel. Tailscale's route table sits at
  # priority 5270, far below it, so while EduVPN is connected all Tailscale
  # traffic is silently dropped in the VPN: both the 100.64.0.0/10 peer
  # addresses and the 192.168.x subnet routes advertised by the proxmox subnet
  # router. `--accept-routes` is working fine; the routes just never get
  # consulted.
  #
  # EduVPN's own RFC1918 escape hatch (priority 2,
  # `to 192.168.0.0/16 lookup main suppress_prefixlength 0`) doesn't help,
  # because Tailscale keeps its routes in table 52 rather than main.
  #
  # Fix: put the Tailscale ranges ahead of EduVPN at priority 1. The rules only
  # select a table, so they're inert when Tailscale is down and survive EduVPN
  # connect/disconnect cycles - installing them once per boot is enough.
  #
  # Caveat: if this host is ever physically on 192.168.0.0/24, LAN traffic
  # hairpins via Tailscale through proxmox instead of going out directly. It
  # still works, just with an extra hop.
  systemd.services.tailscale-route-priority = {
    description = "Prioritise Tailscale routes over the EduVPN default route";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-pre.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for net in 100.64.0.0/10 192.168.0.0/24 192.168.1.0/24; do
        while ${pkgs.iproute2}/bin/ip rule del to "$net" priority 1 lookup 52 2>/dev/null; do :; done
        ${pkgs.iproute2}/bin/ip rule add to "$net" priority 1 lookup 52
      done
    '';
    preStop = ''
      for net in 100.64.0.0/10 192.168.0.0/24 192.168.1.0/24; do
        while ${pkgs.iproute2}/bin/ip rule del to "$net" priority 1 lookup 52 2>/dev/null; do :; done
      done
    '';
  };
}
