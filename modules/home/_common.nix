# Shared Home Manager helpers: per-host config + theme generators.
# Imported (not a module) by modules/home/*.nix.
{ lib, hostName }:
rec {
  # Work hosts don't get gaming/personal services
  isWorkHost = hostName == "sikt";

  # Laptop hosts dock/undock - don't bind workspaces to specific monitors
  # Keep this definition in sync with modules/system/power.nix (any non-desktop
  # host is treated as a laptop — battery/power mgmt + no fixed workspace binding).
  isLaptopHost = hostName != "desktop";

  # Import theme system
  themeRegistry = import ../../themes/default.nix;
  allThemes = themeRegistry.themes;
  themeNames = themeRegistry.themeNames;

  # Default colors for non-switchable configs (backwards compatible)
  colors = import ../../colors.nix;

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
      # Auto-detect resolution/refresh per monitor; positions adapt accordingly.
      # eDP-1 (laptop) always leftmost, external monitors to the right.
      monitor = builtins.concatStringsSep "\n" [
        "monitor=eDP-1,preferred,auto-left,1" # Laptop screen leftmost
        "monitor=DP-3,preferred,auto,1" # Ultrawide in middle (main)
        "monitor=DP-1,preferred,auto-right,1" # Lenovo on right
      ];
      primaryOutput = "DP-3"; # Philips ultrawide (Waybar and workspaces go here)
      scale = 1;
      cursorSize = 24;
      vrr = false;
      terminal = "alacritty"; # Reliable on Intel graphics
      dimInactive = false; # No dimming on work machine
    };
  };

  # Get current host config (with sensible defaults for unknown hosts)
  currentHost =
    hostConfig.${hostName} or {
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
  mkQuickshellThemeJson =
    themeName: theme:
    builtins.toJSON {
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
  allThemeFiles = lib.foldl' (
    acc: themeName: acc // (mkThemeFiles themeName allThemes.${themeName})
  ) { } themeNames;

}
