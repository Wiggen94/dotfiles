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
      # eDP-1 (laptop) always leftmost, external monitors to the right
      monitor = builtins.concatStringsSep "\n" [
        "monitor=eDP-1,1920x1200@60,0x0,1"           # Laptop screen leftmost
        "monitor=DP-3,3440x1440@60,1920x0,1"         # Ultrawide in middle (main)
        "monitor=DP-1,2560x1440@60,5360x0,1"         # Lenovo on right
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

  # Generate Hyprland theme colors as a Lua module (loaded via require)
  mkHyprThemeColors = theme: ''
    -- Theme: ${theme.meta.name}
    -- Auto-generated - do not edit manually

    hl.config({
        general = {
            col = {
                active_border   = { colors = { "${theme.rgba.mauve}", "${theme.rgba.pink}", "${theme.rgba.blue}" }, angle = 45 },
                inactive_border = "${theme.transparent.surface1_67}",
            },
        },
        decoration = {
            shadow = {
                color = "${theme.transparent.crust_93}",
            },
        },
        misc = {
            background_color = "${theme.rgba.base}",
        },
    })
  '';

  # Waybar style removed - using Quickshell
  _unusedWaybarStyle = theme: ''
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

    [env]
    TERM = "xterm-256color"

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
    detect_files = ["package.json", ".node-version"]
    detect_folders = ["node_modules"]
    detect_extensions = []

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

  # Generate quickshell theme JSON from a theme attrset
  mkQuickshellThemeJson = themeName: theme: builtins.toJSON {
    name = themeName;
    accent = theme.meta.accent;
    base = theme.base;
    mantle = theme.mantle;
    crust = theme.crust;
    surface0 = theme.surface0;
    surface1 = theme.surface1;
    surface2 = theme.surface2;
    overlay0 = theme.overlay0;
    overlay1 = theme.overlay1;
    text = theme.text;
    subtext0 = theme.subtext0;
    subtext1 = theme.subtext1;
    lavender = theme.lavender;
    blue = theme.blue;
    sapphire = theme.sapphire;
    sky = theme.sky;
    teal = theme.teal;
    green = theme.green;
    yellow = theme.yellow;
    peach = theme.peach;
    maroon = theme.maroon;
    red = theme.red;
    mauve = theme.mauve;
    pink = theme.pink;
    flamingo = theme.flamingo;
    rosewater = theme.rosewater;
    fontMono = theme.fonts.monospace;
    fontSans = theme.fonts.sansSerif;
  };

  # Generate all theme files as an attrset for home.file
  mkThemeFiles = themeName: theme: {
    ".local/share/themes/${themeName}/hypr/theme-colors.lua" = {
      text = mkHyprThemeColors theme;
    };
    ".local/share/themes/${themeName}/alacritty/alacritty.toml" = {
      text = mkAlacrittyConfig theme;
    };
    ".local/share/themes/${themeName}/starship/starship.toml" = {
      text = mkStarshipConfig theme;
    };
    ".local/share/themes/${themeName}/quickshell/colors.json" = {
      text = mkQuickshellThemeJson themeName theme;
    };
  };

  # Generate files for all themes
  allThemeFiles = lib.foldl' (acc: themeName:
    acc // (mkThemeFiles themeName allThemes.${themeName})
  ) {} themeNames;

in
{
  imports = [
    ../work-container/launcher.nix
  ];

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
    settings = {
      "*.uninett.no" = {
        ForwardAgent = "yes";
      };
      "*" = {
        User = "gjewig";
        SetEnv = { TERM = "xterm-256color"; };
        IdentityAgent = "~/.1password/agent.sock";
      };
    };
  };

  programs.thunderbird = {
    enable = true;
    profiles.default = {
      isDefault = true;
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

  # Override Gridcoin wallet to use ~/games datadir when present (desktop), else default.
  xdg.desktopEntries.gridcoinresearch = lib.mkIf (!isWorkHost) {
    name = "Gridcoin";
    comment = "Gridcoin Research wallet";
    exec = "gridcoin-wallet";
    icon = "gridcoinresearch";
    terminal = false;
    categories = [ "Office" "Finance" ];
  };

  # Fresco (modern BOINC manager) desktop entry
  xdg.desktopEntries.fresco = lib.mkIf (!isWorkHost) {
    name = "Fresco";
    comment = "Modern BOINC manager";
    exec = "fresco";
    icon = "fresco";
    terminal = false;
    categories = [ "System" "Utility" ];
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
  wayland.windowManager.hyprland = let
    # --- Per-host monitor configs as Lua hl.monitor() calls ---
    parseMonitor = line:
      let
        s = lib.removePrefix "monitor=" line;
        parts = lib.splitString "," s;
      in {
        output = builtins.elemAt parts 0;
        mode = builtins.elemAt parts 1;
        position = builtins.elemAt parts 2;
        scale = builtins.elemAt parts 3;
      };
    monitorLines = lib.splitString "\n" (monitorConfig.${hostName} or "monitor=,preferred,auto,1");
    monitorCalls = lib.concatMapStringsSep "\n" (line:
      let m = parseMonitor line; in
      ''hl.monitor({ output = "${m.output}", mode = "${m.mode}", position = "${m.position}", scale = "${m.scale}" })''
    ) monitorLines;

    primaryMon = primaryMonitor.${hostName} or "DP-1";
    workspaceMonitorRules = lib.optionalString (!isLaptopHost) (
      lib.concatStringsSep "\n" (map (i:
        ''hl.workspace_rule({ workspace = "${toString i}", monitor = "${primaryMon}"${lib.optionalString (i == 1) ", default = true"} })''
      ) [ 1 2 3 4 5 6 ])
    );

    inactiveOpacity = if currentHost.dimInactive then "0.90" else "1.0";
    dimInactive = if currentHost.dimInactive then "true" else "false";
    vrrValue = if currentHost.vrr then "1" else "0";
    hidpiMozWayland = lib.optionalString (currentHost.scale > 1) ''hl.env("MOZ_ENABLE_WAYLAND", "1")'';
    nvidiaEnv = lib.optionalString (hostName == "desktop") ''
      hl.env("LIBVA_DRIVER_NAME", "nvidia")
      hl.env("XDG_SESSION_TYPE", "wayland")
      hl.env("GBM_BACKEND", "nvidia-drm")
      hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    '';
    nvidiaRender = lib.optionalString (hostName == "desktop") ''
      hl.config({ render = { direct_scanout = false } })
    '';
  in {
    enable = true;
    configType = "lua";
    plugins = [ ];

    extraConfig = ''
      ----------------------------------------------------------------
      -- Variables
      ----------------------------------------------------------------
      local mainMod     = "SUPER"
      local terminal    = "${currentHost.terminal}"
      local fileManager = "dolphin"
      local menu        = "vicinae toggle"

      ----------------------------------------------------------------
      -- Monitors
      ----------------------------------------------------------------
      ${monitorCalls}

      ----------------------------------------------------------------
      -- Environment variables
      ----------------------------------------------------------------
      hl.env("XCURSOR_SIZE",       "${toString currentHost.cursorSize}")
      hl.env("HYPRCURSOR_SIZE",    "${toString currentHost.cursorSize}")
      hl.env("XCURSOR_THEME",      "Bibata-Modern-Ice")
      hl.env("SSH_ASKPASS_REQUIRE","prefer")
      hl.env("QT_QPA_PLATFORMTHEME","kde")
      hl.env("QT_STYLE_OVERRIDE",  "Breeze")
      hl.env("BROWSER",            "vivaldi")
      ${hidpiMozWayland}
      ${nvidiaEnv}

      ----------------------------------------------------------------
      -- Theme colors (hot-swappable via theme-switcher)
      ----------------------------------------------------------------
      require("theme-colors")

      ----------------------------------------------------------------
      -- Look and feel
      ----------------------------------------------------------------
      hl.config({
          general = {
              gaps_in          = 6,
              gaps_out         = 12,
              border_size      = 3,
              resize_on_border = true,
              allow_tearing    = true,
              layout           = "dwindle",
          },
          decoration = {
              rounding         = 12,
              active_opacity   = 0.98,
              inactive_opacity = ${inactiveOpacity},
              dim_inactive     = ${dimInactive},
              dim_strength     = 0.15,
              dim_special      = 0.3,
              shadow = {
                  enabled        = true,
                  range          = 12,
                  render_power   = 4,
                  color_inactive = "rgba(11111b50)",
                  offset         = "0 3",
                  scale          = 1.0,
              },
              blur = {
                  enabled            = true,
                  size               = 10,
                  passes             = 4,
                  new_optimizations  = true,
                  ignore_opacity     = true,
                  xray               = false,
                  noise              = 0.015,
                  contrast           = 1.0,
                  brightness         = 1.0,
                  vibrancy           = 0.4,
                  vibrancy_darkness  = 0.3,
                  popups             = true,
                  popups_ignorealpha = 0.2,
                  special            = true,
              },
          },
          animations = { enabled = true },
          input = {
              kb_layout    = "no",
              follow_mouse = 1,
              sensitivity  = 0,
              touchpad = {
                  natural_scroll       = true,
                  tap_to_click         = true,
                  disable_while_typing = true,
              },
          },
          dwindle = { preserve_split = true },
          master  = { new_status = "master" },
          misc = {
              force_default_wallpaper = 0,
              disable_hyprland_logo   = true,
              vrr                     = ${vrrValue},
          },
      })
      ${nvidiaRender}

      ----------------------------------------------------------------
      -- Animation curves
      ----------------------------------------------------------------
      hl.curve("smoothOut",    { type = "bezier", points = { {0.36, 0},    {0.66, -0.56} } })
      hl.curve("smoothIn",     { type = "bezier", points = { {0.25, 1},    {0.5,  1}     } })
      hl.curve("overshot",     { type = "bezier", points = { {0.05, 0.9},  {0.1,  1.1}   } })
      hl.curve("smoothSpring", { type = "bezier", points = { {0.55, -0.15},{0.20, 1.3}   } })
      hl.curve("fluent",       { type = "bezier", points = { {0.0,  0.0},  {0.2,  1.0}   } })
      hl.curve("snappy",       { type = "bezier", points = { {0.4,  0.0},  {0.2,  1.0}   } })
      hl.curve("easeOutExpo",  { type = "bezier", points = { {0.16, 1},    {0.3,  1}     } })

      ----------------------------------------------------------------
      -- Animations
      ----------------------------------------------------------------
      hl.animation({ leaf = "windowsIn",        enabled = true, speed = 4,  bezier = "overshot",    style = "popin 80%" })
      hl.animation({ leaf = "windowsOut",       enabled = true, speed = 3,  bezier = "smoothOut",   style = "popin 80%" })
      hl.animation({ leaf = "windowsMove",      enabled = true, speed = 4,  bezier = "fluent",      style = "slide" })
      hl.animation({ leaf = "fadeIn",           enabled = true, speed = 3,  bezier = "smoothIn" })
      hl.animation({ leaf = "fadeOut",          enabled = true, speed = 3,  bezier = "smoothOut" })
      hl.animation({ leaf = "fadeSwitch",       enabled = true, speed = 4,  bezier = "smoothIn" })
      hl.animation({ leaf = "fadeDim",          enabled = true, speed = 4,  bezier = "smoothIn" })
      hl.animation({ leaf = "fadeLayers",       enabled = true, speed = 3,  bezier = "easeOutExpo" })
      hl.animation({ leaf = "border",           enabled = true, speed = 8,  bezier = "default" })
      hl.animation({ leaf = "borderangle",      enabled = true, speed = 50, bezier = "smoothIn",    style = "loop" })
      hl.animation({ leaf = "workspaces",       enabled = true, speed = 5,  bezier = "easeOutExpo", style = "slide" })
      hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4,  bezier = "smoothSpring",style = "slidevert" })
      hl.animation({ leaf = "layers",           enabled = true, speed = 3,  bezier = "snappy",      style = "popin 90%" })

      ----------------------------------------------------------------
      -- Gestures
      ----------------------------------------------------------------
      hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

      ----------------------------------------------------------------
      -- Autostart
      ----------------------------------------------------------------
      hl.on("hyprland.start", function()
          hl.exec_cmd("vicinae server")
          hl.exec_cmd("swaync")
          hl.exec_cmd("1password")
          hl.exec_cmd("wl-paste --type text --watch cliphist store")
          hl.exec_cmd("wl-paste --type image --watch cliphist store")
          hl.exec_cmd("wl-clip-persist --clipboard regular")
          hl.exec_cmd("hypridle")
          hl.exec_cmd("nm-applet --indicator")
          hl.exec_cmd("kdeconnect-indicator")
          hl.exec_cmd("notification-sound-daemon")
          hl.exec_cmd("wayvnc --render-cursor 0.0.0.0")
          hl.exec_cmd([[swww-daemon && sleep 0.5 && [ -f ~/.config/current-wallpaper ] && swww img "$(cat ~/.config/current-wallpaper)" --transition-type fade --transition-duration 1]])
          hl.exec_cmd("pypr")
          hl.exec_cmd("monitor-handler")
          hl.exec_cmd("runelite-mouse4-daemon")
      end)

      ----------------------------------------------------------------
      -- Keybindings
      ----------------------------------------------------------------
      hl.bind(mainMod .. " + T",         hl.dsp.exec_cmd(terminal))
      hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("$HOME/.local/bin/wterm"))
      hl.bind(mainMod .. " + B",         hl.dsp.exec_cmd("vivaldi"))
      hl.bind(mainMod .. " + C",         hl.dsp.exec_cmd("qalculate-gtk"))
      hl.bind(mainMod .. " + Q",         hl.dsp.window.close())
      hl.bind(mainMod .. " + E",         hl.dsp.exec_cmd(fileManager))
      hl.bind(mainMod .. " + W",         hl.dsp.window.float({ action = "toggle" }))
      hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
      hl.bind(mainMod .. " + A",         hl.dsp.exec_cmd(menu))
      hl.bind(mainMod .. " + J",         hl.dsp.layout("togglesplit"))
      hl.bind(mainMod .. " + V",         hl.dsp.exec_cmd("vicinae deeplink vicinae://launch/clipboard/history"))
      hl.bind(mainMod .. " + P",         hl.dsp.exec_cmd("screenshot"))
      hl.bind(mainMod .. " + L",         hl.dsp.global("quickshell:powermenu"))
      hl.bind(mainMod .. " + G",         hl.dsp.exec_cmd("gaming-mode-toggle"))
      hl.bind("CTRL + SUPER + Tab",      hl.dsp.exec_cmd("theme-switcher"))
      hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("wallpaper-picker"))
      hl.bind(mainMod .. " + Y",         hl.dsp.exec_cmd("pypr toggle term"))
      hl.bind(mainMod .. " + SHIFT + Y", hl.dsp.exec_cmd("pypr toggle btop"))
      hl.bind(mainMod .. " + SHIFT + B", hl.dsp.global("quickshell:bartoggle"))
      hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd("swaync-client -t -sw"))
      hl.bind(mainMod .. " + O",         hl.dsp.exec_cmd("obsidian"))

      -- Move focus
      hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
      hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
      hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
      hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

      -- Workspaces (1-6) and move-to-workspace
      for i = 1, 6 do
          hl.bind(mainMod .. " + "         .. i, hl.dsp.focus({ workspace = i }))
          hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
      end

      -- Special workspace
      hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
      hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

      -- Mouse scroll workspaces
      hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
      hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

      -- Move windows (Super+Ctrl+arrows)
      hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.move({ direction = "left" }))
      hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.move({ direction = "right" }))
      hl.bind(mainMod .. " + CTRL + up",    hl.dsp.window.move({ direction = "up" }))
      hl.bind(mainMod .. " + CTRL + down",  hl.dsp.window.move({ direction = "down" }))

      -- Move current workspace to monitor (relative)
      hl.bind("CTRL + ALT + " .. mainMod .. " + left",  hl.dsp.workspace.move({ monitor = "-1" }))
      hl.bind("CTRL + ALT + " .. mainMod .. " + right", hl.dsp.workspace.move({ monitor = "+1" }))

      -- Cycle windows
      hl.bind(mainMod .. " + Tab",         hl.dsp.window.cycle_next())
      hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.window.cycle_next({ prev = true }))

      -- Resize active window (repeating)
      hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.resize({ x = -30, y = 0, relative = true }), { repeating = true })
      hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x =  30, y = 0, relative = true }), { repeating = true })
      hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.resize({ x = 0, y = -30, relative = true }), { repeating = true })
      hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.resize({ x = 0, y =  30, relative = true }), { repeating = true })

      -- Audio / brightness (locked + repeating)
      hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("volume-up"),                           { locked = true, repeating = true })
      hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("volume-down"),                         { locked = true, repeating = true })
      hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),       { locked = true, repeating = true })
      hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),       { locked = true, repeating = true })

      -- Audio mute / media / lid (locked, non-repeating)
      hl.bind("XF86AudioMute",    hl.dsp.exec_cmd("volume-mute"),                                  { locked = true })
      hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
      hl.bind("XF86AudioPlay",    hl.dsp.exec_cmd("playerctl play-pause"),                         { locked = true })
      hl.bind("XF86AudioPause",   hl.dsp.exec_cmd("playerctl play-pause"),                         { locked = true })
      hl.bind("XF86AudioNext",    hl.dsp.exec_cmd("playerctl next"),                               { locked = true })
      hl.bind("XF86AudioPrev",    hl.dsp.exec_cmd("playerctl previous"),                           { locked = true })
      hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd("lid-handler close"), { locked = true })
      hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("lid-handler open"),  { locked = true })

      -- Mouse drag / resize
      hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
      hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

      ----------------------------------------------------------------
      -- Window rules
      ----------------------------------------------------------------
      hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })
      hl.window_rule({
          match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
          no_focus = true,
      })

      -- Calculator
      hl.window_rule({ match = { class = "^(qalculate-gtk)$" }, float = true, center = true, size = { 400, 500 } })

      -- Pyprland scratchpads
      hl.window_rule({ match = { class = "^(dropdown-terminal)$" }, float = true, center = true, animation = "slide" })
      hl.window_rule({ match = { class = "^(btop-scratchpad)$"  }, float = true, center = true, animation = "slide" })

      -- Vivaldi - never dim
      hl.window_rule({ match = { class = "^(vivaldi.*)$" }, no_dim = true })

      -- Picture-in-Picture
      hl.window_rule({ match = { title = "^Picture-in-Picture$" }, opaque = true, pin = true })
      hl.window_rule({ match = { title = "^Picture in picture$" }, opaque = true, pin = true })

      -- World of Warcraft
      hl.window_rule({ match = { title = "^World of Warcraft$" }, tile = true })

      -- EDMC Modern Overlay
      hl.window_rule({
          match = { class = "^(python3)$" },
          float = true, pin = true, no_focus = true, border_size = 0,
          no_shadow = true, no_blur = true, no_dim = true, opaque = true,
      })

      -- Winboat main window - hide on special workspace
      hl.window_rule({ match = { class = "^(winboat)$" }, workspace = "special:6" })

      -- Winboat RemoteApp windows
      hl.window_rule({
          match = { class = "^(winboat-.*)$" },
          workspace = "1",
          suppress_event = "fullscreen maximize activate activatefocus",
          no_initial_focus = true,
          fullscreen = true,
          no_anim = true,
          rounding = 0,
          no_shadow = true,
          no_blur = true,
          xray = false,
          opaque = true,
          no_dim = true,
      })

      -- Force RGBX for non-winboat XWayland windows
      hl.window_rule({ match = { xwayland = true, class = "^(?!winboat-).+$" }, force_rgbx = true })

      ----------------------------------------------------------------
      -- Workspace rules (multi-monitor desktops only)
      ----------------------------------------------------------------
      ${workspaceMonitorRules}

      ----------------------------------------------------------------
      -- Layer rules (blur)
      ----------------------------------------------------------------
      hl.layer_rule({ match = { namespace = "launcher"        }, blur = true, ignore_alpha = 0.3 })
      hl.layer_rule({ match = { namespace = "logout_dialog"   }, blur = true, ignore_alpha = 0.3 })
      hl.layer_rule({ match = { namespace = "notifications"   }, blur = true, ignore_alpha = 0.3 })
      hl.layer_rule({ match = { namespace = "quickshell"      }, blur = true, ignore_alpha = 0.3 })
      hl.layer_rule({ match = { namespace = "gtk-layer-shell" }, blur = true, ignore_alpha = 0.3 })
    '';
  };

  # Quickshell bar and lockscreen configs
  xdg.configFile."quickshell/bar" = {
    source = ../quickshell/bar;
    recursive = true;
    onChange = ''
      ${pkgs.systemd}/bin/systemctl --user restart quickshell-bar.service || true
    '';
  };
  xdg.configFile."quickshell/lockscreen" = {
    source = ../quickshell/lockscreen;
    recursive = true;
  };

  # Hypridle configuration (auto-lock, screen off)
  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
        lock_cmd = quickshell -p ~/.config/quickshell/lockscreen
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = hyprctl eval 'hl.dsp.dpms("on")'
    }

    # Lock screen after 10 minutes (DPMS disabled due to refresh rate issues)
    listener {
        timeout = 600
        on-timeout = loginctl lock-session
    }
  '';

  # Power menu is now handled by Quickshell (PowerMenu.qml)
  # Vicinae theming is managed through its built-in theme system (vicinae "Set Theme" command)

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

  # Quickshell bar - restartIfChanged ensures it restarts on rebuild
  systemd.user.services.quickshell-bar = {
    Unit = {
      Description = "Quickshell bar";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStartPre = "-/run/current-system/sw/bin/killall quickshell";
      ExecStart = "/run/current-system/sw/bin/quickshell -p %h/.config/quickshell/bar";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };


  # Proton-GE auto-update service (disabled on work hosts)
  systemd.user.services.protonup = lib.mkIf (!isWorkHost) {
    Unit = {
      Description = "Update Proton-GE";
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

  # TESS Miner autonomous pipeline — desktop only
  systemd.user.services.tess-miner-automine = lib.mkIf (hostName == "desktop") {
    Unit = {
      Description = "TESS Miner Autonomous Mining Run";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      WorkingDirectory = "%h/tess-miner";
      ExecStart = "%h/tess-miner/automine-cron.sh";
      TimeoutSec = 1800;
    };
  };

  systemd.user.timers.tess-miner-automine = lib.mkIf (hostName == "desktop") {
    Unit = {
      Description = "Run TESS Miner automine every 30 minutes";
    };
    Timer = {
      OnCalendar = "*:0/30";
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
