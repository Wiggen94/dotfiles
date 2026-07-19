# Hyprland config, quickshell configs, hypridle, pyprland
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
  # Hyprland configuration - Home Manager module
  wayland.windowManager.hyprland =
    let
      # --- Per-host monitor configs as Lua hl.monitor() calls ---
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
      monitorLines = lib.splitString "\n" (currentHost.monitor or "monitor=,preferred,auto,1");
      monitorCalls = lib.concatMapStringsSep "\n" (
        line:
        let
          m = parseMonitor line;
        in
        ''hl.monitor({ output = "${m.output}", mode = "${m.mode}", position = "${m.position}", scale = "${m.scale}" })''
      ) monitorLines;

      primaryMon = currentHost.primaryOutput or "DP-1";
      workspaceMonitorRules = lib.optionalString (!isLaptopHost) (
        lib.concatStringsSep "\n" (
          map
            (
              i:
              ''hl.workspace_rule({ workspace = "${toString i}", monitor = "${primaryMon}"${
                lib.optionalString (i == 1) ", default = true"
              } })''
            )
            [
              1
              2
              3
              4
              5
              6
            ]
        )
      );

      inactiveOpacity = "1.0"; # windows always opaque ("glassy, not transparent"); focus shown via dim_inactive only
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
    in
    {
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
        hl.env("QT_QPA_PLATFORMTHEME","kde")
        hl.env("QT_STYLE_OVERRIDE",  "Breeze")
        hl.env("BROWSER",            "zen")
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
                kb_options   = "grp:win_space_toggle",  -- Super+Space toggles no <-> kvikk
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
        ${nvidiaRender}

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

        ----------------------------------------------------------------
        -- Autostart
        ----------------------------------------------------------------
        hl.on("hyprland.start", function()
            hl.exec_cmd("systemctl --user import-environment XDG_SESSION_ID XDG_SESSION_TYPE DISPLAY WAYLAND_DISPLAY")
            -- Strip ambient capabilities before starting vicinae. Hyprland holds
            -- cap_sys_nice (file caps, for RT scheduling) and leaks it as an
            -- AMBIENT capability to everything it execs at autostart. Ambient caps
            -- flow into every child, so apps launched from vicinae inherit
            -- cap_sys_nice too - which makes Steam's pressure-vessel bwrap abort
            -- with "Unexpected capabilities but not setuid". setpriv clears it.
            hl.exec_cmd("setpriv --ambient-caps=-all vicinae server")
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
            hl.exec_cmd([[awww-daemon && sleep 0.5 && [ -f ~/.config/current-wallpaper ] && awww img "$(cat ~/.config/current-wallpaper)" --transition-type fade --transition-duration 1]])
            hl.exec_cmd("pypr")
            hl.exec_cmd("monitor-handler")
            hl.exec_cmd("runelite-mouse4-daemon")
        end)

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
        hl.window_rule({ match = { class = "^(zen.*)$" },     no_dim = true })

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

        -- Force RGBX for XWayland windows
        hl.window_rule({ match = { xwayland = true, class = "^.+$" }, force_rgbx = true })

        ----------------------------------------------------------------
        -- Workspace rules (multi-monitor desktops only)
        ----------------------------------------------------------------
        ${workspaceMonitorRules}

        ----------------------------------------------------------------
        -- Layer rules (blur)
        ----------------------------------------------------------------
        hl.layer_rule({ match = { namespace = "vicinae"         }, blur = true, ignore_alpha = 0.3, animation = "popin" })
        hl.layer_rule({ match = { namespace = "notifications"   }, blur = true, ignore_alpha = 0.3, animation = "slide" })
        hl.layer_rule({ match = { namespace = "quickshell"      }, blur = true, ignore_alpha = 0.3, animation = "fade" })
        hl.layer_rule({ match = { namespace = "gtk-layer-shell" }, blur = true, ignore_alpha = 0.3 })
      '';
    };

  # Quickshell bar and lockscreen configs
  xdg.configFile."quickshell/bar" = {
    source = ../../quickshell/bar;
    recursive = true;
    onChange = ''
      ${pkgs.systemd}/bin/systemctl --user restart quickshell-bar.service || true
    '';
  };
  xdg.configFile."quickshell/lockscreen" = {
    source = ../../quickshell/lockscreen;
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
        on-timeout = quickshell -p ~/.config/quickshell/lockscreen
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
}
