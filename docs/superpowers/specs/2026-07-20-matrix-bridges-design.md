# Matrix homeserver + Meta/Discord bridges on k3s (Docker host)

**Date:** 2026-07-20
**Target host:** `k3s` / `192.168.0.182` (Debian 12, Docker 28.1.1, Compose v2.35.1)
**Domain:** `gjermund.xyz` (Cloudflare DNS, dynamic home IP via `cloudflare-ddns`)

## Goal

Self-host a federated Matrix homeserver on the existing Docker host and bridge
three personal messaging networks into it:

- **Discord** (personal account)
- **Facebook Messenger**
- **Instagram DMs**

Access via the Element apps (Element X on mobile, Element Desktop on machines).

## Constraints & environment

- **Docker only** — no Ansible, no Kubernetes, no Komodo. Follow the host's
  existing convention: one plain Compose stack per dir under `/zfs/stacks/<name>/`
  (`compose.yaml` + `.env`), persistent data/config under `/zfs/config/<name>/`.
  Stacks are run with `docker compose` (Arcane is available as a management UI).
- **Reverse proxy is existing Caddy** (`caddy-cloudflaredns` image), config at
  `/zfs/config/Caddyfile`. Pattern: `sub.gjermund.xyz { reverse_proxy 192.168.0.182:PORT }`.
  `CF_API_TOKEN` is already in Caddy's environment (used by `tls { dns cloudflare ... }`
  on some sites). The Matrix stack brings **no** reverse proxy of its own.
- **Inbound reachability** is already proven: a public mail server runs on the
  same connection (port 25 inbound), so the IP is routable (not CGNAT) and
  ports 80/443 reach the host.
- **Passwordless sudo** available for `gjermund`; user is in the `docker` group.

## Architecture

### Identity & endpoints

- **server_name:** `gjermund.xyz` → user IDs look like `@gjermund:gjermund.xyz`.
- **Client + federation host:** `matrix.gjermund.xyz` → Synapse `:8008`
  (single listener serves both the client-server API and federation).
- **Delegation:** `https://gjermund.xyz/.well-known/matrix/server` and
  `/.well-known/matrix/client` served as static JSON by Caddy (new apex block):
  - `server` → `{"m.server": "matrix.gjermund.xyz:443"}`
  - `client` → `{"m.homeserver": {"base_url": "https://matrix.gjermund.xyz"}}`
    (+ `Access-Control-Allow-Origin: *` and `Content-Type: application/json`).

### Stack: `/zfs/stacks/matrix/`

Containers on a private Docker network (`matrix` internal bridge). Only Synapse
is published to the host, on `192.168.0.182:8008` — matching how every other
service here is fronted (Caddy runs in a container and reaches host services via
the LAN IP, not loopback). Caddy proxies `matrix.gjermund.xyz` → `192.168.0.182:8008`.

| Container | Image | Role | Published |
|-----------|-------|------|-----------|
| `matrix-postgres` | `postgres:16-alpine` | Dedicated DB for Synapse + bridges | internal only |
| `synapse` | `matrixdotorg/synapse:latest` | Homeserver | `192.168.0.182:8008` |
| `mautrix-discord` | `dock.mau.dev/mautrix/discord:latest` | Discord bridge | internal only |
| `mautrix-meta-messenger` | `dock.mau.dev/mautrix/meta:latest` | Facebook Messenger bridge | internal only |
| `mautrix-meta-instagram` | `dock.mau.dev/mautrix/meta:latest` | Instagram DM bridge | internal only |

Rationale for a **dedicated Postgres** (not reusing an existing one): isolation
of backups, Postgres version, and blast radius. Separate logical databases:
`synapse`, `mautrix_discord`, `mautrix_meta_messenger`, `mautrix_meta_instagram`.

> **Note:** one `mautrix-meta` instance bridges exactly one network, so Messenger
> and Instagram are **two separate containers**, each with its own bot user,
> config, and appservice registration.

### Config & data layout (`/zfs/config/matrix/`)

```
/zfs/config/matrix/
├── postgres/                 # PGDATA
├── synapse/
│   ├── homeserver.yaml
│   ├── <server>.log.config
│   ├── *.signing.key
│   └── registrations/        # bridge registration.yaml files, mounted RO into synapse
├── mautrix-discord/          # config.yaml, registration.yaml, data
├── mautrix-meta-messenger/
└── mautrix-meta-instagram/
```

Each bridge generates its own `registration.yaml`; those are referenced from
Synapse's `app_service_config_files`. Bridges reach Synapse at
`http://synapse:8008` over the internal network; Synapse reaches each bridge at
its in-network hostname/port.

### Bridges & double puppeting

- **Automatic double puppeting** enabled on all three bridges (via the
  `double_puppet` / appservice login flow) so the user's own messages appear as
  themselves, not a bot. Configured server-side; no special client needed.
- **Encryption:** end-to-bridge encryption available; decide per-bridge at
  implementation (default: enable, since it is stable as of 2025).
- **Login (performed after infra is up, via the bridge bot in Element):**
  - Discord: **personal account** via token/QR. *(Self-bot — against Discord
    ToS; low-but-nonzero termination risk; accepted by user.)*
  - Meta (both): cookie-based login. Recommend enabling 2FA on the Meta account
    to reduce suspicious-activity lockouts.

### Caddy integration

Add to `/zfs/config/Caddyfile` (then reload Caddy):

```
matrix.gjermund.xyz {
    reverse_proxy 192.168.0.182:8008
}

gjermund.xyz {
    handle /.well-known/matrix/server {
        header Content-Type application/json
        respond `{"m.server": "matrix.gjermund.xyz:443"}`
    }
    handle /.well-known/matrix/client {
        header Content-Type application/json
        header Access-Control-Allow-Origin *
        respond `{"m.homeserver": {"base_url": "https://matrix.gjermund.xyz"}}`
    }
    # existing/other apex behavior (if any) preserved here
}
```

> Implementation check: confirm no apex `gjermund.xyz` block already exists and
> decide what the apex serves for non-well-known paths (404, redirect, or an
> existing target).

### DNS (Cloudflare)

- Add `matrix.gjermund.xyz` (and ensure apex `gjermund.xyz`) resolve to the home
  IP maintained by `cloudflare-ddns`.
- **`matrix.gjermund.xyz` must be DNS-only (grey cloud)**, not proxied —
  Cloudflare's proxy imposes upload/body-size limits and can interfere with
  federation and media. Matches the host's other ALPN-cert services.

### Registration & admin

- Public registration **disabled**.
- Admin user `@gjermund:gjermund.xyz` created via
  `register_new_matrix_user` after first boot.
- `registration_shared_secret` kept only in `homeserver.yaml` (not committed).

## Security

- Only Synapse's `8008` is published (on the LAN IP, like the host's other
  services); the DB and all bridges stay on the internal network. Caddy
  terminates TLS. Federation/client traffic only enters through Caddy on 443.
- Secrets (Postgres password, registration shared secret, bridge `as`/`hs`
  tokens, any login tokens) live in `.env` / config files under
  `/zfs/config/matrix/`, **not** in this repo. `.env` is git-ignored.
- Bridge "permissions" restricted so only `@gjermund:gjermund.xyz` can use the
  bridges (no open relay).

## Backups

- Nightly `pg_dump` of the four databases to `/zfs/...` (align with the host's
  existing backup approach — confirm at implementation).
- `/zfs/config/matrix/` is on ZFS; rely on existing ZFS snapshot/backup routine
  if present. Signing keys and registration files are the critical
  non-regenerable artifacts.

## Phased rollout (execution plan; each phase verified before the next)

1. **Homeserver core** — Postgres + Synapse + Caddy blocks + DNS. Create admin
   user. **Verify:** log in with Element; `federationtester.matrix.org` reports
   `gjermund.xyz` fully working.
2. **Discord bridge** — deploy, register, log in with personal account.
   **Verify:** a Discord DM round-trips and double puppeting works.
3. **Meta Messenger bridge** — deploy, register, cookie login.
   **Verify:** a Messenger DM round-trips.
4. **Instagram bridge** — deploy, register, cookie login.
   **Verify:** an Instagram DM round-trips.

## Risks & caveats

- **Discord self-bot ToS risk** — accepted; use an account whose loss is
  tolerable, avoid spammy automation.
- **Meta lockouts** — periodic captcha/re-auth possible; 2FA recommended;
  re-login via the bridge bot when it happens.
- **Federation exposure** — homeserver becomes reachable from the public Matrix
  network. Registration is closed; bridge permissions are locked to the one
  user.
- **Cloudflare proxy** — must stay grey-cloud for `matrix.gjermund.xyz` (see DNS).
- **Media size** — Synapse `max_upload_size` set sanely (e.g. 100M); ensure
  Caddy does not cap below it.

## Out of scope (YAGNI for now)

- Outbound email (SMTP via postfix) — closed registration + admin-created user
  means it is not needed to run. Easy later add.
- Self-hosted `element-web` at `element.gjermund.xyz` — use Element apps. Easy
  later add.
- Additional bridges (WhatsApp, Signal, Telegram, Slack), TURN/voice, and
  Sydent/identity server.

## Implementation-time verifications (things read off the host, to reconfirm)

- No existing apex `gjermund.xyz` Caddy block conflicts.
- `matrix.gjermund.xyz` created grey-cloud in Cloudflare.
- Host backup convention (to match the pg_dump/snapshot approach).
- Caddy reload mechanism used on this host (e.g. `docker exec caddy caddy reload`).
