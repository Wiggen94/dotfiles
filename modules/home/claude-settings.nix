# Routes the default `claude` (Claude Code) on every host through the
# self-hosted 9Router instance on k3s (192.168.0.182:20128). 9Router falls
# back from the personal Claude subscription to Ollama Cloud, then to Kiro
# free, when subscription limits are hit.
#
# 9Router itself is a docker-compose stack on the Debian host `k3s`
# (/zfs/stacks/9router/), NOT managed by this config. See
# docs/superpowers/specs/2026-09-08-9router-claude-routing-design.md.
#
# Exactly the two keys 9Router's docs specify — nothing more. Model selection
# is whatever Claude Code sends (claude-sonnet-5 etc.), which routes to the
# matching provider on the 9Router side. The dashboard also has *combos*
# (multi-provider fallback chains, e.g. route-sonnet); to use one, point
# ANTHROPIC_MODEL at the combo name — see the fallback-chain notes in
# CLAUDE.md before re-adding model env vars here.
#
# How the env reaches Claude Code: this HM activation merges the block into
# ~/.claude/settings.json's `env` (9Router's documented setup). settings.json
# env is applied by Claude Code itself at startup and beats shell env, so
# unlike the previous zsh-init approach this also covers GUI-launched `claude`
# (no interactive shell). Only these keys are merged — everything else in the
# user's settings.json (hooks, permissions, plugins… Claude Code rewrites the
# file for theme changes etc.) is preserved.
#
# The API key comes from the sops secret at /run/secrets/9router_api_key
# (modules/secrets.nix) at activation time and is written ONLY to the local
# settings.json — never into this repo. Remote /v1 access to 9Router requires
# it (only same-host calls skip the check).
#
# Companion pieces in modules/system/packages.nix:
#   - claude-direct overrides the settings.json env via --settings (unsetting
#     shell env is not enough — settings env wins) so it talks to Anthropic
#   - dclaude / orclaude / orclaude-status run with their own CLAUDE_CONFIG_DIR
#     so they never see this block
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
}
try:
    with open(settings_path) as f:
        s = json.load(f)
except FileNotFoundError:
    s = {}
except json.JSONDecodeError:
    sys.exit(f"nix-config: {settings_path} is not valid JSON — fix it by hand; 9Router env not merged")

merged = {**s.get("env", {}), **env}
if s.get("env") != merged:
    s["env"] = merged
    with open(settings_path, "w") as f:
        json.dump(s, f, indent=2)
        f.write("\n")
    print("nix-config: merged 9Router env into ~/.claude/settings.json")
sys.exit(0)
PYEOF
      then
        :
      else
        echo "nix-config: 9Router settings.json merge failed (see above)"
      fi
    '';
}