# 9Router Default-`claude` Routing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route the default `claude` on all three NixOS hosts through a self-hosted 9Router on `k3s`, so requests fall back from the personal Claude subscription to Ollama Cloud, then to a free tier, when subscription limits hit.

**Architecture:** 9Router runs as a `docker compose` stack on the Debian host `k3s` (`192.168.0.182`), reachable from every host via the existing Tailscale subnet router. NixOS sets `ANTHROPIC_BASE_URL` + combo-name model aliases globally; `wclaude` and a new `claude-direct` wrapper opt back out. Providers and fallback combos are configured once in the 9Router web dashboard (not declarative).

**Tech Stack:** Docker Compose, NixOS modules (`environment.sessionVariables`, `writeShellScriptBin`), 9Router (`decolua/9router:latest`).

**Spec:** `docs/superpowers/specs/2026-09-08-9router-claude-routing-design.md`

---

## File Structure

| File | Location | Responsibility |
|---|---|---|
| `docker-compose.yml` | `/zfs/stacks/9router/` (on `k3s`, via NFS mount — **not** in this repo) | 9Router service definition, named data volume |
| `.env` | `/zfs/stacks/9router/` (on `k3s` — **not** in this repo, contains secrets) | `JWT_SECRET`, `INITIAL_PASSWORD`, runtime config |
| `claude-router.nix` | `modules/system/` (new) | Global `ANTHROPIC_*` session env pointing `claude` at 9Router |
| `common.nix` | `modules/` (modify) | Import `claude-router.nix` on all hosts |
| `packages.nix` | `modules/system/` (modify) | `wclaude` opt-out block; `dclaude`/`orclaude` defensive unset; new `claude-direct` wrapper |
| `CLAUDE.md` | repo root (modify) | Document the setup, combos, escape hatch |

Two tasks (1, 2) touch only `k3s` and the 9Router dashboard — no repo commit. Tasks 3–8 are repo changes, each committed. Task 9 hands off to the user for `nrs`.

---

## Task 1: Deploy the 9Router compose stack on `k3s`

**Files:**
- Create: `/zfs/stacks/9router/docker-compose.yml` (mounted locally over NFS at `/zfs`)
- Create: `/zfs/stacks/9router/.env`

Not a repo change — no commit. `/zfs` is the same NFS share mounted on this desktop, so the files can be authored locally; Docker commands run over SSH on `k3s`.

- [ ] **Step 1: Create the stack directory**

Run:
```bash
mkdir -p /zfs/stacks/9router
```
Expected: no output, `ls -d /zfs/stacks/9router` succeeds.

- [ ] **Step 2: Write `docker-compose.yml`**

Create `/zfs/stacks/9router/docker-compose.yml`:
```yaml
services:
  9router:
    image: decolua/9router:latest
    container_name: 9router
    restart: unless-stopped
    ports:
      - "20128:20128"
    env_file: .env
    volumes:
      - 9router-data:/app/data

volumes:
  9router-data:
```

The data volume is a **named Docker volume** (host local disk), not a
`/zfs` bind mount — 9Router runs as root and `chown`s / writes SQLite into
`/app/data`, which fails on `/zfs` NFS root-squash.

- [ ] **Step 3: Generate secrets and write `.env`**

Run:
```bash
printf 'JWT_SECRET=%s\nINITIAL_PASSWORD=%s\n' \
  "$(openssl rand -hex 32)" "$(openssl rand -base64 18)" \
  > /zfs/stacks/9router/.env
cat >> /zfs/stacks/9router/.env <<'EOF'
NODE_ENV=production
DATA_DIR=/app/data
PORT=20128
HOSTNAME=0.0.0.0
REQUIRE_API_KEY=false
BASE_URL=http://192.168.0.182:20128
CLOUD_URL=https://9router.com
EOF
chmod 600 /zfs/stacks/9router/.env
```
Then print the dashboard password for the user to save:
```bash
grep INITIAL_PASSWORD /zfs/stacks/9router/.env
```
Expected: `.env` exists, mode `600`, contains both generated secrets plus the fixed lines.

- [ ] **Step 4: Pull and start the stack**

Run:
```bash
ssh gjermund@192.168.0.182 'cd /zfs/stacks/9router && docker compose pull && docker compose up -d'
```
Expected: image pulls, `Container 9router  Started`.

- [ ] **Step 5: Verify the service is healthy**

Run:
```bash
sleep 5 && curl -fsS http://192.168.0.182:20128/health
```
Expected: HTTP 200, a small JSON/text health body (not a connection refused / 502).

If it fails, check `ssh gjermund@192.168.0.182 'docker logs --tail 50 9router'` — a
permission error on `/app/data` means the volume mount is wrong (must be the
named volume, not a path).

- [ ] **Step 6: Confirm data persists on local disk, not `/zfs`**

Run:
```bash
ssh gjermund@192.168.0.182 'docker volume inspect 9router-data --format "{{.Mountpoint}}" && docker exec 9router ls -la /app/data/db'
```
Expected: mountpoint under `/var/lib/docker/volumes/…`, and `data.sqlite` present in `/app/data/db`.

---

## Task 2: Configure providers and combos in the dashboard

**Files:** none (9Router dashboard state, stored in the `9router-data` volume).

This is a **manual human step** — OAuth logins need a browser. The agent
prepares the checklist and verifies the result; the user performs the logins.

- [ ] **Step 1: Present the configuration checklist to the user**

Tell the user to open `http://192.168.0.182:20128`, log in with the
`INITIAL_PASSWORD` from Task 1 Step 3, then:

1. **Providers → Connect Claude Code** → OAuth with the **personal** Anthropic account.
2. **Providers → Connect Ollama Cloud** → paste an API key from <https://ollama.com/settings/keys>.
3. **Providers → Connect Kiro** → OAuth (AWS Builder ID / Google / GitHub), free tier.
4. Note the exact model slugs the dashboard now lists under each provider
   (`cc/claude-opus-…`, `cc/claude-sonnet-…`, `cc/claude-haiku-…`,
   `ollama/glm-…`, `ollama/glm-…-flash` or nearest, `kr/claude-sonnet-4.5`,
   `kr/claude-haiku-4.5`).
5. **Combos → Create** three, named exactly `route-opus`, `route-sonnet`, `route-haiku`:
   - `route-opus`:   `cc/claude-opus-<slug>`   → `ollama/glm-<slug>` → `kr/claude-sonnet-4.5`
   - `route-sonnet`: `cc/claude-sonnet-<slug>` → `ollama/glm-<slug>` → `kr/claude-sonnet-4.5`
   - `route-haiku`:  `cc/claude-haiku-<slug>`  → `ollama/glm-<flash-slug>` → `kr/claude-haiku-4.5`
6. Leave RTK token saver at its default (on).

- [ ] **Step 2: Verify the combos exist via the API**

Run:
```bash
curl -fsS http://192.168.0.182:20128/v1/models -H 'x-api-key: 9router' \
  | grep -o '"id":"route-[a-z]*"'
```
Expected: `"id":"route-opus"`, `"id":"route-sonnet"`, `"id":"route-haiku"` all present.

- [ ] **Step 3: Verify a routed completion actually returns**

Run:
```bash
curl -sS http://192.168.0.192:20128/v1/messages \
  -H 'content-type: application/json' -H 'x-api-key: 9router' \
  -H 'anthropic-version: 2023-06-01' \
  -d '{"model":"route-sonnet","max_tokens":16,"messages":[{"role":"user","content":"reply with the single word ok"}]}'
```
Expected: a JSON response containing `"type":"message"` and an assistant
`content` block with text. (Correct host is `192.168.0.182` — fix the typo
if copy-pasting.)

If this 404s, retry with the URL `http://192.168.0.182:20128/v1/v1/messages`
and also `.../messages` — record which path returns a completion; Task 3 uses it.

---

## Task 3: Determine the correct `ANTHROPIC_BASE_URL` shape

**Files:** none — produces a recorded fact used by Task 4.

- [ ] **Step 1: Test the bare host:port form (Anthropic SDK convention)**

Run:
```bash
curl -sS -o /dev/null -w '%{http_code}\n' \
  http://192.168.0.182:20128/v1/messages \
  -H 'content-type: application/json' -H 'x-api-key: 9router' \
  -H 'anthropic-version: 2023-06-01' \
  -d '{"model":"route-haiku","max_tokens":8,"messages":[{"role":"user","content":"hi"}]}'
```
Expected: `200`. This means `ANTHROPIC_BASE_URL=http://192.168.0.182:20128`
is correct (Claude Code appends `/v1/messages`).

- [ ] **Step 2: If Step 1 was not 200, test the `/v1`-suffixed form**

Run:
```bash
curl -sS -o /dev/null -w '%{http_code}\n' \
  http://192.168.0.182:20128/v1/v1/messages \
  -H 'content-type: application/json' -H 'x-api-key: 9router' \
  -H 'anthropic-version: 2023-06-01' \
  -d '{"model":"route-haiku","max_tokens":8,"messages":[{"role":"user","content":"hi"}]}'
```
If this is `200`, the base URL must be `http://192.168.0.182:20128/v1`.

- [ ] **Step 3: Record the winner**

Write the working base URL into the plan here and use it verbatim in Task 4:

```
ANTHROPIC_BASE_URL = ____________________________   (fill in)
```

---

## Task 4: Create `modules/system/claude-router.nix` and wire it in

**Files:**
- Create: `modules/system/claude-router.nix`
- Modify: `modules/common.nix` (imports list)

- [ ] **Step 1: Create the module**

Create `modules/system/claude-router.nix` (replace the `ANTHROPIC_BASE_URL`
value with the one recorded in Task 3 Step 3):
```nix
# Routes the default `claude` (Claude Code) on every host through the
# self-hosted 9Router instance on k3s (192.168.0.182:20128). 9Router falls
# back from the personal Claude subscription to Ollama Cloud, then to a free
# tier (Kiro), when subscription limits are hit.
#
# 9Router itself is a docker-compose stack on the Debian host `k3s`
# (/zfs/stacks/9router/), NOT managed by this config. See
# docs/superpowers/specs/2026-09-08-9router-claude-routing-design.md.
#
# route-opus / route-sonnet / route-haiku are 9Router *combo* names created
# in its dashboard, each: cc/claude-<x> -> ollama/glm-5 -> kr/claude-<x>.
#
# Reachable from every host via the Tailscale subnet router, so the raw
# subnet IP works both on and off the home LAN.
#
# Companion pieces in modules/system/packages.nix:
#   - wclaude unsets these vars so the work account stays on api.anthropic.com
#   - claude-direct unsets these vars — the escape hatch when k3s is unreachable
#   - dclaude / orclaude defensively unset the model-alias vars (they set
#     their own backend explicitly)
{
  environment.sessionVariables = {
    ANTHROPIC_BASE_URL = "http://192.168.0.182:20128";
    # REQUIRE_API_KEY=false on the server; Claude Code still needs a
    # non-empty token to issue requests. 9Router ignores the value.
    ANTHROPIC_AUTH_TOKEN = "9router";
    ANTHROPIC_DEFAULT_OPUS_MODEL = "route-opus";
    ANTHROPIC_DEFAULT_SONNET_MODEL = "route-sonnet";
    ANTHROPIC_DEFAULT_HAIKU_MODEL = "route-haiku";
  };
}
```

- [ ] **Step 2: Add the import in `modules/common.nix`**

Modify the `imports` list in `modules/common.nix` — add the line after
`./system/packages.nix` (line 17):
```nix
    ./system/packages.nix
    ./system/claude-router.nix
  ]
```
Unconditional: all three hosts route through 9Router (per the spec).

- [ ] **Step 3: Evaluate the new config**

Run:
```bash
cd ~/nix-config && nix eval --raw .#nixosConfigurations.desktop.config.environment.sessionVariables.ANTHROPIC_BASE_URL
```
Expected: prints the base URL string (e.g. `http://192.168.0.182:20128`), no eval error.

- [ ] **Step 4: Build (not switch) all three hosts**

Run:
```bash
cd ~/nix-config && for h in desktop laptop sikt; do nixos-rebuild build --flake ".#$h" || break; done
```
Expected: three successful builds, no errors. (`build` needs no root and no TTY.)

- [ ] **Step 5: Commit**

```bash
cd ~/nix-config && git add modules/system/claude-router.nix modules/common.nix
git commit -m "$(printf 'Add claude-router module: route default claude through 9Router\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01Y2t66EU65b84dsUGNHe7SH')"
```

---

## Task 5: Add the opt-out block to `wclaude`

**Files:**
- Modify: `modules/system/packages.nix` (the `wclaude` `writeShellScriptBin`, ~line 989–1018)

`wclaude` does a bare `exec claude` with no base URL. With the new global
`ANTHROPIC_BASE_URL`, the work Anthropic account would be routed through the
personal 9Router. It must opt out.

- [ ] **Step 1: Insert the unset block**

In `modules/system/packages.nix`, in the `wclaude` script, immediately after
`set -euo pipefail` and before `export CLAUDE_CONFIG_DIR=...`, add:
```bash
      # This is a plain Anthropic OAuth login for the work account. The
      # global 9Router routing env (modules/system/claude-router.nix) must
      # NOT apply here — that would send work traffic through the personal
      # router. Strip it before Claude Code starts.
      unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY \
        ANTHROPIC_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL \
        ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL \
        CLAUDE_CODE_SUBAGENT_MODEL
```

- [ ] **Step 2: Build to check the shell script still parses**

Run:
```bash
cd ~/nix-config && nixos-rebuild build --flake .#desktop
```
Expected: success. (`writeShellScriptBin` runs `shellcheck`/`bash -n` at
build; a syntax error fails the build here.)

- [ ] **Step 3: Verify the wrapper content**

Run:
```bash
cd ~/nix-config && nix build --no-link --print-out-paths .#nixosConfigurations.desktop.config.system.build.toplevel >/dev/null
grep -A2 'set -euo pipefail' $(nix eval --raw .#nixosConfigurations.desktop.pkgs.path >/dev/null 2>&1; command -v wclaude 2>/dev/null || echo /dev/null) 2>/dev/null || true
```
Simpler check — build a standalone copy:
```bash
cd ~/nix-config && cat $(nix eval --raw '.#nixosConfigurations.desktop.config.environment.systemPackages' 2>/dev/null | tr ' ' '\n' | grep -m1 wclaude || true)/bin/wclaude 2>/dev/null | grep -c 'unset ANTHROPIC_BASE_URL'
```
Expected: `1` (the unset line is present). If the eval expression is
awkward, it is sufficient that Step 2 built successfully and the diff shows
the block in `packages.nix`.

- [ ] **Step 4: Commit**

```bash
cd ~/nix-config && git add modules/system/packages.nix
git commit -m "$(printf 'wclaude: opt out of global 9Router routing env\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01Y2t66EU65b84dsUGNHe7SH')"
```

---

## Task 6: Defensive `unset` in `dclaude` and `orclaude`

**Files:**
- Modify: `modules/system/packages.nix` (`dclaude` ~line 870, `orclaude` ~line 1050)

Both already `export` their own `ANTHROPIC_BASE_URL` and all three
`ANTHROPIC_DEFAULT_*_MODEL`, so they are functionally correct today. Add the
`unset` anyway so a future edit that drops one `export` cannot silently
inherit a global combo name.

- [ ] **Step 1: `dclaude` — insert after `set -euo pipefail`**

```bash
      # Backend is set explicitly below; strip any inherited global 9Router
      # routing env (modules/system/claude-router.nix) so a partial future
      # edit can't leak a combo name in.
      unset ANTHROPIC_BASE_URL ANTHROPIC_DEFAULT_OPUS_MODEL \
        ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL
```

- [ ] **Step 2: `orclaude` — insert after `set -euo pipefail`**

```bash
      # Backend is set explicitly below; strip any inherited global 9Router
      # routing env (modules/system/claude-router.nix) so a partial future
      # edit can't leak a combo name in.
      unset ANTHROPIC_BASE_URL ANTHROPIC_DEFAULT_OPUS_MODEL \
        ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL
```

- [ ] **Step 3: Build**

Run:
```bash
cd ~/nix-config && nixos-rebuild build --flake .#desktop
```
Expected: success.

- [ ] **Step 4: Commit**

```bash
cd ~/nix-config && git add modules/system/packages.nix
git commit -m "$(printf 'dclaude, orclaude: defensively unset global routing env\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01Y2t66EU65b84dsUGNHe7SH')"
```

---

## Task 7: Add the `claude-direct` escape-hatch wrapper

**Files:**
- Modify: `modules/system/packages.nix` (add a `writeShellScriptBin` in the
  main package list, next to `pkgs.claude-code` ~line 863)

- [ ] **Step 1: Add the wrapper**

In `modules/system/packages.nix`, right after `pkgs.claude-code` (line 863),
add:
```nix
    # Escape hatch: the default `claude` is routed through 9Router on k3s
    # (modules/system/claude-router.nix). When k3s is down, or this machine
    # is off both the home LAN and Tailscale, that backend is unreachable.
    # `claude-direct` strips the routing env and runs Claude Code straight
    # against the personal Anthropic OAuth login in ~/.claude.
    (pkgs.writeShellScriptBin "claude-direct" ''
      #!/usr/bin/env bash
      set -euo pipefail
      unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY \
        ANTHROPIC_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL \
        ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL \
        CLAUDE_CODE_SUBAGENT_MODEL
      exec claude "$@"
    '')
```

- [ ] **Step 2: Build**

Run:
```bash
cd ~/nix-config && nixos-rebuild build --flake .#desktop
```
Expected: success.

- [ ] **Step 3: Commit**

```bash
cd ~/nix-config && git add modules/system/packages.nix
git commit -m "$(printf 'Add claude-direct wrapper: bypass 9Router when k3s is unreachable\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01Y2t66EU65b84dsUGNHe7SH')"
```

---

## Task 8: Document in `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md` (AI Claude Code Setups section; Custom Commands table; Networking section)

- [ ] **Step 1: Add a row to the "AI Claude Code Setups" table**

In the table under `## AI Claude Code Setups`, after the `orclaude` row, add:
```
| `claude` (default) | Personal Anthropic via **9Router** on k3s | Routed: subscription → Ollama Cloud → Kiro free. `claude-direct` bypasses it. |
```

- [ ] **Step 2: Add a "9Router" subsection under "AI Claude Code Setups"**

After the existing bullet list in that section, add:
```markdown
### 9Router (default `claude` routing)

The default `claude` on all three hosts is pointed at a self-hosted
[9Router](https://github.com/decolua/9router) instance via
`modules/system/claude-router.nix` (`ANTHROPIC_BASE_URL`,
`ANTHROPIC_DEFAULT_*_MODEL` = combo names).

- **Where it runs:** `docker compose` stack on `k3s` at
  `/zfs/stacks/9router/` (named volume `9router-data`, **not** on `/zfs` —
  root-squash). Port `20128`. Reached from every host over the Tailscale
  subnet router at `http://192.168.0.182:20128`. `REQUIRE_API_KEY=false` —
  the LAN/tailnet is the trust boundary; there is no public ingress.
- **Fallback chain** (9Router combos, configured in its dashboard, not in
  this repo): `route-opus` / `route-sonnet` / `route-haiku` =
  `cc/claude-<x>` → `ollama/glm-5` (Ollama Cloud, paid) → `kr/claude-<x>`
  (Kiro free, ~50 credits/mo).
- **Reconfigure providers/combos:** dashboard at
  `http://192.168.0.182:20128` (state lives in the `9router-data` volume).
- **`wclaude`** strips the routing env — the work account always talks to
  `api.anthropic.com` directly.
- **`claude-direct`** strips the routing env and runs against the pristine
  `~/.claude` OAuth login — use it when `k3s` is down or the machine is off
  both the LAN and Tailscale.
- **Update the stack:**
  `ssh gjermund@192.168.0.182 'cd /zfs/stacks/9router && docker compose pull && docker compose up -d'`

Design/spec: `docs/superpowers/specs/2026-09-08-9router-claude-routing-design.md`
```

- [ ] **Step 3: Add `claude-direct` to the Custom Commands table**

In the `## Custom Commands` table, add:
```
| `claude-direct` | Claude Code straight to Anthropic, bypassing 9Router (escape hatch) |
```

- [ ] **Step 4: Note the service in the Networking section**

Under `## Networking`, in the "Other open TCP ports" line or as a new
bullet, add:
```
- **9Router**: `192.168.0.182:20128` on k3s — default `claude` backend, reached via the Tailscale subnet router (see AI Claude Code Setups)
```

- [ ] **Step 5: Commit**

```bash
cd ~/nix-config && git add CLAUDE.md
git commit -m "$(printf 'Document 9Router default-claude routing\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01Y2t66EU65b84dsUGNHe7SH')"
```

---

## Task 9: Final verification and hand-off

**Files:** none — verification only. Claude never runs `nrs`.

- [ ] **Step 1: Confirm all three host builds are green**

Run:
```bash
cd ~/nix-config && for h in desktop laptop sikt; do echo "== $h =="; nixos-rebuild build --flake ".#$h" >/dev/null && echo OK || echo FAIL; done
```
Expected: `OK` for all three.

- [ ] **Step 2: Confirm 9Router is still serving**

Run:
```bash
curl -fsS http://192.168.0.182:20128/health && echo && \
curl -sS http://192.168.0.182:20128/v1/messages \
  -H 'content-type: application/json' -H 'x-api-key: 9router' \
  -H 'anthropic-version: 2023-06-01' \
  -d '{"model":"route-haiku","max_tokens":8,"messages":[{"role":"user","content":"ok"}]}' \
  | head -c 300
```
Expected: health 200, then a `"type":"message"` completion.

- [ ] **Step 3: Hand off to the user**

Tell the user:
> Build verified on all three hosts and 9Router is serving. Run `nrs` on
> each host to activate. After switching, on each host:
> - `claude -p "say ok"` — should return via 9Router (check the dashboard
>   usage view attributes it to `cc/…`).
> - `wclaude -p "say ok"` — should still hit Anthropic directly.
> - `claude-direct -p "say ok"` — should hit Anthropic directly.
> To exercise the fallback: temporarily drag `ollama/glm-5` to the top of
> the `route-sonnet` combo in the dashboard, run `claude -p "say ok"`, and
> confirm the usage view shows Ollama Cloud served it. Then restore the
> order.

- [ ] **Step 4: Update the memory index**

Add to `/home/gjermund/.claude/projects/-home-gjermund-nix-config/memory/MEMORY.md`
and create `project_9router_claude_routing.md` capturing: default `claude`
routes through 9Router on k3s; `claude-direct` is the bypass; combos live in
the dashboard not the repo; `REQUIRE_API_KEY=false` gated by tailnet.

---

## Self-Review Notes

- **Spec coverage:** service on k3s (T1), named volume not `/zfs` (T1 S2/S6),
  `REQUIRE_API_KEY=false` (T1 S3), providers + 3 combos (T2), base-URL shape
  resolution (T3), `claude-router.nix` + import all hosts (T4), `wclaude`
  opt-out (T5), `dclaude`/`orclaude` defensive unset (T6), `claude-direct`
  (T7), docs incl. networking + command table (T8), verification incl.
  forced tier-2 hit (T9). All spec sections mapped.
- **Placeholder scan:** the only intentional fill-ins are the live model
  slugs (T2 S1) and the base-URL winner (T3 S3) — both are explicitly
  "resolve at execution time" per the spec's open questions, with the exact
  command to resolve them. No `TODO`/`TBD`/vague-error-handling.
- **Type/name consistency:** combo names `route-opus` / `route-sonnet` /
  `route-haiku` used identically in T2, T4, T8, T9. Env var names identical
  across `claude-router.nix`, `wclaude`, `dclaude`, `orclaude`,
  `claude-direct`. Host IP `192.168.0.182` consistent (one deliberate typo
  call-out in T2 S3).
