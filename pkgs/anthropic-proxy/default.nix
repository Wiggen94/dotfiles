# anthropic-proxy — Anthropic Messages API proxy to OpenAI-compatible
# endpoints (OpenRouter, etc), patched locally on top of upstream.
#
# Upstream: https://github.com/m0n0x41d/anthropic-proxy-rs (MIT)
#
# Local patches on top of upstream v1.2.0 (not yet upstreamed):
#   - `provider` field on the outgoing OpenAI-shaped request: injects a
#     fixed OpenRouter `provider` preferences object (OPENROUTER_PROVIDER_PREFERENCES)
#     so callers that can only speak the Anthropic Messages API (Claude
#     Code) still get OpenRouter's `only`/`ignore`/`sort`/quantization
#     routing controls, which OpenRouter's own "Anthropic Skin" endpoint
#     does not expose to Claude Code at all.
#   - `session_id` forwarded from Claude Code's own `metadata.user_id` (a
#     JSON blob Claude Code already sends, stable for one Claude Code
#     session) onto the outgoing request, enabling OpenRouter's sticky
#     provider routing without any client-side header injection.
#   - Dynamic, session-frozen provider routing (see src/routing.rs):
#     periodically polls `/models/{model}/endpoints` for live quantization,
#     and builds its own rolling per-provider latency/throughput picture
#     from real completed-request lookups (OpenRouter's public API does not
#     expose live performance stats). The combined "quantization-and-
#     performance" allowlist is computed fresh only for a session's first
#     request, then frozen for that session's lifetime so a stats update
#     mid-conversation can never bump a session off the provider holding
#     its warm prompt cache.
#
# See docs/ or ask about "orclaude" for the wrapper that runs this locally
# in front of OpenRouter for the DeepSeek-via-OpenRouter setup.
{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "anthropic-proxy";
  version = "1.2.0-local";

  src = lib.cleanSource ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  meta = with lib; {
    description = "Anthropic Messages API proxy to OpenAI-compatible endpoints, with dynamic OpenRouter provider routing";
    homepage = "https://github.com/m0n0x41d/anthropic-proxy-rs";
    license = licenses.mit;
    mainProgram = "anthropic-proxy";
    platforms = platforms.unix;
  };
}
