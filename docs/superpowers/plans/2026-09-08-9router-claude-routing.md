# 9Router Default-`claude` Routing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route the default `claude` on all three NixOS hosts through a self-hosted 9Router on `k3s`, so requests fall back from the personal Claude subscription to Ollama Cloud, then to a free tier, when subscription limits hit.

**Architecture:** 9Router runs as a `docker compose` stack on the Debian host `k3s` (`192.168.0.182`), reached from every host via the Tailscale subnet router. Remote `/v1` access **requires** a dashboard-issued API key (9Router's `REQUIRE_API_KEY` env is dead code — the host-vs-remote check in `dashboardGuard.js` is what governs), so the key is distributed by expanding sops-nix from desktop-only to all three hosts. NixOS sets `ANTHROPIC_BASE_URL` + combo-name model aliases globally; the key is exported from `/run/secrets/9router_api_key` in zsh init; `wclaude` and a new `claude-direct` opt back out.

**Tech Stack:** Docker Compose, sops-nix, NixOS modules (`environment.sessionVariables`, `programs.zsh.interactiveShellInit`, `writeShellScriptBin`), 9Router (`decolua/9router:latest`).

**Spec:** `docs/superpowers/specs/2026-09-08-9router-claude-routing-design.md`

---

## File Structure

| File | Location | Responsibility |
|---|---|---|
| `docker-compose.yml`, `.env` | `/zfs/stacks/9router/` (on `k3s` via NFS mount — **not** in this repo) | 9Router service + named data volume; host secrets |
| `.sops.yaml` | repo root (new) | age recipients for `secrets/secrets.yaml` (desktop + laptop + sikt) |
| `secrets.nix` | `modules/` (modify) | multi-host; guard `ritz_tcl` to desktop; add `9router_api_key` |
| `secrets/secrets.yaml` | repo (modify, encrypted) | add `9router_api_key`, re-encrypt to 3 recipients |
| `flake.nix` | repo root (modify) | add sops-nix module + `secrets.nix` to `laptop` and `sikt` |
| `claude-router.nix` | `modules/system/` (new) | `ANTHROPIC_*` static env + key export from `/run/secrets` |
| `common.nix` | `modules/` (modify) | import `claude-router.nix` on all hosts |
| `packages.nix` | `modules/system/` (modify) | `wclaude` opt-out; `dclaude`/`orclaude` defensive unset; `claude-direct` |
| `CLAUDE.md` | repo root (modify) | document the setup |

---

## Task 1: Deploy the 9Router compose stack on `k3s` — DONE

Already executed. `/zfs/stacks/9router/{docker-compose.yml,.env}` written; stack
running; `curl http://192.168.0.182:20128/api/health` → `{"ok":true}`; data on
named volume `9router_9router-data`. Dashboard password is in
`/zfs/stacks/9router/.env` (`INITIAL_PASSWORD`).

- [x] Stack deployed and healthy
- [ ] **Cleanup step: drop the dead `REQUIRE_API_KEY` line from `.env`**

Edit `/zfs/stacks/9router/.env`, remove the `REQUIRE_API_KEY=false` line
(nothing reads it; keeping it implies a control that does not exist), then:
```bash
ssh gjermund@192.168.0.182 'cd /zfs/stacks/9router && docker compose up -d'
curl -fsS http://192.168.0.182:20128/api/health
```
Expected: `{"ok":true}`.

---

## Task 2: Configure providers, combos, and an API key in the dashboard

**Files:** none (9Router state lives in the `9router_9router-data` volume).

Manual human step — OAuth logins need a browser. The agent prepares the
checklist and verifies the result.

- [ ] **Step 1: Present the checklist to the user**

Open `http://192.168.0.182:20128`, log in with `INITIAL_PASSWORD` from
`/zfs/stacks/9router/.env`, then:

1. **Providers → Connect Claude Code** → OAuth, **personal** Anthropic account.
2. **Providers → Connect Ollama Cloud** → API key from <https://ollama.com/settings/keys>.
3. **Providers → Connect Kiro** → OAuth (AWS Builder ID / Google / GitHub), free tier.
4. Record the exact model slugs the dashboard lists (`cc/claude-opus-…`,
   `cc/claude-sonnet-…`, `cc/claude-haiku-…`, `ollama/glm-…`,
   `ollama/glm-…-flash` or nearest, `kr/claude-sonnet-4.5`, `kr/claude-haiku-4.5`).
5. **Combos → Create** three, named exactly:
   - `route-opus`   : `cc/claude-opus-<slug>`   → `ollama/glm-<slug>` → `kr/claude-sonnet-4.5`
   - `route-sonnet` : `cc/claude-sonnet-<slug>` → `ollama/glm-<slug>` → `kr/claude-sonnet-4.5`
   - `route-haiku`  : `cc/claude-haiku-<slug>`  → `ollama/glm-<flash-slug>` → `kr/claude-haiku-4.5`
6. **Settings → API Keys → Create** one key. Copy it — this is what goes
   into sops in Task 4. Call it `nixos-hosts`.
7. Leave RTK token saver at its default (on).

- [ ] **Step 2: Verify combos exist (needs the key from Step 1.6 as `$KEY`)**

```bash
curl -fsS http://192.168.0.182:20128/v1/models -H "x-api-key: $KEY" \
  | grep -o '"id":"route-[a-z]*"' | sort -u
```
Expected: `"id":"route-haiku"`, `"id":"route-opus"`, `"id":"route-sonnet"`.

- [ ] **Step 3: Verify a routed completion returns**

```bash
curl -sS http://192.168.0.182:20128/v1/messages \
  -H 'content-type: application/json' -H "x-api-key: $KEY" \
  -H 'anthropic-version: 2023-06-01' \
  -d '{"model":"route-sonnet","max_tokens":16,"messages":[{"role":"user","content":"reply with the single word ok"}]}'
```
Expected: JSON with `"type":"message"` and an assistant text block.

---

## Task 3: Determine the correct `ANTHROPIC_BASE_URL` shape

**Files:** none — produces a recorded fact for Task 5.

- [ ] **Step 1: Test the bare host:port form**

```bash
curl -sS -o /dev/null -w '%{http_code}\n' \
  http://192.168.0.182:20128/v1/messages \
  -H 'content-type: application/json' -H "x-api-key: $KEY" \
  -H 'anthropic-version: 2023-06-01' \
  -d '{"model":"route-haiku","max_tokens":8,"messages":[{"role":"user","content":"hi"}]}'
```
`200` → `ANTHROPIC_BASE_URL=http://192.168.0.182:20128` (Claude Code appends `/v1/messages`).

- [ ] **Step 2: If not 200, test the `/v1`-suffixed form**

```bash
curl -sS -o /dev/null -w '%{http_code}\n' \
  http://192.168.0.182:20128/v1/v1/messages \
  -H 'content-type: application/json' -H "x-api-key: $KEY" \
  -H 'anthropic-version: 2023-06-01' \
  -d '{"model":"route-haiku","max_tokens":8,"messages":[{"role":"user","content":"hi"}]}'
```
`200` here → base URL must be `http://192.168.0.182:20128/v1`.

- [x] **Step 3: Record the winner**

```
ANTHROPIC_BASE_URL = http://192.168.0.182:20128     (bare form; both bare and /v1 return 200, bare is the SDK convention)
```

Task 2 verified: all three combos present; `route-sonnet` completion
returned from `claude-sonnet-5` (tier 1). `cc/` slugs are
`claude-opus-5`, `claude-sonnet-5`, `claude-haiku-4-5-20251001`; Ollama has
`ollama/glm-5` and `ollama/glm-4.7-flash`. API key: stored for Task 4.

---

## Task 4: Expand sops-nix to all three hosts; add the `9router_api_key` secret

**Files:**
- Create: `.sops.yaml`
- Modify: `modules/secrets.nix`, `flake.nix`
- Modify (encrypted): `secrets/secrets.yaml`

- [ ] **Step 1: User generates age keys on laptop and sikt**

Tell the user to run on **each** of laptop and sikt:
```bash
nix-shell -p age --run 'age-keygen -o ~/.ssh/age-key.txt' 2>/dev/null || age-keygen -o ~/.ssh/age-key.txt
chmod 600 ~/.ssh/age-key.txt
age-keygen -y ~/.ssh/age-key.txt
```
The last command prints the **public** key (`age1…`). Collect both, plus
the existing desktop public key:
```bash
age-keygen -y ~/.ssh/age-key.txt   # run on desktop
```
Wait for the user to supply all three `age1…` strings before continuing.

- [ ] **Step 2: Write `.sops.yaml`**

Create `.sops.yaml` at the repo root (substitute the three real keys):
```yaml
keys:
  - &desktop age1desktopxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  - &laptop  age1laptopxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  - &sikt    age1siktxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
creation_rules:
  - path_regex: secrets/secrets\.yaml$
    key_groups:
      - age:
          - *desktop
          - *laptop
          - *sikt
```

- [ ] **Step 3: Re-encrypt `secrets/secrets.yaml` and add the new key**

Run from the repo root on desktop (1Password/age unlocked):
```bash
sops updatekeys secrets/secrets.yaml    # re-wraps the data key for all 3 recipients
sops secrets/secrets.yaml                # opens $EDITOR — add the line below, save
```
Add inside the YAML:
```yaml
9router_api_key: PASTE_THE_KEY_FROM_TASK_2_STEP_1.6
```
Verify:
```bash
sops -d secrets/secrets.yaml | grep -c 9router_api_key
```
Expected: `1`.

- [ ] **Step 4: Restructure `modules/secrets.nix`**

Replace the file with (keeps `ritz_tcl` desktop-only, adds the new key everywhere):
```nix
# sops-nix secrets — decrypted at activation with the age key in ~/.ssh/age-key.txt
#
# Edit secrets with:  sops secrets/secrets.yaml   (from repo root)
# Recipients (age keys) are listed in ../.sops.yaml; after adding one run
#   sops updatekeys secrets/secrets.yaml
{ lib, hostName, ... }:

{
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age.keyFile = "/home/gjermund/.ssh/age-key.txt";

    secrets = {
      # 9Router API key — bearer token for the routed `claude` on every host
      # (modules/system/claude-router.nix reads /run/secrets/9router_api_key).
      "9router_api_key" = {
        owner = "gjermund";
        group = "users";
        mode = "0400";
      };
    }
    # curitz Zino config at ~/.ritz.tcl — desktop only (needs EduVPN to reach hugin).
    // lib.optionalAttrs (hostName == "desktop") {
      ritz_tcl = {
        path = "/home/gjermund/.ritz.tcl";
        owner = "gjermund";
        group = "users";
        mode = "0600";
      };
    };
  };
}
```

- [ ] **Step 5: Add sops-nix to laptop and sikt in `flake.nix`**

In `flake.nix`, the `laptop` and `sikt` `hostModules` lists each gain two
lines (mirroring desktop's):
```nix
        laptop = mkHost {
          hostName = "laptop";
          hostModules = [
            inputs.sops-nix.nixosModules.sops
            ./hosts/laptop/hardware-configuration.nix
            ./hosts/laptop/nvidia-prime.nix
            ./hosts/laptop/default.nix
            ./modules/secrets.nix
          ];
        };
```
and the same `inputs.sops-nix.nixosModules.sops` + `./modules/secrets.nix`
for `sikt`.

- [ ] **Step 6: Build all three hosts**

```bash
cd ~/nix-config && for h in desktop laptop sikt; do echo "== $h =="; nixos-rebuild build --flake ".#$h" >/dev/null && echo OK || { echo FAIL; break; }; done
```
Expected: `OK` ×3. (A missing recipient key would only fail at *activation*,
not build — build just needs the module to evaluate.)

- [ ] **Step 7: Commit**

```bash
cd ~/nix-config && git add .sops.yaml modules/secrets.nix flake.nix secrets/secrets.yaml
git commit -m "$(printf 'sops: expand to all hosts, add 9router_api_key secret\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01Y2t66EU65b84dsUGNHe7SH')"
```

---

## Task 5: Create `modules/system/claude-router.nix` and wire it in

**Files:**
- Create: `modules/system/claude-router.nix`
- Modify: `modules/common.nix`

- [ ] **Step 1: Create the module**

Create `modules/system/claude-router.nix` (replace `ANTHROPIC_BASE_URL`
with the Task 3 Step 3 value):
```nix
# Routes the default `claude` (Claude Code) on every host through the
# self-hosted 9Router instance on k3s (192.168.0.182:20128). 9Router falls
# back from the personal Claude subscription to Ollama Cloud, then to Kiro
# free, when subscription limits are hit.
#
# 9Router itself is a docker-compose stack on the Debian host `k3s`
# (/zfs/stacks/9router/), NOT managed by this config. See
# docs/superpowers/specs/2026-09-08-9router-claude-routing-design.md.
#
# route-opus / route-sonnet / route-haiku are 9Router *combo* names created
# in its dashboard, each: cc/claude-<x> -> ollama/glm-5 -> kr/claude-<x>.
#
# Remote /v1 access requires a dashboard-issued API key (9Router only skips
# the key check for requests from its own host). The key is a sops secret
# at /run/secrets/9router_api_key (modules/secrets.nix), exported below in
# zsh init — a static sessionVariables string can't hold a secret.
#
# Companion pieces in modules/system/packages.nix:
#   - wclaude unsets these vars so the work account stays on api.anthropic.com
#   - claude-direct unsets these vars — the escape hatch when k3s is unreachable
#   - dclaude / orclaude defensively unset the model-alias vars
{
  environment.sessionVariables = {
    ANTHROPIC_BASE_URL = "http://192.168.0.182:20128";
    ANTHROPIC_DEFAULT_OPUS_MODEL = "route-opus";
    ANTHROPIC_DEFAULT_SONNET_MODEL = "route-sonnet";
    ANTHROPIC_DEFAULT_HAIKU_MODEL = "route-haiku";
  };

  # The API key is secret — read it from the sops-decrypted file at shell
  # start (sub-ms local read, no 1Password prompt). Interactive zsh is the
  # login shell on every host. GUI-launched `claude` won't get this (same
  # caveat as dclaude/orclaude) — use a terminal, or `claude-direct`.
  programs.zsh.interactiveShellInit = ''
    if [ -z "''${ANTHROPIC_AUTH_TOKEN:-}" ] && [ -r /run/secrets/9router_api_key ]; then
      export ANTHROPIC_AUTH_TOKEN="$(cat /run/secrets/9router_api_key)"
    fi
  '';
}
```

- [ ] **Step 2: Import it in `modules/common.nix`**

Add after `./system/packages.nix` (line 17):
```nix
    ./system/packages.nix
    ./system/claude-router.nix
  ]
```

- [ ] **Step 3: Evaluate and build**

```bash
cd ~/nix-config && nix eval --raw .#nixosConfigurations.sikt.config.environment.sessionVariables.ANTHROPIC_BASE_URL && echo
for h in desktop laptop sikt; do nixos-rebuild build --flake ".#$h" >/dev/null && echo "$h OK" || { echo "$h FAIL"; break; }; done
```
Expected: prints the base URL, then `desktop OK` / `laptop OK` / `sikt OK`.

- [ ] **Step 4: Commit**

```bash
cd ~/nix-config && git add modules/system/claude-router.nix modules/common.nix
git commit -m "$(printf 'Add claude-router module: route default claude through 9Router\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01Y2t66EU65b84dsUGNHe7SH')"
```

---

## Task 6: Add the opt-out block to `wclaude`

**Files:** Modify `modules/system/packages.nix` (`wclaude` script, ~line 989–1018)

`wclaude` does a bare `exec claude` with no base URL. With the new global
env, the work Anthropic account would be routed through the personal
9Router. It must opt out.

- [ ] **Step 1: Insert the unset block**

In the `wclaude` script, immediately after `set -euo pipefail` and before
`export CLAUDE_CONFIG_DIR=...`, add:
```bash
      # Plain Anthropic OAuth login for the work account — the global 9Router
      # routing env (modules/system/claude-router.nix) must NOT apply here.
      unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY \
        ANTHROPIC_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL \
        ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL \
        CLAUDE_CODE_SUBAGENT_MODEL
```

- [ ] **Step 2: Build (checks the shell script parses)**

```bash
cd ~/nix-config && nixos-rebuild build --flake .#desktop >/dev/null && echo OK
```
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
cd ~/nix-config && git add modules/system/packages.nix
git commit -m "$(printf 'wclaude: opt out of global 9Router routing env\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01Y2t66EU65b84dsUGNHe7SH')"
```

---

## Task 7: Defensive `unset` in `dclaude` and `orclaude`

**Files:** Modify `modules/system/packages.nix` (`dclaude` ~line 870, `orclaude` ~line 1050)

Both already `export` their own base URL and all three model vars, so they
are correct today. Add the `unset` so a future partial edit can't inherit a
global combo name.

- [ ] **Step 1: `dclaude` — after `set -euo pipefail`**

```bash
      # Backend set explicitly below; strip inherited global 9Router routing
      # env (modules/system/claude-router.nix).
      unset ANTHROPIC_BASE_URL ANTHROPIC_DEFAULT_OPUS_MODEL \
        ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL
```

- [ ] **Step 2: `orclaude` — after `set -euo pipefail`**

```bash
      # Backend set explicitly below; strip inherited global 9Router routing
      # env (modules/system/claude-router.nix).
      unset ANTHROPIC_BASE_URL ANTHROPIC_DEFAULT_OPUS_MODEL \
        ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL
```

- [ ] **Step 3: Build**

```bash
cd ~/nix-config && nixos-rebuild build --flake .#desktop >/dev/null && echo OK
```
Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
cd ~/nix-config && git add modules/system/packages.nix
git commit -m "$(printf 'dclaude, orclaude: defensively unset global routing env\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01Y2t66EU65b84dsUGNHe7SH')"
```

---

## Task 8: Add the `claude-direct` escape-hatch wrapper

**Files:** Modify `modules/system/packages.nix` (add a `writeShellScriptBin` right after `pkgs.claude-code`, ~line 863)

- [ ] **Step 1: Add the wrapper**

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

```bash
cd ~/nix-config && nixos-rebuild build --flake .#desktop >/dev/null && echo OK
```
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
cd ~/nix-config && git add modules/system/packages.nix
git commit -m "$(printf 'Add claude-direct wrapper: bypass 9Router when k3s is unreachable\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01Y2t66EU65b84dsUGNHe7SH')"
```

---

## Task 9: Document in `CLAUDE.md`

**Files:** Modify `CLAUDE.md`

- [ ] **Step 1: Add a row to the "AI Claude Code Setups" table**

After the `orclaude` row:
```
| `claude` (default) | Personal Anthropic via **9Router** on k3s | Routed: subscription → Ollama Cloud → Kiro free. `claude-direct` bypasses it. |
```

- [ ] **Step 2: Add a "9Router" subsection under "AI Claude Code Setups"**

```markdown
### 9Router (default `claude` routing)

The default `claude` on all three hosts routes through a self-hosted
[9Router](https://github.com/decolua/9router) via
`modules/system/claude-router.nix`.

- **Where it runs:** `docker compose` stack on `k3s` at
  `/zfs/stacks/9router/` (named volume `9router_9router-data` — **not** on
  `/zfs`, root-squash). Port `20128`, reached from every host over the
  Tailscale subnet router at `http://192.168.0.182:20128`.
- **Auth:** remote `/v1` calls need a dashboard-issued API key (9Router's
  `REQUIRE_API_KEY` env is dead code; only same-host calls skip the key).
  The key is a sops secret `9router_api_key` on all three hosts —
  `modules/system/claude-router.nix` exports it from
  `/run/secrets/9router_api_key` in zsh init.
- **Fallback chain** (9Router combos, dashboard-configured, not in this
  repo): `route-opus` / `route-sonnet` / `route-haiku` = `cc/claude-<x>` →
  `ollama/glm-5` (Ollama Cloud, paid) → `kr/claude-<x>` (Kiro free).
- **Reconfigure providers/combos:** dashboard at
  `http://192.168.0.182:20128` (state in the named volume).
- **`wclaude`** strips the routing env — the work account always talks to
  `api.anthropic.com` directly.
- **`claude-direct`** strips the routing env and runs against `~/.claude`'s
  OAuth login — use it when `k3s` is down or the machine is off both the
  LAN and Tailscale.
- **Update the stack:**
  `ssh gjermund@192.168.0.182 'cd /zfs/stacks/9router && docker compose pull && docker compose up -d'`

Design/spec: `docs/superpowers/specs/2026-09-08-9router-claude-routing-design.md`
```

- [ ] **Step 3: Add `claude-direct` to the Custom Commands table**

```
| `claude-direct` | Claude Code straight to Anthropic, bypassing 9Router (escape hatch) |
```

- [ ] **Step 4: Update the Secrets section**

Under `## Secrets (sops-nix)` — it currently says "Desktop only". Replace
with a note that sops-nix now runs on all three hosts (`.sops.yaml` lists
one age key per host), `9router_api_key` is shared by all, and `ritz_tcl`
stays desktop-only.

- [ ] **Step 5: Note the service in the Networking section**

```
- **9Router**: `192.168.0.182:20128` on k3s — default `claude` backend, reached via the Tailscale subnet router (see AI Claude Code Setups)
```

- [ ] **Step 6: Commit**

```bash
cd ~/nix-config && git add CLAUDE.md
git commit -m "$(printf 'Document 9Router default-claude routing\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01Y2t66EU65b84dsUGNHe7SH')"
```

---

## Task 10: Final verification and hand-off

**Files:** none. Claude never runs `nrs`.

- [ ] **Step 1: All three host builds green**

```bash
cd ~/nix-config && for h in desktop laptop sikt; do echo "== $h =="; nixos-rebuild build --flake ".#$h" >/dev/null && echo OK || echo FAIL; done
```
Expected: `OK` ×3.

- [ ] **Step 2: 9Router still serving a routed completion**

```bash
curl -fsS http://192.168.0.182:20128/api/health && echo
curl -sS http://192.168.0.182:20128/v1/messages \
  -H 'content-type: application/json' -H "x-api-key: $KEY" \
  -H 'anthropic-version: 2023-06-01' \
  -d '{"model":"route-haiku","max_tokens":8,"messages":[{"role":"user","content":"ok"}]}' | head -c 300
```
Expected: `{"ok":true}` then a `"type":"message"` completion.

- [ ] **Step 3: Hand off to the user**

> Builds verified on all three hosts; 9Router serving. On desktop the sops
> key is already present; **laptop and sikt need their age key added to
> `.sops.yaml` + `sops updatekeys` (Task 4) before their `claude` will
> authenticate** — until then use `claude-direct` there.
>
> Run `nrs` on each host to activate. Then per host:
> - `claude -p "say ok"` — routes via 9Router (dashboard usage shows `cc/…`)
> - `wclaude -p "say ok"` — still hits Anthropic directly
> - `claude-direct -p "say ok"` — hits Anthropic directly
>
> Exercise the fallback: drag `ollama/glm-5` to the top of the
> `route-sonnet` combo, run `claude -p "say ok"`, confirm the dashboard
> attributes it to Ollama Cloud, then restore the order.

- [ ] **Step 4: Update the memory index**

Add to `MEMORY.md` and create `project_9router_claude_routing.md`: default
`claude` routes through 9Router on k3s; `claude-direct` bypasses; combos
live in the dashboard not the repo; remote `/v1` needs a dashboard API key
(sops `9router_api_key`, now on all 3 hosts); `REQUIRE_API_KEY` env is dead
code.

---

## Self-Review Notes

- **Spec coverage:** k3s service + named volume (T1); auth reality + API key
  (T2 S6, T4); base-URL shape (T3); sops expansion to all hosts + new
  secret + `.sops.yaml` + `ritz_tcl` guard (T4); `claude-router.nix` with
  split static-env / secret-export + import all hosts (T5); `wclaude`
  opt-out (T6); `dclaude`/`orclaude` defensive unset (T7); `claude-direct`
  (T8); docs incl. Secrets + Networking + command table (T9); verification
  incl. forced tier-2 (T10). All spec sections mapped.
- **Placeholder scan:** intentional fill-ins are the live model slugs (T2),
  the base-URL winner (T3 S3), and the three `age1…` public keys (T4 S1–2)
  — each with the exact command that resolves it. No `TODO`/`TBD`/vague
  error handling.
- **Name consistency:** combo names `route-opus`/`route-sonnet`/`route-haiku`
  identical across T2, T5, T9, T10. Secret name `9router_api_key` identical
  in T4 (`secrets.nix`, `secrets.yaml`), T5 (`/run/secrets/9router_api_key`),
  T9. Env var names identical across `claude-router.nix`, `wclaude`,
  `dclaude`, `orclaude`, `claude-direct`. Volume name
  `9router_9router-data` (compose project-prefixed) consistent T1/T9.
  Health path `/api/health` (not `/health`) consistent everywhere.
