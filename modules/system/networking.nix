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
      PasswordAuthentication = true; # 2026-09-04: password login re-enabled on request
      PermitRootLogin = "no";
    };
  };

  # NetworkManager
  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = [
    pkgs.networkmanager-openvpn
    pkgs.networkmanager-l2tp
  ];

  # Static DNS only on the stationary desktop (AdGuard primary, Cloudflare
  # fallback). Portable hosts (laptop, sikt) use DHCP-provided DNS so an
  # unroutable home-LAN nameserver (192.168.0.185) can't stall lookups off
  # the home network — resolved still caches on the laptop, just with the
  # network's own upstreams.
  # AdGuard Home only. 1.1.1.1 used to sit alongside as fallback, but
  # resolved kept picking it: AdGuard Home's rewrite responses (e.g.
  # git.gjermund.xyz) lack the EDNS OPT record, so resolved degrades .185
  # below 1.1.1.1 and never queries it — killing split-horizon domains and
  # ad-blocking. With one server there is no selection to lose; resolved
  # still retries .185 with backoff if it is ever down.
  networking.nameservers = lib.mkIf (hostName == "desktop") [
    "192.168.0.185"
  ];
  # On home hosts, systemd-resolved (below) sets this to "systemd-resolved";
  # only the work laptop (resolved disabled) needs an explicit value.
  networking.networkmanager.dns = lib.mkIf (hostName == "sikt") "default";

  # Home Wi-Fi hands out AdGuard (192.168.0.185) *and* the router itself
  # (192.168.0.1) as DNS servers via DHCP. resolved's per-link server
  # selection then demotes .185 for the same EDNS-OPT reason documented
  # above (AdGuard's rewrite responses lack the OPT record), so split-horizon
  # names like git.gjermund.xyz silently stop resolving even though DHCP
  # correctly offered .185 — while the desktop, pinned to a single static
  # nameserver, never hits this. Can't just static-pin the laptop too: it
  # needs the network's own DNS off the home LAN. Instead, pin resolved to
  # AdGuard only while connected to the home SSID; a NetworkManager
  # dispatcher re-applies it on "up" and again after every DHCP renewal
  # ("dhcp4-change"), since a renewal re-pushes both servers and would
  # otherwise silently undo the pin.
  networking.networkmanager.dispatcherScripts = lib.mkIf (hostName == "laptop") [
    {
      type = "basic";
      source = pkgs.writeShellScript "pin-home-dns" ''
        set -eu
        iface="$1"
        action="$2"
        home_ssid="AvadaKedavra"

        [ "$iface" = "wlo1" ] || exit 0
        case "$action" in
          up|dhcp4-change) ;;
          *) exit 0 ;;
        esac
        [ "''${CONNECTION_ID:-}" = "$home_ssid" ] || exit 0

        ${pkgs.systemd}/bin/resolvectl dns "$iface" 192.168.0.185
      '';
    }
  ];

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
      22   # SSH (also auto-opened by services.openssh.openFirewall's default;
           # listed explicitly here since it's the one LAN password-login depends on)
      3100 # Curari frontend (Next.js)
      3200 # Curari landing page (Next.js)
      3773 # LAN access (Gjermund)
      5173 # Cerebro frontend (Vite dev server)
      5357 # my-world-dashboard (proxied via home.gjermund.xyz)
      8000 # Cerebro backend (FastAPI)
      9876 # Curari API (Hono)
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
