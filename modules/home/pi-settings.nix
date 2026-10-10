# Registers the self-hosted 9Router instance (see CLAUDE.md "9Router") as a
# custom provider for the `pi` coding agent (https://github.com/earendil-works/pi,
# installed via `npm install -g @earendil-works/pi-coding-agent` — no nixpkgs
# entry, and the release binary route was declined in favor of the officially
# documented npm install + pi's own self-updater).
#
# Only ~/.pi/agent/models.json is Nix-managed. ~/.pi/agent/settings.json is
# left alone: pi writes defaultProvider/defaultModel there itself when you
# press Ctrl+S in /model, and a Nix-owned settings.json would fight that the
# same way monitors.lua used to before it became self-updating (see CLAUDE.md
# "monitors.lua is now self-updating"). Run `pi`, `/model`, pick a
# `9router/route-*` model, Ctrl+S to make it the startup default.
#
# apiKey uses pi's `!command` value syntax (models.md "Value Resolution") to
# shell out to `cat /run/secrets/9router_api_key` at request time instead of
# baking the sops secret into this file or any activation-written JSON — the
# secret never leaves /run/secrets. The file is world-readable-by-owner-only
# (mode 0400, owner gjermund — modules/secrets.nix), and pi runs as gjermund,
# so no secrets.nix change is needed.
#
# authHeader = true forces `Authorization: Bearer <key>` instead of pi's
# default native Anthropic `x-api-key` header for the anthropic-messages API.
# This mirrors exactly how Claude Code's ANTHROPIC_AUTH_TOKEN talks to
# 9Router today (modules/home/claude-settings.nix) — 9Router's dashboard-
# issued API key is checked as a bearer token, not as a native Anthropic key.
#
# Only `route-sonnet` is registered. It is the sole combo left in 9Router
# (2026-10-10); the former route-sonnet-fast and route-opus combos are gone, and
# the cc/ tier 401s outright (no Claude subscription), so the combo works via
# its Ollama/Kiro fallback legs. Cost is zero because it is a fallback chain,
# not a single metered model — usage tracking in pi's UI is not meaningful.
# The 1M contextWindow is only honored while a request stays on the primary
# cc/claude-sonnet-5 leg, which currently never succeeds; declaring it anyway is
# harmless and correct if the cc/ credential is restored.
{ lib, ... }:
{
  home.file.".pi/agent/models.json".text = lib.generators.toJSON { } {
    providers = {
      "9router" = {
        name = "9Router";
        baseUrl = "http://192.168.0.182:20128/v1";
        api = "anthropic-messages";
        apiKey = "!cat /run/secrets/9router_api_key";
        authHeader = true;
        models = [
          {
            id = "route-sonnet";
            name = "9Router Sonnet (fallback chain)";
            reasoning = true;
            input = [
              "text"
              "image"
            ];
            contextWindow = 1000000;
            maxTokens = 64000;
            cost = {
              input = 0;
              output = 0;
              cacheRead = 0;
              cacheWrite = 0;
            };
          }
        ];
      };
    };
  };
}
