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
in
{
  config = lib.mkMerge [
    # Omarchy owns the whole Hyprland/desktop stack on desktop (see
    # hosts/desktop/omarchy.nix) — this module is inert there. The user's
    # keybindings still apply on desktop via hosts/desktop/omarchy-hm.nix,
    # which reuses the same Lua fragments from _common.nix. (Keeping this
    # module out of the desktop eval also avoids the hard conflict between
    # configType "lua" here and the "hyprlang" one omarchy's HM module sets.)
    (lib.mkIf (hostName != "desktop") {
      # Hyprland configuration - Home Manager module
      wayland.windowManager.hyprland = {
        enable = true;
        configType = "lua";
        plugins = [ ];

        extraConfig = ''
          ${mkHyprVars currentHost}

          ----------------------------------------------------------------
          -- Monitors
          ----------------------------------------------------------------
          ${mkMonitorLuaCalls currentHost.monitor}

          ----------------------------------------------------------------
          -- Environment variables
          ----------------------------------------------------------------
          ${mkEnvBlock currentHost ""}

          ----------------------------------------------------------------
          -- Theme colors (hot-swappable via theme-switcher)
          ----------------------------------------------------------------
          require("theme-colors")

          ----------------------------------------------------------------
          -- Look and feel
          ----------------------------------------------------------------
          ${mkLooknfeelConfig currentHost}

          ${animationsLua}

          ----------------------------------------------------------------
          -- Autostart
          ----------------------------------------------------------------
          ${mkAutostartBlock { }}

          ${mkBindBlock { }}

          ${windowRulesLua}

          ----------------------------------------------------------------
          -- Layer rules (blur)
          ----------------------------------------------------------------
          ${layerRulesLua}
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
    })

    # Pyprland scratchpads — kept on every host, including desktop (pypr runs
    # alongside omarchy's shell; SUPER+Y/Shift+Y are part of the user's
    # keybinding set ported into hm.lua there)
    {
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
    }
  ];
}
