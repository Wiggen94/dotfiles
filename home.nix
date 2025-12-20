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

  # GTK theming - dark mode for GTK apps
  gtk = {
    enable = true;
    theme = {
      name = "Breeze-Dark";
      package = pkgs.kdePackages.breeze-gtk;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 24;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  # dconf settings - tells apps user prefers dark mode
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Breeze-Dark";
      icon-theme = "Papirus-Dark";
      cursor-theme = "Bibata-Modern-Ice";
    };
  };

  # Git configuration
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Gjermund Wiggen";
        email = "gjermund.wiggen@sikt.no";
        signingkey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDCFErYzeQDyksloDzmjx72vft5FYqiBW87Z7/nY70JSWIAfKz6970jCG1ObCKQ0kPMukY0pKrHJZVHAGOwRYTUtnF+7OAB26On5QNdphoJg1BVtRnNAfyQiV9DhsTzVQsGO/3+DI7EbhaaVNsY4kJEJjXmwu+KKxFAW8DObwpi/sKh5lyXQgNFupR8jork5g6XLAD77U3ZqrQXJfJtkVP0yOd9bUbbprLb0nAzwDLyLhXtSgbAexAN0nloqjU4S8CetiMQB3JWmA/8Uam7mxbOGV+u4yYPgjorlC1u6JOipO/os01MzHfcqrDMztk5kFCJy8mCNUTfu4kQVbVUrlyN";
      };
      gpg = {
        format = "ssh";
        ssh.program = "/run/current-system/sw/bin/op-ssh-sign";
      };
      commit.gpgsign = true;
    };
  };

  # Default applications
  xdg.configFile."mimeapps.list".force = true;
  xdg.mimeApps = {
    enable = true;
    associations.added = {
      # Archives - Ark
      "application/zip" = "org.kde.ark.desktop";
      "application/x-tar" = "org.kde.ark.desktop";
      "application/x-gzip" = "org.kde.ark.desktop";
      "application/x-bzip2" = "org.kde.ark.desktop";
      "application/x-xz" = "org.kde.ark.desktop";
      "application/x-7z-compressed" = "org.kde.ark.desktop";
      "application/x-rar" = "org.kde.ark.desktop";
      "application/x-compressed-tar" = "org.kde.ark.desktop";
      "application/x-bzip-compressed-tar" = "org.kde.ark.desktop";
      "application/x-xz-compressed-tar" = "org.kde.ark.desktop";
      # Images - Gwenview
      "image/png" = "org.kde.gwenview.desktop";
      "image/jpeg" = "org.kde.gwenview.desktop";
      "image/gif" = "org.kde.gwenview.desktop";
      "image/webp" = "org.kde.gwenview.desktop";
      "image/bmp" = "org.kde.gwenview.desktop";
      "image/svg+xml" = "org.kde.gwenview.desktop";
      "image/tiff" = "org.kde.gwenview.desktop";
    };
    defaultApplications = {
      # Archives - Ark
      "application/zip" = "org.kde.ark.desktop";
      "application/x-tar" = "org.kde.ark.desktop";
      "application/x-gzip" = "org.kde.ark.desktop";
      "application/x-bzip2" = "org.kde.ark.desktop";
      "application/x-xz" = "org.kde.ark.desktop";
      "application/x-7z-compressed" = "org.kde.ark.desktop";
      "application/x-rar" = "org.kde.ark.desktop";
      "application/x-compressed-tar" = "org.kde.ark.desktop";
      "application/x-bzip-compressed-tar" = "org.kde.ark.desktop";
      "application/x-xz-compressed-tar" = "org.kde.ark.desktop";
      # Images - Gwenview
      "image/png" = "org.kde.gwenview.desktop";
      "image/jpeg" = "org.kde.gwenview.desktop";
      "image/gif" = "org.kde.gwenview.desktop";
      "image/webp" = "org.kde.gwenview.desktop";
      "image/bmp" = "org.kde.gwenview.desktop";
      "image/svg+xml" = "org.kde.gwenview.desktop";
      "image/tiff" = "org.kde.gwenview.desktop";
    };
  };

  # KDE file type associations (filetypesrc)
  xdg.configFile."filetypesrc".text = ''
    [AddedAssociations]
    application/zip=org.kde.ark.desktop;
    application/x-7z-compressed=org.kde.ark.desktop;
    application/x-tar=org.kde.ark.desktop;
    application/x-compressed-tar=org.kde.ark.desktop;
    application/gzip=org.kde.ark.desktop;
    application/x-rar=org.kde.ark.desktop;
    image/png=org.kde.gwenview.desktop;
    image/jpeg=org.kde.gwenview.desktop;
    image/gif=org.kde.gwenview.desktop;
    image/webp=org.kde.gwenview.desktop;
  '';

  # Hyprland configuration
  xdg.configFile."hypr/hyprland.conf".text = ''
    # #######################################################################################
    # HYPRLAND CONFIG
    # #######################################################################################

    ################
    ### MONITORS ###
    ################

    monitor=,5120x1440@240,auto,1


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
    exec-once = wl-clip-persist --clipboard regular
    exec-once = hypridle
    exec-once = /run/current-system/sw/libexec/polkit-gnome-authentication-agent-1
    exec-once = nm-applet --indicator
    exec-once = notification-sound-daemon


    #############################
    ### ENVIRONMENT VARIABLES ###
    #############################

    env = XCURSOR_SIZE,24
    env = HYPRCURSOR_SIZE,24
    env = XCURSOR_THEME,Bibata-Modern-Ice
    env = SSH_ASKPASS_REQUIRE,prefer

    # Qt/KDE theming
    env = QT_QPA_PLATFORMTHEME,kde
    env = QT_STYLE_OVERRIDE,Breeze
    env = KDE_FULL_SESSION,true


    #####################
    ### LOOK AND FEEL ###
    #####################

    source = ~/.config/hypr/visuals-production.conf

    animations {
        enabled = true
        # Fast workspace switching (speed is in 100ms units)
        animation = workspaces, 1, 1, default, slide
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
    bind = $mainMod, V, exec, cliphist-paste

    # Screenshot snippet to clipboard (Super+P)
    bind = $mainMod, P, exec, screenshot

    # Power menu (Super+L)
    bind = $mainMod, L, exec, wlogout

    # Gaming mode toggle
    bind = $mainMod, G, exec, gaming-mode-toggle

    # Toggle HyprPanel visibility
    bind = $mainMod SHIFT, B, exec, hyprpanel t bar-0

    # Media keys
    bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
    bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bindl = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    bindl = , XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    bindl = , XF86AudioPlay, exec, playerctl play-pause
    bindl = , XF86AudioNext, exec, playerctl next
    bindl = , XF86AudioPrev, exec, playerctl previous

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
    # For NVIDIA RTX 5070 Ti with nvidia.nix enabled

    #############################
    ### NVIDIA-SPECIFIC SETTINGS
    #############################

    # NVIDIA environment variables (also set in nvidia.nix but Hyprland needs them too)
    env = LIBVA_DRIVER_NAME,nvidia
    env = XDG_SESSION_TYPE,wayland
    env = GBM_BACKEND,nvidia-drm
    env = __GLX_VENDOR_LIBRARY_NAME,nvidia

    # Hardware cursor settings for NVIDIA
    # Try with hardware cursors first (should work on modern NVIDIA drivers 555+)
    # If you see cursor issues, uncomment the line below:
    # cursor:no_hardware_cursors = true

    # Render settings for NVIDIA
    render {
        direct_scanout = false
    }

    ################
    ### VISUALS ###
    ################

    general {
        gaps_in = 6
        gaps_out = 12
        border_size = 2
        col.active_border = rgba(cba6f7ff) rgba(f5c2e7ff) 45deg
        col.inactive_border = rgba(313244aa)
        resize_on_border = true
        allow_tearing = true  # Enable for gaming (reduces input lag)
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
        vrr = 1  # Enable VRR/G-Sync (0=off, 1=on, 2=fullscreen only)
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
    "theme.font.size" = "1rem";
    "theme.bar.transparent" = true;
    "theme.bar.opacity" = 85;
    "theme.matugen" = false;
    "theme.bar.outer_spacing" = "6px";
    "theme.bar.buttons.radius" = "10px";
    "theme.bar.floating" = true;
    "theme.bar.margin_top" = "2px";
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

  # Hyprlock configuration (screen locker)
  xdg.configFile."hypr/hyprlock.conf".text = ''
    general {
        hide_cursor = true
        disable_loading_bar = true
    }

    background {
        monitor =
        color = rgb(1e1e2e)
    }

    input-field {
        monitor =
        size = 300, 50
        outline_thickness = 3
        dots_size = 0.25
        dots_spacing = 0.2
        dots_center = true
        outer_color = rgb(cba6f7)
        inner_color = rgb(313244)
        font_color = rgb(cdd6f4)
        fade_on_empty = false
        placeholder_text = <span foreground="##cdd6f4">Password...</span>
        hide_input = false
        position = 0, -50
        halign = center
        valign = center
        rounding = 10
    }

    label {
        monitor =
        text = $TIME
        color = rgb(cdd6f4)
        font_size = 72
        font_family = JetBrainsMono Nerd Font Bold
        position = 0, 100
        halign = center
        valign = center
    }

    label {
        monitor =
        text = cmd[update:60000] date +"%A, %B %d"
        color = rgb(cdd6f4)
        font_size = 20
        font_family = JetBrainsMono Nerd Font
        position = 0, 30
        halign = center
        valign = center
    }
  '';

  # Hypridle configuration (auto-lock, screen off)
  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
        lock_cmd = pidof hyprlock || hyprlock
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = hyprctl dispatch dpms on
    }

    # Turn off screen after 5 minutes
    listener {
        timeout = 300
        on-timeout = hyprctl dispatch dpms off
        on-resume = hyprctl dispatch dpms on
    }

    # Lock screen after 10 minutes
    listener {
        timeout = 600
        on-timeout = loginctl lock-session
    }
  '';

  # Wlogout configuration (power menu)
  xdg.configFile."wlogout/layout".text = ''
    {
        "label" : "lock",
        "action" : "hyprlock",
        "text" : "󰌾  Lock",
        "keybind" : "l"
    }
    {
        "label" : "logout",
        "action" : "hyprctl dispatch exit",
        "text" : "󰗼  Logout",
        "keybind" : "e"
    }
    {
        "label" : "suspend",
        "action" : "systemctl suspend",
        "text" : "󰒲  Suspend",
        "keybind" : "u"
    }
    {
        "label" : "hibernate",
        "action" : "systemctl hibernate",
        "text" : "󰋊  Hibernate",
        "keybind" : "h"
    }
    {
        "label" : "reboot",
        "action" : "systemctl reboot",
        "text" : "󰜉  Reboot",
        "keybind" : "r"
    }
    {
        "label" : "shutdown",
        "action" : "systemctl poweroff",
        "text" : "󰐥  Shutdown",
        "keybind" : "s"
    }
  '';

  # Wlogout style (Catppuccin Mocha theme)
  xdg.configFile."wlogout/style.css".text = ''
    * {
        background-image: none;
        font-family: "JetBrainsMono Nerd Font";
    }

    window {
        background-color: rgba(30, 30, 46, 0.9);
    }

    button {
        color: #cdd6f4;
        background-color: #313244;
        border-style: solid;
        border-width: 2px;
        border-color: #45475a;
        border-radius: 16px;
        margin: 10px;
        padding: 20px;
        font-size: 24px;
    }

    button:focus, button:active, button:hover {
        background-color: #45475a;
        border-color: #cba6f7;
        outline-style: none;
    }

    #lock:hover {
        border-color: #a6e3a1;
    }

    #logout:hover {
        border-color: #f9e2af;
    }

    #suspend:hover {
        border-color: #89b4fa;
    }

    #hibernate:hover {
        border-color: #94e2d5;
    }

    #reboot:hover {
        border-color: #fab387;
    }

    #shutdown:hover {
        border-color: #f38ba8;
    }
  '';

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
    size = 14.0

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
  #home.file.".p10k.zsh".text = builtins.readFile ./p10k.zsh;
}
