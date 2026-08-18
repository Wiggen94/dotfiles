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

  # ═══════════════════════════════════════════════════════════════════════════
  # SHARED HYPRLAND LUA FRAGMENTS
  # Single source of truth consumed by modules/home/hyprland.nix and by the
  # omarchy port at hosts/desktop/omarchy-hm.nix (desktop only). The omarchy
  # port reuses these verbatim — only the three retargeted binds (SUPER+L,
  # SUPER+SHIFT+B, SUPER+N) and the env block are parameterized.
  # ═══════════════════════════════════════════════════════════════════════════

  # Variables block (mainMod, terminal, fileManager, menu)
  mkHyprVars = host: ''
    ----------------------------------------------------------------
    -- Variables
    ----------------------------------------------------------------
    local mainMod     = "SUPER"
    local terminal    = "${host.terminal}"
    local fileManager = "nautilus"
    local menu        = "vicinae toggle"
  '';

  # monitor=... lines → hl.monitor() Lua calls
  mkMonitorLuaCalls = monitor: let
    parseMonitor =
      line:
      let
        s = lib.removePrefix "monitor=" line;
        parts = lib.splitString "," s;
      in
      {
        output = builtins.elemAt parts 0;
        mode = builtins.elemAt parts 1;
        position = builtins.elemAt parts 2;
        scale = builtins.elemAt parts 3;
      };
  in
    lib.concatMapStringsSep "\n" (
      line:
      let
        m = parseMonitor line;
      in
      ''hl.monitor({ output = "${m.output}", mode = "${m.mode}", position = "${m.position}", scale = "${m.scale}" })''
    ) (lib.splitString "\n" monitor);

  # Workspaces 1-9 pinned to the primary monitor (non-laptop hosts)
  mkWorkspaceMonitorRules = primaryMon:
    lib.concatStringsSep "\n" (
      map
        (
          i:
          ''hl.workspace_rule({ workspace = "${toString i}", monitor = "${primaryMon}"${
            lib.optionalString (i == 1) ", default = true"
          } })''
        )
        (lib.range 1 9)
    );

  # NVIDIA env + render tweaks (desktop only — the omarchy port appends these
  # to its hm.lua; plain hosts never include them)
  nvidiaEnvLua = ''
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("XDG_SESSION_TYPE", "wayland")
    hl.env("GBM_BACKEND", "nvidia-drm")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
  '';
  nvidiaRenderLua = ''
    hl.config({ render = { direct_scanout = false } })
  '';

  # User env block (cursors, Qt, browser). `extraEnv` holds host-specific
  # lines (e.g. the GTK_THEME neutralizer on desktop).
  mkEnvBlock = host: extraEnv: ''
    hl.env("XCURSOR_SIZE",       "${toString host.cursorSize}")
    hl.env("HYPRCURSOR_SIZE",    "${toString host.cursorSize}")
    hl.env("XCURSOR_THEME",      "Bibata-Modern-Ice")
    hl.env("QT_QPA_PLATFORMTHEME","kde")
    hl.env("QT_STYLE_OVERRIDE",  "Breeze")
    hl.env("BROWSER",            "zen")
    ${lib.optionalString (host.scale > 1) ''hl.env("MOZ_ENABLE_WAYLAND", "1")''}
    ${extraEnv}
  '';

  # Look and feel — the whole hl.config block
  mkLooknfeelConfig = host: let
    inactiveOpacity = "1.0"; # windows always opaque ("glassy, not transparent"); focus shown via dim_inactive only
    dimInactive = if host.dimInactive then "true" else "false";
    vrrValue = if host.vrr then "1" else "0";
  in ''
    hl.config({
        general = {
            gaps_in          = 8,
            gaps_out         = 18,
            border_size      = 3,
            resize_on_border = true,
            allow_tearing    = true,
            layout           = "dwindle",
        },
        decoration = {
            rounding         = 18,
            active_opacity   = 1.0,
            inactive_opacity = ${inactiveOpacity},
            dim_inactive     = ${dimInactive},
            dim_strength     = 0.15,
            dim_special      = 0.3,
            shadow = {
                enabled        = true,
                range          = 45,
                render_power   = 3,
                color          = "rgba(00000070)",
                color_inactive = "rgba(11111b50)",
                offset         = "0 12",
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
                contrast           = 1.05,
                brightness         = 1.0,
                vibrancy           = 0.65,
                vibrancy_darkness  = 0.4,
                popups             = true,
                popups_ignorealpha = 0.2,
                special            = true,
            },
        },
        animations = { enabled = true },
        input = {
            kb_layout    = "no,kvikk",              -- default Norwegian; Kvikk as 2nd group
            -- Deliberately no grp:*_toggle here. An xkb toggle only switches the
            -- device that received the keypress, so keyboards drift out of sync and
            -- the layout appears to change on its own. Super+Shift+Space below
            -- switches every keyboard at once instead.
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
            animate_manual_resizes        = false,  -- instant neighbour reflow on mouse-drag resize
            animate_mouse_windowdragging  = false,
        },
    })
  '';

  # Curves + animations + gesture (verbatim, all hosts)
  animationsLua = ''
    ----------------------------------------------------------------
    -- Animation curves
    ----------------------------------------------------------------
    -- macOS-smooth curve set: front-loaded motion, gentle settle
    hl.curve("macEase",   { type = "bezier", points = { {0.22, 1},    {0.36, 1} } })  -- quint ease-out
    hl.curve("macSpring", { type = "bezier", points = { {0.34, 1.56}, {0.64, 1} } })  -- mild overshoot, settles
    hl.curve("macFade",   { type = "bezier", points = { {0.4,  0},    {0.2,  1} } })  -- smooth ease in-out
    hl.curve("macSnap",   { type = "bezier", points = { {0.16, 1},    {0.3,  1} } })  -- expo-out, crisp but soft
    hl.curve("borderRot", { type = "bezier", points = { {0.5,  0},    {0.5,  1} } })  -- even border rotation

    ----------------------------------------------------------------
    -- Animations
    ----------------------------------------------------------------
    hl.animation({ leaf = "windowsIn",        enabled = true, speed = 6,  bezier = "macSpring",  style = "popin 70%" })
    hl.animation({ leaf = "windowsOut",       enabled = true, speed = 5,  bezier = "macEase",    style = "popin 80%" })
    hl.animation({ leaf = "windowsMove",      enabled = true, speed = 3,  bezier = "macSnap" })
    hl.animation({ leaf = "fadeIn",           enabled = true, speed = 4,  bezier = "macFade" })
    hl.animation({ leaf = "fadeOut",          enabled = true, speed = 4,  bezier = "macFade" })
    hl.animation({ leaf = "fadeSwitch",       enabled = true, speed = 4,  bezier = "macFade" })
    hl.animation({ leaf = "fadeDim",          enabled = true, speed = 4,  bezier = "macFade" })
    hl.animation({ leaf = "fadeLayers",       enabled = true, speed = 4,  bezier = "macSnap" })
    hl.animation({ leaf = "border",           enabled = true, speed = 10, bezier = "default" })
    hl.animation({ leaf = "borderangle",      enabled = true, speed = 70, bezier = "borderRot",  style = "loop" })
    hl.animation({ leaf = "workspaces",       enabled = true, speed = 8,  bezier = "macEase",    style = "slide" })
    hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 7,  bezier = "macSpring",  style = "slidevert" })
    hl.animation({ leaf = "layers",           enabled = true, speed = 4,  bezier = "macSnap",    style = "popin 90%" })

    ----------------------------------------------------------------
    -- Gestures
    ----------------------------------------------------------------
    hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
  '';

  # Autostart block (common to all hosts). Flags drop pieces the omarchy
  # shell owns on desktop: swaync notifications, nm-applet, the awww
  # wallpaper daemon (omarchy's shell + theme background switcher replace
  # them). hypridle stays everywhere (omarchy has no idle-timeout; the
  # desktop's hypridle.conf retargets the lock to omarchy-system-lock).
  mkAutostartBlock =
    {
      includeSwaync ? true,
      includeNmApplet ? true,
      includeAwww ? true,
    }:
    ''
      hl.on("hyprland.start", function()
          hl.exec_cmd("systemctl --user import-environment XDG_SESSION_ID XDG_SESSION_TYPE DISPLAY WAYLAND_DISPLAY")
          -- Strip ambient capabilities before starting vicinae. Hyprland holds
          -- cap_sys_nice (file caps, for RT scheduling) and leaks it as an
          -- AMBIENT capability to everything it execs at autostart. Ambient caps
          -- flow into every child, so apps launched from vicinae inherit
          -- cap_sys_nice too - which makes Steam's pressure-vessel bwrap abort
          -- with "Unexpected capabilities but not setuid". setpriv clears it.
          hl.exec_cmd("setpriv --ambient-caps=-all vicinae server")
          ${lib.optionalString includeSwaync ''hl.exec_cmd("swaync")''}
          hl.exec_cmd("1password")
          hl.exec_cmd("wl-paste --type text --watch cliphist store")
          hl.exec_cmd("wl-paste --type image --watch cliphist store")
          hl.exec_cmd("wl-clip-persist --clipboard regular")
          hl.exec_cmd("hypridle")
          ${lib.optionalString includeNmApplet ''hl.exec_cmd("nm-applet --indicator")''}
          hl.exec_cmd("kdeconnect-indicator")
          hl.exec_cmd("notification-sound-daemon")
          hl.exec_cmd("wayvnc --render-cursor 0.0.0.0")
          ${lib.optionalString includeAwww ''hl.exec_cmd([[awww-daemon && sleep 0.5 && [ -f ~/.config/current-wallpaper ] && awww img "$(cat ~/.config/current-wallpaper)" --transition-type fade --transition-duration 1]])''}
          hl.exec_cmd("pypr")
          hl.exec_cmd("monitor-handler")
          hl.exec_cmd("runelite-mouse4-daemon")
      end)
    '';

  # Full keybinding block. The three binds that differ between plain Hyprland
  # and the omarchy port are parameterized (defaults = plain-Hyprland targets);
  # `extraBinds` (the omarchy bridge binds on desktop) is appended after the
  # mouse-drag binds. Verbatim ports of the pre-omarchy config otherwise.
  mkBindBlock =
    {
      superL ? ''hl.dsp.global("quickshell:powermenu")'',
      superShiftB ? ''hl.dsp.global("quickshell:bartoggle")'',
      superN ? ''hl.dsp.exec_cmd("swaync-client -t -sw")'',
      # Theme machinery: the user's theme-switcher/wallpaper-picker by default;
      # the omarchy desktop trial retargets these to omarchy's switchers.
      themeSwitcher ? "theme-switcher",
      wallpaperPicker ? "wallpaper-picker",
      extraBinds ? "",
    }:
    ''
      ----------------------------------------------------------------
      -- Keybindings
      ----------------------------------------------------------------
      hl.bind(mainMod .. " + T",         hl.dsp.exec_cmd(terminal))
      hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("$HOME/.local/bin/wterm"))
      hl.bind(mainMod .. " + B",         hl.dsp.exec_cmd("zen"))
      hl.bind(mainMod .. " + C",         hl.dsp.exec_cmd("qalculate-gtk"))
      hl.bind(mainMod .. " + Q",         hl.dsp.window.close())
      hl.bind(mainMod .. " + E",         hl.dsp.exec_cmd(fileManager))
      hl.bind(mainMod .. " + W",         hl.dsp.window.float({ action = "toggle" }))
      hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
      hl.bind(mainMod .. " + A",         hl.dsp.exec_cmd(menu))
      hl.bind(mainMod .. " + J",         hl.dsp.layout("togglesplit"))
      hl.bind(mainMod .. " + V",         hl.dsp.exec_cmd("vicinae deeplink vicinae://launch/clipboard/history"))
      hl.bind(mainMod .. " + P",         hl.dsp.exec_cmd("screenshot"))
      hl.bind(mainMod .. " + L",         ${superL})
      hl.bind(mainMod .. " + G",         hl.dsp.exec_cmd("gaming-mode-toggle"))
      hl.bind("CTRL + SUPER + Tab",      hl.dsp.exec_cmd(${lib.toJSON themeSwitcher}))
      hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(${lib.toJSON wallpaperPicker}))
      hl.bind(mainMod .. " + Y",         hl.dsp.exec_cmd("pypr toggle term"))
      hl.bind(mainMod .. " + SHIFT + Y", hl.dsp.exec_cmd("pypr toggle btop"))
      hl.bind(mainMod .. " + SHIFT + B", ${superShiftB})
      hl.bind(mainMod .. " + N",         ${superN})
      hl.bind(mainMod .. " + O",         hl.dsp.exec_cmd("obsidian"))
      -- Toggle Norwegian <-> Kvikk on all keyboards at once (see input.kb_layout)
      hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"))

      -- Move focus
      hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
      hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
      hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
      hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

      -- Workspaces (1-9) and move-to-workspace
      for i = 1, 9 do
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

      ${extraBinds}
    '';

  # Window rules + layer rules (verbatim, all hosts)
  windowRulesLua = ''
    ----------------------------------------------------------------
    -- Window rules
    ----------------------------------------------------------------
    hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })
    hl.window_rule({
        match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
        no_focus = true,
    })

    -- Waydroid (Android) — float by default. The guest hwcomposer resizes its
    -- display from xdg_toplevel configure events, so a floating window is
    -- drag-resizable and Android follows. Tiling forces sizes on it instead,
    -- which black-screens the surface and restarts the container.
    hl.window_rule({
        match = { class = "^([Ww]aydroid.*)$" },
        float = true, center = true, size = { 1280, 800 },
    })

    -- Calculator
    hl.window_rule({ match = { class = "^(qalculate-gtk)$" }, float = true, center = true, size = { 400, 500 } })

    -- Pyprland scratchpads
    hl.window_rule({ match = { class = "^(dropdown-terminal)$" }, float = true, center = true, animation = "slide" })
    hl.window_rule({ match = { class = "^(btop-scratchpad)$"  }, float = true, center = true, animation = "slide" })

    -- Vivaldi - never dim
    hl.window_rule({ match = { class = "^(vivaldi.*)$" }, no_dim = true })
    hl.window_rule({ match = { class = "^(zen.*)$" },     no_dim = true })

    -- Picture-in-Picture
    hl.window_rule({ match = { title = "^Picture-in-Picture$" }, opaque = true, pin = true })
    hl.window_rule({ match = { title = "^Picture in picture$" }, opaque = true, pin = true })

    -- World of Warcraft
    hl.window_rule({ match = { title = "^World of Warcraft$" }, tile = true })

    -- Black Desert Mobile (Steam) - fixed size hints make Hyprland auto-float
    -- and refuse resizes; forcing tile bypasses both. Title has a build
    -- number suffix that changes on updates, hence the wildcard.
    hl.window_rule({ match = { title = "^Black Desert Mobile.*$" }, tile = true })

    -- EDMC Modern Overlay
    hl.window_rule({
        match = { class = "^(python3)$" },
        float = true, pin = true, no_focus = true, border_size = 0,
        no_shadow = true, no_blur = true, no_dim = true, opaque = true,
    })

    -- Force RGBX for XWayland windows
    hl.window_rule({ match = { xwayland = true, class = "^.+$" }, force_rgbx = true })
  '';

  layerRulesLua = ''
    ----------------------------------------------------------------
    -- Layer rules (blur)
    ----------------------------------------------------------------
    hl.layer_rule({ match = { namespace = "vicinae"         }, blur = true, ignore_alpha = 0.3, animation = "popin" })
    hl.layer_rule({ match = { namespace = "notifications"   }, blur = true, ignore_alpha = 0.3, animation = "slide" })
    hl.layer_rule({ match = { namespace = "quickshell"      }, blur = true, ignore_alpha = 0.3, animation = "fade" })
    hl.layer_rule({ match = { namespace = "gtk-layer-shell" }, blur = true, ignore_alpha = 0.3 })
  '';

}
