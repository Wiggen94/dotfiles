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
    # i5-14600K: 14 cores/20 threads — 5 jobs × 4 cores saturates all 20 threads.
    # Drop max-jobs to 4 if the desktop stutters or zram fills during big rebuilds.
    max-jobs = 5;
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

    # mattermost-desktop 6.3.0 bundles the @koromix/koffi FFI module, whose
    # prebuilt .node dlopen()s libstdc++.so.6 at startup. The nixpkgs wrapper
    # doesn't put a C++ stdlib on the loader path, so the app dies immediately
    # with "libstdc++.so.6: cannot open shared object file". Re-wrap the binary
    # with LD_LIBRARY_PATH pointing at gcc-lib (symlinkJoin, so no rebuild from
    # source). https://github.com/NixOS/nixpkgs/issues/447619
    (final: prev: {
      mattermost-desktop = prev.symlinkJoin {
        name = "mattermost-desktop-${prev.mattermost-desktop.version}";
        paths = [ prev.mattermost-desktop ];
        nativeBuildInputs = [ prev.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/mattermost-desktop \
            --prefix LD_LIBRARY_PATH : ${prev.lib.makeLibraryPath [ prev.stdenv.cc.cc.lib ]}

          # The bundled .desktop file hardcodes Exec= to the unwrapped store
          # path, so launching from the app menu bypasses the wrapper above and
          # dies on libstdc++. Replace the symlink with a copy pointing at the
          # wrapped binary.
          for f in $out/share/applications/*.desktop; do
            rm "$f"
            substitute ${prev.mattermost-desktop}/share/applications/$(basename "$f") "$f" \
              --replace-fail ${prev.mattermost-desktop}/bin/mattermost-desktop $out/bin/mattermost-desktop
          done
        '';
        inherit (prev.mattermost-desktop) meta;
      };
    })

    # winbox4 ships upstream's prebuilt binary with Qt6 linked statically, so
    # the only platform plugin compiled in is xcb — under Wayland it dies with
    # "no Qt platform plugin could be initialized". Adding pkgs.qt6.qtwayland
    # can't help (a static Qt won't load a foreign plugin build), so pin it to
    # XWayland. The .desktop file's Exec is the bare name "WinBox", so app-menu
    # launches resolve through PATH to this wrapper too.
    (final: prev: {
      winbox4 = prev.symlinkJoin {
        name = "winbox4-${prev.winbox4.version}";
        paths = [ prev.winbox4 ];
        nativeBuildInputs = [ prev.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/WinBox --set QT_QPA_PLATFORM xcb
        '';
        inherit (prev.winbox4) meta;
      };
    })

    # 9Router web-search MCP server (pkgs/9router-search-mcp). Overlaid (not just
    # added to environment.systemPackages) so `pkgs.nine-router-search-mcp`
    # resolves in the Home Manager side too, where the declarative MCP server
    # config (modules/home/claude-mcp.nix) needs its absolute store path.
    # Replaces the built-in WebSearch tool, which cannot work here (see the
    # script's docstring / modules/home/claude-settings.nix).
    (final: prev: {
      nine-router-search-mcp = final.callPackage ../../pkgs/9router-search-mcp { };
    })

    # Chrome DevTools MCP server (pkgs/chrome-devtools-mcp). Overlaid for the
    # same reason as 9router-search-mcp above: modules/home/claude-mcp.nix
    # points at it by absolute store path. Gives the agent console, network,
    # performance traces and real screenshots over CDP — the web-development
    # tooling, as opposed to a crawler's page extraction.
    (final: prev: {
      chrome-devtools-mcp = final.callPackage ../../pkgs/chrome-devtools-mcp { };
    })

    # GitHub MCP server wrapped so the auth token is injected as the env var it
    # requires, instead of sitting in plaintext in .claude.json. Overlaid for the
    # same reason as the servers above: the Home Manager side
    # (modules/home/claude-mcp.nix) references the wrapper by store path.
    #
    # The server has no --token flag and does not read gh's config, so a wrapper
    # is the only way to keep the token out of a file the user edits. The token
    # comes from `gh auth token`, i.e. gh's own credential store (`gh auth
    # login`), so there is no separate secret to manage or duplicate — if you
    # are logged into gh, the MCP server is authenticated.
    #
    # If gh has no token, pass through to the server anyway: it fails with its
    # own "authentication required" message, which is clearer than a wrapper
    # error and keeps a hand-supplied GITHUB_PERSONAL_ACCESS_TOKEN working.
    (final: prev: {
      github-mcp-server-auth = prev.writeShellScriptBin "github-mcp-server-auth" ''
        #!/usr/bin/env bash
        set -euo pipefail

        if [ -z "''${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
          token="$(${prev.gh}/bin/gh auth token 2>/dev/null || true)"
          [ -n "$token" ] && export GITHUB_PERSONAL_ACCESS_TOKEN="$token"
        fi

        exec ${prev.github-mcp-server}/bin/github-mcp-server "$@"
      '';
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
