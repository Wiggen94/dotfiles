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

  # herdr-world's bridge (127.0.0.1:8787, started by `herdr-world` /
  # `herdr-world-tailnet`) 403s any request to /api or /ws whose Host header
  # isn't loopback — its --allow-host flag is a no-op in v0.1.1 — and Tailscale
  # Serve forwards the browser's Host verbatim. This always-on shim on :8788
  # (what `svc:herdr-world` actually points at) re-issues each request/WS to the
  # bridge from loopback with Host/Origin stripped. Harmless when the bridge is
  # down (it just 502s). Payload: ../../herdr-world-shim.js.
  systemd.user.services.herdr-world-shim = lib.mkIf (hostName == "desktop") {
    description = "Host-rewriting shim for the herdr-world bridge";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.bun}/bin/bun ${../../herdr-world-shim.js}";
      Environment = [
        "HERDR_WORLD_BACKEND=127.0.0.1:8787"
        "HERDR_WORLD_SHIM_PORT=8788"
      ];
      Restart = "always";
      RestartSec = 2;
    };
  };

  # ── Tailscale Services hosted on this node (desktop only) ───────────────────
  # Each entry `name = backend` becomes `svc:<name>`: its own virtual IP and
  # MagicDNS name, reachable tailnet-wide at
  #   https://<name>                (bare, via the MagicDNS search domain)
  #   https://<name>.<tailnet>.ts.net
  # tailscaled terminates TLS on the service VIP and reverse-proxies to the
  # loopback `backend` — the backend never binds a routable address. Services
  # are independent: distinct VIPs mean no port-443 clash between them, and
  # each `tailscale serve --service=` call only touches its own entry. Add a
  # line here to publish another (e.g. a dashboard on 127.0.0.1:5357).
  #
  #   herdr-world  →  :8788, the always-on `herdr-world-shim` above. It proxies
  #                   to the bridge on :8787, which only listens while you run
  #                   `herdr-world` / `herdr-world-tailnet`; the serve config
  #                   and the shim persist regardless.
  #
  # Service hosts must be TAGGED nodes. That's a one-time identity change made
  # with `tailscale up` (not `set`, which has no --advertise-tags), so it's not
  # automated here — this unit only checks for the tag and tells you the command
  # if it's missing. Deliberately non-fatal: never fails activation.
  #
  # One-time setup:
  #   1. Define the Service in the admin console → Services → Advertise → "Define
  #      a Service": name `herdr-world`, HTTPS 443. There is NO policy-file way
  #      to create a service; until it exists, this node's advertisement has
  #      nowhere to land and the Services page stays empty.
  #   2. Tailnet policy (admin console → Access Controls):
  #        "tagOwners":     { "tag:server": ["autogroup:admin"] },
  #        "autoApprovers": { "services": { "svc:herdr-world": ["tag:server"] } },
  #        "grants": [ { "src": ["autogroup:member"],
  #                      "dst": ["svc:herdr-world"], "ip": ["tcp:443"] } ]
  #      (the grant is required even on the default allow-all ACL — `*` does not
  #       cover svc: targets; autoApprovers only approves the HOST, not the
  #       service's existence)
  #   3. DNS page: MagicDNS + "HTTPS Certificates" enabled.
  #   4. Tag this node:  sudo tailscale up --advertise-tags=tag:server
  #      `tailscale up` insists you re-list every non-default flag it's already
  #      running with (e.g. --accept-routes --ssh) — it prints the exact command
  #      to copy. The node then becomes tailnet-owned (matches `tag:server`
  #      instead of `autogroup:member` in ACLs, key stops expiring).
  #   5. systemctl restart tailscale-services  (then approve the pending host on
  #      the Services page unless autoApprovers did it)
  # A new service later needs only its attrset line + the autoApprovers line.
  systemd.services.tailscale-services =
    let
      services = {
        herdr-world = "http://127.0.0.1:8788"; # the shim, not the bridge (8787)
      };
      nodeTag = "tag:server";
      serviceLines = lib.concatStringsSep "\n" (lib.mapAttrsToList (n: b: "${n} ${b}") services);
      ts = "${config.services.tailscale.package}/bin/tailscale";
      jq = "${pkgs.jq}/bin/jq";
    in
    lib.mkIf (hostName == "desktop" && services != { }) {
      description = "Advertise this node's Tailscale Services";
      after = [
        "tailscaled.service"
        "tailscaled-autoconnect.service"
      ];
      wants = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -u
        log() { echo "tailscale-services: $*"; }

        state=""
        for _ in $(seq 1 30); do
          state="$(${ts} status --json 2>/dev/null | ${jq} -r '.BackendState // ""' 2>/dev/null || true)"
          [ "$state" = "Running" ] && break
          sleep 2
        done
        if [ "$state" != "Running" ]; then
          log "tailscaled not Running yet — skipping (retry: systemctl restart tailscale-services)"
          exit 0
        fi

        # Service hosts must be tagged. This is a one-time `tailscale up` — do it
        # by hand (see the comment above); the unit won't change node identity.
        if ! ${ts} status --json 2>/dev/null | ${jq} -e '(.Self.Tags // []) | index("${nodeTag}")' >/dev/null 2>&1; then
          log "node is not tagged ${nodeTag} — run 'sudo tailscale up --advertise-tags=${nodeTag}' (re-list current flags as it instructs), then: systemctl restart tailscale-services"
          exit 0
        fi
        log "node carries ${nodeTag}"

        while read -r name backend; do
          [ -n "$name" ] || continue
          if out="$(${ts} serve --service="svc:$name" --yes --https=443 "$backend" 2>&1)"; then
            log "svc:$name  tcp:443 -> $backend"
          else
            log "svc:$name  serve failed ($out)"
            continue
          fi
          ${ts} serve advertise "svc:$name" >/dev/null 2>&1 || true
        done <<'SERVICES'
        ${serviceLines}
        SERVICES

        log "done (auto-approved via autoApprovers.services, else approve on the admin console Services page)"
        exit 0
      '';
    };
}
