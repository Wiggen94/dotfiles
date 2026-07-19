# NetworkManager, DNS/resolved, WireGuard, Tailscale, firewall, SSH, avahi
{
  config,
  pkgs,
  lib,
  inputs,
  hostName,
  ...
}:
{

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      X11Forwarding = true;
    };
  };

  # NetworkManager
  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = [
    pkgs.networkmanager-openvpn
    pkgs.networkmanager-l2tp
  ];

  # Static DNS on home machines (AdGuard primary, Cloudflare fallback)
  # Work laptop (sikt) uses DHCP DNS
  networking.nameservers = lib.mkIf (hostName != "sikt") [
    "192.168.0.185"
    "1.1.1.1"
  ];
  # On home hosts, systemd-resolved (below) sets this to "systemd-resolved";
  # only the work laptop (resolved disabled) needs an explicit value.
  networking.networkmanager.dns = lib.mkIf (hostName == "sikt") "default";

  # Local DNS caching via systemd-resolved (home hosts only).
  # Steam opens dozens of parallel connections to CDN hostnames; without a
  # resolver cache each one re-queries the upstream, which stalls downloads on
  # NixOS. resolved serves a cached stub (127.0.0.53) and uses the nameservers
  # above as upstreams (AdGuard primary, Cloudflare fallback).
  services.resolved.enable = (hostName != "sikt");

  # Prefer IPv4 over IPv6 - prevents slow connections when IPv6 route
  # is only available through eduVPN (timeouts on every connection when VPN is down)
  environment.etc."gai.conf".text = lib.mkForce ''
    precedence ::ffff:0:0/96 100
  '';

  # WireGuard
  networking.wireguard.enable = true;

  # Tailscale mesh VPN
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client"; # accept subnet routes advertised by other nodes
    extraUpFlags = [ "--accept-routes" ];
  };

  # Firewall - open ports for KDE Connect and WireGuard
  networking.firewall = {
    allowedTCPPorts = [
      5173 # Cerebro frontend (Vite dev server)
      5900 # VNC (wayvnc)
      8000 # Cerebro backend (FastAPI)
      8644 # Hermes Lise API server
    ];
    allowedTCPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
    allowedUDPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
    allowedUDPPorts = [ 51820 ]; # WireGuard
    checkReversePath = "loose"; # Required for WireGuard
    # Trust traffic originating from docker bridges so containers can reach
    # host-exposed services (e.g. ollama on 11434). docker0 = default bridge,
    # br-+ = compose-managed user networks.
    trustedInterfaces = [
      "docker0"
      "br-+"
      "tailscale0"
    ];
  };

  # mDNS/DNS-SD for local network discovery (find NAS, printers, Chromecast)
  services.avahi = {
    enable = true;
    nssmdns4 = true; # Allow .local hostname resolution
    openFirewall = true;
  };
}
