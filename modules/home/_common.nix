# Shared Home Manager helpers: per-host config + Hyprland Lua fragments.
# Imported (not a module) by modules/home/*.nix and modules/omarchy-hm.nix.
{ lib, hostName }:
rec {
  # Work hosts don't get gaming/personal services
  isWorkHost = hostName == "sikt";

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

  # ═══════════════════════════════════════════════════════════════════════════
  # SHARED HYPRLAND LUA FRAGMENTS
  # Single source of truth consumed by modules/omarchy-hm.nix, which ports
  # them into hypr/hm.lua (the omarchy "loaded last, overrides everything"
  # layer). Only the retargeted binds (SUPER+L, SUPER+SHIFT+B, SUPER+N) and
  # the env block are parameterized there.
  # ═══════════════════════════════════════════════════════════════════════════

  # Variables block (mainMod, terminal, fileManager, menu)
  mkHyprVars = host: ''
    ----------------------------------------------------------------
    -- Variables
    ----------------------------------------------------------------
    local mainMod     = "SUPER"
    local terminal    = "${host.terminal}"
    local fileManager = "nautilus"
    local menu        = "omarchy-menu toggle"
  '';

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
    inactiveOpacity = "0.90"; # slight transparency (0.98 active / 0.90 inactive — user's classic values); focus shown via dim_inactive
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
            active_opacity   = 0.98,
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
            -- Empty xkb options → default Caps Lock behavior (caps toggle).
            -- Needed on desktop: omarchy's framework sets compose:caps (Caps
            -- Lock as compose key); hm.lua loads last, so this wins.
            kb_options   = "",
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
  mkAutostartBlock = ''
    hl.on("hyprland.start", function()
        hl.exec_cmd("systemctl --user import-environment XDG_SESSION_ID XDG_SESSION_TYPE DISPLAY WAYLAND_DISPLAY")
        -- XWayland starts with the default US keymap (Hyprland spawns it without
        -- XKB_DEFAULT_* env and XWayland ignores wl_keyboard keymap events), so
        -- X11/Proton apps see enus. Push the Norwegian keymap from the X side.
        hl.exec_cmd([[for i in $(seq 1 25); do setxkbmap no 2>/dev/null && break; sleep 0.2; done]])
        -- (swaync/nm-applet/awww/vicinae are gone — omarchy's shell owns
        -- notifications, network, wallpapers, menus and clipboard)
        hl.exec_cmd("1password")
        -- (clipboard capture is the omarchy shell's clipboard plugin — the
        -- cliphist watchers are gone; SUPER+V / SUPER+CTRL+V toggle the
        -- overlay via omarchy-shell; omarchy-clipboard-open (needs
        -- --history-index) is only called from inside the overlay)
        hl.exec_cmd("wl-clip-persist --clipboard regular")
        hl.exec_cmd("hypridle")
        hl.exec_cmd("kdeconnect-indicator")
        hl.exec_cmd("notification-sound-daemon")
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
      hl.bind(mainMod .. " + V",         hl.dsp.exec_cmd("omarchy-shell shell toggle omarchy.clipboard"))
      hl.bind(mainMod .. " + CTRL + V",  hl.dsp.exec_cmd("omarchy-shell shell toggle omarchy.clipboard"))
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
    hl.layer_rule({ match = { namespace = "notifications"   }, blur = true, ignore_alpha = 0.3, animation = "slide" })
    hl.layer_rule({ match = { namespace = "quickshell"      }, blur = true, ignore_alpha = 0.3, animation = "fade" })
    hl.layer_rule({ match = { namespace = "gtk-layer-shell" }, blur = true, ignore_alpha = 0.3 })
  '';

}
