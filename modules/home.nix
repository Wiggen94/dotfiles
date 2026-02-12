# Home Manager configuration shared between all hosts
# Monitor configuration is per-host based on hostName
{ config, pkgs, lib, inputs, hostName, ... }:

let
  # Work hosts don't get gaming/personal services
  isWorkHost = hostName == "sikt";

  # Laptop hosts dock/undock - don't bind workspaces to specific monitors
  isLaptopHost = hostName == "laptop" || hostName == "sikt";

  # Import theme system
  themeRegistry = import ../themes/default.nix;
  allThemes = themeRegistry.themes;
  themeNames = themeRegistry.themeNames;

  # Default colors for non-switchable configs (backwards compatible)
  colors = import ../colors.nix;

  # ═══════════════════════════════════════════════════════════════════════════
  # PER-HOST CONFIGURATION
  # When adding a new host, configure these settings:
  # 1. Run: hyprctl monitors  (to get resolution, refresh rate, and output name)
  # 2. Decide on scale factor (1.0 for large screens, 1.25-1.5 for HiDPI laptops)
  # 3. Choose terminal
  # ═══════════════════════════════════════════════════════════════════════════
  hostConfig = {
    desktop = {
      monitor = "monitor=,5120x1440@240,auto,1";
      primaryOutput = "DP-1";
      scale = 1;
      cursorSize = 24;
      vrr = true;
      terminal = "alacritty";
      dimInactive = true;
    };
    laptop = {
      monitor = "monitor=,2560x1440@60,auto,1.33";
      primaryOutput = "eDP-1";
      scale = 1.33;
      cursorSize = 32;
      vrr = false;
      terminal = "alacritty";
      dimInactive = true;
    };
    sikt = {
      # Dual external monitors: DP-3 (ultrawide) on left, DP-1 on right
      # eDP-1 (laptop) disabled when lid closed via lid-handler
      monitor = builtins.concatStringsSep "\n" [
        "monitor=DP-3,3440x1440@60,0x0,1"      # Ultrawide on left (main)
        "monitor=DP-1,2560x1440@60,3440x0,1"   # Lenovo on right
        "monitor=eDP-1,preferred,auto,1"       # Laptop (auto position, disabled when lid closed)
      ];
      primaryOutput = "DP-3";  # Philips ultrawide (Waybar and workspaces go here)
      scale = 1;
      cursorSize = 24;
      vrr = false;
      terminal = "alacritty";  # Reliable on Intel graphics
      dimInactive = false;  # No dimming on work machine
    };
  };

  # Get current host config (with sensible defaults for unknown hosts)
  currentHost = hostConfig.${hostName} or {
    monitor = "monitor=,preferred,auto,1";
    primaryOutput = "eDP-1";
    scale = 1;
    cursorSize = 24;
    vrr = false;
    terminal = "alacritty";
    dimInactive = true;
  };

  # Terminal command helpers (different syntax for different terminals)
  terminalCmd = {
    alacritty = {
      withClass = class: "alacritty --class ${class}";
      withClassAndCmd = class: cmd: "alacritty --class ${class} -e ${cmd}";
    };
  };
  termCmd = terminalCmd.${currentHost.terminal} or terminalCmd.alacritty;

  # Legacy aliases for compatibility
  monitorConfig.${hostName} = currentHost.monitor;
  primaryMonitor.${hostName} = currentHost.primaryOutput;
  vrr = if currentHost.vrr then "1" else "0";

  # ===========================================
  # Theme Config Generators
  # These functions generate config content for any theme
  # ===========================================

  # Generate Hyprland theme colors (sourced by visuals.conf)
  mkHyprThemeColors = theme: ''
    # Theme: ${theme.meta.name}
    # Auto-generated - do not edit manually

    general {
        col.active_border = ${theme.rgba.mauve} ${theme.rgba.pink} ${theme.rgba.blue} 45deg
        col.inactive_border = ${theme.transparent.surface1_67}
    }

    decoration {
        shadow {
            color = ${theme.transparent.crust_93}
        }
    }

    misc {
        background_color = ${theme.rgba.base}
    }
  '';

  # Generate Waybar style.css
  mkWaybarStyle = theme: ''
    /* Theme: ${theme.meta.name} */
    @define-color base ${theme.base};
    @define-color mantle ${theme.mantle};
    @define-color crust ${theme.crust};
    @define-color surface0 ${theme.surface0};
    @define-color surface1 ${theme.surface1};
    @define-color surface2 ${theme.surface2};
    @define-color text ${theme.text};
    @define-color subtext0 ${theme.subtext0};
    @define-color subtext1 ${theme.subtext1};
    @define-color mauve ${theme.mauve};
    @define-color pink ${theme.pink};
    @define-color red ${theme.red};
    @define-color peach ${theme.peach};
    @define-color yellow ${theme.yellow};
    @define-color green ${theme.green};
    @define-color blue ${theme.blue};
    @define-color teal ${theme.teal};
    @define-color lavender ${theme.lavender};
    @define-color sky ${theme.sky};

    * {
      font-family: "${theme.fonts.monospace}";
      font-size: 13px;
      min-height: 0;
      border: none;
      border-radius: 0;
    }

    window#waybar {
      background: alpha(@base, 0.88);
      border-radius: 14px;
      border: 2px solid alpha(@surface1, 0.6);
      color: @text;
    }

    /* ═══ Launcher ═══ */
    #custom-launcher {
      font-size: 18px;
      padding: 0 14px 0 12px;
      color: @mauve;
      transition: all 0.2s ease;
    }

    #custom-launcher:hover {
      color: @pink;
    }

    /* ═══ Workspaces ═══ */
    #workspaces {
      margin: 4px 0;
    }

    #workspaces button {
      min-width: 28px;
      min-height: 28px;
      padding: 0;
      color: @subtext0;
      border-radius: 50%;
      border: 2px solid @surface1;
      margin: 2px 3px;
      transition: all 0.2s ease;
      font-size: 14px;
      font-weight: bold;
    }

    #workspaces button:hover {
      background: alpha(@surface1, 0.6);
      color: @text;
    }

    #workspaces button.active {
      background: linear-gradient(135deg, @mauve, @pink);
      border-color: @mauve;
      color: @crust;
      font-weight: bold;
    }

    #workspaces button.urgent {
      background: @red;
      color: @crust;
      font-weight: bold;
    }

    /* ═══ Window Title ═══ */
    #window {
      color: @subtext1;
      padding: 0 12px;
      font-style: italic;
    }

    /* ═══ Media Player ═══ */
    #custom-media {
      color: @green;
      padding: 0 10px;
      font-size: 12px;
    }

    #custom-media.spotify {
      color: @green;
    }

    /* ═══ Clock ═══ */
    #clock {
      color: @text;
      padding: 0 14px;
      font-weight: bold;
      font-size: 14px;
    }

    /* ═══ Weather ═══ */
    #custom-weather {
      color: @sky;
      padding: 0 10px;
    }

    /* ═══ System Stats ═══ */
    #cpu, #memory {
      padding: 0 10px;
      color: @text;
      font-size: 12px;
    }

    #cpu.warning, #memory.warning {
      color: @yellow;
    }

    #cpu.critical, #memory.critical {
      color: @red;
      font-weight: bold;
    }

    /* ═══ System Tray & Controls ═══ */
    #network, #pulseaudio, #bluetooth, #battery, #tray {
      padding: 0 10px;
      color: @text;
    }

    #network.disconnected {
      color: @red;
    }

    #network.wifi {
      color: @teal;
    }

    #pulseaudio.muted {
      color: @surface2;
    }

    #bluetooth.connected {
      color: @blue;
    }

    #battery.charging, #battery.plugged {
      color: @green;
    }

    #battery.warning:not(.charging) {
      color: @peach;
    }

    #battery.critical:not(.charging) {
      color: @red;
    }

    #tray {
      margin-right: 4px;
    }

    #tray > .passive {
      -gtk-icon-effect: dim;
    }

    #tray > .needs-attention {
      -gtk-icon-effect: highlight;
      background-color: @red;
    }

    /* ═══ Notifications ═══ */
    #custom-swaync {
      padding: 0 10px;
      color: @text;
    }

    #custom-swaync.has-notifications {
      color: @peach;
    }

    /* ═══ Power Button ═══ */
    #custom-power {
      color: @red;
      padding: 0 12px 0 10px;
      font-size: 15px;
      transition: all 0.2s ease;
    }

    #custom-power:hover {
      color: @pink;
    }

    /* ═══ Tooltip ═══ */
    tooltip {
      background: @surface0;
      border: 2px solid @surface1;
      border-radius: 10px;
    }

    tooltip label {
      color: @text;
      padding: 4px 8px;
    }
  '';

  # Generate Alacritty config
  mkAlacrittyConfig = theme: ''
    # Theme: ${theme.meta.name}
    [general]
    live_config_reload = true

    [window]
    padding = { x = 12, y = 12 }
    decorations = "None"
    opacity = 0.95
    dynamic_title = true

    [font]
    normal = { family = "${theme.fonts.monospace}", style = "Regular" }
    bold = { family = "${theme.fonts.monospace}", style = "Bold" }
    italic = { family = "${theme.fonts.monospace}", style = "Italic" }
    bold_italic = { family = "${theme.fonts.monospace}", style = "Bold Italic" }
    size = 13.0

    [colors.primary]
    background = "${theme.base}"
    foreground = "${theme.text}"
    dim_foreground = "${theme.subtext1}"
    bright_foreground = "${theme.text}"

    [colors.cursor]
    text = "${theme.base}"
    cursor = "${theme.rosewater}"

    [colors.vi_mode_cursor]
    text = "${theme.base}"
    cursor = "${theme.lavender}"

    [colors.search.matches]
    foreground = "${theme.base}"
    background = "${theme.subtext0}"

    [colors.search.focused_match]
    foreground = "${theme.base}"
    background = "${theme.green}"

    [colors.footer_bar]
    foreground = "${theme.base}"
    background = "${theme.subtext0}"

    [colors.hints.start]
    foreground = "${theme.base}"
    background = "${theme.yellow}"

    [colors.hints.end]
    foreground = "${theme.base}"
    background = "${theme.subtext0}"

    [colors.selection]
    text = "${theme.base}"
    background = "${theme.rosewater}"

    [colors.normal]
    black = "${theme.surface1}"
    red = "${theme.red}"
    green = "${theme.green}"
    yellow = "${theme.yellow}"
    blue = "${theme.blue}"
    magenta = "${theme.pink}"
    cyan = "${theme.teal}"
    white = "${theme.subtext1}"

    [colors.bright]
    black = "${theme.surface2}"
    red = "${theme.red}"
    green = "${theme.green}"
    yellow = "${theme.yellow}"
    blue = "${theme.blue}"
    magenta = "${theme.pink}"
    cyan = "${theme.teal}"
    white = "${theme.subtext0}"

    [colors.dim]
    black = "${theme.surface1}"
    red = "${theme.red}"
    green = "${theme.green}"
    yellow = "${theme.yellow}"
    blue = "${theme.blue}"
    magenta = "${theme.pink}"
    cyan = "${theme.teal}"
    white = "${theme.subtext1}"
  '';

  # Generate wlogout style
  mkWlogoutStyle = theme: ''
    /* Theme: ${theme.meta.name} */
    * {
        background-image: none;
        font-family: "${theme.fonts.monospace}";
    }

    window {
        background-color: rgba(${theme.rgb.base}, 0.9);
    }

    button {
        color: ${theme.text};
        background-color: ${theme.surface0};
        border-style: solid;
        border-width: 2px;
        border-color: ${theme.surface1};
        border-radius: 16px;
        margin: 10px;
        padding: 20px;
        font-size: 24px;
    }

    button:focus, button:active, button:hover {
        background-color: ${theme.surface1};
        border-color: ${theme.mauve};
        outline-style: none;
    }

    #lock:hover { border-color: ${theme.green}; }
    #logout:hover { border-color: ${theme.yellow}; }
    #suspend:hover { border-color: ${theme.blue}; }
    #hibernate:hover { border-color: ${theme.teal}; }
    #reboot:hover { border-color: ${theme.peach}; }
    #shutdown:hover { border-color: ${theme.red}; }
  '';

  # Generate fuzzel config
  mkFuzzelConfig = theme: ''
    # Theme: ${theme.meta.name}
    [main]
    font=${theme.fonts.monospace}:size=12
    terminal=alacritty
    layer=overlay
    prompt="  "
    width=50
    lines=12

    [colors]
    background=${builtins.substring 1 6 theme.base}ee
    text=${builtins.substring 1 6 theme.text}ff
    match=${builtins.substring 1 6 theme.mauve}ff
    selection=${builtins.substring 1 6 theme.surface1}ff
    selection-text=${builtins.substring 1 6 theme.text}ff
    selection-match=${builtins.substring 1 6 theme.mauve}ff
    border=${builtins.substring 1 6 theme.surface1}ff

    [border]
    width=2
    radius=12
  '';

  # Generate Starship config (TOML)
  mkStarshipConfig = theme: ''
    # Theme: ${theme.meta.name}
    format = """
    [](${theme.mauve})\
    $os\
    [](bg:${theme.pink} fg:${theme.mauve})\
    $directory\
    [](fg:${theme.pink} bg:${theme.blue})\
    $git_branch\
    $git_status\
    [](fg:${theme.blue} bg:${theme.teal})\
    $c\
    $rust\
    $golang\
    $nodejs\
    $python\
    $nix_shell\
    [](fg:${theme.teal} bg:${theme.surface0})\
    $docker_context\
    [ ](fg:${theme.surface0})\
    $character\
    """

    [os]
    disabled = false
    style = "bg:${theme.mauve} fg:${theme.base}"

    [os.symbols]
    NixOS = "󱄅 "

    [directory]
    style = "bg:${theme.pink} fg:${theme.base}"
    format = "[ $path ]($style)"
    truncation_length = 3
    truncation_symbol = "…/"

    [directory.substitutions]
    Documents = "󰈙 "
    Downloads = " "
    Music = " "
    Pictures = " "
    nix-config = "󱄅 "

    [git_branch]
    symbol = ""
    style = "bg:${theme.blue} fg:${theme.base}"
    format = "[ $symbol $branch ]($style)"

    [git_status]
    style = "bg:${theme.blue} fg:${theme.base}"
    format = "[$all_status$ahead_behind ]($style)"

    [nix_shell]
    symbol = "󱄅"
    style = "bg:${theme.teal} fg:${theme.base}"
    format = "[ $symbol $name ]($style)"

    [nodejs]
    symbol = ""
    style = "bg:${theme.teal} fg:${theme.base}"
    format = "[ $symbol ($version) ]($style)"

    [rust]
    symbol = ""
    style = "bg:${theme.teal} fg:${theme.base}"
    format = "[ $symbol ($version) ]($style)"

    [golang]
    symbol = ""
    style = "bg:${theme.teal} fg:${theme.base}"
    format = "[ $symbol ($version) ]($style)"

    [python]
    symbol = ""
    style = "bg:${theme.teal} fg:${theme.base}"
    format = "[ $symbol ($version) ]($style)"

    [c]
    symbol = ""
    style = "bg:${theme.teal} fg:${theme.base}"
    format = "[ $symbol ($version) ]($style)"

    [docker_context]
    symbol = ""
    style = "bg:${theme.surface0} fg:${theme.text}"
    format = "[ $symbol $context ]($style)"

    [time]
    disabled = true

    [character]
    success_symbol = "[❯](bold ${theme.green})"
    error_symbol = "[❯](bold ${theme.red})"
  '';

  # Generate all theme files as an attrset for home.file
  mkThemeFiles = themeName: theme: {
    ".local/share/themes/${themeName}/hypr/theme-colors.conf" = {
      text = mkHyprThemeColors theme;
    };
    ".local/share/themes/${themeName}/waybar/style.css" = {
      text = mkWaybarStyle theme;
    };
    ".local/share/themes/${themeName}/alacritty/alacritty.toml" = {
      text = mkAlacrittyConfig theme;
    };
    ".local/share/themes/${themeName}/wlogout/style.css" = {
      text = mkWlogoutStyle theme;
    };
    ".local/share/themes/${themeName}/fuzzel/fuzzel.ini" = {
      text = mkFuzzelConfig theme;
    };
    ".local/share/themes/${themeName}/starship/starship.toml" = {
      text = mkStarshipConfig theme;
    };
  };

  # Generate files for all themes
  allThemeFiles = lib.foldl' (acc: themeName:
    acc // (mkThemeFiles themeName allThemes.${themeName})
  ) {} themeNames;

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
  home.file = allThemeFiles;

  # Initialize default theme on rebuild if no current theme set
  home.activation.initializeTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    CURRENT_FILE="$HOME/.config/current-theme"
    THEMES_DIR="$HOME/.local/share/themes"
    DEFAULT_THEME="catppuccin-mocha"

    # If no current theme, initialize with default
    if [ ! -f "$CURRENT_FILE" ]; then
      echo "Initializing theme to $DEFAULT_THEME"
      mkdir -p ~/.config/hypr ~/.config/waybar ~/.config/alacritty ~/.config/wlogout ~/.config/fuzzel
      $DRY_RUN_CMD install -m 644 "$THEMES_DIR/$DEFAULT_THEME/hypr/theme-colors.conf" ~/.config/hypr/theme-colors.conf
      $DRY_RUN_CMD install -m 644 "$THEMES_DIR/$DEFAULT_THEME/waybar/style.css" ~/.config/waybar/style.css
      $DRY_RUN_CMD install -m 644 "$THEMES_DIR/$DEFAULT_THEME/alacritty/alacritty.toml" ~/.config/alacritty/alacritty.toml
      $DRY_RUN_CMD install -m 644 "$THEMES_DIR/$DEFAULT_THEME/wlogout/style.css" ~/.config/wlogout/style.css
      $DRY_RUN_CMD install -m 644 "$THEMES_DIR/$DEFAULT_THEME/fuzzel/fuzzel.ini" ~/.config/fuzzel/fuzzel.ini
      $DRY_RUN_CMD install -m 644 "$THEMES_DIR/$DEFAULT_THEME/starship/starship.toml" ~/.config/starship.toml
      echo "$DEFAULT_THEME" > "$CURRENT_FILE"
    else
      # Theme exists but some configs might be missing (upgrade case)
      CURRENT_THEME=$(cat "$CURRENT_FILE")
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

  # Git configuration
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Gjermund Wiggen";
        email = "gjermund.wiggen@sikt.no";
        signingkey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDCFErYzeQDyksloDzmjx72vft5FYqiBW87Z7/nY70JSWIAfKz6970jCG1ObCKQ0kPMukY0pKrHJZVHAGOwRYTUtnF+7OAB26On5QNdphoJg1BVtRnNAfyQiV9DhsTzVQsGO/3+DI7EbhaaVNsY4kJEJjXmwu+KKxFAW8DObwpi/sKh5lyXQgNFupR8jork5g6XLAD77U3ZqrQXJfJtkVP0yOd9bUbbprLb0nAzwDLyLhXtSgbAexAN0nloqjU4S8CetiMQB3JWmA/8Uam7mxbOGV+u4yYPgjorlC1u6JOipO/os01MzHfcqrDMztk5kFCJy8mCNUTfu4kQVbVUrlyN";
      };
      gpg = {
        format = "ssh";
        ssh.program = "/run/current-system/sw/bin/op-ssh-sign";
      };
      commit.gpgsign = true;
    };
  };

  # SSH client configuration
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        user = "gjewig";
        extraOptions = {
          "SetEnv" = "TERM=xterm-256color";
          "IdentityAgent" = "~/.1password/agent.sock";
        };
      };
    };
  };

  # Desktop entries
  xdg.desktopEntries.outlook = {
    name = "Outlook";
    comment = "Microsoft Outlook Web";
    exec = "outlook";
    icon = "internet-mail";
    terminal = false;
    categories = [ "Network" "Email" "Office" ];
  };

  # Override default BOINC Manager to use ~/boinc data directory (disabled on work hosts)
  xdg.desktopEntries.boinc = lib.mkIf (!isWorkHost) {
    name = "BOINC Manager";
    comment = "BOINC distributed computing manager";
    exec = "boinc-manager";
    icon = "boincmgr";
    terminal = false;
    categories = [ "System" "Utility" ];
  };

  # Override Gridcoin to use custom data directories (disabled on work hosts)
  xdg.desktopEntries.gridcoinresearch = lib.mkIf (!isWorkHost) {
    name = "Gridcoin Research";
    comment = "Gridcoin wallet with BOINC integration";
    exec = "gridcoinresearch -datadir=/home/gjermund/games/GridCoin/GridCoinResearch/ -boincdatadir=/home/gjermund/boinc/";
    icon = "gridcoinresearch";
    terminal = false;
    categories = [ "Finance" "Network" ];
  };

  # Default applications
  xdg.configFile."mimeapps.list".force = true;
  xdg.mimeApps = {
    enable = true;
    # Note: associations.added removed - defaultApplications handles all MIME types
    defaultApplications = {
      # Web browser - Vivaldi
      "x-scheme-handler/http" = "vivaldi.desktop";
      "x-scheme-handler/https" = "vivaldi.desktop";
      "x-scheme-handler/about" = "vivaldi.desktop";
      "x-scheme-handler/unknown" = "vivaldi.desktop";
      "text/html" = "vivaldi.desktop";
      "application/xhtml+xml" = "vivaldi.desktop";
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
      # Torrents - qBittorrent
      "application/x-bittorrent" = "org.qbittorrent.qBittorrent.desktop";
      "x-scheme-handler/magnet" = "org.qbittorrent.qBittorrent.desktop";
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

  # Hyprland configuration - Home Manager module
  wayland.windowManager.hyprland = {
    enable = true;

    plugins = [
      pkgs.hyprlandPlugins.hyprscrolling
    ];

    settings = {
      # --- Monitors ---
      monitor = let
        raw = monitorConfig.${hostName} or "monitor=,preferred,auto,1";
        # Strip "monitor=" prefix from config strings
        stripPrefix = s:
          let m = builtins.match "monitor=(.*)" s;
          in if m != null then builtins.head m else s;
        lines = lib.splitString "\n" raw;
      in map stripPrefix lines;

      # --- Variables ---
      "$terminal" = currentHost.terminal;
      "$fileManager" = "dolphin";
      "$menu" = "fuzzel";
      "$mainMod" = "SUPER";

      # --- Autostart ---
      "exec-once" = [
        "waybar && echo \"1\" > /tmp/waybar-visible"
        "swaync"
        "1password"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
        "wl-clip-persist --clipboard regular"
        "hypridle"
        "/run/current-system/sw/libexec/polkit-gnome-authentication-agent-1"
        "nm-applet --indicator"
        "kdeconnect-indicator"
        "notification-sound-daemon"
        "wayvnc --render-cursor 0.0.0.0"
        "swww-daemon && sleep 0.5 && [ -f ~/.config/current-wallpaper ] && swww img \"$(cat ~/.config/current-wallpaper)\" --transition-type fade --transition-duration 1"
        "pypr"
        "monitor-handler"
      ];

      # --- Environment variables ---
      env = [
        "XCURSOR_SIZE,${toString currentHost.cursorSize}"
        "HYPRCURSOR_SIZE,${toString currentHost.cursorSize}"
        "XCURSOR_THEME,Bibata-Modern-Ice"
        "SSH_ASKPASS_REQUIRE,prefer"
        "QT_QPA_PLATFORMTHEME,kde"
        "QT_STYLE_OVERRIDE,Breeze"
        "BROWSER,vivaldi"
      ]
      ++ lib.optionals (currentHost.scale > 1) [
        "MOZ_ENABLE_WAYLAND,1"
      ]
      ++ lib.optionals (hostName == "desktop") [
        "LIBVA_DRIVER_NAME,nvidia"
        "XDG_SESSION_TYPE,wayland"
        "GBM_BACKEND,nvidia-drm"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
      ];

      # --- Source runtime theme colors ---
      source = [ "~/.config/hypr/theme-colors.conf" ];

      # --- General ---
      general = {
        gaps_in = 6;
        gaps_out = 12;
        border_size = 3;
        resize_on_border = true;
        allow_tearing = true;
        layout = "scrolling";
      };

      # --- Decoration ---
      decoration = {
        rounding = 12;
        active_opacity = 0.98;
        inactive_opacity = if currentHost.dimInactive then 0.90 else 1.0;
        dim_inactive = currentHost.dimInactive;
        dim_strength = 0.15;
        dim_special = 0.3;

        shadow = {
          enabled = true;
          range = 12;
          render_power = 4;
          color_inactive = "rgba(11111b50)";
          offset = "0 3";
          scale = 1.0;
        };

        blur = {
          enabled = true;
          size = 10;
          passes = 4;
          new_optimizations = true;
          ignore_opacity = true;
          xray = false;
          noise = 1.5e-2;
          contrast = 1.0;
          brightness = 1.0;
          vibrancy = 0.4;
          vibrancy_darkness = 0.3;
          popups = true;
          popups_ignorealpha = 0.2;
          special = true;
        };
      };

      # --- Animations ---
      animations = {
        enabled = true;
        bezier = [
          "smoothOut, 0.36, 0, 0.66, -0.56"
          "smoothIn, 0.25, 1, 0.5, 1"
          "overshot, 0.05, 0.9, 0.1, 1.1"
          "smoothSpring, 0.55, -0.15, 0.20, 1.3"
          "fluent, 0.0, 0.0, 0.2, 1.0"
          "snappy, 0.4, 0.0, 0.2, 1.0"
          "easeOutExpo, 0.16, 1, 0.3, 1"
        ];
        animation = [
          "windowsIn, 1, 4, overshot, popin 80%"
          "windowsOut, 1, 3, smoothOut, popin 80%"
          "windowsMove, 1, 4, fluent, slide"
          "fadeIn, 1, 3, smoothIn"
          "fadeOut, 1, 3, smoothOut"
          "fadeSwitch, 1, 4, smoothIn"
          "fadeDim, 1, 4, smoothIn"
          "fadeLayers, 1, 3, easeOutExpo"
          "border, 1, 8, default"
          "borderangle, 1, 50, smoothIn, loop"
          "workspaces, 1, 5, easeOutExpo, slide"
          "specialWorkspace, 1, 4, smoothSpring, slidevert"
          "layers, 1, 3, snappy, popin 90%"
        ];
      };

      # --- Input ---
      input = {
        kb_layout = "no";
        kb_variant = "";
        kb_model = "";
        kb_options = "";
        kb_rules = "";
        follow_mouse = 1;
        sensitivity = 0;
        touchpad = {
          natural_scroll = true;
          tap-to-click = true;
          disable_while_typing = true;
        };
      };

      gestures = {
        workspace_swipe = true;
        workspace_swipe_fingers = 3;
      };

      device = [
        {
          name = "epic-mouse-v1";
          sensitivity = -0.5;
        }
      ];

      # --- Layout ---
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      master = {
        new_status = "master";
      };

      # --- Misc ---
      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
        vfr = true;
        vrr = if currentHost.vrr then 1 else 0;
      };

      # --- Keybindings ---
      bind = [
        "$mainMod, T, exec, $terminal"
        "$mainMod, B, exec, vivaldi"
        "$mainMod, C, exec, qalculate-gtk"
        "$mainMod, Q, killactive,"
        "$mainMod, M, exit,"
        "$mainMod, E, exec, $fileManager"
        "$mainMod, W, togglefloating,"
        "$mainMod, F, fullscreen, 0"
        "$mainMod, R, exec, $menu"
        "$mainMod, A, exec, $menu"
        "$mainMod, J, togglesplit,"
        "$mainMod, V, exec, cliphist-paste"
        "$mainMod, P, exec, screenshot"
        "$mainMod, L, exec, wlogout"
        "$mainMod, G, exec, gaming-mode-toggle"
        "CTRL SUPER, Tab, exec, theme-switcher"
        "$mainMod SHIFT, W, exec, wallpaper-picker"
        "$mainMod, Y, exec, pypr toggle term"
        "$mainMod SHIFT, Y, exec, pypr toggle btop"
        "$mainMod SHIFT, B, exec, waybar-toggle"
        "$mainMod, N, exec, swaync-client -t -sw"
        # Move focus
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"
        # Workspaces (1-6)
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        # Move to workspace (1-6)
        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
        "$mainMod SHIFT, 6, movetoworkspace, 6"
        # Special workspace
        "$mainMod, S, togglespecialworkspace, magic"
        "$mainMod SHIFT, S, movetoworkspace, special:magic"
        # Mouse scroll workspaces
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"
        # Move windows (Super+Ctrl+arrows)
        "$mainMod CTRL, left, movewindow, l"
        "$mainMod CTRL, right, movewindow, r"
        "$mainMod CTRL, up, movewindow, u"
        "$mainMod CTRL, down, movewindow, d"
        # Quick window actions
        "$mainMod, Tab, cyclenext,"
        "$mainMod SHIFT, Tab, cyclenext, prev"
      ];

      binde = [
        "$mainMod SHIFT, left, resizeactive, -30 0"
        "$mainMod SHIFT, right, resizeactive, 30 0"
        "$mainMod SHIFT, up, resizeactive, 0 -30"
        "$mainMod SHIFT, down, resizeactive, 0 30"
      ];

      bindel = [
        ", XF86AudioRaiseVolume, exec, volume-up"
        ", XF86AudioLowerVolume, exec, volume-down"
        ", XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-"
      ];

      bindl = [
        ", XF86AudioMute, exec, volume-mute"
        ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPause, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
        ", switch:on:Lid Switch, exec, lid-handler close"
        ", switch:off:Lid Switch, exec, lid-handler open"
      ];

      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];

      # --- Window rules ---
      windowrule = [
        "match:class .*, suppress_event maximize"
        "match:class ^$, match:title ^$, match:xwayland true, match:float true, match:fullscreen false, match:pin false, no_focus on"
        # Calculator - float and center
        "match:class ^(qalculate-gtk)$, float on"
        "match:class ^(qalculate-gtk)$, size 400 500"
        "match:class ^(qalculate-gtk)$, center on"
        # Pyprland scratchpad window rules
        "match:class ^(dropdown-terminal)$, float on"
        "match:class ^(dropdown-terminal)$, center on"
        "match:class ^(dropdown-terminal)$, animation slide"
        "match:class ^(btop-scratchpad)$, float on"
        "match:class ^(btop-scratchpad)$, center on"
        "match:class ^(btop-scratchpad)$, animation slide"
        "match:class ^(yazi-scratchpad)$, float on"
        "match:class ^(yazi-scratchpad)$, animation slideright"
        # Vivaldi Browser - never dim
        "match:class ^(vivaldi.*)$, no_dim on"
        # Picture-in-Picture
        "match:title ^Picture-in-Picture$, opaque on"
        "match:title ^Picture-in-Picture$, pin on"
        "match:title ^Picture in picture$, opaque on"
        "match:title ^Picture in picture$, pin on"
        # World of Warcraft - tile instead of float
        "match:title ^World of Warcraft$, tile on"
        # EDMC Modern Overlay
        "match:class ^(python3)$, float on"
        "match:class ^(python3)$, pin on"
        "match:class ^(python3)$, no_focus on"
        "match:class ^(python3)$, border_size 0"
        "match:class ^(python3)$, no_shadow on"
        "match:class ^(python3)$, no_blur on"
        "match:class ^(python3)$, no_dim on"
        "match:class ^(python3)$, opaque on"
      ];

      # --- Workspace bindings (desktop only) ---
      workspace = lib.optionals (!isLaptopHost) [
        "1, monitor:${primaryMonitor.${hostName} or "DP-1"}, default:true"
        "2, monitor:${primaryMonitor.${hostName} or "DP-1"}"
        "3, monitor:${primaryMonitor.${hostName} or "DP-1"}"
        "4, monitor:${primaryMonitor.${hostName} or "DP-1"}"
        "5, monitor:${primaryMonitor.${hostName} or "DP-1"}"
        "6, monitor:${primaryMonitor.${hostName} or "DP-1"}"
      ];

      # --- Layer rules (blur) ---
      layerrule = [
        "blur on, match:namespace launcher"
        "ignore_alpha 0.3, match:namespace launcher"
        "blur on, match:namespace logout_dialog"
        "ignore_alpha 0.3, match:namespace logout_dialog"
        "blur on, match:namespace notifications"
        "ignore_alpha 0.3, match:namespace notifications"
        "blur on, match:namespace waybar"
        "ignore_alpha 0.3, match:namespace waybar"
        "blur on, match:namespace gtk-layer-shell"
        "ignore_alpha 0.3, match:namespace gtk-layer-shell"
        "blur on, match:namespace rofi"
        "ignore_alpha 0.3, match:namespace rofi"
        "blur on, match:namespace wofi"
        "ignore_alpha 0.3, match:namespace wofi"
      ];
    };

    # NVIDIA render block (desktop only) — can't conditionally add sections in settings
    extraConfig = lib.optionalString (hostName == "desktop") ''
      render {
          direct_scanout = false
      }
    '';
  };

  # Waybar configuration
  # Laptop: no output specified = Waybar on all monitors (handles dock/undock)
  # Desktop: output set to primary monitor only
  xdg.configFile."waybar/config".text = builtins.toJSON ({
    layer = "top";
    position = "top";
  } // (if isLaptopHost then {} else {
    output = "${primaryMonitor.${hostName} or "DP-1"}";
  }) // {
    height = 40;
    margin-top = 6;
    margin-left = 10;
    margin-right = 10;
    spacing = 4;

    modules-left = [ "custom/launcher" "hyprland/workspaces" "hyprland/window" ];
    modules-center = [ "custom/media" "clock" "custom/swaync" ];
    modules-right = [ "custom/weather" "cpu" "memory" "tray" "network" "bluetooth" "battery" "pulseaudio" "custom/power" ];

    "custom/launcher" = {
      format = "󱄅";
      tooltip = false;
      on-click = "fuzzel";
    };

    "hyprland/workspaces" = {
      format = "{icon}";
      format-icons = {
        "1" = "1";
        "2" = "2";
        "3" = "3";
        "4" = "4";
        "5" = "5";
        "6" = "6";
        urgent = "!";
        default = "•";
      };
    };

    "custom/media" = {
      format = "{icon} {}";
      return-type = "json";
      max-length = 30;
      format-icons = {
        spotify = "";
        default = "󰎆";
      };
      escape = true;
      exec = "${pkgs.playerctl}/bin/playerctl -a metadata --format '{\"text\": \"{{artist}} - {{title}}\", \"tooltip\": \"{{playerName}}: {{artist}} - {{title}}\", \"class\": \"{{playerName}}\"}' -F 2>/dev/null";
      on-click = "${pkgs.playerctl}/bin/playerctl play-pause";
    };

    "custom/weather" = {
      format = "{}";
      tooltip = true;
      interval = 1800;
      exec = "${pkgs.curl}/bin/curl -sf 'https://wttr.in/Trondheim?format=%c%t' 2>/dev/null || echo '󰖐 --'";
      return-type = "";
    };

    cpu = {
      interval = 5;
      format = "󰍛 {usage}%";
      tooltip-format = "CPU: {usage}%\nLoad: {load}";
      states = {
        warning = 70;
        critical = 90;
      };
    };

    memory = {
      interval = 5;
      format = "󰆼 {percentage}%";
      tooltip-format = "Memory: {used:0.1f}G / {total:0.1f}G ({percentage}%)\nSwap: {swapUsed:0.1f}G / {swapTotal:0.1f}G";
      states = {
        warning = 70;
        critical = 90;
      };
    };

    "custom/power" = {
      format = "⏻";
      tooltip = false;
      on-click = "wlogout";
    };

    "hyprland/window" = {
      format = "{}";
      max-length = 50;
      separate-outputs = true;
      icon = true;
      icon-size = 18;
    };

    clock = {
      format = "{:%H:%M}";
      format-alt = "{:%A, %B %d, %Y}";
      tooltip-format = "<tt><small>{calendar}</small></tt>";
      calendar = {
        mode = "month";
        mode-mon-col = 3;
        weeks-pos = "right";
        format = {
          months = "<span color='${colors.text}'><b>{}</b></span>";
          days = "<span color='${colors.subtext0}'>{}</span>";
          weeks = "<span color='${colors.mauve}'><b>W{}</b></span>";
          weekdays = "<span color='${colors.peach}'><b>{}</b></span>";
          today = "<span color='${colors.mauve}'><b><u>{}</u></b></span>";
        };
      };
    };

    "custom/swaync" = {
      tooltip = false;
      format = "{icon}";
      format-icons = {
        notification = "󰂚";
        none = "󰂜";
        dnd-notification = "󰂛";
        dnd-none = "󰪑";
        inhibited-notification = "󰂛";
        inhibited-none = "󰂜";
        dnd-inhibited-notification = "󰂛";
        dnd-inhibited-none = "󰪑";
      };
      return-type = "json";
      exec-if = "which swaync-client";
      exec = "swaync-client -swb";
      on-click = "swaync-client -t -sw";
      on-click-right = "swaync-client -C";
      escape = true;
    };

    tray = {
      spacing = 8;
      icon-size = 16;
    };

    network = {
      format-wifi = "󰤨 {essid}";
      format-ethernet = "󰈀 {ipaddr}";
      format-disconnected = "󰤭 ";
      tooltip-format-wifi = "{essid} ({signalStrength}%)\n{ipaddr}";
      tooltip-format-ethernet = "{ifname}\n{ipaddr}";
      on-click = "nm-connection-editor";
    };

    bluetooth = {
      format = "󰂯";
      format-disabled = "󰂲";
      format-connected = "󰂱 {num_connections}";
      tooltip-format = "{controller_alias}\t{controller_address}";
      tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{device_enumerate}";
      tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
      on-click = "blueman-manager";
    };

    battery = {
      interval = 5;
      states = {
        warning = 30;
        critical = 15;
      };
      format = "{icon} {capacity}%";
      format-charging = "󰂄 {capacity}%";
      format-plugged = "󰚥 {capacity}%";
      format-icons = [ "󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
      tooltip-format = "{timeTo}\n{capacity}% - {power:.1f}W";
    };

    pulseaudio = {
      format = "{icon} {volume}%";
      format-muted = "󰝟 ";
      format-icons = {
        default = [ "󰕿" "󰖀" "󰕾" ];
        headphone = "󰋋";
        headset = "󰋎";
      };
      tooltip-format = "{desc}\n{volume}%";
      on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      on-click-right = "pavucontrol";
      on-scroll-up = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
      on-scroll-down = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
    };
  });

  # Waybar style.css is managed by theme-switcher (see ~/.local/share/themes/)

  # Hyprlock configuration (screen locker)
  xdg.configFile."hypr/hyprlock.conf".text = ''
    general {
        hide_cursor = true
        disable_loading_bar = true
    }

    background {
        monitor =
        color = ${colors.hypr.base}
    }

    input-field {
        monitor =
        size = 300, 50
        outline_thickness = 3
        dots_size = 0.25
        dots_spacing = 0.2
        dots_center = true
        outer_color = ${colors.hypr.mauve}
        inner_color = ${colors.hypr.surface0}
        font_color = ${colors.hypr.text}
        fade_on_empty = false
        placeholder_text = Password...
        hide_input = false
        position = 0, -50
        halign = center
        valign = center
        rounding = 10
    }

    label {
        monitor =
        text = $TIME
        color = ${colors.hypr.text}
        font_size = 72
        font_family = ${colors.fonts.monospace} Bold
        position = 0, 100
        halign = center
        valign = center
    }

    label {
        monitor =
        text = cmd[update:60000] date +"%A, %B %d"
        color = ${colors.hypr.text}
        font_size = 20
        font_family = ${colors.fonts.monospace}
        position = 0, 30
        halign = center
        valign = center
    }
  '';

  # Hypridle configuration (auto-lock, screen off)
  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
        lock_cmd = pidof hyprlock || hyprlock
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = hyprctl dispatch dpms on
    }

    # Lock screen after 10 minutes (DPMS disabled due to refresh rate issues)
    listener {
        timeout = 600
        on-timeout = loginctl lock-session
    }
  '';

  # Wlogout configuration (power menu)
  xdg.configFile."wlogout/layout".text = ''
    {
        "label" : "lock",
        "action" : "hyprlock",
        "text" : "  Lock",
        "keybind" : "l"
    }
    {
        "label" : "logout",
        "action" : "hyprctl dispatch exit",
        "text" : "  Logout",
        "keybind" : "e"
    }
    {
        "label" : "suspend",
        "action" : "systemctl suspend",
        "text" : "  Suspend",
        "keybind" : "u"
    }
    {
        "label" : "hibernate",
        "action" : "systemctl hibernate",
        "text" : "  Hibernate",
        "keybind" : "h"
    }
    {
        "label" : "reboot",
        "action" : "systemctl reboot",
        "text" : "  Reboot",
        "keybind" : "r"
    }
    {
        "label" : "shutdown",
        "action" : "systemctl poweroff",
        "text" : "  Shutdown",
        "keybind" : "s"
    }
  '';

  # Wlogout style.css is managed by theme-switcher (see ~/.local/share/themes/)
  # Fuzzel config is managed by theme-switcher (see ~/.local/share/themes/)

  # ═══════════════════════════════════════════════════════════════════════════
  # PYPRLAND - Scratchpads & Dropdown Terminal
  # ═══════════════════════════════════════════════════════════════════════════
  xdg.configFile."hypr/pyprland.toml".text = ''
    [pyprland]
    plugins = ["scratchpads", "magnify"]

    [scratchpads.term]
    animation = "fromTop"
    command = "${termCmd.withClass "dropdown-terminal"}"
    class = "dropdown-terminal"
    size = "80% 50%"
    unfocus = "hide"
    lazy = true

    [scratchpads.btop]
    animation = "fromTop"
    command = "${termCmd.withClassAndCmd "btop-scratchpad" "btop"}"
    class = "btop-scratchpad"
    size = "80% 70%"
    unfocus = "hide"
    lazy = true

    [scratchpads.files]
    animation = "fromRight"
    command = "${termCmd.withClassAndCmd "yazi-scratchpad" "yazi"}"
    class = "yazi-scratchpad"
    size = "60% 80%"
    position = "40% 10%"
    unfocus = "hide"
    lazy = true
  '';

  # ═══════════════════════════════════════════════════════════════════════════
  # YAZI - Modern Terminal File Manager
  # ═══════════════════════════════════════════════════════════════════════════
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      manager = {
        show_hidden = false;
        sort_by = "natural";
        sort_dir_first = true;
        linemode = "size";
        show_symlink = true;
      };
      preview = {
        tab_size = 2;
        max_width = 600;
        max_height = 900;
        image_filter = "triangle";
        image_quality = 75;
        sixel_fraction = 15;
        ueberzug_scale = 1;
        ueberzug_offset = [0 0 0 0];
      };
      opener = {
        edit = [
          { run = ''nvim "$@"''; block = true; for = "unix"; }
        ];
        open = [
          { run = ''xdg-open "$@"''; desc = "Open"; for = "linux"; }
        ];
        reveal = [
          { run = ''xdg-open "$(dirname "$0")"''; desc = "Reveal"; for = "linux"; }
        ];
      };
    };
    # Catppuccin Mocha theme for Yazi
    theme = {
      manager = {
        cwd = { fg = "${colors.teal}"; };
        hovered = { bg = "${colors.surface0}"; };
        preview_hovered = { underline = true; };
        find_keyword = { fg = "${colors.yellow}"; italic = true; };
        find_position = { fg = "${colors.pink}"; bg = "reset"; italic = true; };
        marker_selected = { fg = "${colors.green}"; bg = "${colors.green}"; };
        marker_copied = { fg = "${colors.yellow}"; bg = "${colors.yellow}"; };
        marker_cut = { fg = "${colors.red}"; bg = "${colors.red}"; };
        tab_active = { fg = "${colors.base}"; bg = "${colors.mauve}"; };
        tab_inactive = { fg = "${colors.text}"; bg = "${colors.surface1}"; };
        tab_width = 1;
        border_symbol = "│";
        border_style = { fg = "${colors.surface1}"; };
      };
      status = {
        separator_open = "";
        separator_close = "";
        separator_style = { fg = "${colors.surface1}"; bg = "${colors.surface1}"; };
        mode_normal = { fg = "${colors.base}"; bg = "${colors.blue}"; bold = true; };
        mode_select = { fg = "${colors.base}"; bg = "${colors.green}"; bold = true; };
        mode_unset = { fg = "${colors.base}"; bg = "${colors.flamingo}"; bold = true; };
        progress_label = { fg = "${colors.text}"; bold = true; };
        progress_normal = { fg = "${colors.blue}"; bg = "${colors.surface1}"; };
        progress_error = { fg = "${colors.red}"; bg = "${colors.surface1}"; };
        permissions_t = { fg = "${colors.blue}"; };
        permissions_r = { fg = "${colors.yellow}"; };
        permissions_w = { fg = "${colors.red}"; };
        permissions_x = { fg = "${colors.green}"; };
        permissions_s = { fg = "${colors.overlay1}"; };
      };
      input = {
        border = { fg = "${colors.mauve}"; };
        title = {};
        value = {};
        selected = { reversed = true; };
      };
      select = {
        border = { fg = "${colors.mauve}"; };
        active = { fg = "${colors.pink}"; };
        inactive = {};
      };
      tasks = {
        border = { fg = "${colors.mauve}"; };
        title = {};
        hovered = { underline = true; };
      };
      which = {
        mask = { bg = "${colors.surface0}"; };
        cand = { fg = "${colors.teal}"; };
        rest = { fg = "${colors.overlay1}"; };
        desc = { fg = "${colors.pink}"; };
        separator = " ➜ ";
        separator_style = { fg = "${colors.surface2}"; };
      };
      help = {
        on = { fg = "${colors.pink}"; };
        exec = { fg = "${colors.teal}"; };
        desc = { fg = "${colors.overlay1}"; };
        hovered = { bg = "${colors.surface0}"; bold = true; };
        footer = { fg = "${colors.surface1}"; bg = "${colors.text}"; };
      };
      filetype = {
        rules = [
          { mime = "image/*"; fg = "${colors.teal}"; }
          { mime = "video/*"; fg = "${colors.yellow}"; }
          { mime = "audio/*"; fg = "${colors.yellow}"; }
          { mime = "application/zip"; fg = "${colors.pink}"; }
          { mime = "application/gzip"; fg = "${colors.pink}"; }
          { mime = "application/x-tar"; fg = "${colors.pink}"; }
          { mime = "application/x-7z-compressed"; fg = "${colors.pink}"; }
          { mime = "application/x-rar"; fg = "${colors.pink}"; }
          { mime = "application/pdf"; fg = "${colors.red}"; }
          { name = "*"; fg = "${colors.text}"; }
          { name = "*/"; fg = "${colors.blue}"; }
        ];
      };
    };
  };

  # ═══════════════════════════════════════════════════════════════════════════
  # STARSHIP - Modern Cross-Shell Prompt (config managed by theme-switcher)
  # ═══════════════════════════════════════════════════════════════════════════
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    # Settings are managed by theme-switcher (see ~/.local/share/themes/)
  };

  # btop configuration - Catppuccin Mocha theme
  xdg.configFile."btop/btop.conf".text = ''
    color_theme = "catppuccin_mocha"
    theme_background = True
    vim_keys = True
  '';

  xdg.configFile."btop/themes/catppuccin_mocha.theme".text = ''
    # Catppuccin Mocha theme for btop
    # https://github.com/catppuccin/btop

    theme[main_bg]="${colors.base}"
    theme[main_fg]="${colors.text}"
    theme[title]="${colors.text}"
    theme[hi_fg]="${colors.blue}"
    theme[selected_bg]="${colors.surface1}"
    theme[selected_fg]="${colors.blue}"
    theme[inactive_fg]="${colors.overlay1}"
    theme[graph_text]="${colors.rosewater}"
    theme[meter_bg]="${colors.surface1}"
    theme[proc_misc]="${colors.rosewater}"
    theme[cpu_box]="${colors.mauve}"
    theme[mem_box]="${colors.green}"
    theme[net_box]="${colors.maroon}"
    theme[proc_box]="${colors.blue}"
    theme[div_line]="${colors.overlay0}"
    theme[temp_start]="${colors.green}"
    theme[temp_mid]="${colors.yellow}"
    theme[temp_end]="${colors.red}"
    theme[cpu_start]="${colors.teal}"
    theme[cpu_mid]="${colors.sapphire}"
    theme[cpu_end]="${colors.lavender}"
    theme[free_start]="${colors.mauve}"
    theme[free_mid]="${colors.lavender}"
    theme[free_end]="${colors.blue}"
    theme[cached_start]="${colors.sapphire}"
    theme[cached_mid]="${colors.blue}"
    theme[cached_end]="${colors.lavender}"
    theme[available_start]="${colors.peach}"
    theme[available_mid]="${colors.maroon}"
    theme[available_end]="${colors.red}"
    theme[used_start]="${colors.green}"
    theme[used_mid]="${colors.teal}"
    theme[used_end]="${colors.sky}"
    theme[download_start]="${colors.peach}"
    theme[download_mid]="${colors.maroon}"
    theme[download_end]="${colors.red}"
    theme[upload_start]="${colors.green}"
    theme[upload_mid]="${colors.teal}"
    theme[upload_end]="${colors.sky}"
    theme[process_start]="${colors.sapphire}"
    theme[process_mid]="${colors.lavender}"
    theme[process_end]="${colors.mauve}"
  '';

  # lazygit configuration - Catppuccin Mocha theme
  xdg.configFile."lazygit/config.yml".text = ''
    # Catppuccin Mocha theme for lazygit
    # https://github.com/catppuccin/lazygit
    gui:
      nerdFontsVersion: "3"
      theme:
        activeBorderColor:
          - "${colors.blue}"
          - bold
        inactiveBorderColor:
          - "${colors.subtext0}"
        optionsTextColor:
          - "${colors.blue}"
        selectedLineBgColor:
          - "${colors.surface0}"
        cherryPickedCommitBgColor:
          - "${colors.surface1}"
        cherryPickedCommitFgColor:
          - "${colors.blue}"
        unstagedChangesColor:
          - "${colors.red}"
        defaultFgColor:
          - "${colors.text}"
        searchingActiveBorderColor:
          - "${colors.yellow}"
      authorColors:
        "*": "${colors.lavender}"
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
    control-center-margin-top = 50;
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

  # Zen Browser userChrome.css - Catppuccin Mocha theme
  # Note: Requires toolkit.legacyUserProfileCustomizations.stylesheets = true in about:config
  home.activation.zenBrowserTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Find Zen profile directory and install userChrome.css
    ZEN_DIR="$HOME/.zen"
    if [ -d "$ZEN_DIR" ]; then
      for profile in "$ZEN_DIR"/*.default* "$ZEN_DIR"/*release*; do
        if [ -d "$profile" ]; then
          $DRY_RUN_CMD mkdir -p "$profile/chrome"
          $DRY_RUN_CMD cp -f ${pkgs.writeText "userChrome.css" ''
            /* Catppuccin Mocha theme for Zen Browser */
            /* Enable in about:config: toolkit.legacyUserProfileCustomizations.stylesheets = true */

            :root {
              /* Catppuccin Mocha colors from colors.nix */
              --catppuccin-base: ${colors.base};
              --catppuccin-mantle: ${colors.mantle};
              --catppuccin-crust: ${colors.crust};
              --catppuccin-surface0: ${colors.surface0};
              --catppuccin-surface1: ${colors.surface1};
              --catppuccin-surface2: ${colors.surface2};
              --catppuccin-overlay0: ${colors.overlay0};
              --catppuccin-overlay1: ${colors.overlay1};
              --catppuccin-text: ${colors.text};
              --catppuccin-subtext0: ${colors.subtext0};
              --catppuccin-subtext1: ${colors.subtext1};
              --catppuccin-mauve: ${colors.mauve};
              --catppuccin-pink: ${colors.pink};
              --catppuccin-red: ${colors.red};
              --catppuccin-peach: ${colors.peach};
              --catppuccin-yellow: ${colors.yellow};
              --catppuccin-green: ${colors.green};
              --catppuccin-teal: ${colors.teal};
              --catppuccin-blue: ${colors.blue};
              --catppuccin-lavender: ${colors.lavender};

              /* Apply to Firefox/Zen variables */
              --toolbar-bgcolor: var(--catppuccin-base) !important;
              --toolbar-color: var(--catppuccin-text) !important;
              --toolbar-field-background-color: var(--catppuccin-surface0) !important;
              --toolbar-field-color: var(--catppuccin-text) !important;
              --toolbar-field-border-color: var(--catppuccin-surface1) !important;
              --toolbar-field-focus-background-color: var(--catppuccin-surface0) !important;
              --toolbar-field-focus-border-color: var(--catppuccin-mauve) !important;
              --urlbar-box-bgcolor: var(--catppuccin-surface0) !important;
              --urlbar-box-hover-bgcolor: var(--catppuccin-surface1) !important;
              --urlbar-box-active-bgcolor: var(--catppuccin-surface1) !important;
              --urlbar-box-text-color: var(--catppuccin-text) !important;
              --lwt-accent-color: var(--catppuccin-base) !important;
              --lwt-text-color: var(--catppuccin-text) !important;
              --arrowpanel-background: var(--catppuccin-base) !important;
              --arrowpanel-color: var(--catppuccin-text) !important;
              --arrowpanel-border-color: var(--catppuccin-surface1) !important;
              --panel-separator-color: var(--catppuccin-surface1) !important;
              --tab-selected-bgcolor: var(--catppuccin-surface0) !important;
              --tab-selected-textcolor: var(--catppuccin-text) !important;
              --tab-loading-fill: var(--catppuccin-mauve) !important;
              --focus-outline-color: var(--catppuccin-mauve) !important;
            }

            /* Tab bar background */
            #TabsToolbar {
              background-color: var(--catppuccin-mantle) !important;
            }

            /* Navigation bar */
            #nav-bar {
              background-color: var(--catppuccin-base) !important;
              border-bottom: 1px solid var(--catppuccin-surface0) !important;
            }

            /* URL bar */
            #urlbar-background {
              background-color: var(--catppuccin-surface0) !important;
              border: 1px solid var(--catppuccin-surface1) !important;
            }

            #urlbar[focused="true"] > #urlbar-background {
              border-color: var(--catppuccin-mauve) !important;
            }

            /* Sidebar */
            #sidebar-box {
              background-color: var(--catppuccin-mantle) !important;
            }

            /* Context menus */
            menupopup, panel {
              --panel-background: var(--catppuccin-base) !important;
              --panel-color: var(--catppuccin-text) !important;
            }

            menuitem:hover, .panel-subview-body toolbarbutton:hover {
              background-color: var(--catppuccin-surface1) !important;
            }

            /* Bookmarks bar */
            #PersonalToolbar {
              background-color: var(--catppuccin-mantle) !important;
            }

            /* Selected tab indicator */
            .tabbrowser-tab[selected="true"] .tab-line {
              background-color: var(--catppuccin-mauve) !important;
            }

            /* Hover states */
            .tabbrowser-tab:hover .tab-background {
              background-color: var(--catppuccin-surface0) !important;
            }

            /* Scrollbar styling */
            * {
              scrollbar-color: var(--catppuccin-surface2) var(--catppuccin-base) !important;
            }
          ''} "$profile/chrome/userChrome.css"
          $DRY_RUN_CMD chmod 644 "$profile/chrome/userChrome.css"
        fi
      done
    fi
  '';

  # Proton-GE auto-update service (disabled on work hosts)
  systemd.user.services.protonup = lib.mkIf (!isWorkHost) {
    Unit = {
      Description = "Update Proton-GE";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.protonup-ng}/bin/protonup";
      Environment = "PATH=${pkgs.coreutils}/bin";
    };
  };

  # Run on login and weekly (disabled on work hosts)
  systemd.user.timers.protonup = lib.mkIf (!isWorkHost) {
    Unit = {
      Description = "Update Proton-GE weekly and on login";
    };
    Timer = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1week";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  # VSCode configuration with Catppuccin theme
  programs.vscode = {
    enable = true;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        catppuccin.catppuccin-vsc
        catppuccin.catppuccin-vsc-icons
      ];
      userSettings = {
        # Theme
        "workbench.colorTheme" = "Catppuccin Mocha";
        "workbench.iconTheme" = "catppuccin-mocha";

        # Font
        "editor.fontFamily" = "'${colors.fonts.monospace}', 'monospace', monospace";
        "editor.fontSize" = 14;
        "editor.fontLigatures" = true;
        "terminal.integrated.fontFamily" = "'${colors.fonts.monospace}'";
        "terminal.integrated.fontSize" = 14;

        # Editor appearance
        "editor.cursorBlinking" = "smooth";
        "editor.cursorSmoothCaretAnimation" = "on";
        "editor.smoothScrolling" = true;
        "workbench.list.smoothScrolling" = true;
        "terminal.integrated.smoothScrolling" = true;

        # Window
        "window.titleBarStyle" = "custom";
        "window.menuBarVisibility" = "toggle";

        # Catppuccin accent color (mauve)
        "catppuccin.accentColor" = "mauve";
      };
    };
  };
}
