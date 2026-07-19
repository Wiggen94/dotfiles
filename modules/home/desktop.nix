# Desktop entries, mimeapps, filetype associations, swaync
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
  # Desktop entries
  xdg.desktopEntries.outlook = {
    name = "Outlook";
    comment = "Microsoft Outlook Web";
    exec = "outlook";
    icon = "internet-mail";
    terminal = false;
    categories = [
      "Network"
      "Email"
      "Office"
    ];
  };

  # Override default BOINC Manager to use ~/boinc data directory (disabled on work hosts)
  xdg.desktopEntries.boinc = lib.mkIf (!isWorkHost) {
    name = "BOINC Manager";
    comment = "BOINC distributed computing manager";
    exec = "boinc-manager";
    icon = "boincmgr";
    terminal = false;
    categories = [
      "System"
      "Utility"
    ];
  };

  # Override Gridcoin wallet to use ~/games datadir when present (desktop), else default.
  xdg.desktopEntries.gridcoinresearch = lib.mkIf (!isWorkHost) {
    name = "Gridcoin";
    comment = "Gridcoin Research wallet";
    exec = "gridcoin-wallet";
    icon = "gridcoinresearch";
    terminal = false;
    categories = [
      "Office"
      "Finance"
    ];
  };

  # Fresco (modern BOINC manager) desktop entry
  xdg.desktopEntries.fresco = lib.mkIf (!isWorkHost) {
    name = "Fresco";
    comment = "Modern BOINC manager";
    exec = "fresco";
    icon = "fresco";
    terminal = false;
    categories = [
      "System"
      "Utility"
    ];
  };

  # Default applications
  xdg.configFile."mimeapps.list".force = true;
  xdg.mimeApps = {
    enable = true;
    # Note: associations.added removed - defaultApplications handles all MIME types
    defaultApplications = {
      # Web browser - Zen
      "x-scheme-handler/http" = "zen.desktop";
      "x-scheme-handler/https" = "zen.desktop";
      "x-scheme-handler/about" = "zen.desktop";
      "x-scheme-handler/unknown" = "zen.desktop";
      "text/html" = "zen.desktop";
      "application/xhtml+xml" = "zen.desktop";
      # Text files - VS Code
      "text/plain" = "code.desktop";
      "text/x-readme" = "code.desktop";
      "text/markdown" = "code.desktop";
      "text/x-log" = "code.desktop";
      "application/json" = "code.desktop";
      "application/xml" = "code.desktop";
      "application/x-yaml" = "code.desktop";
      "text/x-python" = "code.desktop";
      "text/x-shellscript" = "code.desktop";
      "text/x-c" = "code.desktop";
      "text/x-c++src" = "code.desktop";
      "text/x-java" = "code.desktop";
      "application/javascript" = "code.desktop";
      "application/x-nix" = "code.desktop";
      # Archives - Ark
      "application/zip" = "org.kde.ark.desktop";
      "application/x-tar" = "org.kde.ark.desktop";
      "application/x-gzip" = "org.kde.ark.desktop";
      "application/x-bzip2" = "org.kde.ark.desktop";
      "application/x-xz" = "org.kde.ark.desktop";
      "application/x-7z-compressed" = "org.kde.ark.desktop";
      "application/x-rar" = "org.kde.ark.desktop";
      "application/x-compressed-tar" = "org.kde.ark.desktop";
      "application/x-bzip-compressed-tar" = "org.kde.ark.desktop";
      "application/x-xz-compressed-tar" = "org.kde.ark.desktop";
      # Images - Loupe
      "image/png" = "org.gnome.Loupe.desktop";
      "image/jpeg" = "org.gnome.Loupe.desktop";
      "image/gif" = "org.gnome.Loupe.desktop";
      "image/webp" = "org.gnome.Loupe.desktop";
      "image/bmp" = "org.gnome.Loupe.desktop";
      "image/svg+xml" = "org.gnome.Loupe.desktop";
      "image/tiff" = "org.gnome.Loupe.desktop";
    };
  };

  # KDE file type associations (filetypesrc)
  xdg.configFile."filetypesrc".text = ''
    [AddedAssociations]
    application/zip=org.kde.ark.desktop;
    application/x-7z-compressed=org.kde.ark.desktop;
    application/x-tar=org.kde.ark.desktop;
    application/x-compressed-tar=org.kde.ark.desktop;
    application/gzip=org.kde.ark.desktop;
    application/x-rar=org.kde.ark.desktop;
    image/png=org.gnome.Loupe.desktop;
    image/jpeg=org.gnome.Loupe.desktop;
    image/gif=org.gnome.Loupe.desktop;
    image/webp=org.gnome.Loupe.desktop;
  '';

  # Alacritty config is managed by theme-switcher (see ~/.local/share/themes/)

  # SwayNC notification center - config
  xdg.configFile."swaync/config.json".text = builtins.toJSON {
    "$schema" = "/etc/xdg/swaync/configSchema.json";
    # Notification popups - bottom right
    positionX = "right";
    positionY = "bottom";
    # Control center - top center (below bar, where the module is)
    control-center-positionX = "center";
    control-center-positionY = "top";
    control-center-margin-top = 0;
    control-center-margin-bottom = 10;
    control-center-margin-right = 10;
    control-center-margin-left = 10;
    notification-window-width = 450;
    notification-icon-size = 48;
    notification-body-image-height = 100;
    notification-body-image-width = 200;
    timeout = 8;
    timeout-low = 4;
    timeout-critical = 0;
    fit-to-screen = false;
    control-center-width = 450;
    control-center-height = 600;
    notification-2fa-action = true;
    keyboard-shortcuts = true;
    image-visibility = "when-available";
    transition-time = 200;
    hide-on-clear = false;
    hide-on-action = true;
    script-fail-notify = true;
  };

  # SwayNC notification center - Catppuccin Mocha style
  xdg.configFile."swaync/style.css".text = ''
    /* Catppuccin Mocha theme for SwayNC */
    @define-color base ${colors.base};
    @define-color mantle ${colors.mantle};
    @define-color crust ${colors.crust};
    @define-color surface0 ${colors.surface0};
    @define-color surface1 ${colors.surface1};
    @define-color surface2 ${colors.surface2};
    @define-color text ${colors.text};
    @define-color subtext0 ${colors.subtext0};
    @define-color mauve ${colors.mauve};
    @define-color pink ${colors.pink};
    @define-color red ${colors.red};
    @define-color peach ${colors.peach};
    @define-color yellow ${colors.yellow};
    @define-color green ${colors.green};
    @define-color blue ${colors.blue};

    * {
      font-family: "${colors.fonts.monospace}";
      font-size: 14px;
    }

    .notification-row {
      outline: none;
      background: transparent;
    }

    .notification-row:focus,
    .notification-row:hover {
      background: transparent;
    }

    .notification {
      border-radius: 12px;
      margin: 6px;
      padding: 0;
      background: @base;
      border: 2px solid @mauve;
    }

    .notification:hover {
      background: @surface0;
    }

    .notification-content {
      padding: 12px;
      border-radius: 12px;
    }

    .close-button {
      background: @surface1;
      color: @text;
      border-radius: 6px;
      margin: 6px;
      padding: 4px;
    }

    .close-button:hover {
      background: @red;
      color: @base;
    }

    .notification-default-action,
    .notification-action {
      padding: 6px;
      margin: 6px;
      border-radius: 8px;
      background: @surface0;
      color: @text;
      border: none;
    }

    .notification-default-action:hover,
    .notification-action:hover {
      background: @surface1;
    }

    .notification-action {
      margin-top: 0;
    }

    .summary {
      color: @text;
      font-weight: bold;
      font-size: 15px;
    }

    .body {
      color: @subtext0;
      font-size: 13px;
    }

    .critical {
      border-color: @red;
    }

    .control-center {
      background: @base;
      border: 2px solid @surface1;
      border-radius: 12px;
      padding: 12px;
    }

    .control-center-list {
      background: transparent;
    }

    .floating-notifications {
      background: transparent;
    }

    .widget-title {
      color: @text;
      font-weight: bold;
      font-size: 16px;
      margin: 8px;
    }

    .widget-title > button {
      background: @surface0;
      color: @text;
      border-radius: 8px;
      padding: 4px 8px;
      border: none;
    }

    .widget-title > button:hover {
      background: @surface1;
    }

    .widget-dnd {
      background: @surface0;
      border-radius: 8px;
      margin: 8px;
      padding: 8px;
    }

    .widget-dnd > switch {
      background: @surface1;
      border-radius: 8px;
    }

    .widget-dnd > switch:checked {
      background: @mauve;
    }

    .widget-dnd > switch slider {
      background: @text;
      border-radius: 8px;
    }
  '';

}
