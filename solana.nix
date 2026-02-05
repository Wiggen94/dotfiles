{ pkgs }:

let
  version = "3.1.8";

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
      mkdir -p $out/bin

      # Copy everything from bin/ (including platform-tools-sdk which must be sibling to binaries)
      cp -r solana-release/bin/* $out/bin/
      runHook postInstall
    '';
  };

in
pkgs.symlinkJoin {
  name = "solana-cli-${version}";
  paths = [ solana-unwrapped ];
  buildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    # Remove symlinks and create wrapper scripts for executables only
    for bin in $out/bin/*; do
      name=$(basename "$bin")
      # Only wrap regular executable files, not directories
      if [ -L "$bin" ] && [ -f "${solana-unwrapped}/bin/$name" ] && [ -x "${solana-unwrapped}/bin/$name" ]; then
        rm "$bin"
        makeWrapper ${solana-unwrapped}/bin/$name $out/bin/$name \
          --run 'export SOLANA_INSTALL_DIR="''${SOLANA_INSTALL_DIR:-$HOME/.local/share/solana}"'
      fi
    done
  '';

  meta = with pkgs.lib; {
    description = "Solana CLI tools";
    homepage = "https://solana.com";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
  };
}
