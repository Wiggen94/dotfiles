{ pkgs }:

let
  version = "3.1.8";

  # Base solana binaries with patched ELF
  solana-unwrapped = pkgs.stdenv.mkDerivation {
    pname = "solana-cli-unwrapped";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/anza-xyz/agave/releases/download/v${version}/solana-release-x86_64-unknown-linux-gnu.tar.bz2";
      sha256 = "1s4ihw5zf9f1wbmzq4yp97i69cg9a8cng8dw7sy60x654y0vnlg9";
    };

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [
      pkgs.stdenv.cc.cc.lib
      pkgs.zlib
      pkgs.openssl
      pkgs.systemd
    ];

    autoPatchelfIgnoreMissingDeps = [
      "libsgx_uae_service.so"
      "libsgx_urts.so"
      "libOpenCL.so.1"
    ];

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r solana-release/* $out/
      runHook postInstall
    '';
  };

in
pkgs.stdenv.mkDerivation {
  pname = "solana-cli";
  inherit version;

  dontUnpack = true;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin

    # Create wrapper script that sets up writable SDK structure
    for bin in ${solana-unwrapped}/bin/*; do
      if [ -f "$bin" ] && [ -x "$bin" ]; then
        name=$(basename "$bin")
        cat > $out/bin/$name << 'WRAPPER'
#!/usr/bin/env bash
# Set up writable SDK directory structure
SOLANA_SDK_HOME="''${SOLANA_SDK_HOME:-$HOME/.local/share/solana/sdk}"
mkdir -p "$SOLANA_SDK_HOME/platform-tools-sdk/sbf/dependencies"

# Set SBF_SDK_PATH to our writable location
export SBF_SDK_PATH="$SOLANA_SDK_HOME/platform-tools-sdk/sbf"

# Copy SDK files if not present (first run setup)
if [ ! -f "$SOLANA_SDK_HOME/platform-tools-sdk/sbf/scripts/install.sh" ]; then
  cp -rn SOLANA_UNWRAPPED/bin/platform-tools-sdk/* "$SOLANA_SDK_HOME/platform-tools-sdk/" 2>/dev/null || true
fi

exec "SOLANA_UNWRAPPED/bin/BINNAME" "$@"
WRAPPER
        sed -i "s|SOLANA_UNWRAPPED|${solana-unwrapped}|g" $out/bin/$name
        sed -i "s|BINNAME|$name|g" $out/bin/$name
        chmod +x $out/bin/$name
      fi
    done
    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Solana CLI tools";
    homepage = "https://solana.com";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
  };
}
