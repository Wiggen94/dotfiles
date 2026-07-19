# Nix settings, binary caches, overlays, nix-ld, comma, nh
{
  config,
  pkgs,
  lib,
  inputs,
  hostName,
  ...
}:
{
  nixpkgs.config.allowUnfree = true;

  # Enable flakes and binary caches
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    warn-dirty = false;
    # i7-10700KF: 8 cores/16 threads — cap parallel jobs to avoid memory pressure freezes
    max-jobs = 4;
    cores = 4;
    # Binary caches for faster builds
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
      "https://cuda-maintainers.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  # Custom overlays
  nixpkgs.overlays = [
    # Claude Code from dedicated overlay (updates independently of nixpkgs)
    inputs.claude-code-overlay.overlays.default

    # EDMarketConnector overlay to add SQLAlchemy for Pioneer/ExploData/BioScan plugins
    (final: prev: {
      edmarketconnector = prev.edmarketconnector.overrideAttrs (
        oldAttrs:
        let
          pythonEnv = prev.python3.buildEnv.override {
            extraLibs = with prev.python3.pkgs; [
              tkinter
              requests
              pillow
              watchdog
              semantic-version
              psutil
              tomli-w
              sqlalchemy # For Pioneer/ExploData/BioScan plugins
            ];
          };
        in
        {
          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin $out/share/applications $out/share/icons/hicolor/512x512/apps
            makeWrapper ${pythonEnv}/bin/python $out/bin/edmarketconnector \
              --add-flags "$src/EDMarketConnector.py"
            ln -s $src/io.edcd.EDMarketConnector.png $out/share/icons/hicolor/512x512/apps/
            ln -s $src/io.edcd.EDMarketConnector.desktop $out/share/applications/
            runHook postInstall
          '';
        }
      );
    })

    # FreeRDP overlay: add xfreerdp3/freerdp/freerdp3 symlinks for Winboat compatibility
    (final: prev: {
      freerdp = prev.symlinkJoin {
        name = "freerdp-wrapped";
        paths = [ prev.freerdp ];
        postBuild = ''
          ln -s $out/bin/xfreerdp $out/bin/xfreerdp3
          ln -s $out/bin/xfreerdp $out/bin/freerdp
          ln -s $out/bin/xfreerdp $out/bin/freerdp3
        '';
      };
    })

    # Skip openldap tests for i686 only: test017-syncreplication-refresh
    # is flaky on the 32-bit build pulled in by Lutris's FHS env.
    # Scoped to i686 so the 64-bit openldap stays cache-hittable.
    (final: prev: {
      openldap =
        if prev.stdenv.hostPlatform.system == "i686-linux" then
          prev.openldap.overrideAttrs (_: {
            doCheck = false;
          })
        else
          prev.openldap;
    })

    # tokenjuice: token-optimizing output compactor for agent/terminal workflows
    # Not in nixpkgs; ships pre-built JS with no runtime deps beyond Node.
    (final: prev: {
      tokenjuice = prev.stdenv.mkDerivation rec {
        pname = "tokenjuice";
        version = "0.7.1";
        src = prev.fetchurl {
          url = "https://registry.npmjs.org/tokenjuice/-/tokenjuice-${version}.tgz";
          hash = "sha256-XtNt4+H5/8OeqBWKYB53H+Qpfrnb8vOV2gu2rBiwmRA=";
        };
        nativeBuildInputs = [ prev.makeWrapper ];
        dontBuild = true;
        installPhase = ''
          mkdir -p $out/lib/tokenjuice $out/bin
          cp -r dist package.json $out/lib/tokenjuice/
          makeWrapper ${prev.nodejs_22}/bin/node $out/bin/tokenjuice \
            --add-flags "$out/lib/tokenjuice/dist/cli/main.js"
        '';
      };
    })
  ];

  # Periodic nix store optimization (hardlinks identical files)
  nix.optimise.automatic = true;

  # NH - Nix Helper with automatic cleanup
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep 5 --keep-since 3d";
    };
  };

  # Comma - run any program without installing it (e.g., ", cowsay hello")
  programs.nix-index-database.comma.enable = true;
  programs.command-not-found.enable = false; # Replaced by nix-index

  # AppImage support - allows running AppImages directly
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # nix-ld - allows running unpatched dynamic binaries (needed for BOINC, etc.)
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    # Standard libraries for most binaries
    stdenv.cc.cc.lib
    zlib
    glib
    # CUDA support for BOINC GPU tasks
    cudaPackages.cuda_cudart
    cudaPackages.libcublas
    cudaPackages.libcufft
    # Electron app support (EDHM-UI, etc.)
    nss
    nspr
    alsa-lib
    cups
    libdrm
    mesa
    libgbm
    libxkbcommon
    gtk3
    pango
    cairo
    gdk-pixbuf
    at-spi2-atk
    at-spi2-core
    dbus
    expat
    libxcb
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxshmfence
  ];
}
