# 9Router — default `claude` with subscription → Ollama Cloud fallback

**Date:** 2026-09-08
**Status:** Design approved, pending spec review

## Goal

Route the default `claude` (Claude Code) on all three hosts through a
self-hosted [9Router](https://github.com/decolua/9router) instance so that
when the personal Claude subscription hits its 5-hour / weekly limits,
requests fall back automatically to Ollama Cloud (a paid plan the user
already has), and then to a free tier, instead of the session stopping.

9Router is a local OpenAI/Anthropic-compatible gateway: it does format
translation, per-provider quota tracking, ordered "combo" fallback, and RTK
tool-output compression (−20–40% input tokens).

## Architecture

Three parts, only the third lives in this repo.

### 1. 9Router service (on `k3s.lan`, not this repo)

`docker compose` stack at `/zfs/stacks/9router/` on the Debian Docker host
(`k3s`, `192.168.0.182`). The compose file and `.env` are written to that
path (mounted on the desktop over NFS, so they can be authored from here);
they are **not** tracked in nix-config.

- Image: `decolua/9router:latest`, published multi-arch by upstream.
- Port: `20128` (host `20128:20128`).
- **Data volume: a Docker named volume `9router-data` mounted at `/app/data`.**
  Not a `/zfs` bind mount — 9Router runs as root and writes
  `db/data.sqlite` into its data dir; `/zfs` is NFS with root-squash and
  this fails ("Operation not permitted"), exactly as it does for the host's
  Postgres containers. Named volumes live on the host's local disk.
- Env (`/zfs/stacks/9router/.env`, host-only, gitignored there):
  - `JWT_SECRET` — long random string
  - `INITIAL_PASSWORD` — dashboard first-login password
  - `NODE_ENV=production`
  - `DATA_DIR=/app/data`
  - `BASE_URL=http://192.168.0.182:20128`

### Auth reality (discovered during implementation)

9Router's `REQUIRE_API_KEY` env var is **dead code** — nothing in the
source reads it. API access is gated by `src/dashboardGuard.js`
(`canAccessPublicLlmApi`): a request to any `/v1/*` path is allowed
**without a key only when it originates from 9Router's own host**
(loopback peer + loopback `Origin`). Every **remote** request — which is
all three NixOS hosts hitting `k3s` — **must present a valid API key
created in the dashboard** (`Authorization: Bearer <key>` or `x-api-key`).
There is no IP-allowlist setting and no env override.

Consequence: the central deployment **requires** a real 9Router API key on
every client host. It is generated once in the dashboard
(Settings → API Keys) and distributed via **sops-nix**, which is expanded
from desktop-only to all three hosts for this (see component 4). The key
grants full use of the routed Claude subscription + Ollama credits, so it
is not committed.
- Reachability: `http://192.168.0.182:20128` resolves from every host —
  directly on the home LAN, and via the existing Tailscale **subnet
  router** when away. No MagicDNS name and no `.lan` DNS dependency; the
  raw subnet IP is what the subnet router guarantees.
- Optional, not required for this to work: a Caddy vhost
  `9router.gjermund.xyz` (Cloudflare DNS-01) fronting the dashboard UI for
  convenience. The Claude Code path stays on the raw port.

### 2. Provider + combo configuration (9Router dashboard, one-time)

Done in the web UI at `http://192.168.0.182:20128` after first boot.
Persisted in the `9router-data` volume; optionally mirrored via 9Router's
own cloud sync. **Not declarative — not in this repo.**

- **Tier 1** — connect **Claude Code** provider via OAuth with the personal
  Anthropic account. Exposes `cc/claude-*` models; 9Router tracks the
  5-hour + weekly quota.
- **Tier 2** — connect **Ollama Cloud** provider with an API key from
  <https://ollama.com/settings/keys>. Exposes `ollama/*` (`ollama/glm-5`,
  `ollama/kimi-k2.5`, `ollama/gpt-oss:120b`, …). Exact GLM slug is whatever
  Ollama Cloud currently serves — confirm in the dashboard model list.
- **Tier 3** — connect **Kiro** (free, OAuth via AWS Builder ID / Google /
  GitHub, ~50 credits/month, no card). Exposes `kr/claude-sonnet-4.5`,
  `kr/claude-haiku-4.5`, etc.
- **Combos** — create three, names referenced verbatim by the NixOS env:
  - `route-opus`   = `cc/claude-opus-<x>`   → `ollama/glm-5` → `kr/claude-sonnet-4.5`
  - `route-sonnet` = `cc/claude-sonnet-<x>` → `ollama/glm-5` → `kr/claude-sonnet-4.5`
  - `route-haiku`  = `cc/claude-haiku-<x>`  → `ollama/glm-4.7-flash` → `kr/claude-haiku-4.5`

  Exact `cc/` slugs (`opus-4-7` etc.) filled from the dashboard's live list
  at config time.
- Leave RTK token saver at its default (on).

### 3. NixOS client wiring (this repo, all three hosts)

**New file `modules/system/claude-router.nix`**, added to the `imports`
list in `modules/common.nix` (unconditional — all three hosts, per the
decision to route sikt too).

**All four vars go in `programs.zsh.interactiveShellInit`, not
`environment.sessionVariables`.** `sessionVariables` land in
`/etc/set-environment`, which each shell sources only once per login
(guarded by `__NIXOS_SET_ENVIRONMENT_DONE`). A graphical session that
predates the rebuild keeps that flag exported, so **new terminals never
pick the vars up until a full re-login** — and a half-applied state (token
set, base URL not) sends the 9Router key to `api.anthropic.com` and blocks
`claude` entirely. `/etc/zshrc` (from `interactiveShellInit`) re-runs for
every interactive shell, so a new terminal is enough.

```nix
programs.zsh.interactiveShellInit = ''
  export ANTHROPIC_BASE_URL="http://192.168.0.182:20128"
  export ANTHROPIC_DEFAULT_OPUS_MODEL="route-opus"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="route-sonnet"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="route-haiku"
  if [ -r /run/secrets/9router_api_key ]; then
    export ANTHROPIC_AUTH_TOKEN="$(cat /run/secrets/9router_api_key)"
  fi
'';
```

GUI-launched `claude` (no interactive shell) is not routed — an accepted
limitation, matching the existing `dclaude`/`orclaude` GUI-launch caveat;
terminal use is the norm and `claude-direct` is the fallback. This also
keeps `ANTHROPIC_BASE_URL` out of the `anthropic-proxy-openrouter` systemd
user service's environment (which `sessionVariables` would have entered).

The exact `ANTHROPIC_BASE_URL` suffix (bare host:port vs. trailing `/v1`)
is confirmed with a real `/v1/messages` request during implementation —
the upstream doc says `/v1`, the Anthropic SDK convention says bare.

**Companion changes in `modules/system/packages.nix`:**

- **`wclaude`** — currently does a bare `exec claude` with no base URL, so a
  global `ANTHROPIC_BASE_URL` would silently route the *work* Anthropic
  account through the *personal* 9Router. Add near the top, before the
  `exec`:
  ```bash
  unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN \
        ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL \
        ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_MODEL CLAUDE_CODE_SUBAGENT_MODEL
  ```
- **`dclaude`, `orclaude`** — already export their own `ANTHROPIC_BASE_URL`
  and model vars, so they are functionally unaffected. Add the same
  defensive `unset` of the three `ANTHROPIC_DEFAULT_*_MODEL` vars at the top
  anyway, so a global combo name can never leak into a code path that
  doesn't re-set all three.
- **New `claude-direct` wrapper** (`writeShellScriptBin`), installed on all
  hosts:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN \
        ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL \
        ANTHROPIC_DEFAULT_HAIKU_MODEL
  exec claude "$@"
  ```
  The escape hatch when `k3s` is down or the machine is off both the LAN
  and Tailscale — otherwise the default `claude` has no working backend in
  that state. Uses the pristine `~/.claude` OAuth login.

**Docs:**

- `CLAUDE.md` — new "9Router" section (what it is, where it runs, the combo
  chain, `claude-direct` escape hatch, how to reconfigure providers); add a
  row to the "AI Claude Code Setups" table; note the new Tailscale-reached
  service in the Networking section.

### 4. sops-nix expansion to all three hosts (this repo)

Currently `inputs.sops-nix.nixosModules.sops` and `./modules/secrets.nix`
are in the **desktop** host modules only (`flake.nix`), and `secrets.nix`
carries one desktop-specific secret (`ritz_tcl`, the curitz/Zino config).

Changes:

- `flake.nix` — add `inputs.sops-nix.nixosModules.sops` and
  `./modules/secrets.nix` to the `laptop` and `sikt` `hostModules` lists.
- `modules/secrets.nix` — restructure for multiple hosts:
  - Keep `defaultSopsFile` and `age.keyFile` (same path
    `~/.ssh/age-key.txt` on every host).
  - Guard `secrets.ritz_tcl` with `lib.mkIf (hostName == "desktop")` — it
    is only useful on desktop.
  - Add `secrets.\"9router_api_key\"` with
    `owner = "gjermund"; mode = "0400";` on all hosts.
- `.sops.yaml` (new, repo root) — creation rules listing the age recipients
  for `secrets/secrets.yaml`: the existing desktop key plus new keys for
  `laptop` and `sikt`.
- `secrets/secrets.yaml` — add the `9router_api_key` entry and re-encrypt
  to all three recipients (`sops updatekeys`).

**User-run, one-time, on laptop and sikt** (cannot be done from desktop):

```bash
# on each of laptop and sikt:
nix-shell -p age --run 'age-keygen -o ~/.ssh/age-key.txt'
age-keygen -y ~/.ssh/age-key.txt          # prints the public key -> hand to desktop
```

The two public keys go into `.sops.yaml`; then on desktop
`sops updatekeys secrets/secrets.yaml` re-wraps the data key for all three.
Until a host has its key and is a recipient, its build still succeeds but
`/run/secrets/9router_api_key` is absent there and the default `claude`
has no token on that host (falls back to `claude-direct`).

**No change:** `nrs`, the `anthropic-proxy-openrouter` service.

## Data flow

```
claude
  └─ $ANTHROPIC_BASE_URL/v1/messages   (Anthropic wire format)
       └─ 9Router @ 192.168.0.182:20128
            ├─ RTK: compress tool_result blocks
            └─ combo route-<alias>:
                 1. cc/claude-<alias>      personal subscription
                    │ quota exhausted / error
                 2. ollama/glm-5           Ollama Cloud (user's key)
                    │ error / unavailable
                 3. kr/claude-sonnet-4.5   Kiro free (~50 credits/mo)
            └─ response streamed back to Claude Code
```

## Failure modes

| Condition | Result | Mitigation |
|---|---|---|
| `k3s` down, or host off LAN **and** Tailscale | default `claude` fails to connect | `claude-direct` (pristine Anthropic); `wclaude` unaffected |
| 9Router up, Claude tier quota hit | auto-fallback to `ollama/glm-5` | none needed — this is the point |
| Ollama key missing / expired | 9Router skips tier 2 → Kiro | fix key in dashboard |
| All three tiers exhausted | upstream error surfaces in Claude Code | wait for reset / `claude-direct` |
| Global env leaks into `wclaude` | work account routed through personal 9Router | the `unset` block added to `wclaude` |
| Host has no sops key / not a recipient yet | `/run/secrets/9router_api_key` absent → `claude` gets no token → 401 from 9Router | add the host's age key to `.sops.yaml` + `sops updatekeys`; `claude-direct` meanwhile |

## Verification (before asking the user to `nrs`)

1. `curl -fsS http://192.168.0.182:20128/api/health` from the desktop → `{"ok":true}`.
2. Raw request to settle the base-URL shape, using a **real** dashboard API
   key (`$KEY`):
   ```bash
   curl -sS http://192.168.0.182:20128/v1/messages \
     -H 'content-type: application/json' -H "x-api-key: $KEY" \
     -H 'anthropic-version: 2023-06-01' \
     -d '{"model":"route-sonnet","max_tokens":16,"messages":[{"role":"user","content":"hi"}]}'
   ```
   Adjust the module's `ANTHROPIC_BASE_URL` to whichever form (bare /
   `/v1`) returns a completion.
3. `sops -d secrets/secrets.yaml` shows `9router_api_key`; `nixos-rebuild
   build --flake .#<host>` green for all three.
4. After the user switches: `claude -p "say ok"` on each host routes via
   9Router (dashboard usage shows `cc/…`); `wclaude -p "say ok"` still hits
   Anthropic directly; `claude-direct -p "say ok"` hits Anthropic directly.
5. Force a tier-2 hit (temporarily reorder the combo to put `ollama/glm-5`
   first) and confirm the dashboard usage view attributes the request to
   Ollama Cloud.

## Out of scope

- Packaging 9Router for Nix — upstream Docker image only.
- Tracking the compose stack in this repo — it targets a non-NixOS host.
- `orclaude` / `dclaude` behavioural changes beyond the defensive `unset`.
- Caddy vhost for the dashboard — optional, can be added later.
- Migrating the existing `ritz_tcl` secret's storage — only its host guard
  changes.

## Open questions

- Exact current `cc/` and `ollama/` model slugs — resolved from the live
  dashboard at config time, not now.
- Whether `ANTHROPIC_BASE_URL` needs the `/v1` suffix — resolved by verification 2.
