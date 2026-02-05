{ pkgs }:

let
  version = "3.1.8";
in
pkgs.stdenv.mkDerivation {
  pname = "solana-cli";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://github.com/anza-xyz/agave/releases/download/v${version}/solana-release-x86_64-unknown-linux-gnu.tar.bz2";
    sha256 = "1s4ihw5zf9f1wbmzq4yp97i69cg9a8cng8dw7sy60x654y0vnlg9";
  };

  nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.makeWrapper ];
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
    mkdir -p $out/bin $out/share/solana

    # Copy SDK and libs
    cp -r solana-release/bin/platform-tools-sdk $out/share/solana/ || true
    cp -r solana-release/bin/perf-libs $out/share/solana/ || true

    # Copy and wrap binaries
    for bin in solana-release/bin/*; do
      if [ -f "$bin" ] && [ -x "$bin" ]; then
        name=$(basename "$bin")
        cp "$bin" $out/bin/
        wrapProgram $out/bin/$name \
          --set SBF_SDK_PATH $out/share/solana/platform-tools-sdk/sbf \
          --set-default SOLANA_INSTALL_DIR "\$HOME/.local/share/solana"
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
