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
# - Tier-1 conflicts (git credentials, mimeapps) are mkForce'd back to the
#   user's choices.
# - Theming: omarchy's system owns everything (CTRL+SUPER+Tab →
#   omarchy-theme-switcher, SUPER+SHIFT+W → omarchy-theme-bg-switcher,
#   Hyprland colors from omarchy.current.theme.hyprland, GTK = Adwaita:dark
#   + per-theme gsettings). The user's own 12-theme system is gated off the
#   desktop in modules/home/base.nix; the cursor stays Bibata (user choice).
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
        -- GTK: omarchy's stock env (Adwaita:dark). Omarchy's theme set
        -- switches light/dark + icons via gsettings (theme-set-gnome);
        -- gtk.theme/iconTheme are mkForce null below so the user's own
        -- catppuccin set doesn't fight it.
        hl.env("GTK_THEME", "Adwaita:dark")
        -- NVIDIA (standalone GPU; mirrors hosts/desktop/nvidia.nix)
        ${nvidiaEnvLua}
      ''}

      -- Hyprland colors come from the omarchy theme system:
      -- default/hypr/omarchy.lua (shadow) requires
      -- omarchy.current.theme.hyprland, which reads the active theme's
      -- hyprland.lua. No user theme-colors require — the omarchy switcher
      -- owns colors here.

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
        # Theme machinery retargeted: the user's own theme-switcher /
        # wallpaper-picker don't apply on desktop — omarchy's do. The
        # switchers only print the pick; the -menu wrappers apply it
        # (home.packages below), mirroring the shell's own pickers.
        themeSwitcher = "omarchy-theme-menu";
        wallpaperPicker = "omarchy-bg-menu";
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
  # Theme keybind wrappers. The switchers only PRINT the chosen
  # theme/background (they end at `exec omarchy-menu-images`); the apply step
  # is done by the shell's own picker processes (Background.qml:
  # theme=$(omarchy-theme-switcher) && omarchy-theme-set). These wrappers
  # reproduce that for Hyprland keybinds. (Hyprland itself gets reloaded by
  # omarchy's own omarchy-restart-hyprctl, generated by its HM module into
  # ~/.local/share/omarchy/bin — that's what re-reads the theme colors.)
  # ─────────────────────────────────────────────────────────────────────────
  home.packages = [
    (pkgs.writeShellScriptBin "omarchy-theme-menu" ''
      # Mirrors shell/plugins/background/Background.qml themeSwitchProc.
      theme=$(omarchy-theme-switcher)
      [[ -n $theme ]] && omarchy-theme-set "$theme" >/dev/null 2>&1 &
    '')
    (pkgs.writeShellScriptBin "omarchy-bg-menu" ''
      # Mirrors shell/plugins/background/Background.qml bgSwitchProc.
      background=$(omarchy-theme-bg-switcher)
      [[ -n $background ]] && omarchy-theme-bg-set "$background"
    '')
  ];

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
  # Tier 1: gh — omarchy enables programs.gh, which writes a minimal
  # config.yml. The user's real config.yml had one actual customization
  # (`co: pr checkout`); the auth token lives in hosts.yml and is untouched.
  # ─────────────────────────────────────────────────────────────────────────
  programs.gh.settings.aliases.co = "pr checkout";

  # ─────────────────────────────────────────────────────────────────────────
  # Tier 1: zsh — omarchy's zplug zsh owns .zshrc/.zshenv; the user's own
  # hand-written bits are carried over: the cargo PATH line (.zshenv, rustup
  # install) and BridgeSpace's shell integration (.zshrc — precmd/preexec/
  # chpwd hooks emitting OSC 133 + OSC 9;9 for its AI autocomplete).
  # ─────────────────────────────────────────────────────────────────────────
  programs.zsh.envExtra = ''
    # Rust (rustup install)
    [[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
  '';

  programs.zsh.initExtra = ''
    # >>> BridgeSpace shell integration >>>
    # v3: skip inside the primary BridgeSpace shell (its own integration.zsh
    # emits these markers — running both double-emitted every prompt).
    # v2: also emits the working directory (OSC 9;9) on every prompt and cd.
    # BridgeSpace emits OSC 133 semantic prompt markers so its AI inline
    # autocomplete can tell when you are typing vs when a command is
    # running, plus OSC 9;9 so suggestions are scoped to the directory you
    # are actually in. Safe to delete this block — it only adds
    # precmd/preexec/chpwd hooks. Unset BRIDGESPACE_SHELL_INTEGRATION to
    # disable at runtime.
    if [[ -o interactive && "''${BRIDGESPACE_SHELL_INTEGRATION:-1}" != "0" && -z "''${BRIDGESPACE_INTEGRATION_DIR:-}" ]]; then
      __bridgespace_emit_cwd() { printf '\e]9;9;%s\a' "$PWD"; }
      __bridgespace_prompt_start() { __bridgespace_emit_cwd; printf '\e]133;A\a'; }
      __bridgespace_command_start() { printf '\e]133;C\a'; }
      autoload -Uz add-zsh-hook 2>/dev/null
      if (( ''${+functions[add-zsh-hook]} )); then
        add-zsh-hook precmd __bridgespace_prompt_start 2>/dev/null
        add-zsh-hook preexec __bridgespace_command_start 2>/dev/null
        add-zsh-hook chpwd __bridgespace_emit_cwd 2>/dev/null
      fi
    fi
  '';

  # ─────────────────────────────────────────────────────────────────────────
  # Tier 1: GTK — omarchy's theming wins. base.nix sets the user's
  # catppuccin-mocha / Papirus-Dark set; nulling both here cancels it, so GTK
  # apps follow GTK_THEME=Adwaita:dark (hm.lua) and the per-theme gsettings
  # switches from omarchy-theme-set-gnome (color-scheme + icon-theme).
  # The cursor stays the user's Bibata set — omarchy doesn't theme cursors.
  # ─────────────────────────────────────────────────────────────────────────
  gtk.theme = lib.mkForce null;
  gtk.iconTheme = lib.mkForce null;
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
