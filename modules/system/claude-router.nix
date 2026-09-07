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
# Remote /v1 access requires a dashboard-issued API key — 9Router only skips
# the key check for requests from its own host (src/dashboardGuard.js), so
# the `REQUIRE_API_KEY` env var it documents is dead code. The key is a sops
# secret at /run/secrets/9router_api_key (modules/secrets.nix), exported
# below in zsh init; a static sessionVariables string can't hold a secret.
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
