# Routes the default `claude` (Claude Code) on every host through the
# self-hosted 9Router instance on k3s (192.168.0.182:20128). 9Router falls
# back from the personal Claude subscription to Ollama Cloud, then to Kiro
# free, when subscription limits are hit.
#
# 9Router itself is a docker-compose stack on the Debian host `k3s`
# (/zfs/stacks/9router/), NOT managed by this config. See
# docs/superpowers/specs/2026-09-08-9router-claude-routing-design.md.
#
# Model selection uses Claude Code's GATEWAY MODEL DISCOVERY: 9Router serves
# /v1/models (combos + raw providers), the /model picker is populated from it,
# and ANTHROPIC_MODEL picks the default session model (the route-sonnet
# combo). CLAUDE.md "9Router" has the combo table and the classifier rules.
#
# How the env reaches Claude Code: this HM activation merges the block into
# ~/.claude/settings.json's `env` (9Router's documented setup). settings.json
# env is applied by Claude Code itself at startup and beats shell env, so
# unlike the previous zsh-init approach this also covers GUI-launched `claude`
# (no interactive shell). Only the ANTHROPIC_*/CLAUDE_CODE_* keys we own are
# merged — everything else in the user's settings.json (hooks, permissions,
# plugins… Claude Code rewrites the file for theme changes etc.) is preserved.
#
# The API key comes from the sops secret at /run/secrets/9router_api_key
# (modules/secrets.nix) at activation time and is written ONLY to the local
# settings.json — never into this repo. Remote /v1 access to 9Router requires
# it (only same-host calls skip the check).
#
# [1m] tells Claude Code to use the 1M context window; it strips the suffix
# again before the request reaches 9Router, so it is purely a client-side
# flag, not a combo name. Only safe because the primary cc/ tier (Sonnet 5 /
# Opus 5) natively supports 1M — if a request falls back past that to
# ollama/* or kr/*, those legs may not honor the full window.
#
# permissions.defaultMode = "bypassPermissions" (= --dangerously-skip-
# permissions, as a setting): NO permission prompts, NO auto-mode classifier
# calls. Chosen deliberately (2026-09-08): the classifier round-trips through
# 9Router with the whole transcript, and its internal timeout is tighter than
# any remote model's latency when the cc/ tier 429s — auto-mode Bash blocked
# in every subscription-limit window. Bypass removes the dependency entirely
# (and works for GUI launches, which a shell alias would not). Consequence:
# every Bash/edit runs without approval — the safety net is your own review
# of what Claude does. Change this one key back to "default" in
# ~/.claude/settings.json for normal prompting.
#
# The haiku alias serves background functionality (the Bash permission
# classifier fallback). It points at the same `route-sonnet` combo as the
# session model — there is no separate fast combo any more (2026-10-10: the
# only combo left in 9Router is `route-sonnet`; route-sonnet-fast and
# route-opus are gone, and the whole cc/ tier 401s because there is no Claude
# subscription). Note the trade-off: `route-sonnet` leads with cc/ and falls
# through to Ollama/Kiro, so a classifier call pays that fallback hop. If Bash
# ever blocks with "route-sonnet is temporarily unavailable", point this back
# at a single raw non-cc model instead — kr/claude-haiku-4.5 measured clean
# (no thinking blocks, ~840ms).
#
# Companion pieces in modules/system/packages.nix:
#   - claude-direct overrides the settings.json env via --settings (unsetting
#     shell env is not enough — settings env wins) so it talks to Anthropic
#   - wclaude runs with its own CLAUDE_CONFIG_DIR, so it never sees this block
{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.activation.routeClaudeThrough9Router =
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      settings="$HOME/.claude/settings.json"
      tokenFile="/run/secrets/9router_api_key"

      if [ ! -r "$tokenFile" ]; then
        echo "nix-config: $tokenFile not readable — 9Router env NOT merged into $settings"
      elif ${pkgs.python3}/bin/python3 - "$settings" "$tokenFile" <<'PYEOF'
import json, sys

settings_path, token_path = sys.argv[1], sys.argv[2]
env = {
    "ANTHROPIC_BASE_URL": "http://192.168.0.182:20128/v1",
    "ANTHROPIC_AUTH_TOKEN": open(token_path).read().strip(),
    "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY": "1",
    "ANTHROPIC_MODEL": "route-sonnet[1m]",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "route-sonnet",
}
try:
    with open(settings_path) as f:
        s = json.load(f)
except FileNotFoundError:
    s = {}
except json.JSONDecodeError:
    sys.exit(f"nix-config: {settings_path} is not valid JSON — fix it by hand; 9Router env not merged")

merged = {**s.get("env", {}), **env}
perm = s.get("permissions", {})
changed = False
if perm.get("defaultMode") != "bypassPermissions":
    perm = {**perm, "defaultMode": "bypassPermissions"}
    changed = True
    print("nix-config: set permissions.defaultMode=bypassPermissions in ~/.claude/settings.json")

# Remove the built-in web tools from Claude's context entirely. Bare-name deny
# rules do that (not just block calls), so the model is never offered a tool that
# cannot work here, and the definitions stop costing tokens. Deny rules are
# honoured in every permission mode including bypassPermissions, so this holds
# despite defaultMode above.
#
# Both are unusable on this instance: WebSearch/WebFetch ask *Anthropic* to run
# the search server-side, but this session's requests go through 9Router and
# never reach Anthropic (its cc/ tier 401s -- no Claude subscription on this
# account), so no web_search_tool_result is ever produced. The replacement is the
# nine-router-search MCP server (modules/home/claude-mcp.nix).
#
# Only ever added to ~/.claude/settings.json -- `wclaude` runs with
# CLAUDE_CONFIG_DIR=~/.claude-work and real Anthropic, where both tools work
# fine, so nothing here touches it.
DENY = ["WebSearch", "WebFetch"]
if perm.get("deny") != DENY:
    perm = {**perm, "deny": DENY}
    changed = True
    print("nix-config: denied WebSearch/WebFetch in ~/.claude/settings.json")

if s.get("permissions") != perm:
    s["permissions"] = perm
    changed = True
if s.get("env") != merged:
    s["env"] = merged
    changed = True
    print("nix-config: merged 9Router env into ~/.claude/settings.json")
if changed:
    with open(settings_path, "w") as f:
        json.dump(s, f, indent=2)
        f.write("\n")
sys.exit(0)
PYEOF
      then
        :
      else
        echo "nix-config: 9Router settings.json merge failed (see above)"
      fi
    '';
}