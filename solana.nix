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

  # FHS environment that allows Solana to download platform-tools
  solana-fhs = pkgs.buildFHSEnv {
    name = "solana-fhs";
    targetPkgs = pkgs: [
      pkgs.stdenv.cc.cc.lib
      pkgs.zlib
      pkgs.openssl
      pkgs.systemd
      pkgs.cacert
      pkgs.curl
    ];
    runScript = "";
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

    # Create wrappers for each solana binary that run inside FHS
    for bin in ${solana-unwrapped}/bin/*; do
      if [ -f "$bin" ] && [ -x "$bin" ]; then
        name=$(basename "$bin")
        makeWrapper ${solana-fhs}/bin/solana-fhs $out/bin/$name \
          --add-flags "$bin"
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
