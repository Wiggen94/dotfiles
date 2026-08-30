# niri user config — keybinds ported as close to 1:1 as niri's model allows
# from the Hyprland setup (the Lua fragments in modules/home/_common.nix and
# the omarchy bridge binds in modules/omarchy-hm.nix). Only takes effect in
# the "Niri" session; the Hyprland session reads none of this.
#
# The omarchy quickshell shell (bar, launcher, menu, notifications, OSD,
# clipboard, power menu, wallpaper, lock, polkit) is the SAME instance used
# under Hyprland — it's a mostly compositor-agnostic Quickshell tree, so it's
# started here too and driven by the same `omarchy-*` commands.
#
# Known casualties under niri (the shell is not an officially supported combo):
#   - the bar's Workspaces + KeyboardLayout widgets (Quickshell.Hyprland IPC)
#     render nothing — niri workspaces are on Mod+1..9 / the overview instead
#   - Super+K (omarchy-menu-keybindings) reads `hyprctl binds` → empty; use
#     niri's own Mod+Shift+/ hotkey overlay
#   - a few omarchy scripts shell out to hyprctl for minor tweaks and no-op
#
# Model differences worth knowing before rebinding anything:
#   - niri has columns on an infinite horizontal strip, not dwindle/master.
#     "focus left/right" moves between columns; "focus up/down" within a column.
#   - Workspaces are dynamic and stacked vertically per-monitor. Super+1..9
#     still work. There is no special/scratchpad workspace → Super+S = overview.
#   - No pyprland → Super+Y is dropped. Super+M is maximize-column; Super+G
#     is a niri-native gaming mode (toggles an included gaps/border override).
{
  config,
  lib,
  pkgs,
  hostName,
  ...
}:
let
  common = import ./_common.nix { inherit lib hostName; };
  host = common.currentHost;
  inherit (config.lib.niri) actions;

  omarchyPath = "${config.home.homeDirectory}/.local/share/omarchy";

  # Output config. niri keys outputs by connector name; the source of truth
  # for resolution/refresh/scale/VRR is hostConfig in _common.nix. sikt's
  # monitors are matched there by EDID description (they flip connectors
  # between dock reconnects), so that host is left for niri to auto-configure.
  niriConnector =
    {
      desktop = "DP-1";
      laptop = "eDP-1";
    }
    .${hostName} or null;
  niriMode =
    {
      desktop = {
        width = 5120;
        height = 1440;
        refresh = 240.0;
      };
      laptop = {
        width = 2560;
        height = 1440;
        refresh = 60.0;
      };
    }
    .${hostName} or null;
  outputs = lib.optionalAttrs (niriConnector != null) {
    "${niriConnector}" = {
      mode = niriMode;
      variable-refresh-rate = host.vrr;
      scale = host.scale;
    };
  };

  # Super+1..9 : focus workspace / move column to workspace. The index-taking
  # move action isn't in the `actions` helper, so it uses the raw shorthand.
  workspaceBinds = builtins.listToAttrs (
    builtins.concatMap (n: [
      {
        name = "Mod+${toString n}";
        value.action = actions.focus-workspace n;
      }
      {
        name = "Mod+Shift+${toString n}";
        value.action.move-column-to-workspace = n;
      }
    ]) (lib.range 1 9)
  );
in
{
  # The niri-flake NixOS module (modules/system/niri.nix) auto-wires its
  # home-manager module into home-manager.users.*, so it is NOT imported here.

  programs.niri.settings = {
    prefer-no-csd = true;
    screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";
    hotkey-overlay.skip-at-startup = true;

    inherit outputs;

    cursor = {
      theme = "Bibata-Modern-Ice";
      size = host.cursorSize;
    };

    input = {
      keyboard.xkb = {
        # Norwegian default, Kvikk as 2nd group (see _common.nix input block).
        # Super+Shift+Space switches groups; no grp:*_toggle in xkb options.
        layout = "no,kvikk";
        options = "";
      };
      touchpad = {
        tap = true;
        natural-scroll = true;
        dwt = true;
      };
      focus-follows-mouse.enable = true;
      # niri's default 3-finger touchpad swipe already switches workspaces/
      # columns, matching the Hyprland `gesture workspace` binding.
    };

    layout = {
      gaps = 8;
      border = {
        enable = true;
        width = 3;
      };
      focus-ring.enable = false;
      default-column-width.proportion = 0.5;
      preset-column-widths = [
        { proportion = 1.0 / 3.0; }
        { proportion = 0.5; }
        { proportion = 2.0 / 3.0; }
      ];
    };

    # X11 apps: niri manages xwayland-satellite and exports DISPLAY itself.
    xwayland-satellite = {
      enable = true;
      path = "${pkgs.xwayland-satellite}/bin/xwayland-satellite";
    };

    environment = {
      OMARCHY_PATH = omarchyPath;
      XCURSOR_SIZE = toString host.cursorSize;
      XCURSOR_THEME = "Bibata-Modern-Ice";
      QT_QPA_PLATFORMTHEME = "kde";
      QT_STYLE_OVERRIDE = "Breeze";
      BROWSER = "zen";
      XKB_DEFAULT_LAYOUT = "no";
      NIXOS_OZONE_WL = "1";
    }
    // lib.optionalAttrs (hostName == "desktop") {
      # NVIDIA: keep it to the two vendor-selection vars. GBM_BACKEND is
      # deliberately omitted — it's the one CLAUDE.md flags for browser
      # crashes on this GPU.
      LIBVA_DRIVER_NAME = "nvidia";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    };

    spawn-at-startup = [
      # The omarchy quickshell shell — same tree, same shell.json as Hyprland.
      # `quickshell` on PATH is omarchy-nix's wrapped build. File watcher off:
      # omarchy restarts the shell deliberately on rebuild (omarchy-restart-shell).
      { sh = ''QS_DISABLE_FILE_WATCHER=1 exec quickshell -n -p "${omarchyPath}/shell"''; }
      {
        argv = [
          "1password"
          "--silent"
        ];
      }
      {
        argv = [
          "wl-clip-persist"
          "--clipboard"
          "regular"
        ];
      }
      { argv = [ "kdeconnect-indicator" ]; }
      { argv = [ "notification-sound-daemon" ]; }
    ]
    ++ lib.optional (hostName == "desktop") { argv = [ "runelite-mouse4-daemon" ]; };

    binds = {
      # ── Applications ───────────────────────────────────────────────
      "Mod+T".action = actions.spawn host.terminal;
      "Mod+Shift+T".action = actions.spawn "sh" "-lc" "exec $HOME/.local/bin/wterm";
      "Mod+B".action = actions.spawn "zen";
      "Mod+C".action = actions.spawn "qalculate-gtk";
      "Mod+E".action = actions.spawn "nautilus" "--new-window";
      "Mod+O".action = actions.spawn "obsidian";

      # ── omarchy shell bridge (same commands as the Hyprland session) ──
      "Mod+A".action = actions.spawn "omarchy-menu" "toggle";
      "Mod+Space".action = actions.spawn "omarchy-menu" "toggle";
      "Mod+Escape".action = actions.spawn "omarchy-menu" "toggle" "system";
      "Mod+L".action = actions.spawn "omarchy-menu" "toggle" "system";
      "Mod+Ctrl+L".action = actions.spawn "omarchy-system-lock";
      # Super+K = keybind reference (as on Hyprland). omarchy-menu-keybindings
      # reads `hyprctl binds` and is empty under niri, so use niri's own
      # overlay instead.
      "Mod+K".action = actions.show-hotkey-overlay;
      "Mod+V".action = actions.spawn "omarchy-shell" "shell" "toggle" "omarchy.clipboard";
      "Mod+Ctrl+V".action = actions.spawn "omarchy-shell" "shell" "toggle" "omarchy.clipboard";
      "Mod+N".action = actions.spawn "omarchy-shell" "notifications" "showHistory";
      "Mod+Comma".action = actions.spawn "omarchy-shell" "notifications" "dismissOne";
      "Mod+Shift+B".action = actions.spawn "omarchy-toggle-bar";
      "Ctrl+Mod+Tab".action = actions.spawn "omarchy-theme-menu";
      "Mod+Shift+W".action = actions.spawn "omarchy-bg-menu";
      "Mod+P".action = actions.spawn "screenshot";
      "Print".action = actions.spawn "omarchy-capture-screenshot";

      # ── Window management ──────────────────────────────────────────
      "Mod+Q".action = actions.close-window;
      "Mod+F".action = actions.fullscreen-window;
      "Mod+W".action = actions.toggle-window-floating;
      # Hyprland Super+J was togglesplit — nearest niri idea is tabbed columns.
      "Mod+J".action = actions.toggle-column-tabbed-display;

      # focus (Hyprland Super+arrows)
      "Mod+Left".action = actions.focus-column-left;
      "Mod+Right".action = actions.focus-column-right;
      "Mod+Up".action = actions.focus-window-up;
      "Mod+Down".action = actions.focus-window-down;

      # move window (Hyprland Super+Ctrl+arrows)
      "Mod+Ctrl+Left".action = actions.move-column-left;
      "Mod+Ctrl+Right".action = actions.move-column-right;
      "Mod+Ctrl+Up".action = actions.move-window-up;
      "Mod+Ctrl+Down".action = actions.move-window-down;

      # resize (Hyprland Super+Shift+arrows, repeating)
      "Mod+Shift+Left" = {
        repeat = true;
        action = actions.set-column-width "-5%";
      };
      "Mod+Shift+Right" = {
        repeat = true;
        action = actions.set-column-width "+5%";
      };
      "Mod+Shift+Up" = {
        repeat = true;
        action = actions.set-window-height "-5%";
      };
      "Mod+Shift+Down" = {
        repeat = true;
        action = actions.set-window-height "+5%";
      };

      # column sizing / placement — niri's idiom for "snap left third / half /
      # two-thirds" and centre (no Hyprland equivalent). Shoving a column to
      # the far edge is just Super+Ctrl+arrow held down.
      "Mod+R".action = actions.switch-preset-column-width; # cycle ⅓ → ½ → ⅔
      "Mod+Shift+R".action = actions.switch-preset-window-height;
      "Mod+M".action = actions.maximize-column;
      "Mod+Ctrl+C".action = actions.center-column;

      # cycle windows (Hyprland Super+Tab / Super+Shift+Tab)
      "Mod+Tab".action = actions.focus-window-down-or-column-right;
      "Mod+Shift+Tab".action = actions.focus-window-up-or-column-left;

      # move workspace between monitors (Hyprland Ctrl+Alt+Super+arrows)
      "Ctrl+Alt+Mod+Left".action = actions.move-workspace-to-monitor-left;
      "Ctrl+Alt+Mod+Right".action = actions.move-workspace-to-monitor-right;

      # scratchpad → overview (niri has no special workspace)
      "Mod+S".action = actions.toggle-overview;

      # mouse-wheel workspace scroll (Hyprland Super+scroll)
      "Mod+WheelScrollDown" = {
        cooldown-ms = 150;
        action = actions.focus-workspace-down;
      };
      "Mod+WheelScrollUp" = {
        cooldown-ms = 150;
        action = actions.focus-workspace-up;
      };

      # ── Layout / keyboard ─────────────────────────────────────────
      "Mod+Shift+Space".action = actions.switch-layout "next";

      # ── Media / brightness (allowed on lock screen) ───────────────
      "XF86AudioRaiseVolume" = {
        allow-when-locked = true;
        action = actions.spawn "volume-up";
      };
      "XF86AudioLowerVolume" = {
        allow-when-locked = true;
        action = actions.spawn "volume-down";
      };
      "XF86AudioMute" = {
        allow-when-locked = true;
        action = actions.spawn "volume-mute";
      };
      "XF86AudioMicMute" = {
        allow-when-locked = true;
        action = actions.spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle";
      };
      "XF86MonBrightnessUp" = {
        allow-when-locked = true;
        action = actions.spawn "brightnessctl" "-e4" "-n2" "set" "5%+";
      };
      "XF86MonBrightnessDown" = {
        allow-when-locked = true;
        action = actions.spawn "brightnessctl" "-e4" "-n2" "set" "5%-";
      };
      "XF86AudioPlay" = {
        allow-when-locked = true;
        action = actions.spawn "playerctl" "play-pause";
      };
      "XF86AudioPause" = {
        allow-when-locked = true;
        action = actions.spawn "playerctl" "play-pause";
      };
      "XF86AudioNext" = {
        allow-when-locked = true;
        action = actions.spawn "playerctl" "next";
      };
      "XF86AudioPrev" = {
        allow-when-locked = true;
        action = actions.spawn "playerctl" "previous";
      };

      # ── niri housekeeping (no Hyprland equivalent) ────────────────
      "Mod+Shift+E".action = actions.quit;

      # Gaming mode: toggle ~/.config/niri/gaming.kdl (gaps/struts/border/
      # focus-ring off). See the xdg.configFile.niri-config override below.
      "Mod+G".action = actions.spawn "gaming-mode";
    }
    // workspaceBinds;

    window-rules = [
      {
        matches = [ { app-id = "^(qalculate-gtk)$"; } ];
        open-floating = true;
      }
      {
        # Waydroid: float, same reasoning as the Hyprland rule.
        matches = [ { app-id = "^([Ww]aydroid.*)$"; } ];
        open-floating = true;
      }
      {
        matches = [ { title = "^(Picture-in-Picture|Picture in picture)$"; } ];
        open-floating = true;
      }
      {
        # Rounded corners on everything, matching Hyprland rounding = 18.
        geometry-corner-radius =
          let
            r = 18.0;
          in
          {
            top-left = r;
            top-right = r;
            bottom-left = r;
            bottom-right = r;
          };
        clip-to-geometry = true;
      }
    ];
  };

  # Gaming mode (Super+G → `gaming-mode`). niri has no live gaps/border knob
  # like `hyprctl keyword`, but it hot-reloads included files, so append an
  # optional include at the very end of the generated config — after
  # everything niri-flake renders, so its overrides win (includes are
  # positional). The `gaming-mode` script writes/removes the target file;
  # `optional=true` makes its absence a no-op. Rebuilt through `niri
  # validate`, same as niri-flake's own `validated-config-for`.
  xdg.configFile.niri-config = lib.mkForce {
    target = "niri/config.kdl";
    source =
      pkgs.runCommand "config.kdl"
        {
          config = ''
            ${config.programs.niri.finalConfig}

            include optional=true "${config.xdg.configHome}/niri/gaming.kdl"
          '';
          passAsFile = [ "config" ];
          buildInputs = [ config.programs.niri.package ];
        }
        ''
          niri validate -c $configPath
          cp $configPath $out
        '';
  };
}
