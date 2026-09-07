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
  - `REQUIRE_API_KEY=false`
  - `BASE_URL=http://192.168.0.182:20128`
- **`REQUIRE_API_KEY=false`** is deliberate. Reachability is already gated
  by the LAN and the Tailscale subnet router; there is no public ingress.
  This removes the need to distribute a 9Router API key secret to laptop
  and sikt (no sops expansion, no per-host 1Password wrapper). Claude Code
  still sends a dummy bearer token, which 9Router ignores. If the tailnet
  later gains untrusted devices, flip this to `true` and add the key via
  sops (desktop) / a launch wrapper (laptop, sikt).
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
decision to route sikt too). It sets global session env:

```nix
environment.sessionVariables = {
  ANTHROPIC_BASE_URL            = "http://192.168.0.182:20128";
  ANTHROPIC_AUTH_TOKEN          = "9router";        # dummy; REQUIRE_API_KEY=false
  ANTHROPIC_DEFAULT_OPUS_MODEL   = "route-opus";
  ANTHROPIC_DEFAULT_SONNET_MODEL = "route-sonnet";
  ANTHROPIC_DEFAULT_HAIKU_MODEL  = "route-haiku";
};
```

The exact `ANTHROPIC_BASE_URL` suffix (bare host:port vs. trailing `/v1`)
is confirmed with a real `/v1/messages` request during implementation —
the upstream doc says `/v1`, the Anthropic SDK convention says bare. One
wins; the spec value above is the starting guess and will be corrected in
the module if the test says so.

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

**No change:** `nrs`, the `anthropic-proxy-openrouter` service, `flake.nix`.

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

## Verification (before asking the user to `nrs`)

1. `curl -fsS http://192.168.0.182:20128/health` from the desktop.
2. Raw request to settle the base-URL shape:
   ```bash
   curl -sS http://192.168.0.182:20128/v1/messages \
     -H 'content-type: application/json' -H 'x-api-key: 9router' \
     -H 'anthropic-version: 2023-06-01' \
     -d '{"model":"route-sonnet","max_tokens":16,"messages":[{"role":"user","content":"hi"}]}'
   ```
   Adjust the module's `ANTHROPIC_BASE_URL` to whichever form returns a
   completion.
3. Build the module locally (`nix eval` / `nixos-rebuild build`), not switch.
4. After the user switches: `claude -p "say ok"` on each host; `wclaude -p
   "say ok"` still hits Anthropic directly (check
   `~/.claude-work` transcript / network).
5. Force a tier-2 hit (temporarily reorder the combo to put `ollama/glm-5`
   first, or exhaust tier 1) and confirm the dashboard usage view
   attributes the request to Ollama Cloud.

## Out of scope

- Packaging 9Router for Nix — upstream Docker image only.
- Tracking the compose stack in this repo — it targets a non-NixOS host.
- Any 9Router API-key secret management — `REQUIRE_API_KEY` stays `false`.
- `orclaude` / `dclaude` behavioural changes beyond the defensive `unset`.
- Caddy vhost for the dashboard — optional, can be added later.

## Open questions

- Exact current `cc/` and `ollama/` model slugs — resolved from the live
  dashboard at config time, not now.
- Whether `ANTHROPIC_BASE_URL` needs the `/v1` suffix — resolved by test 2.
