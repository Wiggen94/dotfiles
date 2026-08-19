# Quickshell restart unit, protonup auto-update, TESS miner
{
  config,
  pkgs,
  lib,
  hostName,
  ...
}:
let
  inherit (import ./_common.nix { inherit lib hostName; }) isWorkHost;
in
{
  # (the user's own quickshell bar unit is gone — omarchy's shell owns the bar)

  # Proton-GE auto-update service (disabled on work hosts)
  systemd.user.services.protonup = lib.mkIf (!isWorkHost) {
    Unit = {
      Description = "Update Proton-GE";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.protonup-ng}/bin/protonup";
      Environment = "PATH=${pkgs.coreutils}/bin";
    };
  };

  # Run on login and weekly (disabled on work hosts)
  systemd.user.timers.protonup = lib.mkIf (!isWorkHost) {
    Unit = {
      Description = "Update Proton-GE weekly and on login";
    };
    Timer = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1week";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  # Local Anthropic-to-OpenRouter proxy backing `orclaude` (DeepSeek via
  # OpenRouter, with session-frozen quantization + live-observed
  # latency/throughput routing — see pkgs/anthropic-proxy). Runs as a
  # persistent service, NOT spawned per `orclaude` launch, because its
  # routing state (the fp8+ tag cache and the rolling per-provider
  # performance stats it learns from real traffic) lives in-process memory —
  # restarting it on every terminal session would throw away everything it
  # has learned. `orclaude` just makes sure this is running and points
  # Claude Code at it.
  #
  # Not run on work hosts — `orclaude`/`orclaude-status` aren't installed there
  # either (see modules/system/packages.nix), so nothing would use it.
  systemd.user.services.anthropic-proxy-openrouter = lib.mkIf (!isWorkHost) {
    Unit = {
      Description = "Anthropic-to-OpenRouter proxy for orclaude";
      StartLimitIntervalSec = 300;
      StartLimitBurst = 20;
    };
    Service = {
      Type = "simple";
      ExecStart = toString (
        pkgs.writeShellScript "anthropic-proxy-openrouter-start" ''
          set -euo pipefail

          # Key resolution mirrors dclaude/orclaude: 1Password first (and
          # refresh the cache on success), falling back to the cached file
          # for logind/GUI-launch contexts where the 1Password CLI desktop
          # integration isn't reachable. Restart=on-failure below means a
          # locked vault at login just gets retried until it's unlocked.
          keyfile="$HOME/.claude-openrouter/key"
          mkdir -p "$HOME/.claude-openrouter"

          if key="$(op read "op://Personal/OpenRouter API/credential" 2>/dev/null)" && [ -n "$key" ]; then
            ( umask 077; printf '%s' "$key" > "$keyfile" )
          elif [ -s "$keyfile" ]; then
            key="$(cat "$keyfile")"
          else
            echo "anthropic-proxy-openrouter: no OpenRouter key available (1Password locked, no cached key yet)." >&2
            exit 1
          fi

          export UPSTREAM_BASE_URL="https://openrouter.ai/api"
          export OPENROUTER_API_KEY="$key"
          export ANTHROPIC_PROXY_BIND="127.0.0.1"
          export PORT="8317"
          # Pinned to the dated GA slug, not the floating alias — see the
          # comment on `orclaude` in modules/system/packages.nix for why.
          export PROVIDER_TRACKING_MODEL="deepseek/deepseek-v4-flash-20260731"
          # DeepSeek's own published latency/throughput for this model,
          # used as the floor other providers must clear once we have
          # enough observations of them (see pkgs/anthropic-proxy/src/routing.rs).
          export PROVIDER_MIN_THROUGHPUT="66"
          export PROVIDER_MAX_LATENCY_MS="870"

          exec ${pkgs.callPackage ../../pkgs/anthropic-proxy { }}/bin/anthropic-proxy
        ''
      );
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # (tess-miner automine service removed — ~/tess-miner was deleted, so the
  # every-30-min timer only ever failed with 203/EXEC)

}
