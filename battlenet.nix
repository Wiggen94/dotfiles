{ pkgs }:

let
  wine = pkgs.wineWowPackages.stagingFull;

  battlenetScript = pkgs.writeShellScriptBin "battlenet" ''
    #!/usr/bin/env bash
    set -e

    BATTLENET_DIR="$HOME/.local/share/battlenet"
    WINEPREFIX="$BATTLENET_DIR/prefix"
    BATTLENET_EXE="$WINEPREFIX/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
    BATTLENET_INSTALLER="$BATTLENET_DIR/Battle.net-Setup.exe"
    INSTALLER_URL="https://downloader.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live"

    # Create directories
    mkdir -p "$BATTLENET_DIR"
    mkdir -p "$WINEPREFIX"

    # Set up Wine environment
    export WINEPREFIX
    export WINEARCH=win64
    export DXVK_LOG_LEVEL=none

    # Install dependencies using winetricks if not done
    DEPS_MARKER="$WINEPREFIX/.deps_installed"
    if [ ! -f "$DEPS_MARKER" ]; then
      echo "Installing Wine dependencies (corefonts, dxvk, vkd3d)..."
      echo "This may take a few minutes on first run..."

      # Initialize prefix first
      ${wine}/bin/wineboot --init 2>/dev/null || true
      ${wine}/bin/wineserver --wait 2>/dev/null || true

      # Install dependencies
      WINE=${wine}/bin/wine ${pkgs.winetricks}/bin/winetricks -q corefonts dxvk vkd3d 2>&1 || true

      touch "$DEPS_MARKER"
    fi

    # Check if Battle.net is installed
    if [ ! -f "$BATTLENET_EXE" ]; then
      echo "Battle.net not found. Installing..."

      # Download installer if not present
      if [ ! -f "$BATTLENET_INSTALLER" ]; then
        echo "Downloading Battle.net installer..."
        ${pkgs.curl}/bin/curl -L -o "$BATTLENET_INSTALLER" "$INSTALLER_URL"
      fi

      echo "Running Battle.net installer..."
      echo "Please complete the installation in the GUI."
      ${wine}/bin/wine "$BATTLENET_INSTALLER"

      # Wait for installation to complete
      ${wine}/bin/wineserver --wait 2>/dev/null || true
    fi

    # Launch Battle.net
    if [ -f "$BATTLENET_EXE" ]; then
      echo "Launching Battle.net..."
      ${wine}/bin/wine "$BATTLENET_EXE" "$@"
    else
      echo "Error: Battle.net installation not found at $BATTLENET_EXE"
      echo "Please run 'battlenet' again to retry installation."
      exit 1
    fi
  '';

  desktopItem = pkgs.makeDesktopItem {
    name = "battlenet";
    desktopName = "Battle.net Installer";
    comment = "Blizzard Battle.net Game Launcher";
    exec = "${battlenetScript}/bin/battlenet";
    icon = "applications-games";
    categories = [ "Game" ];
    terminal = false;
  };

in
pkgs.symlinkJoin {
  name = "battlenet";
  paths = [ battlenetScript desktopItem ];
}
