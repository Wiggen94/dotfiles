{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should manage
  home.username = "gjermund";
  home.homeDirectory = "/home/gjermund";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  home.stateVersion = "25.11";

  # Suppress version mismatch warning (expected when using NixOS unstable with Home Manager master)
  home.enableNixpkgsReleaseCheck = false;

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # Hyprland configuration
  xdg.configFile."hypr/hyprland.conf".text = ''
    # #######################################################################################
    # HYPRLAND CONFIG
    # #######################################################################################

    ################
    ### MONITORS ###
    ################

    monitor=,3840x1440@60,auto,1.6


    ###################
    ### MY PROGRAMS ###
    ###################

    $terminal = alacritty
    $fileManager = dolphin
    $menu = fuzzel


    #################
    ### AUTOSTART ###
    #################

    exec-once = hyprpanel
    exec-once = 1password --silent
    exec-once = wl-paste --type text --watch cliphist store
    exec-once = wl-paste --type image --watch cliphist store


    #############################
    ### ENVIRONMENT VARIABLES ###
    #############################

    env = XCURSOR_SIZE,24
    env = HYPRCURSOR_SIZE,24
    env = XCURSOR_THEME,Bibata-Modern-Ice
    env = SSH_ASKPASS_REQUIRE,prefer


    #####################
    ### LOOK AND FEEL ###
    #####################

    source = ~/.config/hypr/visuals-vm.conf

    animations {
        enabled = false
    }

    dwindle {
        pseudotile = true
        preserve_split = true
    }

    master {
        new_status = master
    }


    #############
    ### INPUT ###
    #############

    input {
        kb_layout = no
        kb_variant =
        kb_model =
        kb_options =
        kb_rules =

        follow_mouse = 1
        sensitivity = 0

        touchpad {
            natural_scroll = false
        }
    }

    gesture = 3, horizontal, workspace

    device {
        name = epic-mouse-v1
        sensitivity = -0.5
    }


    ###################
    ### KEYBINDINGS ###
    ###################

    $mainMod = SUPER

    bind = $mainMod, T, exec, $terminal
    bind = $mainMod, B, exec, zen
    bind = $mainMod, Q, killactive,
    bind = $mainMod, M, exit,
    bind = $mainMod, E, exec, $fileManager
    bind = $mainMod, W, togglefloating,
    bind = $mainMod, F, fullscreen, 0
    bind = $mainMod, R, exec, $menu
    bind = $mainMod, A, exec, $menu
    bind = $mainMod, J, togglesplit,

    # Clipboard history (Super+V)
    bind = $mainMod, V, exec, cliphist list | fuzzel --dmenu | cliphist decode | wl-copy

    # Screenshot snippet to clipboard (Super+P)
    bind = $mainMod, P, exec, screenshot

    # Gaming mode
    bind = $mainMod, G, exec, hyprctl keyword decoration:blur:enabled false; hyprctl keyword animations:enabled false
    bind = $mainMod SHIFT, G, exec, hyprctl keyword decoration:blur:enabled true; hyprctl keyword animations:enabled true

    # Move focus
    bind = $mainMod, left, movefocus, l
    bind = $mainMod, right, movefocus, r
    bind = $mainMod, up, movefocus, u
    bind = $mainMod, down, movefocus, d

    # Workspaces
    bind = $mainMod, 1, workspace, 1
    bind = $mainMod, 2, workspace, 2
    bind = $mainMod, 3, workspace, 3
    bind = $mainMod, 4, workspace, 4
    bind = $mainMod, 5, workspace, 5
    bind = $mainMod, 6, workspace, 6
    bind = $mainMod, 7, workspace, 7
    bind = $mainMod, 8, workspace, 8
    bind = $mainMod, 9, workspace, 9
    bind = $mainMod, 0, workspace, 10

    # Move to workspace
    bind = $mainMod SHIFT, 1, movetoworkspace, 1
    bind = $mainMod SHIFT, 2, movetoworkspace, 2
    bind = $mainMod SHIFT, 3, movetoworkspace, 3
    bind = $mainMod SHIFT, 4, movetoworkspace, 4
    bind = $mainMod SHIFT, 5, movetoworkspace, 5
    bind = $mainMod SHIFT, 6, movetoworkspace, 6
    bind = $mainMod SHIFT, 7, movetoworkspace, 7
    bind = $mainMod SHIFT, 8, movetoworkspace, 8
    bind = $mainMod SHIFT, 9, movetoworkspace, 9
    bind = $mainMod SHIFT, 0, movetoworkspace, 10

    # Special workspace
    bind = $mainMod, S, togglespecialworkspace, magic
    bind = $mainMod SHIFT, S, movetoworkspace, special:magic

    # Mouse
    bind = $mainMod, mouse_down, workspace, e+1
    bind = $mainMod, mouse_up, workspace, e-1
    bindm = $mainMod, mouse:272, movewindow
    bindm = $mainMod, mouse:273, resizewindow

    # Media keys
    bindel = ,XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
    bindel = ,XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bindel = ,XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    bindel = ,XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    bindel = ,XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+
    bindel = ,XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-
    bindl = , XF86AudioNext, exec, playerctl next
    bindl = , XF86AudioPause, exec, playerctl play-pause
    bindl = , XF86AudioPlay, exec, playerctl play-pause
    bindl = , XF86AudioPrev, exec, playerctl previous


    ##############################
    ### WINDOWS AND WORKSPACES ###
    ##############################

    windowrule = suppressevent maximize, class:.*
    windowrule = nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0
  '';

  xdg.configFile."hypr/visuals-vm.conf".text = ''
    # VM Optimized Visual Settings - Minimal GPU usage

    general {
        gaps_in = 0
        gaps_out = 0
        border_size = 1
        col.active_border = rgba(cba6f7ff)
        col.inactive_border = rgba(313244aa)
        resize_on_border = false
        allow_tearing = false
        layout = dwindle
    }

    decoration {
        rounding = 0
        active_opacity = 1.0
        inactive_opacity = 1.0

        shadow {
            enabled = false
        }

        blur {
            enabled = false
        }
    }

    misc {
        force_default_wallpaper = 0
        disable_hyprland_logo = true
        disable_splash_rendering = true
        background_color = rgba(1e1e2eff)
        vfr = true
        vrr = 0
    }
  '';

  xdg.configFile."hypr/visuals-production.conf".text = ''
    # Production/Real Hardware Visual Settings - Maximum Beauty

    general {
        gaps_in = 6
        gaps_out = 12
        border_size = 2
        col.active_border = rgba(cba6f7ff) rgba(f5c2e7ff) 45deg
        col.inactive_border = rgba(313244aa)
        resize_on_border = true
        allow_tearing = false
        layout = dwindle
    }

    decoration {
        rounding = 12
        active_opacity = 0.98
        inactive_opacity = 0.92

        shadow {
            enabled = true
            range = 16
            render_power = 3
            color = rgba(11111bdd)
            offset = 0 4
        }

        blur {
            enabled = true
            size = 6
            passes = 3
            new_optimizations = true
            ignore_opacity = true
            noise = 0.02
            vibrancy = 0.25
        }
    }

    misc {
        force_default_wallpaper = 0
        disable_hyprland_logo = true
        background_color = rgba(1e1e2eff)
        vfr = true
    }
  '';

  # HyprPanel configuration
  xdg.configFile."hyprpanel/config.json".text = builtins.toJSON {
    "bar.customModules.storage.paths" = [ "/" ];
    "menus.power.showLabel" = true;
    "bar.customModules.ram.label" = true;
    "theme.bar.buttons.modules.ram.enableBorder" = false;
    "scalingPriority" = "hyprland";
    "bar.customModules.kbLayout.label" = true;
    "theme.bar.buttons.modules.updates.enableBorder" = false;
    "bar.customModules.updates.extendedTooltip" = false;
    "theme.font.size" = "0.8rem";
    "theme.bar.transparent" = true;
    "theme.bar.opacity" = 85;
    "theme.matugen" = false;
    "theme.bar.outer_spacing" = "6px";
    "theme.bar.buttons.radius" = "10px";
    "theme.bar.floating" = true;
    "theme.bar.margin_top" = "3px";
    "theme.bar.margin_sides" = "12px";
    "bar.customModules.netstat.dynamicIcon" = false;
    "menus.clock.time.military" = true;
    "menus.clock.time.hideSeconds" = true;
    "bar.clock.format" = "%H:%M";
    "menus.clock.weather.location" = "Trondheim";
    "menus.clock.weather.unit" = "metric";
    "menus.clock.calendar.weekStart" = "monday";
    "bar.bluetooth.enabled" = false;
    "wallpaper.enable" = false;
    "menus.dashboard.shortcuts.left.shortcut1.icon" = "";
    "menus.dashboard.shortcuts.left.shortcut1.command" = "";
    "menus.dashboard.shortcuts.left.shortcut2.icon" = "";
    "menus.dashboard.shortcuts.left.shortcut2.command" = "";
    "menus.dashboard.shortcuts.left.shortcut3.icon" = "";
    "menus.dashboard.shortcuts.left.shortcut3.command" = "";
    "menus.dashboard.shortcuts.left.shortcut4.icon" = "";
    "menus.dashboard.shortcuts.left.shortcut4.command" = "";
    "menus.dashboard.shortcuts.right.shortcut1.icon" = "";
    "menus.dashboard.shortcuts.right.shortcut1.command" = "";
    "menus.dashboard.shortcuts.right.shortcut3.icon" = "";
    "menus.dashboard.shortcuts.right.shortcut3.command" = "";
    "bar.layouts" = {
      "0" = {
        "left" = [ "dashboard" "workspaces" "windowtitle" ];
        "middle" = [ "clock" "notifications" ];
        "right" = [ "volume" "network" "systray" ];
      };
    };
  };

  # Alacritty configuration
  xdg.configFile."alacritty/alacritty.toml".text = ''
    # Alacritty Configuration - Catppuccin Mocha Theme

    [terminal.shell]
    program = "/run/current-system/sw/bin/zsh"

    [window]
    opacity = 0.95
    padding = { x = 12, y = 12 }
    decorations = "None"
    dynamic_padding = true

    [font]
    normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
    bold = { family = "JetBrainsMono Nerd Font", style = "Bold" }
    italic = { family = "JetBrainsMono Nerd Font", style = "Italic" }
    size = 11.0

    [cursor]
    style = { shape = "Block", blinking = "On" }
    blink_interval = 750

    [colors.primary]
    background = "#1e1e2e"
    foreground = "#cdd6f4"

    [colors.cursor]
    text = "#1e1e2e"
    cursor = "#f5e0dc"

    [colors.normal]
    black = "#45475a"
    red = "#f38ba8"
    green = "#a6e3a1"
    yellow = "#f9e2af"
    blue = "#89b4fa"
    magenta = "#cba6f7"
    cyan = "#94e2d5"
    white = "#bac2de"

    [colors.bright]
    black = "#585b70"
    red = "#f38ba8"
    green = "#a6e3a1"
    yellow = "#f9e2af"
    blue = "#89b4fa"
    magenta = "#cba6f7"
    cyan = "#94e2d5"
    white = "#a6adc8"
  '';

  # Powerlevel10k configuration
  home.file.".p10k.zsh".text = builtins.readFile ./p10k.zsh;
}
