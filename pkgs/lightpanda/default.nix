# Lightpanda — headless browser written in Zig, built for AI agents and
# automation (https://github.com/lightpanda-io/browser). Not a Chromium fork:
# ~16x less memory / ~9x faster than headless Chrome on the upstream crawl
# benchmark. Ships a native MCP server (`lightpanda mcp`, stdio or HTTP) and a
# CDP/WebDriver-BiDi server (`lightpanda serve`).
#
# Upstream distributes only prebuilt release binaries (no nixpkgs entry, not
# packaged in nix-community), so this is a hash-pinned fetchurl of the release
# artifact — nothing vendored, nothing built from source. The Linux builds are
# glibc-linked, so autoPatchelfHook rewrites the interpreter and rpath to the
# Nix store; the binary is then self-contained and does not depend on nix-ld
# (or a /lib64 shim) being present.
#
# To bump: set `version` below and refresh both hashes with
#   nix-prefetch-url --type sha256 \
#     https://github.com/lightpanda-io/browser/releases/download/<ver>/<asset>
# (the release artifact names are keyed by `<arch>-<os>`).
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  version = "1.0.0";

  assets = {
    x86_64-linux = {
      asset = "lightpanda-x86_64-linux";
      hash = "sha256-qlpLjtU9Hjizxz9bJkfQqEqC5nRFV/RfmpyFhYqgMcM=";
    };
    aarch64-linux = {
      asset = "lightpanda-aarch64-linux";
      hash = "sha256-aXkZJLzuQ7E7Ikr0yEViLF/mb9vBuBQ7+qOcqPhSRPU=";
    };
  };

  asset =
    assets.${stdenv.hostPlatform.system}
      or (throw "lightpanda: no prebuilt binary for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "lightpanda";
  inherit version;

  # fetchurl names the output after the URL basename, which is already the
  # binary itself — there is no archive to unpack.
  src = fetchurl {
    url = "https://github.com/lightpanda-io/browser/releases/download/${version}/${asset.asset}";
    inherit (asset) hash;
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/lightpanda
    runHook postInstall
  '';

  meta = {
    description = "Headless browser built from scratch for AI agents and automation";
    homepage = "https://github.com/lightpanda-io/browser";
    changelog = "https://github.com/lightpanda-io/browser/releases/tag/${version}";
    license = lib.licenses.agpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames assets;
    mainProgram = "lightpanda";
  };
}
