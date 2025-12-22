# Home Manager configuration shared between all hosts
# Monitor configuration is per-host based on hostName
{ config, pkgs, lib, inputs, hostName, ... }:

let
  # Per-host monitor configuration
  monitorConfig = {
    desktop = "monitor=,5120x1440@240,auto,1";
    laptop = "monitor=,2560x1440@60,auto,1";
  };

  # Per-host visuals configuration (laptop may want different VRR settings)
  vrr = if hostName == "laptop" then "0" else "1";  # Disable VRR on laptop by default
in
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
    font = {
      name = "Sans";
      size = 10;
    };
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
      font-name = "Sans 10";
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

  # Desktop entries
  xdg.desktopEntries.outlook = {
    name = "Outlook";
    comment = "Microsoft Outlook Web";
    exec = "outlook";
    icon = "internet-mail";
    terminal = false;
    categories = [ "Network" "Email" "Office" ];
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
      # Web browser - Zen
      "x-scheme-handler/http" = "zen.desktop";
      "x-scheme-handler/https" = "zen.desktop";
      "x-scheme-handler/about" = "zen.desktop";
      "x-scheme-handler/unknown" = "zen.desktop";
      "text/html" = "zen.desktop";
      "application/xhtml+xml" = "zen.desktop";
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

  # Hyprland configuration - with per-host monitor
  xdg.configFile."hypr/hyprland.conf".text = ''
    # #######################################################################################
    # HYPRLAND CONFIG
    # #######################################################################################

    ################
    ### MONITORS ###
    ################

    ${monitorConfig.${hostName} or "monitor=,preferred,auto,1"}


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
    exec-once = 1password
    exec-once = wl-paste --type text --watch cliphist store
    exec-once = wl-paste --type image --watch cliphist store
    exec-once = wl-clip-persist --clipboard regular
    exec-once = hypridle
    exec-once = /run/current-system/sw/libexec/polkit-gnome-authentication-agent-1
    exec-once = nm-applet --indicator
    exec-once = kdeconnect-indicator
    exec-once = notification-sound-daemon


    #############################
    ### ENVIRONMENT VARIABLES ###
    #############################

    env = XCURSOR_SIZE,24
    env = HYPRCURSOR_SIZE,24
    env = XCURSOR_THEME,Bibata-Modern-Ice
    env = SSH_ASKPASS_REQUIRE,prefer

    # Qt/KDE theming (KDE_FULL_SESSION removed - breaks xdg-open)
    env = QT_QPA_PLATFORMTHEME,kde
    env = QT_STYLE_OVERRIDE,Breeze
    env = BROWSER,zen


    #####################
    ### LOOK AND FEEL ###
    #####################

    source = ~/.config/hypr/visuals.conf

    animations {
        enabled = true

        # Bezier curves for smooth, natural motion
        bezier = smoothOut, 0.36, 0, 0.66, -0.56
        bezier = smoothIn, 0.25, 1, 0.5, 1
        bezier = overshot, 0.05, 0.9, 0.1, 1.1
        bezier = smoothSpring, 0.55, -0.15, 0.20, 1.3

        # Window animations
        animation = windowsIn, 1, 4, overshot, popin 80%
        animation = windowsOut, 1, 3, smoothOut, popin 80%
        animation = windowsMove, 1, 4, smoothSpring, slide

        # Fade animations
        animation = fadeIn, 1, 3, smoothIn
        animation = fadeOut, 1, 3, smoothOut
        animation = fadeSwitch, 1, 4, smoothIn
        animation = fadeDim, 1, 4, smoothIn

        # Border color animation
        animation = border, 1, 8, default
        animation = borderangle, 1, 30, smoothIn, loop

        # Workspace animations - slide with slight overshoot
        animation = workspaces, 1, 4, overshot, slide
        animation = specialWorkspace, 1, 4, smoothSpring, slidevert
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
            natural_scroll = true
            tap-to-click = true
            disable_while_typing = true
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

    # Media keys (with brightness for laptops)
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

    # World of Warcraft - tile instead of float
    windowrule = tile, title:^World of Warcraft$


    ###########################
    ### LAYER RULES (BLUR) ###
    ###########################

    # Fuzzel (app launcher) - blur background
    layerrule = blur, launcher
    layerrule = ignorealpha 0.3, launcher

    # Wlogout (power menu) - blur background
    layerrule = blur, logout_dialog
    layerrule = ignorealpha 0.3, logout_dialog

    # Notifications - blur background
    layerrule = blur, notifications
    layerrule = ignorealpha 0.3, notifications

    # HyprPanel and menus
    layerrule = blur, bar-0
    layerrule = ignorealpha 0.3, bar-0
    layerrule = blur, gtk-layer-shell
    layerrule = ignorealpha 0.3, gtk-layer-shell

    # Rofi/wofi (if used)
    layerrule = blur, rofi
    layerrule = ignorealpha 0.3, rofi
    layerrule = blur, wofi
    layerrule = ignorealpha 0.3, wofi
  '';

  xdg.configFile."hypr/visuals.conf".text = ''
    # Visual Settings for NVIDIA

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
        border_size = 3
        # Animated gradient border: purple -> pink -> blue (Catppuccin accent colors)
        col.active_border = rgba(cba6f7ff) rgba(f5c2e7ff) rgba(89b4faff) 45deg
        col.inactive_border = rgba(45475aaa)
        resize_on_border = true
        allow_tearing = true  # Enable for gaming (reduces input lag)
        layout = dwindle
    }

    decoration {
        rounding = 12
        active_opacity = 0.98
        inactive_opacity = 0.90

        # Dim inactive windows for better focus
        dim_inactive = true
        dim_strength = 0.12

        shadow {
            enabled = true
            range = 20
            render_power = 3
            color = rgba(11111bee)
            offset = 0 6
            scale = 1.0
        }

        blur {
            enabled = true
            size = 8
            passes = 3
            new_optimizations = true
            ignore_opacity = true
            xray = false
            noise = 0.02
            contrast = 1.0
            brightness = 1.0
            vibrancy = 0.3
            vibrancy_darkness = 0.2
            popups = true
            popups_ignorealpha = 0.2
        }
    }

    misc {
        force_default_wallpaper = 0
        disable_hyprland_logo = true
        background_color = rgba(1e1e2eff)
        vfr = true
        vrr = ${vrr}  # VRR/G-Sync (0=off, 1=on, 2=fullscreen only)
    }
  '';

  # HyprPanel configuration - copied instead of symlinked to avoid GIO symlink issues
  home.activation.hyprpanelConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ${config.xdg.configHome}/hyprpanel
    $DRY_RUN_CMD cp -f ${pkgs.writeText "hyprpanel-config.json" (builtins.toJSON {
      "bar.customModules.storage.paths" = [ "/" ];
      "menus.power.showLabel" = true;
      "bar.customModules.ram.label" = true;
      "theme.bar.buttons.modules.ram.enableBorder" = false;
      "scalingPriority" = "hyprland";
      "bar.workspaces.show_numbered" = true;
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
      "bar.bluetooth.enabled" = true;
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
          "right" = [ "systray" "bluetooth" "volume" ];
        };
      };
    })} ${config.xdg.configHome}/hyprpanel/config.json
    $DRY_RUN_CMD chmod 644 ${config.xdg.configHome}/hyprpanel/config.json
  '';

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
        "text" : "  Lock",
        "keybind" : "l"
    }
    {
        "label" : "logout",
        "action" : "hyprctl dispatch exit",
        "text" : "  Logout",
        "keybind" : "e"
    }
    {
        "label" : "suspend",
        "action" : "systemctl suspend",
        "text" : "  Suspend",
        "keybind" : "u"
    }
    {
        "label" : "hibernate",
        "action" : "systemctl hibernate",
        "text" : "  Hibernate",
        "keybind" : "h"
    }
    {
        "label" : "reboot",
        "action" : "systemctl reboot",
        "text" : "  Reboot",
        "keybind" : "r"
    }
    {
        "label" : "shutdown",
        "action" : "systemctl poweroff",
        "text" : "  Shutdown",
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

  # Fuzzel configuration - Catppuccin Mocha theme
  xdg.configFile."fuzzel/fuzzel.ini".text = ''
    [main]
    font=JetBrainsMono Nerd Font:size=12
    terminal=alacritty
    layer=overlay
    prompt="  "

    [colors]
    background=1e1e2edd
    text=cdd6f4ff
    match=f5c2e7ff
    selection=585b70ff
    selection-text=cdd6f4ff
    selection-match=f5c2e7ff
    border=cba6f7ff

    [border]
    width=2
    radius=10
  '';

  # Alacritty configuration
  xdg.configFile."alacritty/alacritty.toml".text = ''
    # Alacritty Configuration - Catppuccin Mocha Theme

    [terminal.shell]
    program = "/run/current-system/sw/bin/zsh"

    [window]
    opacity = 0.95
    padding = { x = 4, y = 4 }
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

  # Proton-GE auto-update service
  systemd.user.services.protonup = {
    Unit = {
      Description = "Update Proton-GE";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.protonup-ng}/bin/protonup";
      Environment = "PATH=${pkgs.coreutils}/bin";
    };
  };

  # Run on login and weekly
  systemd.user.timers.protonup = {
    Unit = {
      Description = "Update Proton-GE weekly and on login";
    };
    Timer = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1week";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
