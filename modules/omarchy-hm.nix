# Omarchy HM-side overrides (see modules/omarchy.nix).
#
# Strategy:
# - The user's Hyprland config (keybindings, looknfeel, animations, autostart,
#   window/layer rules) is ported VERBATIM from the shared Lua fragments in
#   modules/home/_common.nix, generated into hypr/hm.lua — omarchy's
#   "loaded last, overrides everything" layer.
# - The framework's own keybindings are disabled via a shadow of
#   default/hypr/omarchy.lua in ~/.config (package.path puts ~/.config/?.lua
#   first), plus quick_app_bindings = [] and the preinstalls-removed marker.
#   Framework autostart/envs/looknfeel/input/windows/theme still load.
# - Tier-1 conflicts (git credentials, mimeapps) are mkForce'd back to the
#   user's choices.
# - Theming: omarchy's system owns everything (CTRL+SUPER+Tab →
#   omarchy-theme-switcher, SUPER+SHIFT+W → omarchy-theme-bg-switcher,
#   Hyprland colors from omarchy.current.theme.hyprland, GTK = Adwaita:dark
#   + per-theme gsettings). The cursor stays Bibata (user choice).
{
  config,
  lib,
  pkgs,
  inputs,
  hostName,
  ...
}:
let
  inherit (import ../modules/home/_common.nix { inherit lib hostName; })
    currentHost
    mkHyprVars
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
    termCmd
    ;

  # The packaged (uncolored) omarchy SDDM theme; the sync script below
  # copies from here and recolors the writable copy sddm.theme points at.
  omarchySddmThemeSrc = "${
    (pkgs.callPackage "${inputs.omarchy-nix}/packages/sddm-theme-omarchy.nix" { })
  }/share/sddm/themes/omarchy";

  # Per-host monitors seed. Mirrors omarchy's own monitors.lua skeleton: the
  # panel's scale slider writes omarchy_monitor_scale and reloads Hyprland —
  # the monitor call MUST reference that variable; a hardcoded scale makes
  # the panel's choice revert on every reload. Single-monitor hosts (desktop,
  # laptop) use the variable on their only line; sikt's extra lines stay
  # literal, only the primary (DP-3) follows the panel.
  monitorScaleVar =
    if builtins.length (lib.splitString "\n" currentHost.monitor) == 1 then
      (if currentHost.scale == 1 then "auto" else toString currentHost.scale)
    else
      "1";
  monitorLineCalls =
    let
      mk =
        {
          output,
          mode,
          position,
          scale,
        }:
        ''hl.monitor({ output = "${output}", mode = "${mode}", position = "${position}", scale = ${scale} })'';
      parse = line: lib.splitString "," (lib.removePrefix "monitor=" line);
      lines = lib.splitString "\n" currentHost.monitor;
    in
    if builtins.length lines == 1 then
      let
        parts = parse (builtins.head lines);
      in
      mk {
        output = builtins.elemAt parts 0;
        mode = builtins.elemAt parts 1;
        position = builtins.elemAt parts 2;
        scale = "omarchy_monitor_scale";
      }
    else
      lib.concatMapStringsSep "\n" (
        line:
        let
          parts = parse line;
          output = builtins.elemAt parts 0;
        in
        mk {
          inherit output;
          mode = builtins.elemAt parts 1;
          position = builtins.elemAt parts 2;
          scale =
            if output == currentHost.primaryOutput then
              "omarchy_monitor_scale"
            else
              ''"${builtins.elemAt parts 3}"'';
        }
      ) lines;

  monitorsLua = ''
    -- See https://wiki.hypr.land/Configuring/Basics/Monitors/
    -- Seeded from nix (modules/omarchy-hm.nix); user-owned thereafter.

    local omarchy_gdk_scale = ${toString currentHost.scale}
    local omarchy_monitor_scale = "${monitorScaleVar}"

    hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
    ${monitorLineCalls}
  '';

  # The SDDM greeter sync script. Defined here so the boot activation and the
  # theme-set hook can call it by STORE PATH: on this NixOS setup home.packages
  # land in /etc/profiles/per-user/gjermund/bin, NOT ~/.nix-profile, so the
  # original activation entry's "$HOME/.nix-profile/bin/omarchy-sddm-sync"
  # failed every single run with exit 127 (No such file or directory).
  omarchySddmSync = pkgs.writeShellScriptBin "omarchy-sddm-sync" ''
    # Sync the SDDM greeter with the active omarchy theme. Ported from
    # upstream omarchy-plymouth-set's SDDM half: the packaged theme is
    # static, so recolor a writable copy at
    #   ~/.local/share/sddm/themes/omarchy
    # which services.displayManager.sddm.theme points at (modules/omarchy.nix).
    # Runs at boot (HM activation) and on every theme-set hook, so the
    # next greeter instance shows the new colors — no SDDM restart needed.
    # Builds into a temp dir and swaps it in, so a failure leaves the
    # previous (working) theme in place.
    #
    # Optional args (from the omarchy-plymouth-set* wrappers in
    # ~/.local/share/omarchy/bin — see the shadow entry below):
    #   <bg-hex> <fg-hex> <logo.png> — apply a picked theme's colors/art.
    # Without args, syncs to the active theme (hook/boot path).
    set -eu

    colors="$HOME/.local/state/omarchy/current/theme/colors.toml"
    sddm_dir="$HOME/.local/share/sddm/themes/omarchy"
    tmp="$sddm_dir.tmp"

    bg_hex="''${1:-}"
    fg_hex="''${2:-}"
    logo_path="''${3:-}"
    # The wrappers pass hex with a leading # (upstream strips it too).
    bg_hex="''${bg_hex#\#}"
    fg_hex="''${fg_hex#\#}"

    if [ -z "$bg_hex" ]; then
      # Fall back to omarchy's stock colors until a theme has been applied.
      bg_hex="1a1b26"
      fg_hex="ffffff"
      if [ -f "$colors" ]; then
        bg_hex="$(sed -n 's/^background[[:space:]]*=.*"#\([0-9a-fA-F]\{6\}\)".*/\1/p' "$colors" | head -n1)"
        fg_hex="$(sed -n 's/^foreground[[:space:]]*=.*"#\([0-9a-fA-F]\{6\}\)".*/\1/p' "$colors" | head -n1)"
        [ -n "$bg_hex" ] || bg_hex="1a1b26"
        [ -n "$fg_hex" ] || fg_hex="ffffff"
      fi
      # Follow the active theme's unlock art (mirrors upstream copying the
      # theme's unlock.png into the greeter).
      [ -f "$HOME/.local/state/omarchy/current/theme/unlock.png" ] \
        && logo_path="$HOME/.local/state/omarchy/current/theme/unlock.png"
    else
      # Validate explicit args (mirrors upstream omarchy-plymouth-set).
      if ! [[ $bg_hex =~ ^[0-9a-fA-F]{6}$ ]] || ! [[ $fg_hex =~ ^[0-9a-fA-F]{6}$ ]]; then
        echo "omarchy-sddm-sync: invalid color (expected #RRGGBB): $bg_hex / $fg_hex" >&2
        exit 1
      fi
    fi

    rm -rf "$tmp"
    mkdir -p "$(dirname "$sddm_dir")"
    cp -r ${omarchySddmThemeSrc} "$tmp"
    # The store copy is read-only (0555 dirs) — make the working copy writable.
    chmod -R u+rwX "$tmp"

    # Recolor (mirrors upstream omarchy-plymouth-set).
    sed -i \
      -e "s/#1a1b26/#$bg_hex/g" \
      -e "s/#ffffff/#$fg_hex/g" \
      "$tmp/Main.qml"

    for asset in bullet entry lock; do
      ${pkgs.imagemagick}/bin/magick "$tmp/$asset.png" -channel RGB +level-colors "#$fg_hex","#$fg_hex" "$tmp/$asset.png"
    done
    for asset in entry lock; do
      ${pkgs.imagemagick}/bin/magick "$tmp/$asset.png" -channel RGB +level-colors "#f7768e","#f7768e" "$tmp/$asset-failed.png"
    done
    rm -f "$tmp/logo.svg"

    # Greeter logo: the chosen/active theme's unlock art (upstream copies the
    # same file); keep the packaged logo.png when none resolves.
    if [ -n "$logo_path" ] && [ -f "$logo_path" ]; then
      cp "$logo_path" "$tmp/logo.png"
    fi

    rm -rf "$sddm_dir"
    mv "$tmp" "$sddm_dir"
  '';

  # NixOS shadows of omarchy's Arch-only plymouth binaries. On Arch the
  # originals rewrite /usr/share/plymouth and rebuild the initramfs with
  # mkinitcpio; on NixOS the Plymouth theme is declarative, so these only
  # recolor the SDDM greeter via omarchy-sddm-sync (store path — no sudo,
  # no /usr/share writes). They land INSIDE the HM-managed
  # ~/.local/share/omarchy/bin via the shadow entry below, so they win in
  # every context (see that entry for why).
  omarchyPlymouthSetByTheme = pkgs.writeShellScriptBin "omarchy-plymouth-set-by-theme" ''
    #!/bin/bash
    # Apply a chosen theme's colors + unlock art to the SDDM greeter.
    set -eu

    theme="''${1:?usage: omarchy-plymouth-set-by-theme <theme-name>}"
    theme_dir="$(omarchy-theme-dir "$theme")"

    theme_color() {
      local key="$1"
      # Called with a single key (background/foreground) like upstream; the
      # fallback key only matters with `set -u` off. Default it so the
      # awk's fallback lookup never fires (empty field matches nothing).
      local fallback="''${2:-}"
      awk -F= -v key="$key" -v fallback="$fallback" '
        function clean(raw) {
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", raw)
          if (raw ~ /^"/) { sub(/^"/, "", raw); sub(/".*$/, "", raw) }
          return raw
        }
        { field = $1; gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
          if (field == key) { print clean($2); found = 1; exit }
          if (field == fallback) fallback_value = clean($2) }
        END { if (!found && fallback_value != "") print fallback_value }
      ' "$theme_dir/colors.toml"
    }

    bg="$(theme_color background)"
    text="$(theme_color foreground)"
    if [ -z "$bg" ] || [ -z "$text" ]; then
      echo "omarchy-plymouth-set-by-theme: no colors.toml in $theme_dir" >&2
      exit 1
    fi

    ${omarchySddmSync}/bin/omarchy-sddm-sync "$bg" "$text" "$theme_dir/unlock.png"
  '';

  omarchyPlymouthSet = pkgs.writeShellScriptBin "omarchy-plymouth-set" ''
    #!/bin/bash
    # NixOS shadow of omarchy-plymouth-set: recolor the SDDM greeter with
    # the given colors/logo (the Plymouth half is declarative on NixOS).
    set -eu
    bg_hex="''${1:?usage: omarchy-plymouth-set <background-hex> <text-hex> <logo.png>}"
    text_hex="''${2:?}"
    logo_path="''${3:?}"
    ${omarchySddmSync}/bin/omarchy-sddm-sync "$bg_hex" "$text_hex" "$logo_path"
  '';

  omarchyPlymouthReset = pkgs.writeShellScriptBin "omarchy-plymouth-reset" ''
    #!/bin/bash
    # NixOS shadow of omarchy-plymouth-reset: resync the greeter to the
    # active theme (Arch original resets Plymouth to its default theme).
    set -eu
    ${omarchySddmSync}/bin/omarchy-sddm-sync
  '';

  # NixOS shadow of omarchy-launch-webapp: upstream only supports
  # Chromium-family browsers (--app= app-window mode) and falls back to
  # chromium.desktop for anything else — which this config stubs away, so
  # uwsm-app is handed "--app=<url>" as the command ("Command not found").
  # The default browser here is Zen (Firefox-based — no --app mode), so
  # launch a new window instead. The desktop-file lookup also gains
  # /run/current-system/sw: upstream's {~/.local,~/.nix-profile,/usr} paths
  # are Arch-centric and find nothing on NixOS (zen.desktop lives in the
  # system profile). Lands inside ~/.local/share/omarchy/bin via the shadow
  # entry below.
  omarchyWebappLaunch = pkgs.writeShellScriptBin "omarchy-launch-webapp" ''
    #!/bin/bash

    # omarchy:summary=Launch a URL as a web app in the default supported browser
    # omarchy:args=<url>

    browser=$(xdg-settings get default-web-browser)

    case $browser in
    google-chrome* | brave* | microsoft-edge* | opera* | vivaldi* | helium*) ;;
    zen* | firefox*)
      exec setsid uwsm-app -- $(sed -n 's/^Exec=\([^ ]*\).*/\1/p' {~/.local,~/.nix-profile,/run/current-system/sw,/usr}/share/applications/$browser 2>/dev/null | head -1) --new-window "$1" "''${@:2}"
      ;;
    *) browser="chromium.desktop" ;;
    esac

    exec setsid uwsm-app -- $(sed -n 's/^Exec=\([^ ]*\).*/\1/p' {~/.local,~/.nix-profile,/run/current-system/sw,/usr}/share/applications/$browser 2>/dev/null | head -1) --app="$1" "''${@:2}"
  '';

  # System usage bar widget + unpinned-tray bar clone (see
  # docs/superpowers/specs/2026-08-20-system-usage-widget-design.md). The
  # stock bar unconditionally pins the tray to the inner edge of the right
  # section (BarModel.js pinTrayToInner), so nothing can render left of it;
  # the clone keeps the tray where shell.json puts it, letting the usage
  # widget float in the gap immediately left of the tray. The clone is a
  # fork of the flake input's bar — when bumping omarchy-nix, this derivation
  # re-copies + re-patches automatically (only the sed line must keep
  # matching upstream's pinTrayToInner).
  omarchyBarClone = pkgs.runCommand "omarchy-bar-clone" { } ''
    cp -r ${inputs.omarchy-nix}/shell/plugins/bar/. $out/
    chmod -R u+w $out
    ${pkgs.jq}/bin/jq --arg id "gjermund.bar" --arg name "My Bar" --arg sourceId "omarchy.bar" '
      .id = $id |
      .name = $name |
      .omarchy = ((.omarchy // {}) + { clonedFrom: $sourceId }) |
      del(.omarchy.clonePaths)
    ' "$out/manifest.json" > "$out/manifest.json.tmp"
    mv "$out/manifest.json.tmp" "$out/manifest.json"
    sed -i 's|if (section === "right") result.unshift(trayEntry)|if (false) result.unshift(trayEntry)  // gjermund.bar: tray pinning disabled — shell.json order wins|' "$out/BarModel.js"
    grep -q "tray pinning disabled" "$out/BarModel.js" \
      || { echo "pinTrayToInner patch failed to apply" >&2; exit 1; }
    # The host loads custom bars via Loader.source, which cannot satisfy
    # `required` root properties — the stock Bar.qml declares omarchyPath /
    # barWidgetRegistry / barConfig as required, so a cloned bar fails to
    # instantiate (and the shell's fallback handler itself throws, leaving
    # no bar at all). Default them instead: configureBar injects the real
    # values right after load, and Bar.qml already tolerates nulls
    # (fallbackBarConfig / registry binding re-evaluates on change).
    sed -i \
      -e 's#required property string omarchyPath#property string omarchyPath: Quickshell.env("OMARCHY_PATH") || ""#' \
      -e 's#required property var barWidgetRegistry#property var barWidgetRegistry: null#' \
      -e 's#required property var barConfig#property var barConfig: null#' \
      "$out/Bar.qml"
    grep -q "barWidgetRegistry: null" "$out/Bar.qml" \
      || { echo "Bar.qml required-props patch failed to apply" >&2; exit 1; }
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
        -- NVIDIA env + render tweaks (desktop only — the Prime laptop must
        -- not get GBM_BACKEND=nvidia-drm; see _common.nix)
        ${lib.optionalString (hostName == "desktop") nvidiaEnvLua}
      ''}

      -- Hyprland colors come from the omarchy theme system:
      -- default/hypr/omarchy.lua (shadow) requires
      -- omarchy.current.theme.hyprland, which reads the active theme's
      -- hyprland.lua. No user theme-colors require — the omarchy switcher
      -- owns colors here.

      ${mkLooknfeelConfig currentHost}

      -- NVIDIA render tweak (desktop only)
      ${lib.optionalString (hostName == "desktop") nvidiaRenderLua}

      ${animationsLua}

      ----------------------------------------------------------------
      -- Autostart (omarchy's shell owns notifications/network/wallpaper —
      -- swaync, nm-applet, awww are dropped; hypridle stays, its lock
      -- retargeted below)
      ----------------------------------------------------------------
      ${mkAutostartBlock}

      ${mkBindBlock {
        superL = ''hl.dsp.exec_cmd("omarchy-menu toggle system")'';
        superShiftB = ''hl.dsp.exec_cmd("omarchy-toggle-bar")'';
        superN = ''hl.dsp.exec_cmd("omarchy-shell notifications showHistory")'';
        # Theme machinery retargeted: the user's own theme-switcher /
        # wallpaper-picker don't apply — omarchy's do. The switchers only
        # print the pick; the -menu wrappers apply it (home.packages below),
        # mirroring the shell's own pickers.
        themeSwitcher = "omarchy-theme-menu";
        wallpaperPicker = "omarchy-bg-menu";
        extraBinds = ''
          -- Omarchy bridge binds (framework binds are off — see the shadow
          -- file below; omarchy features land on the free combos)
          hl.bind("SUPER + SPACE",     hl.dsp.exec_cmd("omarchy-menu toggle"))
          hl.bind("SUPER + Escape",    hl.dsp.exec_cmd("omarchy-menu toggle system"))
          hl.bind("SUPER + CTRL + L",  hl.dsp.exec_cmd("omarchy-system-lock"))
          hl.bind("PRINT",             hl.dsp.exec_cmd("omarchy-capture-screenshot"))
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
  # Portal: home-manager's hyprland module auto-enables its portal
  # integration via wayland.windowManager.hyprland.portalPackage (defaults to
  # the NIXPKGS xdg-desktop-portal-hyprland), which lands the nixpkgs build in
  # home.packages — dead weight, since the NixOS side already uses omarchy's
  # git build (portalPackage, mkForce'd in modules/omarchy.nix).
  # ─────────────────────────────────────────────────────────────────────────
  wayland.windowManager.hyprland.portalPackage = lib.mkForce null;
  # Same for the HM systemd integration (hyprland-session.target): uwsm owns
  # session management and omarchy's user services target
  # graphical-session.target, so nothing references it. Also silences the
  # "hyprland has no settings — almost certainly a mistake" warning (the
  # config is deliberately empty; hyprland.lua wins).
  wayland.windowManager.hyprland.systemd.enable = lib.mkForce false;

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

  # Clipboard: the omarchy clipboard plugin IS the clipboard stack (capture
  # watchers + history overlay, SUPER+V → omarchy-clipboard-open from the
  # shared bind block). vicinae/cliphist are gone. First-party built-ins are
  # enabled by default; if the plugin was ever disabled via
  # `omarchy plugin disable omarchy.clipboard` (shell.json disabledPlugins,
  # user-owned runtime state), re-enable it with
  # `omarchy plugin enable omarchy.clipboard`.

  # Shadow of $OMARCHY_PATH/default/hypr/windows.lua. The framework tags every
  # window with default-opacity and applies opacity 0.985/0.96 as a
  # WINDOWRULE; windowrules beat the decoration opacity config, so it fights
  # both the user's looknfeel (0.98/0.90) and gaming mode's 1.0. (Untagging
  # from hm.lua doesn't help — rules evaluate in order, so the opacity rule
  # matches before any later untag.) This copy drops the tag/opacity rules;
  # config opacity applies everywhere. Keep in sync with upstream when
  # bumping omarchy-nix.
  home.file.".config/default/hypr/windows.lua".text = ''
    -- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
    -- Shadow of $OMARCHY_PATH/default/hypr/windows.lua: default-opacity
    -- tag/rule removed (see omarchy-hm.nix).

    o.window(".*", { suppress_event = "maximize" })

    -- Fix some dragging issues with XWayland.
    o.window(
      {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
      },
      { no_focus = true }
    )

    -- App-specific tweaks.
    require("default.hypr.apps")
  '';

  # Pyprland scratchpads — kept on every host (pypr runs alongside omarchy's
  # shell; SUPER+Y/Shift+Y are part of the user's keybinding set in hm.lua)
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

  # Icons follow the active theme. Upstream does this via
  # omarchy-theme-set-gnome → `gsettings set ... icon-theme`, but this
  # NixOS system ships no gsettings-desktop-schemas, so every gsettings call
  # fails ("No schemas installed") and the icon theme silently stuck at
  # whatever base.nix last wrote (Papirus-Dark). dconf writes work
  # schema-free; the Yaru-* variants the themes reference are installed
  # system-wide via pkgs.yaru-theme (modules/omarchy.nix). Runs before
  # 90-sddm-sync (lexicographic hook order).
  home.file.".config/omarchy/hooks/theme-set.d/50-gnome-icons" = {
    executable = true;
    text = ''
      #!/bin/bash
      set -eu
      icons="$HOME/.local/state/omarchy/current/theme/icons.theme"
      [ -f "$icons" ] || exit 0
      name="$(cat "$icons")"
      [ -n "$name" ] || exit 0
      dconf write /org/gnome/desktop/interface/icon-theme "'$name'"
      # Qt/KDE reads the icon theme from the user's kdeglobals (per-key
      # override of the static /etc/xdg/kdeglobals in theming.nix) — keep it
      # in sync so Qt apps don't show Papirus while GTK shows the theme's
      # Yaru variant.
      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file "$HOME/.config/kdeglobals" --group Icons --key Theme "$name"
    '';
  };

  # Recolor the SDDM greeter on every theme switch (omarchy-theme-set →
  # omarchy-hook theme-set). The next login screen shows the new colors.
  home.file.".config/omarchy/hooks/theme-set.d/90-sddm-sync" = {
    executable = true;
    text = ''
      #!/bin/bash
      # Recolor the SDDM greeter (see omarchy-sddm-sync in home.packages).
      # Called by store path — the login-shell PATH is usually fine, but the
      # store path works from any context.
      ${omarchySddmSync}/bin/omarchy-sddm-sync
    '';
  };

  # ─────────────────────────────────────────────────────────────────────────
  # NixOS shadows of omarchy's Arch-only plymouth binaries — IN PLACE.
  # ─────────────────────────────────────────────────────────────────────────
  # The menu's "Unlock" picker (default/omarchy/omarchy-menu.jsonc →
  # omarchy-launch-floating-terminal-with-presentation → NON-LOGIN bash) runs
  # with the SESSION env: ~/.local/share/omarchy/bin is FIRST on that PATH and
  # ~/.local/bin isn't on it at all, so wrappers in ~/.local/bin never win
  # (verified via systemctl --user show-environment). The whole HM-managed
  # dir is therefore replaced with a patched copy of omarchy's bin/ where the
  # three Arch-only scripts are swapped for the NixOS wrappers (defined
  # above) — every context, session or login, resolves the wrappers.
  home.file.".local/share/omarchy/bin" = lib.mkForce {
    source = pkgs.runCommand "omarchy-bin-shadow" { } ''
      cp -r ${inputs.omarchy-nix}/bin/. $out/
      chmod -R u+w $out
      cp ${omarchyPlymouthSetByTheme}/bin/omarchy-plymouth-set-by-theme $out/
      cp ${omarchyPlymouthSet}/bin/omarchy-plymouth-set $out/
      cp ${omarchyPlymouthReset}/bin/omarchy-plymouth-reset $out/
      cp ${omarchyWebappLaunch}/bin/omarchy-launch-webapp $out/
      chmod +x $out/omarchy-plymouth-set-by-theme $out/omarchy-plymouth-set $out/omarchy-plymouth-reset $out/omarchy-launch-webapp
    '';
    recursive = true;
  };

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
    omarchySddmSync
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
  # ─────────────────────────────────────────────────────────────────────────
  home.activation.installMonitorsLua =
    lib.hm.dag.entryBetween
      [
        "seedMonitorsLua"
      ]
      [ "writeBoundary" ]
      ''
        monitors="$HOME/.config/hypr/monitors.lua"
        if [ ! -e "$monitors" ]; then
          run mkdir -p "$(dirname "$monitors")"
          run install -m644 ${pkgs.writeText "monitors.lua" monitorsLua} "$monitors"
        fi
      '';

  # Seed the SDDM greeter copy before sddm starts (the HM service runs before
  # systemd-user-sessions, which gates sddm). Runtime theme switches are
  # handled by the theme-set hook above.
  home.activation.syncSddmTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${omarchySddmSync}/bin/omarchy-sddm-sync
  '';

  # omarchy's copyScreensaverTxt runs BEFORE linkGeneration (module ordering
  # bug) — logo.txt/icon.txt are HM-linked files that only exist after the
  # home files are linked, so its unguarded cp fails the whole activation.
  # Redefined here to run after linkGeneration; the [ ! -f ] guards keep the
  # original "don't clobber user-edited branding" semantics.
  home.activation.copyScreensaverTxt = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    mkdir -p "$HOME/.config/omarchy/branding"
    if [ ! -f "$HOME/.config/omarchy/branding/screensaver.txt" ]; then
      cp "$HOME/.local/share/omarchy/logo.txt" "$HOME/.config/omarchy/branding/screensaver.txt"
    fi
    if [ ! -f "$HOME/.config/omarchy/branding/about.txt" ]; then
      cp "$HOME/.local/share/omarchy/icon.txt" "$HOME/.config/omarchy/branding/about.txt"
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
  # Tier 1: zsh — omarchy's zplug zsh owns .zshrc/.zshenv; the user's cargo
  # PATH line (.zshenv, rustup install) is carried over, and
  # zsh-syntax-highlighting comes back as a zplug plugin (last in the load
  # order, as it must be). The NixOS-side syntaxHighlighting toggle stays off
  # (modules/omarchy.nix) — its init would load before zplug and get
  # clobbered.
  # ─────────────────────────────────────────────────────────────────────────
  programs.zsh.envExtra = ''
    # Rust (rustup install)
    [[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
  '';
  # initContent is a MERGEABLE lines option — the zsh module composes .zshrc
  # from it at ordered priorities (compinit 570, autosuggestion 700, ...).
  # A mkForce here would drop ALL of those (that bug killed zplug and
  # completions); merge with ordering instead.
  #
  # The upstream fns loop (order 1000) sources every omarchy bash fn,
  # including worktrees — which defines bash functions named `ga`/`gd`. zsh
  # refuses to define a function over an alias ("defining function based on
  # alias"). Unaliasing doesn't help: zplug's oh-my-zsh git plugin re-adds
  # ga/gd mid-load. Disable alias EXPANSION while the fns load instead —
  # the function definitions parse cleanly, and afterwards every alias
  # (shell.nix's and zplug's) takes precedence over the shadowed functions.
  programs.zsh.initContent = lib.mkMerge [
    (lib.mkOrder 500 ''
      setopt no_aliases
    '')
    (lib.mkOrder 1500 ''
      setopt aliases
    '')
  ];
  programs.zsh.zplug.plugins = [
    {
      name = "zsh-users/zsh-syntax-highlighting";
      tags = [ ];
    }
  ];

  # ─────────────────────────────────────────────────────────────────────────
  # Tier 1: alacritty — omarchy's module sets JetBrainsMono at 9pt; the
  # user wants 14. The theme import (~/.local/state/omarchy/current/theme/
  # alacritty.toml) carries colors only, so the size here is not overridden.
  # ─────────────────────────────────────────────────────────────────────────
  programs.alacritty.settings.font.size = lib.mkForce 14;

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
    enable = true;
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

  home.file.".config/omarchy/plugins/gjermund.bar" = {
    source = omarchyBarClone;
    recursive = true;
  };

  home.file.".config/omarchy/plugins/local.system-usage/manifest.json".text = ''
    {
      "schemaVersion": 1,
      "id": "local.system-usage",
      "name": "System Usage",
      "version": "1.0.0",
      "author": "Gjermund",
      "description": "CPU, RAM and GPU utilization",
      "kinds": [ "bar-widget" ],
      "entryPoints": { "barWidget": "SystemUsage.qml" },
      "barWidget": {
        "displayName": "System Usage",
        "description": "CPU, RAM and GPU utilization",
        "category": "System",
        "defaultSection": "right",
        "allowMultiple": false
      }
    }
  '';

  home.file.".config/omarchy/plugins/local.system-usage/SystemUsage.qml".text = ''
    import QtQuick
    import Quickshell
    import Quickshell.Io
    import qs.Commons
    import qs.Ui

    BarWidget {
      id: root
      moduleName: "local.system-usage"

      readonly property int pollInterval: Number(setting("interval", 2000))
      readonly property int urgentThreshold: Number(setting("urgent", 90))

      property int cpuPercent: 0
      property var prevCpu: null
      property int ramPercent: 0
      property real ramUsedGb: 0
      property real ramTotalGb: 0
      property int gpuPercent: 0
      property string gpuModel: ""
      property string gpuVramText: ""
      property bool gpuUseSmi: true

      implicitWidth: layout.implicitWidth
      implicitHeight: layout.implicitHeight

      function refresh() {
        cpuFile.reload()
        memFile.reload()
        if (root.gpuUseSmi) {
          if (!gpuSmiProc.running) gpuSmiProc.running = true
        } else if (!gpuSysfsProc.running) {
          gpuSysfsProc.running = true
        }
      }

      // /proc/stat first line: cpu user nice system idle iowait irq softirq steal
      function onCpuRead(text) {
        var parts = String(text || "").split("\n")[0].trim().split(/\s+/)
        if (parts.length < 6 || parts[0] !== "cpu") return
        var busy = parseInt(parts[1], 10) + parseInt(parts[2], 10) + parseInt(parts[3], 10)
        var total = busy + parseInt(parts[4], 10) + parseInt(parts[5], 10)
        if (root.prevCpu && total > root.prevCpu.total) {
          var dTotal = total - root.prevCpu.total
          var dBusy = busy - root.prevCpu.busy
          root.cpuPercent = Math.max(0, Math.min(100, Math.round((dBusy * 100) / dTotal)))
        } else {
          root.cpuPercent = 0
        }
        root.prevCpu = { busy: busy, total: total }
      }

      // MemTotal/MemAvailable (zram-aware) — kB → GiB via 1048576
      function onMeminfoRead(text) {
        var total = 0
        var avail = 0
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
          var m = lines[i].match(/^(MemTotal|MemAvailable):\s+(\d+)/)
          if (!m) continue
          if (m[1] === "MemTotal") total = parseInt(m[2], 10)
          else avail = parseInt(m[2], 10)
        }
        if (!total) return
        var used = total - avail
        root.ramPercent = Math.round((used * 100) / total)
        root.ramUsedGb = used / 1048576
        root.ramTotalGb = total / 1048576
      }

      // nvidia-smi: "util%, memUsedMiB, memTotalMiB, name"
      function onSmiRead(text) {
        var line = String(text || "").split("\n")[0].trim()
        if (!line) {
          console.warn("system-usage: unexpected nvidia-smi output:", line)
          return
        }
        var parts = line.split(",")
        if (parts.length < 4) {
          console.warn("system-usage: unexpected nvidia-smi output:", line)
          return
        }
        var util = parseInt(parts[0].trim(), 10)
        var memUsed = parseFloat(parts[1].trim())
        var memTotal = parseFloat(parts[2].trim())
        if (!isFinite(util)) {
          console.warn("system-usage: unexpected nvidia-smi output:", line)
          root.gpuPercent = 0
        } else {
          root.gpuPercent = Math.max(0, Math.min(100, util))
        }
        root.gpuModel = parts[3].trim()
        if (isFinite(memUsed) && isFinite(memTotal) && memTotal > 0) {
          root.gpuVramText = Math.round(memUsed / 1024) + " / " + Math.round(memTotal / 1024) + " GiB"
        } else {
          root.gpuVramText = ""
        }
      }

      function onSmiFailed() {
        root.gpuUseSmi = false
        root.gpuModel = ""
        root.gpuVramText = ""
        refresh()
      }

      // Intel/AMD fallback (sikt): max gpu_busy_percent across cards
      function onSysfsRead(text) {
        var max = 0
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
          var n = parseInt(lines[i], 10)
          if (isFinite(n) && n > max) max = n
        }
        if (max === 0) console.warn("system-usage: no gpu_busy_percent values")
        root.gpuPercent = Math.max(0, Math.min(100, max))
      }

      function openMonitor() {
        if (root.bar) root.bar.run("pypr toggle btop")
      }

      FileView {
        id: cpuFile
        path: "/proc/stat"
        printErrors: false
        onLoaded: root.onCpuRead(text())
      }

      FileView {
        id: memFile
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: root.onMeminfoRead(text())
      }

      Process {
        id: gpuSmiProc
        command: [ "nvidia-smi", "--query-gpu=utilization.gpu,memory.used,memory.total,name", "--format=csv,noheader,nounits" ]
        stdout: StdioCollector {
          waitForEnd: true
          onStreamFinished: root.onSmiRead(text)
        }
        onExited: function(exitCode) {
          if (exitCode !== 0) root.onSmiFailed()
        }
      }

      Process {
        id: gpuSysfsProc
        command: [ "sh", "-c", "cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null" ]
        stdout: StdioCollector {
          waitForEnd: true
          onStreamFinished: root.onSysfsRead(text)
        }
      }

      Timer {
        interval: root.pollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
      }

      Loader {
        id: layout
        sourceComponent: root.vertical ? verticalLayout : horizontalLayout
      }

      Component {
        id: horizontalLayout
        Row {
          spacing: Style.space(1)
          CpuButton { }
          RamButton { }
          GpuButton { }
        }
      }

      Component {
        id: verticalLayout
        Column {
          spacing: Style.space(1)
          CpuButton { }
          RamButton { }
          GpuButton { }
        }
      }

      component CpuButton: WidgetButton {
        bar: root.bar
        text: "\uf2db  " + root.cpuPercent + "%"
        fontSize: Style.font.caption
        horizontalMargin: 5
        tooltipText: "CPU " + root.cpuPercent + "%"
        active: root.cpuPercent >= root.urgentThreshold
        onPressed: root.openMonitor()
      }

      component RamButton: WidgetButton {
        bar: root.bar
        text: "\uefc5  " + root.ramPercent + "%"
        fontSize: Style.font.caption
        horizontalMargin: 5
        tooltipText: "RAM " + root.ramUsedGb.toFixed(1) + " / " + root.ramTotalGb.toFixed(0) + " GiB (" + root.ramPercent + "%)"
        active: root.ramPercent >= root.urgentThreshold
        onPressed: root.openMonitor()
      }

      component GpuButton: WidgetButton {
        bar: root.bar
        // md-video is U+F0567 — 5 hex digits, needs the ES6 \u{...} form
        // (Qt QJSEngine supports it). Fallback if it renders wrong: put the
        // literal PUA character in the string instead.
        text: "\u{f0567}  " + root.gpuPercent + "%"
        fontSize: Style.font.caption
        horizontalMargin: 5
        tooltipText: {
          var t = "GPU " + root.gpuPercent + "%"
          if (root.gpuModel) t += " · " + root.gpuModel
          if (root.gpuVramText) t += " · " + root.gpuVramText
          return t
        }
        active: root.gpuPercent >= root.urgentThreshold
        onPressed: root.openMonitor()
      }
    }
  '';
}
