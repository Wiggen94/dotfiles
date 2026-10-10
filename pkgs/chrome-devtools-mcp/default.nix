# Chrome DevTools for agents — MCP server giving a coding agent Chrome's
# DevTools surface (console, network, performance traces, real screenshots,
# source-mapped stack traces). https://github.com/ChromeDevTools/chrome-devtools-mcp
#
# Not in nixpkgs (checked 2026-10-10). Microsoft's playwright-mcp IS, but it is a
# different tool — see modules/home/claude-mcp.nix for which one this config uses.
#
# Packaged from the PUBLISHED npm TARBALL, not the GitHub source: the repo's
# `npm run build` (tsc) needs `third_party/devtools-frontend/.../acorn.mjs`,
# which lives in a git submodule absent from the tag archive — the source build
# fails with TS6053. The npm tarball instead ships `build/` already compiled,
# with puppeteer and the MCP SDK bundled into `build/src/third_party/index.js`
# and no runtime `dependencies` at all, so nothing needs installing at build
# time. Verified: `node build/src/bin/chrome-devtools-mcp.js --help` runs
# straight from the unpacked tarball with no node_modules.
#
# It ATTACHES to an already-running browser via `--browserUrl` rather than
# launching one. That matters here: this config stubs `pkgs.chromium` out
# entirely (modules/omarchy.nix), so the default `--channel stable` launch path
# would have no browser to find. It is pointed at Helium — a real Chromium 154
# already installed — running headless on 9222 (modules/home/helium-cdp.nix).
#
# To bump: set `version` to the npm version and refresh `hash` with
#   nix-prefetch-url --type sha256 --print-path \
#     https://registry.npmjs.org/chrome-devtools-mcp/-/chrome-devtools-mcp-<ver>.tgz
# (the printed base32 hash pastes straight in; SRI also works).
{
  lib,
  stdenv,
  fetchurl,
  nodejs,
  makeWrapper,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "chrome-devtools-mcp";
  version = "1.10.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/chrome-devtools-mcp/-/chrome-devtools-mcp-${finalAttrs.version}.tgz";
    hash = "sha256-ASy89ugy1PZwna0MIde+8XCJ6Ure6c8zF50V6gqa3ys=";
  };

  nativeBuildInputs = [ makeWrapper ];

  # fetchurl names the output after the URL basename; there is no build step,
  # the tarball's `build/` is already compiled JS.
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/chrome-devtools-mcp
    cp -r build LICENSE README.md package.json skills $out/share/chrome-devtools-mcp/

    mkdir -p $out/bin
    # node is wrapped in absolutely: Claude Code spawns MCP servers itself, so
    # the binary must not depend on the login shell's PATH.
    makeWrapper ${lib.getExe nodejs} $out/bin/chrome-devtools-mcp \
      --add-flags "$out/share/chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js"
    makeWrapper ${lib.getExe nodejs} $out/bin/chrome-devtools \
      --add-flags "$out/share/chrome-devtools-mcp/build/src/bin/chrome-devtools.js"

    runHook postInstall
  '';

  meta = {
    description = "Chrome DevTools for agents — MCP server exposing Chrome's debugging and performance tooling";
    homepage = "https://github.com/ChromeDevTools/chrome-devtools-mcp";
    changelog = "https://github.com/ChromeDevTools/chrome-devtools-mcp/releases/tag/chrome-devtools-mcp-v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "chrome-devtools-mcp";
    platforms = lib.platforms.linux;
  };
})
