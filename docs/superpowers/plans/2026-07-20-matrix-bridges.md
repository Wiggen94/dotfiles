# Matrix Homeserver + Meta/Discord Bridges — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a federated Synapse homeserver on the k3s Docker host (`192.168.0.182`, domain `gjermund.xyz`) with three mautrix bridges — Discord, Facebook Messenger, Instagram — accessed via Element apps.

**Architecture:** One self-contained plain Docker Compose stack at `/zfs/stacks/matrix/` (dedicated Postgres + Synapse + 3 bridge containers on a private network), fronted by the host's existing Caddy (two new site blocks + apex `.well-known` delegation), with a grey-cloud `matrix.gjermund.xyz` Cloudflare record. Registration closed; bridges locked to `@gjermund:gjermund.xyz`; automatic double puppeting.

**Tech Stack:** Debian 12, Docker 28.1 / Compose v2.35, `matrixdotorg/synapse`, `postgres:16-alpine`, `dock.mau.dev/mautrix/{discord,meta}`, Caddy (`caddy-cloudflaredns`), Cloudflare DNS.

**Spec:** `docs/superpowers/specs/2026-07-20-matrix-bridges-design.md`

## Conventions for every task

- All commands run on the host: prefix with `ssh gjermund@192.168.0.182 '<cmd>'`, or open an interactive session. `docker` works without sudo (user in `docker` group).
- Stack dir: `/zfs/stacks/matrix/` (`compose.yaml`, `.env`). Persistent data/config: `/zfs/config/matrix/`.
- Compose commands run from the stack dir: `cd /zfs/stacks/matrix && docker compose <...>`.
- **Secrets** (`.env`, generated tokens, signing keys) live only on the host. Never copy them into this git repo.
- Editing config files: use the host's editor (`nano`/`vim`) or `docker run` one-liners. Where a step says "set key X: Y", open the generated YAML and change that key.

---

## Phase 1 — Homeserver core

### Task 1: Scaffold stack directory, secrets, and Postgres init

**Files:**
- Create: `/zfs/stacks/matrix/.env`
- Create: `/zfs/stacks/matrix/postgres-init/01-databases.sql`
- Create: `/zfs/config/matrix/{postgres,synapse,mautrix-discord,mautrix-meta-messenger,mautrix-meta-instagram}/` (dirs)

- [ ] **Step 1: Create directories**

```bash
mkdir -p /zfs/stacks/matrix/postgres-init
mkdir -p /zfs/config/matrix/{postgres,synapse/registrations,mautrix-discord,mautrix-meta-messenger,mautrix-meta-instagram}
```

- [ ] **Step 2: Generate a Postgres password and write `.env`**

```bash
PGPW=$(openssl rand -hex 24)
cat > /zfs/stacks/matrix/.env <<EOF
POSTGRES_PASSWORD=$PGPW
SYNAPSE_SERVER_NAME=gjermund.xyz
EOF
chmod 600 /zfs/stacks/matrix/.env
```

- [ ] **Step 3: Write the Postgres init SQL (Synapse requires C collation)**

Create `/zfs/stacks/matrix/postgres-init/01-databases.sql`:

```sql
-- Synapse REQUIRES C collation/ctype; bridges are fine with it too.
CREATE DATABASE synapse
  TEMPLATE template0 LC_COLLATE 'C' LC_CTYPE 'C' ENCODING 'UTF8';
CREATE DATABASE mautrix_discord
  TEMPLATE template0 LC_COLLATE 'C' LC_CTYPE 'C' ENCODING 'UTF8';
CREATE DATABASE mautrix_meta_messenger
  TEMPLATE template0 LC_COLLATE 'C' LC_CTYPE 'C' ENCODING 'UTF8';
CREATE DATABASE mautrix_meta_instagram
  TEMPLATE template0 LC_COLLATE 'C' LC_CTYPE 'C' ENCODING 'UTF8';
```

(The default role is `matrix` — created by the Postgres container env below — and owns all four DBs.)

- [ ] **Step 4: Verify**

```bash
ls -R /zfs/config/matrix && cat /zfs/stacks/matrix/.env | sed 's/=.*/=<set>/'
```
Expected: all dirs present; `.env` shows `POSTGRES_PASSWORD=<set>` and `SYNAPSE_SERVER_NAME=<set>`.

---

### Task 2: Postgres service up and healthy

**Files:**
- Create: `/zfs/stacks/matrix/compose.yaml` (Postgres service only for now)

- [ ] **Step 1: Write initial `compose.yaml`**

```yaml
name: matrix

networks:
  matrix:
    driver: bridge

services:
  postgres:
    image: postgres:16-alpine
    container_name: matrix-postgres
    restart: unless-stopped
    networks: [matrix]
    environment:
      POSTGRES_USER: matrix
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: matrix            # bootstrap DB; real DBs made by init SQL
      POSTGRES_INITDB_ARGS: "--encoding=UTF8 --lc-collate=C --lc-ctype=C"
    volumes:
      - /zfs/config/matrix/postgres:/var/lib/postgresql/data
      - /zfs/stacks/matrix/postgres-init:/docker-entrypoint-initdb.d:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U matrix"]
      interval: 10s
      timeout: 5s
      retries: 5
```

- [ ] **Step 2: Bring up Postgres**

```bash
cd /zfs/stacks/matrix && docker compose up -d postgres
```

- [ ] **Step 3: Verify databases exist**

```bash
sleep 10 && docker exec matrix-postgres psql -U matrix -c "\l" | grep -E "synapse|mautrix_"
```
Expected: four rows — `synapse`, `mautrix_discord`, `mautrix_meta_messenger`, `mautrix_meta_instagram`.

> If the init SQL didn't run (volume already initialized), create the DBs manually with the same `CREATE DATABASE ... TEMPLATE template0 LC_COLLATE 'C' LC_CTYPE 'C'` statements via `docker exec -i matrix-postgres psql -U matrix`.

---

### Task 3: Generate and configure Synapse

**Files:**
- Create (generated): `/zfs/config/matrix/synapse/homeserver.yaml`, signing key, log config

- [ ] **Step 1: Generate the default Synapse config**

```bash
docker run --rm \
  -v /zfs/config/matrix/synapse:/data \
  -e SYNAPSE_SERVER_NAME=gjermund.xyz \
  -e SYNAPSE_REPORT_STATS=no \
  matrixdotorg/synapse:latest generate
```
Expected: creates `homeserver.yaml`, `gjermund.xyz.signing.key`, `gjermund.xyz.log.config` under `/zfs/config/matrix/synapse/`.

- [ ] **Step 2: Point Synapse at Postgres**

Edit `/zfs/config/matrix/synapse/homeserver.yaml` — replace the default SQLite `database:` block with:

```yaml
database:
  name: psycopg2
  args:
    user: matrix
    password: "PASTE_POSTGRES_PASSWORD_FROM_ENV"
    dbname: synapse
    host: postgres
    port: 5432
    cp_min: 5
    cp_max: 10
```

- [ ] **Step 3: Set listener + public baseurl + limits**

In `homeserver.yaml` ensure:

```yaml
public_baseurl: https://matrix.gjermund.xyz/
listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true          # behind Caddy
    bind_addresses: ['0.0.0.0']
    resources:
      - names: [client, federation]
        compress: false

enable_registration: false
max_upload_size: 100M
```

Leave `registration_shared_secret` as generated (used to create the admin user). Keep `server_name: gjermund.xyz`.

- [ ] **Step 4: Verify config parses**

```bash
docker run --rm -v /zfs/config/matrix/synapse:/data matrixdotorg/synapse:latest \
  python -m synapse.config.homeserver -c /data/homeserver.yaml --generate-keys
echo "exit: $?"
```
Expected: `exit: 0`, no traceback.

---

### Task 4: Add Synapse to the stack and verify locally

**Files:**
- Modify: `/zfs/stacks/matrix/compose.yaml` (add `synapse` service)

- [ ] **Step 1: Add the Synapse service**

Append under `services:` in `compose.yaml`:

```yaml
  synapse:
    image: matrixdotorg/synapse:latest
    container_name: synapse
    restart: unless-stopped
    networks: [matrix]
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      SYNAPSE_CONFIG_PATH: /data/homeserver.yaml
    volumes:
      - /zfs/config/matrix/synapse:/data
    ports:
      - "192.168.0.182:8008:8008"   # LAN IP so containerized Caddy can reach it
```

- [ ] **Step 2: Bring up Synapse**

```bash
cd /zfs/stacks/matrix && docker compose up -d synapse && sleep 15
```

- [ ] **Step 3: Verify Synapse answers locally**

```bash
curl -s http://192.168.0.182:8008/_matrix/client/versions | head -c 200; echo
```
Expected: JSON containing `"versions":[...]`.

```bash
docker logs synapse 2>&1 | tail -20
```
Expected: `Synapse now listening on TCP port 8008`, no repeated tracebacks.

---

### Task 5: Caddy site blocks, apex delegation, and DNS

**Files:**
- Modify: `/zfs/config/Caddyfile` (host)
- Modify: `/zfs/config/cloudflare-ddns/config.json` (host) OR Cloudflare dashboard

- [ ] **Step 1: Confirm no conflicting apex block**

```bash
sudo grep -nE "^gjermund\.xyz \{|^matrix\.gjermund\.xyz \{" /zfs/config/Caddyfile || echo "no conflict"
```
Expected: `no conflict` (if an apex block exists, merge the `.well-known` handles into it in Step 2 instead of adding a new block).

- [ ] **Step 2: Add the Matrix blocks to `/zfs/config/Caddyfile`**

```caddyfile
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
	handle {
		respond "gjermund.xyz" 200
	}
}
```

- [ ] **Step 3: Add the DNS record (grey cloud / DNS-only)**

Inspect how the dynamic IP is managed and add `matrix` alongside the apex:

```bash
cat /zfs/config/cloudflare-ddns/config.json
```
Add an entry to the `cloudflare.*.subdomains` (or `subdomains`) list with `"name": "matrix"` and `"proxied": false`, matching the existing schema, then:

```bash
docker restart cloudflare-ddns && docker logs cloudflare-ddns --tail 20
```
Expected: log line showing `matrix.gjermund.xyz` created/updated, proxied disabled.

> If the apex `gjermund.xyz` itself is not currently an A record pointing home, add it too (proxied false) — `.well-known` must be reachable on the apex.

- [ ] **Step 4: Reload Caddy and verify**

```bash
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
sleep 5
curl -s https://gjermund.xyz/.well-known/matrix/server; echo
curl -s https://gjermund.xyz/.well-known/matrix/client; echo
curl -s https://matrix.gjermund.xyz/_matrix/client/versions | head -c 120; echo
```
Expected: correct JSON for both well-known endpoints; `versions` JSON from the third (proves TLS + proxy path end-to-end).

---

### Task 6: Create admin user and verify federation (Phase 1 gate)

- [ ] **Step 1: Create the admin user**

```bash
docker exec -it synapse register_new_matrix_user \
  -c /data/homeserver.yaml http://localhost:8008 -u gjermund -a
```
Enter a password when prompted; `-a` makes it a server admin.

- [ ] **Step 2: Verify federation from the outside**

Open `https://federationtester.matrix.org/#gjermund.xyz` in a browser (or:)

```bash
curl -s "https://federationtester.matrix.org/api/report?server_name=gjermund.xyz" \
  | grep -o '"FederationOK":[a-z]*'
```
Expected: `"FederationOK":true`.

- [ ] **Step 3: Verify client login**

Install Element Desktop; log in with homeserver `gjermund.xyz`, user `gjermund`, the password from Step 1.
Expected: login succeeds; client resolves the server via `.well-known`.

- [ ] **Step 4: Checkpoint**

Phase 1 complete: federated homeserver reachable and usable. Do not proceed until `FederationOK:true` and Element login both succeed.

---

## Phase 2 — Discord bridge

### Task 7: Deploy and connect mautrix-discord

**Files:**
- Create (generated): `/zfs/config/matrix/mautrix-discord/config.yaml`, `registration.yaml`
- Modify: `/zfs/stacks/matrix/compose.yaml` (add service)
- Modify: `/zfs/config/matrix/synapse/homeserver.yaml` (register appservice)

- [ ] **Step 1: Generate the bridge's default config**

```bash
docker run --rm \
  -v /zfs/config/matrix/mautrix-discord:/data \
  dock.mau.dev/mautrix/discord:latest
```
Expected: creates `config.yaml` in the dir and exits asking you to edit it.

- [ ] **Step 2: Edit `config.yaml` — set the key values**

These bridges use the **bridgev2** config layout (`database` and `permissions`
are top-level). Set these values in `/zfs/config/matrix/mautrix-discord/config.yaml`,
editing the keys where they appear in the generated file:

```yaml
homeserver:
    address: http://synapse:8008
    domain: gjermund.xyz

appservice:
    address: http://mautrix-discord:29334
    hostname: 0.0.0.0
    port: 29334

database:
    type: postgres
    uri: postgres://matrix:PASTE_PG_PASSWORD@postgres/mautrix_discord?sslmode=disable

permissions:
    "@gjermund:gjermund.xyz": admin

encryption:
    allow: true
    default: true
    require: false
```

> Match the generated file's actual structure (it is authoritative for the
> installed image version) — change these keys in place rather than pasting the
> block wholesale. **Double puppeting** on a same-homeserver bridge is automatic
> in current mautrix (the appservice puppets your user); no extra config needed.
> Leave any generated `double_puppet:` section at its defaults.

- [ ] **Step 3: Generate the registration file**

```bash
docker run --rm \
  -v /zfs/config/matrix/mautrix-discord:/data \
  dock.mau.dev/mautrix/discord:latest
```
Expected: creates `/zfs/config/matrix/mautrix-discord/registration.yaml`.

- [ ] **Step 4: Register the appservice with Synapse**

Copy the registration where Synapse can read it and reference it:

```bash
cp /zfs/config/matrix/mautrix-discord/registration.yaml \
   /zfs/config/matrix/synapse/registrations/discord-registration.yaml
```

Add to `/zfs/config/matrix/synapse/homeserver.yaml`:

```yaml
app_service_config_files:
  - /data/registrations/discord-registration.yaml
```

- [ ] **Step 5: Add the bridge service to `compose.yaml`**

```yaml
  mautrix-discord:
    image: dock.mau.dev/mautrix/discord:latest
    container_name: mautrix-discord
    restart: unless-stopped
    networks: [matrix]
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - /zfs/config/matrix/mautrix-discord:/data
```

- [ ] **Step 6: Restart Synapse, then start the bridge**

```bash
cd /zfs/stacks/matrix
docker compose up -d synapse && sleep 10
docker compose up -d mautrix-discord && sleep 8
docker logs mautrix-discord --tail 20
```
Expected: bridge connects to homeserver and DB; no auth/permission errors. Synapse log shows the appservice registered.

- [ ] **Step 7: Log in (personal Discord account)**

In Element, start a chat with `@discordbot:gjermund.xyz`, send `login`, and complete QR/token login per the bot's instructions.
Expected: bot confirms login; your Discord DMs/guilds begin to appear.

- [ ] **Step 8: Verify round-trip + double puppeting**

Send a message from Matrix into a Discord DM and reply from the Discord app.
Expected: message arrives in Discord as **you** (not a bot/relay), and the Discord reply appears in the Matrix room. **Phase 2 gate.**

---

## Phase 3 — Facebook Messenger bridge

### Task 8: Deploy and connect mautrix-meta (messenger mode)

**Files:**
- Create (generated): `/zfs/config/matrix/mautrix-meta-messenger/config.yaml`, `registration.yaml`
- Modify: `/zfs/stacks/matrix/compose.yaml`
- Modify: `/zfs/config/matrix/synapse/homeserver.yaml`

- [ ] **Step 1: Generate default config**

```bash
docker run --rm \
  -v /zfs/config/matrix/mautrix-meta-messenger:/data \
  dock.mau.dev/mautrix/meta:latest
```

- [ ] **Step 2: Edit `config.yaml` — messenger mode + unique ports/IDs**

Bridgev2 layout. Set these in `/zfs/config/matrix/mautrix-meta-messenger/config.yaml`:

```yaml
homeserver:
    address: http://synapse:8008
    domain: gjermund.xyz

appservice:
    address: http://mautrix-meta-messenger:29319
    hostname: 0.0.0.0
    port: 29319
    id: meta-messenger          # MUST be unique across bridges
    bot:
        username: messengerbot  # unique bot localpart

database:
    type: postgres
    uri: postgres://matrix:PASTE_PG_PASSWORD@postgres/mautrix_meta_messenger?sslmode=disable

network:
    mode: messenger             # <-- Facebook Messenger

permissions:
    "@gjermund:gjermund.xyz": admin

encryption:
    allow: true
    default: true
    require: false
```

> The `appservice.id`, bot username, `appservice.port`, and DB name MUST differ
> from the Discord and Instagram bridges, or Synapse will reject overlapping
> registrations. Set the bot username at whatever key the generated file uses
> (`appservice.bot.username` or `appservice.bot_username` depending on version).

- [ ] **Step 3: Generate registration + wire into Synapse**

```bash
docker run --rm -v /zfs/config/matrix/mautrix-meta-messenger:/data dock.mau.dev/mautrix/meta:latest
cp /zfs/config/matrix/mautrix-meta-messenger/registration.yaml \
   /zfs/config/matrix/synapse/registrations/meta-messenger-registration.yaml
```

Add to `homeserver.yaml` `app_service_config_files:`:

```yaml
  - /data/registrations/meta-messenger-registration.yaml
```

- [ ] **Step 4: Add service to `compose.yaml`**

```yaml
  mautrix-meta-messenger:
    image: dock.mau.dev/mautrix/meta:latest
    container_name: mautrix-meta-messenger
    restart: unless-stopped
    networks: [matrix]
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - /zfs/config/matrix/mautrix-meta-messenger:/data
```

- [ ] **Step 5: Restart Synapse + start bridge**

```bash
cd /zfs/stacks/matrix
docker compose up -d synapse && sleep 10
docker compose up -d mautrix-meta-messenger && sleep 8
docker logs mautrix-meta-messenger --tail 20
```
Expected: clean startup, appservice registered.

- [ ] **Step 6: Log in + verify (Phase 3 gate)**

In Element, message `@messengerbot:gjermund.xyz`, run `login`, complete cookie login. Enable 2FA on the Meta account first. Send/receive one Messenger DM.
Expected: DM round-trips; messages appear as you.

---

## Phase 4 — Instagram bridge

### Task 9: Deploy and connect mautrix-meta (instagram mode)

**Files:**
- Create (generated): `/zfs/config/matrix/mautrix-meta-instagram/config.yaml`, `registration.yaml`
- Modify: `/zfs/stacks/matrix/compose.yaml`
- Modify: `/zfs/config/matrix/synapse/homeserver.yaml`

- [ ] **Step 1: Generate default config**

```bash
docker run --rm \
  -v /zfs/config/matrix/mautrix-meta-instagram:/data \
  dock.mau.dev/mautrix/meta:latest
```

- [ ] **Step 2: Edit `config.yaml` — instagram mode + unique ports/IDs**

Bridgev2 layout. Set these in `/zfs/config/matrix/mautrix-meta-instagram/config.yaml`:

```yaml
homeserver:
    address: http://synapse:8008
    domain: gjermund.xyz

appservice:
    address: http://mautrix-meta-instagram:29320
    hostname: 0.0.0.0
    port: 29320
    id: meta-instagram
    bot:
        username: instagrambot

database:
    type: postgres
    uri: postgres://matrix:PASTE_PG_PASSWORD@postgres/mautrix_meta_instagram?sslmode=disable

network:
    mode: instagram             # <-- Instagram DMs

permissions:
    "@gjermund:gjermund.xyz": admin

encryption:
    allow: true
    default: true
    require: false
```

> As with Messenger: `appservice.id`, bot username, port, and DB name must be
> unique. Set the bot username at whatever key the generated file uses.

- [ ] **Step 3: Generate registration + wire into Synapse**

```bash
docker run --rm -v /zfs/config/matrix/mautrix-meta-instagram:/data dock.mau.dev/mautrix/meta:latest
cp /zfs/config/matrix/mautrix-meta-instagram/registration.yaml \
   /zfs/config/matrix/synapse/registrations/meta-instagram-registration.yaml
```

Add to `homeserver.yaml` `app_service_config_files:`:

```yaml
  - /data/registrations/meta-instagram-registration.yaml
```

- [ ] **Step 4: Add service to `compose.yaml`**

```yaml
  mautrix-meta-instagram:
    image: dock.mau.dev/mautrix/meta:latest
    container_name: mautrix-meta-instagram
    restart: unless-stopped
    networks: [matrix]
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - /zfs/config/matrix/mautrix-meta-instagram:/data
```

- [ ] **Step 5: Restart Synapse + start bridge**

```bash
cd /zfs/stacks/matrix
docker compose up -d synapse && sleep 10
docker compose up -d mautrix-meta-instagram && sleep 8
docker logs mautrix-meta-instagram --tail 20
```
Expected: clean startup, appservice registered.

- [ ] **Step 6: Log in + verify (Phase 4 gate)**

In Element, message `@instagrambot:gjermund.xyz`, run `login`, complete Instagram login. Send/receive one Instagram DM.
Expected: DM round-trips.

---

## Phase 5 — Hardening & backups

### Task 10: Database backups and Komodo registration

- [ ] **Step 1: Nightly pg_dump of all four databases**

Create `/zfs/config/matrix/backup.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
OUT=/zfs/config/matrix/backups
mkdir -p "$OUT"
STAMP=$(date +%F)
for db in synapse mautrix_discord mautrix_meta_messenger mautrix_meta_instagram; do
  docker exec matrix-postgres pg_dump -U matrix "$db" | gzip > "$OUT/$db-$STAMP.sql.gz"
done
# keep last 14 days
find "$OUT" -name '*.sql.gz' -mtime +14 -delete
```

```bash
chmod +x /zfs/config/matrix/backup.sh
```

- [ ] **Step 2: Schedule it (match the host's existing cron/systemd convention)**

```bash
( crontab -l 2>/dev/null; echo "30 3 * * * /zfs/config/matrix/backup.sh" ) | crontab -
```
Verify: `crontab -l | grep backup.sh`.

- [ ] **Step 3: Test the backup once**

```bash
/zfs/config/matrix/backup.sh && ls -lh /zfs/config/matrix/backups/
```
Expected: four `.sql.gz` files with non-zero size.

- [ ] **Step 4: Confirm the stack is manageable like the others**

Ensure `/zfs/stacks/matrix/` behaves like the host's other plain Compose stacks:
`cd /zfs/stacks/matrix && docker compose ps` lists all services, and the stack
shows up in Arcane. No extra registration needed — it's plain `docker compose`.

- [ ] **Step 5: Verify signing key is backed up**

```bash
ls -l /zfs/config/matrix/synapse/*.signing.key
```
Expected: one signing key present. Confirm `/zfs/config/matrix/` is covered by the host's ZFS snapshot/backup routine (the signing key + registrations are non-regenerable — losing them breaks federation identity).

---

## Rollback

- Per bridge: `docker compose rm -sf <bridge>`, remove its `app_service_config_files` line + registration file, restart Synapse. Bridge DB can be dropped if abandoning.
- Whole stack: `docker compose down`; remove Caddy blocks + reload; remove the Cloudflare `matrix` record. `/zfs/config/matrix/` retains all data for a retry.

## Definition of done

- `federationtester.matrix.org` reports `FederationOK:true` for `gjermund.xyz`.
- Element (desktop + mobile Element X) logs in as `@gjermund:gjermund.xyz`.
- All three bridges log in and round-trip a real DM, with double puppeting.
- Nightly DB backup produces dated dumps; signing key covered by host backups.
