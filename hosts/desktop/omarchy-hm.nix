# Omarchy HM-side overrides for the desktop trial (see omarchy.nix).
#
# Strategy:
# - The user's Hyprland config (keybindings, looknfeel, animations, autostart,
#   window/layer rules) is ported VERBATIM from modules/home/hyprland.nix via
#   the shared Lua fragments in modules/home/_common.nix, generated into
#   hypr/hm.lua — omarchy's "loaded last, overrides everything" layer.
# - The framework's own keybindings are disabled via a shadow of
#   default/hypr/omarchy.lua in ~/.config (package.path puts ~/.config/?.lua
#   first), plus quick_app_bindings = [] and the preinstalls-removed marker.
#   Framework autostart/envs/looknfeel/input/windows/theme still load.
# - Tier-1 conflicts (git credentials, GTK theme, mimeapps) are mkForce'd
#   back to the user's choices.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (import ../../modules/home/_common.nix { inherit lib; hostName = "desktop"; })
    currentHost
    mkHyprVars
    mkMonitorLuaCalls
    mkWorkspaceMonitorRules
    nvidiaEnvLua
    nvidiaRenderLua
    mkEnvBlock
    mkLooknfeelConfig
    animationsLua
    mkAutostartBlock
    mkBindBlock
    windowRulesLua
    layerRulesLua
    ;

  # Seeded once as a user-owned file (mirrors omarchy's own monitors.lua
  # skeleton, but with the user's real monitor line from hostConfig.desktop).
  monitorsLua = ''
    -- See https://wiki.hypr.land/Configuring/Basics/Monitors/
    -- Seeded from nix (hosts/desktop/omarchy-hm.nix); user-owned thereafter.

    local omarchy_gdk_scale = 1
    local omarchy_monitor_scale = "auto"

    hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
    ${mkMonitorLuaCalls currentHost.monitor}
  '';
in
{
  # ─────────────────────────────────────────────────────────────────────────
  # Hyprland: the user's config in omarchy's hm.lua layer
  # ─────────────────────────────────────────────────────────────────────────
  xdg.configFile."hypr/hm.lua" = lib.mkForce {
    text = ''
      ${mkHyprVars currentHost}

      ----------------------------------------------------------------
      -- Environment variables
      ----------------------------------------------------------------
      ${mkEnvBlock currentHost ''
        -- Neutralize omarchy's forced GTK_THEME=Adwaita:dark; the user's
        -- gtk.theme (catppuccin-mocha-mauve-standard) applies instead.
        hl.env("GTK_THEME", "")
        -- NVIDIA (standalone GPU; mirrors hosts/desktop/nvidia.nix)
        ${nvidiaEnvLua}
      ''}

      ----------------------------------------------------------------
      -- Theme colors (hot-swappable via theme-switcher; the `hypr.` prefix
      -- resolves on omarchy's package.path)
      ----------------------------------------------------------------
      require("hypr.theme-colors")

      ${mkLooknfeelConfig currentHost}

      -- NVIDIA render tweak
      ${nvidiaRenderLua}

      ${animationsLua}

      ----------------------------------------------------------------
      -- Autostart (omarchy's shell owns notifications/network/wallpaper —
      -- swaync, nm-applet, awww are dropped; hypridle stays, its lock
      -- retargeted below)
      ----------------------------------------------------------------
      ${mkAutostartBlock {
        includeSwaync = false;
        includeNmApplet = false;
        includeAwww = false;
      }}

      ${mkBindBlock {
        superL = ''hl.dsp.exec_cmd("omarchy-menu toggle system")'';
        superShiftB = ''hl.dsp.exec_cmd("omarchy-toggle-bar")'';
        superN = ''hl.dsp.exec_cmd("omarchy-shell notifications showHistory")'';
        extraBinds = ''
          -- Omarchy bridge binds (framework binds are off — see the shadow
          -- file below; omarchy features land on the free combos)
          hl.bind("SUPER + SPACE",     hl.dsp.exec_cmd("omarchy-menu toggle"))
          hl.bind("SUPER + ESC",       hl.dsp.exec_cmd("omarchy-menu toggle system"))
          hl.bind("SUPER + CTRL + L",  hl.dsp.exec_cmd("omarchy-system-lock"))
          hl.bind("PRINT",             hl.dsp.exec_cmd("omarchy-capture-screenshot"))
          hl.bind("SUPER + CTRL + V",  hl.dsp.exec_cmd("omarchy-clipboard-open"))
          hl.bind("SUPER + K",         hl.dsp.exec_cmd("omarchy-menu-keybindings"))
          hl.bind("SUPER + comma",     hl.dsp.exec_cmd("omarchy-shell notifications dismissOne"))
        '';
      }}

      ${windowRulesLua}

      ----------------------------------------------------------------
      -- Workspaces (1-9 pinned to the primary monitor)
      ----------------------------------------------------------------
      ${mkWorkspaceMonitorRules currentHost.primaryOutput}

      ${layerRulesLua}
    '';
  };

  # ─────────────────────────────────────────────────────────────────────────
  # Framework keybindings off
  # ─────────────────────────────────────────────────────────────────────────
  # package.path puts ~/.config/?.lua before $OMARCHY_PATH/?.lua, so this
  # shadow wins when the loader requires default.hypr.omarchy. Everything
  # else the framework does (autostart, envs, looknfeel, input, windows,
  # theme) loads unchanged.
  home.file.".config/default/hypr/omarchy.lua".text = ''
    -- Shadow of $OMARCHY_PATH/default/hypr/omarchy.lua: the user's
    -- keybindings (hypr/hm.lua) replace the framework's. Framework
    -- autostart/envs/looknfeel/input/windows/theme modules still load;
    -- only the bindings modules are dropped, and the guard flag makes
    -- any straggler skip itself.

    require("default.hypr.helpers")
    local require_optional = require("default.hypr.require_optional")

    _G.omarchy_default_bindings = false

    require("default.hypr.autostart")
    require("default.hypr.envs")
    require("default.hypr.looknfeel")
    require("default.hypr.input")
    require("default.hypr.windows")

    -- Current theme overrides.
    require_optional.module("omarchy.current.theme.hyprland")
  '';

  # Omarchy's preinstalled-app keybindings are generated per quick_app_bindings;
  # the marker removes what the first-run provisioner would add.
  home.file.".local/state/omarchy/preinstalls-removed".text = "";

  # ─────────────────────────────────────────────────────────────────────────
  # Monitors: seed the user's monitor line before omarchy's own seed runs.
  # entryBetween's args are (before, after) — this node runs after
  # writeBoundary and before seedMonitorsLua. monitors.lua is a REAL
  # user-owned file after this — omarchy's seed only fires on missing files.
  home.activation.installMonitorsLua = lib.hm.dag.entryBetween [
    "seedMonitorsLua"
  ] [ "writeBoundary" ] ''
    monitors="$HOME/.config/hypr/monitors.lua"
    if [ ! -e "$monitors" ]; then
      run mkdir -p "$(dirname "$monitors")"
      run install -m644 ${pkgs.writeText "monitors.lua" monitorsLua} "$monitors"
    fi
  '';

  # hypridle: omarchy has no idle-timeout; keep the user's 10-minute lock,
  # retargeted to omarchy's lock command.
  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
        lock_cmd = omarchy-system-lock
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = hyprctl eval 'hl.dsp.dpms("on")'
    }

    # Lock screen after 10 minutes (DPMS disabled due to refresh rate issues)
    listener {
        timeout = 600
        on-timeout = omarchy-system-lock
    }
  '';

  # ─────────────────────────────────────────────────────────────────────────
  # Tier 1: git — kill omarchy's plaintext `credential.helper = store`;
  # identity + SSH signing come from the user's shared programs.nix.
  # ─────────────────────────────────────────────────────────────────────────
  programs.git.settings.credential.helper = lib.mkForce "";

  # ─────────────────────────────────────────────────────────────────────────
  # Tier 1: GTK — the user's catppuccin set wins over omarchy's Adwaita-dark
  # (GTK_THEME neutralized in hm.lua so gtk.theme applies).
  # ─────────────────────────────────────────────────────────────────────────
  gtk.theme = lib.mkForce {
    name = "catppuccin-mocha-mauve-standard";
    package = pkgs.catppuccin-gtk.override {
      accents = [ "mauve" ];
      variant = "mocha";
    };
  };
  gtk.iconTheme = lib.mkForce {
    name = "Papirus-Dark";
    package = pkgs.papirus-icon-theme;
  };
  gtk.cursorTheme = lib.mkForce {
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;
  };
  home.pointerCursor = lib.mkForce {
    gtk.enable = true;
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;
  };

  # ─────────────────────────────────────────────────────────────────────────
  # Tier 1: mimeapps — the user's picks win on the overlapping keys (zen for
  # web, Loupe for images, code for text); omarchy fills the gaps
  # (inode/directory→nautilus, PDF→Evince, video/audio→mpv, markdown→Typora).
  # ─────────────────────────────────────────────────────────────────────────
  xdg.mimeApps.defaultApplications = lib.mkMerge [
    (lib.mapAttrs (_: v: lib.mkForce v) {
      "x-scheme-handler/http" = "zen.desktop";
      "x-scheme-handler/https" = "zen.desktop";
      "text/html" = "zen.desktop";
      "image/png" = "org.gnome.Loupe.desktop";
      "image/jpeg" = "org.gnome.Loupe.desktop";
      "image/gif" = "org.gnome.Loupe.desktop";
      "image/webp" = "org.gnome.Loupe.desktop";
      "image/bmp" = "org.gnome.Loupe.desktop";
      "image/tiff" = "org.gnome.Loupe.desktop";
      "text/plain" = "code.desktop";
      "text/x-shellscript" = "code.desktop";
      "text/x-c++src" = "code.desktop";
      "text/x-java" = "code.desktop";
      "application/xml" = "code.desktop";
      "text/markdown" = "code.desktop";
    })
  ];
}
