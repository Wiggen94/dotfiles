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
# secret at /run/secrets/9router_api_key (modules/secrets.nix).
#
# EVERYTHING is set in zsh init, NOT environment.sessionVariables:
# sessionVariables land in /etc/set-environment, which every shell sources
# only once per login (guarded by __NIXOS_SET_ENVIRONMENT_DONE). A running
# graphical session that predates the rebuild keeps that flag set, so new
# terminals never pick the vars up until a full re-login. zsh init
# (/etc/zshrc) re-runs for every interactive shell, so a new terminal is
# enough. Downside: GUI-launched `claude` (no interactive shell) is not
# routed — use a terminal, or `claude-direct`.
#
# Companion pieces in modules/system/packages.nix:
#   - wclaude unsets these vars so the work account stays on api.anthropic.com
#   - claude-direct unsets these vars — the escape hatch when k3s is unreachable
#   - dclaude / orclaude / orclaude-status unset them (they set their own backend)
{
  programs.zsh.interactiveShellInit = ''
    # 9Router routing for the default `claude` (modules/system/claude-router.nix).
    export ANTHROPIC_BASE_URL="http://192.168.0.182:20128"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="route-opus"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="route-sonnet"
    # haiku alias = background functionality (the Bash permission classifier).
    # It must NEVER route through a cc/ tier: when the personal subscription is
    # rate-limited (429), every request pays the 429-detection + fallback hop,
    # which exceeds the classifier's tight internal timeout and blocks ALL
    # Bash calls with "route-sonnet is temporarily unavailable". This combo is
    # Ollama-only — create it in the 9Router dashboard as a fallback combo with
    # just the fast Ollama model, no cc/ tier.
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="route-haiku-fast"
    if [ -r /run/secrets/9router_api_key ]; then
      export ANTHROPIC_AUTH_TOKEN="$(cat /run/secrets/9router_api_key)"
    fi
  '';
}
