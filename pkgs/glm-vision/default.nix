# glm-vision — vision proxy for text-only LLMs (DeepSeek etc.), patched locally
# on top of upstream.
#
# Upstream: https://github.com/shiss3/glm-vision (no license declared upstream)
#
# Local patches on top of upstream commit d8bf630 (2026-07-14):
#   - 0001: vision calls can go to a different gateway than the main upstream
#     (KIMI_VISION_BASE_URL / KIMI_VISION_AUTH_TOKEN). Needed so image
#     descriptions are done by OpenRouter while the main model stays on
#     DeepSeek-direct.
#   - 0002: recursively rewrite image blocks nested inside tool_result.content
#     (Read-on-image and MCP screenshots arrive there). Stock proxy only
#     rewrites top-level image blocks and would leak them to DeepSeek.
#
# Only the proxy binary (glm-vision-proxy) is installed; the bundled MCP
# server and PreToolUse hook are not needed (patch 0002 covers those paths).
{
  lib,
  fetchFromGitHub,
  buildNpmPackage,
  nodejs,
}:

buildNpmPackage {
  pname = "glm-vision";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "shiss3";
    repo = "glm-vision";
    rev = "d8bf6305ff610727a23074a81116d6b37d1bcd7c";
    hash = "sha256-jqAfHoWzn13ODGRyM3Fe1ob9GaGIhBQf5JY/8OCARjE=";
  };

  npmDepsHash = "sha256-G9bqRHdArRYN7RPKt5nau+EhsVtwBaw2KVnY23R4Vbo=";

  patches = [
    ./patches/0001-vision-endpoint-override.patch
    ./patches/0002-proxy-tool-result-recursion.patch
    ./patches/0003-proxy-health-check.patch
  ];

  postInstall = ''
    mkdir -p $out/bin
    cat > $out/bin/glm-vision-proxy <<EOF
    #!/usr/bin/env bash
    exec ${lib.getExe nodejs} "$out/lib/node_modules/kimi-vision-mcp/dist/proxy.js" "\$@"
    EOF
    chmod +x $out/bin/glm-vision-proxy
  '';

  meta = with lib; {
    description = "Rewrite image blocks to text descriptions before forwarding to an Anthropic-compatible gateway (gives vision to text-only models)";
    homepage = "https://github.com/shiss3/glm-vision";
    mainProgram = "glm-vision-proxy";
    platforms = platforms.unix;
  };
}
