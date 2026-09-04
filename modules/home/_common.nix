# Shared Home Manager helpers: per-host config + Hyprland Lua fragments.
# Imported (not a module) by modules/home/*.nix and modules/omarchy-hm.nix.
{ lib, hostName }:
rec {
  # Work hosts don't get gaming/personal services
  isWorkHost = hostName == "sikt";

  # ═══════════════════════════════════════════════════════════════════════════
  # COMPOSITOR COST PROFILE
  # These used to be hardcoded inside mkLooknfeelConfig/animationsLua, i.e.
  # every host composited the scene the desktop's RTX 5070 Ti was tuned for.
  # The laptops render it on integrated graphics — `sikt` on Intel UHD across
  # a 3440x1440 ultrawide + 2560x1440 + the panel — and the single worst item
  # is `borderangle` with style = "loop": it repaints every window border
  # continuously, forever, so the iGPU never idles even on a static desktop.
  # ═══════════════════════════════════════════════════════════════════════════
  desktopTuning = {
    blurSize = 10;
    blurPasses = 4;
    shadowEnabled = true;
    shadowRange = 45;
    borderAngleLoop = true; # animated 3-color gradient border
  };

  # Integrated-graphics profile. Blur cost scales with size x passes, so 6/2 is
  # roughly a quarter of 10/4; the shadow radius drops with it. The gradient
  # border still animates on focus change (the `border` leaf), it just stops
  # spinning at idle.
  igpuTuning = desktopTuning // {
    blurSize = 6;
    blurPasses = 2;
    shadowRange = 15;
    borderAngleLoop = false;
  };

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
      tuning = desktopTuning;
      internalPanel = null; # no lid
      workspacePins = { };  # single monitor, nothing to pin
    };
    laptop = {
      monitor = "monitor=,2560x1440@60,auto,1.33";
      primaryOutput = "eDP-1";
      scale = 1.33;
      cursorSize = 32;
      vrr = false;
      terminal = "alacritty";
      dimInactive = true;
      tuning = igpuTuning;
      # 8/18 gaps eat ~15% of a 15" panel's usable width once scaled 1.33x.
      # Applied as a workspace rule keyed to the panel rather than globally,
      # so a docked external keeps the roomier desktop spacing.
      internalPanel = {
        output = "eDP-1";
        gapsIn = 3;
        gapsOut = 6;
        borderSize = 2;
      };
      workspacePins = { };
    };
    sikt = {
      # Matched by EDID description (desc:), not connector name (DP-1/DP-3):
      # this dock doesn't assign external monitors to fixed connectors - which
      # physical monitor shows up as "DP-1" vs "DP-3" flips between boots/
      # reconnects, so position rules keyed to connector name silently swap
      # the ultrawide and the Lenovo. Description strings are tied to the
      # physical monitor (make+model+serial from EDID) and stay stable.
      # eDP-1 keeps auto-left since it's placed last, after both fixed
      # positions are known, so its bounding box is unambiguous.
      monitor = builtins.concatStringsSep "\n" [
        "monitor=desc:Philips Consumer Electronics Company PHL 346B1C UK02204026611,preferred,0x0,1" # Ultrawide, main, anchor at origin
        "monitor=desc:Lenovo Group Limited LEN P27h-10 0x4E315043,preferred,3440x0,1" # Lenovo, fixed to the right of the ultrawide
        "monitor=eDP-1,preferred,auto-left,1" # Laptop screen, left of whatever's docked
      ];
      primaryOutput = "desc:Philips Consumer Electronics Company PHL 346B1C UK02204026611"; # Philips ultrawide (Waybar and workspaces go here)
      scale = 1;
      cursorSize = 24;
      vrr = false;
      terminal = "alacritty"; # Reliable on Intel graphics
      dimInactive = false; # No dimming on work machine
      # Intel UHD compositing three panels at once — the most GPU-starved host
      # in the fleet, and the one that spends all day docking/undocking.
      tuning = igpuTuning;
      internalPanel = {
        output = "eDP-1";
        gapsIn = 3;
        gapsOut = 6;
        borderSize = 2;
      };
      # Workspace -> monitor pinning. Without this, which workspace lands on
      # which screen after a dock cycle is whatever order Hyprland happened to
      # bring the outputs up in, so the morning starts by dragging windows
      # back. Keyed by EDID description for the same reason the monitor rules
      # above are (connector names flip between boots on this dock).
      #
      # Adjust the split to taste — it's the one genuinely personal knob here.
      workspacePins =
        let
          ultrawide = "desc:Philips Consumer Electronics Company PHL 346B1C UK02204026611";
          lenovo = "desc:Lenovo Group Limited LEN P27h-10 0x4E315043";
        in
        {
          "1" = ultrawide;
          "2" = ultrawide;
          "3" = ultrawide;
          "4" = ultrawide;
          "5" = ultrawide;
          "6" = lenovo;
          "7" = lenovo;
          "8" = lenovo;
          "9" = "eDP-1";
        };
    };
  };

  # Get current host config (with sensible defaults for unknown hosts).
  # An unknown host is assumed to be a laptop: the igpu profile is the safe
  # guess (it only costs eye candy on a machine that could afford more,
  # whereas the reverse makes a weak GPU feel broken).
  currentHost =
    hostConfig.${hostName} or {
      monitor = "monitor=,preferred,auto,1";
      primaryOutput = "eDP-1";
      scale = 1;
      cursorSize = 24;
      vrr = false;
      terminal = "alacritty";
      dimInactive = true;
      tuning = igpuTuning;
      internalPanel = {
        output = "eDP-1";
        gapsIn = 3;
        gapsOut = 6;
        borderSize = 2;
      };
      workspacePins = { };
    };

  # True on any host with a lid — drives the touchpad/gesture extras and the
  # clamshell lid binds.
  isLaptop = currentHost.internalPanel != null;

  # Re-indent an interpolated block. Nix's '' stripping removes the leading
  # whitespace from a nested multi-line string, so without this the optional
  # blocks below land flat against the margin in the generated hm.lua. Lua
  # doesn't care, but the file is meant to be read.
  indentLines =
    n: text:
    let
      pad = lib.concatStrings (lib.genList (_: " ") n);
    in
    lib.concatStringsSep "\n" (
      map (l: if l == "" then "" else pad + l) (lib.splitString "\n" text)
    );

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
    local fileManager = "nautilus --new-window"
    local menu        = "omarchy-menu toggle"
  '';

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
    -- XWayland initializes its keymap from XKB_DEFAULT_LAYOUT (it ignores
    -- wl_keyboard keymap events), and Hyprland spawns it without the var, so
    -- X11/Proton apps start on enus. Hand it the layout at spawn; the
    -- setxkbmap loop in the autostart stays as a fallback.
    hl.env("XKB_DEFAULT_LAYOUT", "no")
    ${lib.optionalString (host.scale > 1) ''hl.env("MOZ_ENABLE_WAYLAND", "1")''}
    ${extraEnv}
  '';

  # Look and feel — the whole hl.config block
  mkLooknfeelConfig = host: let
    inactiveOpacity = "0.90"; # slight transparency (0.98 active / 0.90 inactive — user's classic values); focus shown via dim_inactive
    dimInactive = if host.dimInactive then "true" else "false";
    vrrValue = if host.vrr then "1" else "0";
    t = host.tuning;
    hasLid = host.internalPanel != null;
    # Touchpad extras. Only the keys set here are overridden — omarchy's
    # input.lua already supplies clickfinger_behavior = true and
    # scroll_factor = 0.4, and hl.config merges per key rather than replacing
    # the whole touchpad table, so those survive untouched. Verified with
    # `hyprctl getoption input:touchpad:scroll_factor`.
    touchpadExtras = lib.optionalString hasLid (indentLines 16 ''
      -- Tap-drag without holding the tap down: a drag continues after the
      -- finger lifts and lands again, which is what makes window drags and
      -- text selection on a small pad tolerable.
      tap_and_drag         = true,
      drag_lock            = true,
      -- Three-finger drag (libinput): press-free window dragging.
      drag_3fg             = true,
    '');
    # Swipe feel. workspace_swipe_distance defaults to 300px of travel for a
    # full workspace change, which is most of a laptop pad's width; 200 makes
    # it a flick. `forever` keeps consuming the same gesture, so one long swipe
    # can cross several workspaces, and direction_lock stops a slightly
    # diagonal swipe from being read as vertical.
    gesturesConfig = lib.optionalString hasLid (indentLines 8 ''
      gestures = {
          workspace_swipe_distance           = 200,
          workspace_swipe_cancel_ratio       = 0.35,
          workspace_swipe_forever            = true,
          workspace_swipe_direction_lock     = true,
          workspace_swipe_create_new         = false,
          workspace_swipe_min_speed_to_force = 20,
      },
    '');
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
                enabled        = ${if t.shadowEnabled then "true" else "false"},
                range          = ${toString t.shadowRange},
                render_power   = 3,
                color          = "rgba(00000070)",
                color_inactive = "rgba(11111b50)",
                offset         = "0 12",
                scale          = 1.0,
            },
            blur = {
                enabled            = true,
                size               = ${toString t.blurSize},
                passes             = ${toString t.blurPasses},
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
${touchpadExtras}            },
        },
${gesturesConfig}        dwindle = { preserve_split = true },
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

  # Curves + animations + gestures. Curves and window animations are the same
  # everywhere; the always-on `borderangle` loop and the touchpad gestures are
  # per-host (see the cost profile at the top).
  mkAnimationsLua = host: ''
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
    ${
      if host.tuning.borderAngleLoop then
        ''hl.animation({ leaf = "borderangle",      enabled = true, speed = 70, bezier = "borderRot",  style = "loop" })''
      else
        ''
          -- borderangle loop deliberately off: style = "loop" repaints every
          -- window border every frame for as long as the session lives, which
          -- on an iGPU is a permanent GPU load (and a permanent battery draw)
          -- for a spinning gradient nobody looks at. The gradient itself is
          -- still there; it just doesn't rotate. The `border` leaf above keeps
          -- animating colour on focus change.
          hl.animation({ leaf = "borderangle",      enabled = false })''
    }
    hl.animation({ leaf = "workspaces",       enabled = true, speed = 8,  bezier = "macEase",    style = "slide" })
    hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 7,  bezier = "macSpring",  style = "slidevert" })
    hl.animation({ leaf = "layers",           enabled = true, speed = 4,  bezier = "macSnap",    style = "popin 90%" })

    ----------------------------------------------------------------
    -- Gestures
    ----------------------------------------------------------------
    hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
    ${lib.optionalString (host.internalPanel != null) ''
      -- Laptop-only. Three fingers sideways already moves between workspaces;
      -- these fill in the operations that otherwise need a reach for Super:
      --   vertical   -> the magic scratchpad     (keyboard: SUPER + S)
      --   4 sideways -> carry the window along   (keyboard: SUPER + SHIFT + n)
      --   pinch in   -> fullscreen toggle        (keyboard: SUPER + F)
      hl.gesture({ fingers = 3, direction = "vertical",   action = "special", workspace_name = "magic" })
      hl.gesture({ fingers = 4, direction = "horizontal", action = "move" })
      hl.gesture({ fingers = 4, direction = "pinchin",    action = "fullscreen" })''}
  '';

  # ═══════════════════════════════════════════════════════════════════════════
  # WORKSPACE RULES (per-host)
  # Two jobs, both laptop-shaped:
  #  1. Tighter gaps/border on the internal panel only. `m[<output>]` selects
  #     whatever workspaces are currently on that monitor, so a docked
  #     external keeps the desktop's roomier spacing on the same host.
  #  2. Pin workspaces to monitors, so a dock cycle puts them back where they
  #     were instead of wherever the outputs happened to come up.
  # ═══════════════════════════════════════════════════════════════════════════
  mkWorkspaceRules = host: let
    panel = host.internalPanel;
    panelRule = lib.optionalString (panel != null) ''
      -- Internal panel: reclaim the screen real estate the desktop gaps cost.
      hl.workspace_rule({
          workspace   = "m[${panel.output}]",
          gaps_in     = ${toString panel.gapsIn},
          gaps_out    = ${toString panel.gapsOut},
          border_size = ${toString panel.borderSize},
      })
    '';
    pinRules = lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        ws: mon: ''hl.workspace_rule({ workspace = "${ws}", monitor = "${mon}" })''
      ) host.workspacePins
    );
  in
  lib.optionalString (panel != null || host.workspacePins != { }) ''
    ----------------------------------------------------------------
    -- Workspace rules
    ----------------------------------------------------------------
    ${panelRule}${lib.optionalString (host.workspacePins != { }) ''
      -- Workspace -> monitor pinning: `monitor` is the workspace's home, so
      -- it goes back there when the output returns instead of staying
      -- wherever the undock left it. Selectors are the same EDID
      -- descriptions the monitor rules use (see hostConfig) — connector
      -- names flip between boots on this dock.
      ${pinRules}''}
  '';

  # Autostart block (common to all hosts). Flags drop pieces the omarchy
  # shell owns on desktop: swaync notifications, nm-applet, the awww
  # wallpaper daemon (omarchy's shell + theme background switcher replace
  # them). hypridle stays everywhere (omarchy has no idle-timeout; the
  # desktop's hypridle.conf retargets the lock to omarchy-system-lock).
  mkAutostartBlock = ''
    hl.on("hyprland.start", function()
        hl.exec_cmd("systemctl --user import-environment XDG_SESSION_ID XDG_SESSION_TYPE DISPLAY WAYLAND_DISPLAY")
        -- XWayland ignores wl_keyboard keymap events, but now spawns with
        -- XKB_DEFAULT_LAYOUT=no from the env block above. This is the
        -- belt-and-suspenders fallback for any X server that still comes up
        -- on the default US keymap. A fixed-duration retry loop raced
        -- XWayland's own startup (NVIDIA can delay it past a few seconds) and
        -- gave up silently, so this waits on the XWayland socket actually
        -- appearing (inotifywait, 60s backstop) before retrying instead of
        -- guessing a timeout.
        hl.exec_cmd([[bash -c 'setxkbmap no 2>/dev/null && exit 0; inotifywait -qq -t 60 -e create,moved_to /tmp/.X11-unix 2>/dev/null; for i in $(seq 1 25); do setxkbmap no 2>/dev/null && break; sleep 0.2; done']])
        -- (swaync/nm-applet/awww/vicinae are gone — omarchy's shell owns
        -- notifications, network, wallpapers, menus and clipboard)
        hl.exec_cmd("1password")
        -- (clipboard capture is the omarchy shell's clipboard plugin — the
        -- cliphist watchers are gone; SUPER+V / SUPER+CTRL+V toggle the
        -- overlay via omarchy-shell; omarchy-clipboard-open (needs
        -- --history-index) is only called from inside the overlay)
        hl.exec_cmd("wl-clip-persist --clipboard regular")
        hl.exec_cmd("hypridle")
        -- (kdeconnect-indicator is a systemd user unit now — see
        -- modules/home/services.nix. Starting it here raced the omarchy
        -- shell's tray host and left no tray icon.)
        hl.exec_cmd("notification-sound-daemon")
        hl.exec_cmd("pypr")
        -- No monitor-handler here any more. Omarchy's autostart already runs
        -- omarchy-hyprland-monitor-watch on the same socket2 events, and it
        -- is strictly better: it recovers a monitor that came up modeless
        -- (the DP/DSC cold-boot race), reconciles clamshell state on a poll
        -- while docked, and holds flocks so overlapping events don't stack.
        -- Ours raced it — two watchers both calling `hyprctl reload` on
        -- monitoradded — and on monitorremoved it moved *every* workspace
        -- onto `hyprctl monitors -j | jq '.[0].name'`, an arbitrary survivor,
        -- so unplugging one of two externals collapsed the whole desktop onto
        -- one screen. Hyprland already migrates orphaned workspaces itself.
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
      hl.bind(mainMod .. " + M",         hl.dsp.exec_cmd("monitor-mirror-toggle"))
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
      -- Lid: hand off to omarchy's clamshell handler rather than our own
      -- lid-handler. It reads the internal panel's *configured* position and
      -- scale back out of monitors.lua, where the old script hardcoded
      -- `position = "auto", scale = 1` — on sikt that threw away the
      -- `auto-left` placement on every lid open, reshuffling the whole
      -- desktop until omarchy's 2s reconciliation poll put it back. It also
      -- decides from the actual lid state (omarchy-hw-clamshell) rather than
      -- the bind direction, so both edges call the same thing, and it agrees
      -- with omarchy-hyprland-monitor-watch instead of racing it.
      hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd("omarchy-hyprland-monitor-clamshell"), { locked = true })
      hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("omarchy-hyprland-monitor-clamshell"), { locked = true })

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
