# Home identity, theme file generation, activation, GTK, dconf
{
  config,
  pkgs,
  lib,
  hostName,
  ...
}:
let
  inherit (import ./_common.nix { inherit lib hostName; })
    isWorkHost
    isLaptopHost
    themeRegistry
    allThemes
    themeNames
    colors
    hostConfig
    currentHost
    terminalCmd
    termCmd
    mkHyprThemeColors
    mkAlacrittyConfig
    mkWlogoutStyle
    mkStarshipConfig
    mkQuickshellThemeJson
    mkThemeFiles
    allThemeFiles
    ;
in
{
  # Home Manager needs a bit of information about you and the paths it should manage
  home.username = "gjermund";
  home.homeDirectory = "/home/gjermund";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  home.stateVersion = "25.11";

  # Suppress version mismatch warning (expected when using NixOS unstable with Home Manager master)
  home.enableNixpkgsReleaseCheck = false;

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # Generate theme files to ~/.local/share/themes/
  home.file = allThemeFiles // {
    ".zen/native-messaging-hosts/com.1password.1password.json".text = builtins.toJSON {
      name = "com.1password.1password";
      description = "1Password BrowserSupport";
      path = "/run/wrappers/bin/1Password-BrowserSupport";
      type = "stdio";
      allowed_extensions = [
        "{0a75d802-9aed-41e7-8daa-24c067386e82}"
        "{25fc87fa-4d31-4fee-b5c1-c32a7844c063}"
        "{d634138d-c276-4fc8-924b-40a0ea21d284}"
      ];
    };
  };

  # Initialize default theme on rebuild if no current theme set
  home.activation.initializeTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    CURRENT_FILE="$HOME/.config/current-theme"
    THEMES_DIR="$HOME/.local/share/themes"
    DEFAULT_THEME="catppuccin-mocha"

    # Remove stale hyprlang theme-colors.conf left over from pre-Lua migration
    $DRY_RUN_CMD rm -f ~/.config/hypr/theme-colors.conf

    # If no current theme, initialize with default
    if [ ! -f "$CURRENT_FILE" ]; then
      echo "Initializing theme to $DEFAULT_THEME"
      mkdir -p ~/.config/hypr ~/.config/alacritty
      $DRY_RUN_CMD install -m 644 "$THEMES_DIR/$DEFAULT_THEME/hypr/theme-colors.lua" ~/.config/hypr/theme-colors.lua
      $DRY_RUN_CMD install -m 644 "$THEMES_DIR/$DEFAULT_THEME/alacritty/alacritty.toml" ~/.config/alacritty/alacritty.toml
      $DRY_RUN_CMD install -m 644 "$THEMES_DIR/$DEFAULT_THEME/starship/starship.toml" ~/.config/starship.toml
      echo "$DEFAULT_THEME" > "$CURRENT_FILE"
    else
      # Theme exists but some configs might be missing (upgrade case)
      CURRENT_THEME=$(cat "$CURRENT_FILE")
      # Hyprland Lua theme: install if missing (e.g. after migrating from .conf)
      if [ -f "$THEMES_DIR/$CURRENT_THEME/hypr/theme-colors.lua" ] && [ ! -f ~/.config/hypr/theme-colors.lua ]; then
        echo "Installing missing Hyprland Lua theme for $CURRENT_THEME"
        $DRY_RUN_CMD install -m 644 "$THEMES_DIR/$CURRENT_THEME/hypr/theme-colors.lua" ~/.config/hypr/theme-colors.lua
      fi
      # Starship: remove symlink if exists (from old programs.starship.settings), then install
      if [ -f "$THEMES_DIR/$CURRENT_THEME/starship/starship.toml" ]; then
        if [ -L ~/.config/starship.toml ]; then
          echo "Removing Starship symlink to enable theme switching"
          $DRY_RUN_CMD rm ~/.config/starship.toml
        fi
        if [ ! -f ~/.config/starship.toml ]; then
          echo "Installing missing Starship config for $CURRENT_THEME"
          $DRY_RUN_CMD install -m 644 "$THEMES_DIR/$CURRENT_THEME/starship/starship.toml" ~/.config/starship.toml
        fi
      fi
    fi
  '';

  # GTK theming - dark mode for GTK apps
  gtk = {
    enable = true;
    font = {
      name = "Noto Sans";
      size = 10;
    };
    theme = {
      name = "catppuccin-mocha-mauve-standard";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "mauve" ];
        variant = "mocha";
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 24;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk4.theme = null;
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  # dconf settings - tells apps user prefers dark mode
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "catppuccin-mocha-mauve-standard";
      icon-theme = "Papirus-Dark";
      cursor-theme = "Bibata-Modern-Ice";
      font-name = "Noto Sans 10";
      monospace-font-name = "${colors.fonts.monospace} 10";
    };
  };

}
