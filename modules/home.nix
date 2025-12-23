# Home Manager configuration shared between all hosts
# Monitor configuration is per-host based on hostName
{ config, pkgs, lib, inputs, hostName, ... }:

let
  # Import centralized color palette
  colors = import ../colors.nix;

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
      name = "Noto Sans";
      size = 10;
    };
    theme = {
      name = "catppuccin-mocha-mauve-standard";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "mauve" ];
        variant = "mocha";
      };
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
      gtk-theme = "catppuccin-mocha-mauve-standard";
      icon-theme = "Papirus-Dark";
      cursor-theme = "Bibata-Modern-Ice";
      font-name = "Noto Sans 10";
      monospace-font-name = "JetBrainsMono Nerd Font 10";
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

  # Override default BOINC Manager to use ~/boinc data directory
  xdg.desktopEntries.boincmgr = {
    name = "BOINC Manager";
    comment = "BOINC distributed computing manager";
    exec = "boinc-manager";
    icon = "boincmgr";
    terminal = false;
    categories = [ "System" "Utility" ];
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
      # Text files - VS Code
      "text/plain" = "code.desktop";
      "text/x-readme" = "code.desktop";
      "text/markdown" = "code.desktop";
      "text/x-log" = "code.desktop";
      "application/json" = "code.desktop";
      "application/xml" = "code.desktop";
      "application/x-yaml" = "code.desktop";
      "text/x-python" = "code.desktop";
      "text/x-shellscript" = "code.desktop";
      "text/x-c" = "code.desktop";
      "text/x-c++src" = "code.desktop";
      "text/x-java" = "code.desktop";
      "application/javascript" = "code.desktop";
      "application/x-nix" = "code.desktop";
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

  # Teams for Linux - Catppuccin Mocha theme
  xdg.configFile."teams-for-linux/config.json".text = builtins.toJSON {
    followSystemTheme = true;
    customCSSLocation = "${config.home.homeDirectory}/.config/teams-for-linux/catppuccin.css";
  };

  xdg.configFile."teams-for-linux/catppuccin.css".text = ''
    /* Catppuccin Mocha theme for Microsoft Teams */
    /* Using colors from colors.nix for consistency */

    /* ===== GLOBAL BACKGROUNDS ===== */
    /* Root and body */
    html, body, #app,
    .fui-FluentProvider,
    [data-tid="app-layout"] {
      background-color: ${colors.crust} !important;
    }

    /* ===== LEFT SIDEBAR / CHAT LIST ===== */
    /* Main sidebar container */
    .left-rail,
    .ts-left-rail,
    .left-rail-list,
    [data-tid="left-rail"],
    [data-tid="chat-list"],
    [data-tid="lr-thread-list"],
    .fui-Tree,
    nav[role="navigation"],
    aside {
      background-color: ${colors.crust} !important;
    }

    /* Sidebar header and top panel */
    .left-rail-header,
    [data-tid="left-rail-header"],
    [data-tid="chat-list-header"],
    [data-tid="team-channel-list-header"] {
      background-color: ${colors.crust} !important;
    }

    /* Sidebar outer frame / wrapper */
    .left-rail-wrapper,
    .left-rail-container,
    [data-tid="left-rail-wrapper"],
    [data-tid="chat-pane-list"],
    .fui-SplitPane,
    .fui-SplitPane__primary,
    [class*="leftRail"],
    [class*="LeftRail"],
    [class*="left-rail"],
    [class*="chatList"],
    [class*="ChatList"] {
      background-color: ${colors.crust} !important;
    }

    /* Secondary/nested panels */
    .secondary-panel,
    [data-tid="secondary-panel"],
    [data-tid="roster-panel"],
    .roster-panel {
      background-color: ${colors.crust} !important;
    }

    /* Individual chat items in sidebar */
    .ts-left-rail-tree,
    .left-rail-item,
    [data-tid="left-rail-item"],
    .fui-TreeItem,
    .fui-TreeItemLayout {
      background-color: ${colors.crust} !important;
    }

    /* Sidebar item hover */
    .left-rail-item:hover,
    [data-tid="left-rail-item"]:hover,
    .fui-TreeItem:hover,
    .fui-TreeItemLayout:hover {
      background-color: ${colors.surface0} !important;
    }

    /* Sidebar item selected */
    .left-rail-selected,
    .left-rail-item--selected,
    [aria-selected="true"],
    .fui-TreeItem[aria-selected="true"] {
      background-color: ${colors.surface0} !important;
    }

    /* ===== TOP BAR / APP HEADER ===== */
    .app-bar-items,
    .app-header-bar,
    .app-header,
    [data-tid="app-header"],
    .ui-grid {
      background-color: ${colors.crust} !important;
    }

    /* Top bar container and wrapper */
    .app-header-bar-content,
    .ts-title-bar,
    [data-tid="title-bar"],
    [data-tid="app-header-bar"],
    [class*="titleBar"],
    [class*="TitleBar"],
    [class*="appHeader"],
    [class*="AppHeader"] {
      background-color: ${colors.crust} !important;
      border-color: ${colors.surface0} !important;
    }

    /* Navigation buttons */
    .app-header-bar button,
    .ts-title-bar button,
    [data-tid="app-header"] button,
    .fui-Button,
    [class*="navButton"],
    [class*="NavButton"] {
      background-color: transparent !important;
      border-color: transparent !important;
    }

    /* Navigation button hover */
    .app-header-bar button:hover,
    .fui-Button:hover {
      background-color: ${colors.surface0} !important;
    }

    /* Search bar */
    .ts-header-search,
    [data-tid="search-box"],
    [data-tid="searchbox"],
    .fui-SearchBox,
    .fui-Input__input,
    [class*="searchBox"],
    [class*="SearchBox"] {
      background-color: ${colors.mantle} !important;
      border-color: ${colors.surface0} !important;
    }

    /* Remove black borders globally */
    .app-header-bar *,
    .ts-title-bar * {
      border-color: ${colors.surface0} !important;
    }

    /* ===== MAIN CHAT AREA ===== */
    /* Chat background - darker */
    .ui-chat,
    .ui-divider,
    .menu-open,
    .chat-pane,
    [data-tid="chat-pane"],
    [data-tid="message-pane"],
    #message-pane-layout-a11y {
      background-color: ${colors.mantle} !important;
    }

    /* Chat message bubbles */
    .ui-chat__message {
      background-color: ${colors.surface0} !important;
      border-radius: 8px !important;
      margin: 4px 0 !important;
      width: fit-content !important;
    }

    /* Own messages - slightly different shade */
    .ui-chat__message--mine {
      background-color: ${colors.surface1} !important;
    }

    /* Message hover */
    .ui-chat__message:hover {
      background-color: ${colors.surface1} !important;
    }

    /* Message header area */
    .app-messages-header,
    [data-tid="chat-header"] {
      background-color: ${colors.mantle} !important;
    }

    /* ===== FLUENT UI COMPONENTS ===== */
    div.fui-Flex {
      background-color: ${colors.mantle} !important;
    }

    .fui-Input,
    .fui-Textarea {
      background-color: ${colors.surface0} !important;
    }

    /* ===== INTERACTIVE ELEMENTS ===== */
    .afu,
    .ts-btn-fluent.ts-btn-fluent-split,
    .cle-item:hover,
    .ui-box.yr.hb.bdh {
      background-color: ${colors.surface2} !important;
    }

    /* ===== CODE BLOCKS ===== */
    pre.language-plaintextskipProofing,
    code {
      background-color: ${colors.base} !important;
      font-family: "${colors.fonts.monospace}" !important;
    }

    pre.ui-box,
    .abr .ck.ck-editor__editable,
    .ys,
    .yf,
    tr {
      background-color: ${colors.surface0} !important;
    }

    /* ===== ACCENT COLORS ===== */
    .app-bar-app-header-bar-common .activity-badge,
    .ui-alert,
    div[id*="alert-body"] {
      background-color: ${colors.red} !important;
      color: ${colors.crust} !important;
    }

    /* Status indicator */
    .ts-sym .ts-left-rail .status-mask {
      background-color: ${colors.green} !important;
    }

    /* ===== SEARCH BAR ===== */
    .app-top-power-bar .ts-header-search,
    [data-tid="search-container"] {
      background-color: ${colors.mantle} !important;
    }

    /* ===== CHAT TABS ===== */
    .fui-Tab,
    .fui-TabList,
    [role="tablist"],
    [role="tab"],
    .ts-tab,
    .ts-tab-item,
    [data-tid="chat-tab"],
    [data-tid="channel-tab"] {
      background-color: transparent !important;
    }

    /* Tab text - remove black background/underline */
    .fui-Tab__content,
    .fui-Tab span,
    [role="tab"] span,
    .ts-tab span {
      background-color: transparent !important;
      text-decoration: none !important;
      box-shadow: none !important;
    }

    /* Selected tab indicator - use accent color */
    .fui-Tab[aria-selected="true"]::after,
    .fui-Tab--selected::after,
    [role="tab"][aria-selected="true"]::after {
      background-color: ${colors.mauve} !important;
    }

    /* Tab hover */
    .fui-Tab:hover,
    [role="tab"]:hover {
      background-color: ${colors.surface0} !important;
    }

    /* ===== TEXT STYLING ===== */
    .cle-title {
      font-weight: bold;
    }

    /* ===== COMPOSE BOX ===== */
    .ts-new-message,
    .cke_editable,
    [data-tid="compose-box"],
    [data-tid="ckeditor"] {
      background-color: ${colors.surface0} !important;
    }

    /* ===== SCROLLBARS ===== */
    ::-webkit-scrollbar {
      width: 8px;
      height: 8px;
    }
    ::-webkit-scrollbar-track {
      background: ${colors.crust};
    }
    ::-webkit-scrollbar-thumb {
      background: ${colors.surface2};
      border-radius: 4px;
    }
    ::-webkit-scrollbar-thumb:hover {
      background: ${colors.overlay0};
    }
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

    exec-once = waybar
    exec-once = swaync
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
        bezier = fluent, 0.0, 0.0, 0.2, 1.0
        bezier = snappy, 0.4, 0.0, 0.2, 1.0
        bezier = easeOutExpo, 0.16, 1, 0.3, 1

        # Window animations - polished feel
        animation = windowsIn, 1, 4, overshot, popin 80%
        animation = windowsOut, 1, 3, smoothOut, popin 80%
        animation = windowsMove, 1, 4, fluent, slide

        # Fade animations
        animation = fadeIn, 1, 3, smoothIn
        animation = fadeOut, 1, 3, smoothOut
        animation = fadeSwitch, 1, 4, smoothIn
        animation = fadeDim, 1, 4, smoothIn
        animation = fadeLayers, 1, 3, easeOutExpo

        # Border color animation - smooth gradient rotation
        animation = border, 1, 8, default
        animation = borderangle, 1, 50, smoothIn, loop

        # Workspace animations - slide with slight overshoot
        animation = workspaces, 1, 5, easeOutExpo, slide
        animation = specialWorkspace, 1, 4, smoothSpring, slidevert

        # Layer animations (notifications, menus, etc.)
        animation = layers, 1, 3, snappy, popin 90%
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
    bind = $mainMod, C, exec, qalculate-gtk
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

    # Toggle Waybar visibility
    bind = $mainMod SHIFT, B, exec, pkill -SIGUSR1 waybar

    # Toggle notification center (swaync)
    bind = $mainMod, N, exec, swaync-client -t -sw

    # Media keys (with sound feedback)
    bindel = , XF86AudioRaiseVolume, exec, volume-up
    bindel = , XF86AudioLowerVolume, exec, volume-down
    bindl = , XF86AudioMute, exec, volume-mute
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

    # Media keys (with brightness for laptops, sound feedback)
    bindel = ,XF86AudioRaiseVolume, exec, volume-up
    bindel = ,XF86AudioLowerVolume, exec, volume-down
    bindel = ,XF86AudioMute, exec, volume-mute
    bindel = ,XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    bindel = ,XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+
    bindel = ,XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-
    bindl = , XF86AudioNext, exec, playerctl next
    bindl = , XF86AudioPause, exec, playerctl play-pause
    bindl = , XF86AudioPlay, exec, playerctl play-pause
    bindl = , XF86AudioPrev, exec, playerctl previous

    # Resize windows (Super+Shift+arrows)
    binde = $mainMod SHIFT, left, resizeactive, -30 0
    binde = $mainMod SHIFT, right, resizeactive, 30 0
    binde = $mainMod SHIFT, up, resizeactive, 0 -30
    binde = $mainMod SHIFT, down, resizeactive, 0 30

    # Move windows (Super+Ctrl+arrows)
    bind = $mainMod CTRL, left, movewindow, l
    bind = $mainMod CTRL, right, movewindow, r
    bind = $mainMod CTRL, up, movewindow, u
    bind = $mainMod CTRL, down, movewindow, d

    # Quick window actions
    bind = $mainMod, Tab, cyclenext,
    bind = $mainMod SHIFT, Tab, cyclenext, prev


    ##############################
    ### WINDOWS AND WORKSPACES ###
    ##############################

    windowrule = suppressevent maximize, class:.*
    windowrule = nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0

    # Calculator - float and center
    windowrulev2 = float, class:^(qalculate-gtk)$
    windowrulev2 = size 400 500, class:^(qalculate-gtk)$
    windowrulev2 = center, class:^(qalculate-gtk)$

    # Zen Browser - never dim
    windowrulev2 = nodim, class:zen

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

    # Waybar
    layerrule = blur, waybar
    layerrule = ignorealpha 0.3, waybar
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
        # Animated gradient border: mauve -> pink -> blue (Catppuccin accent colors)
        col.active_border = ${colors.rgba.mauve} ${colors.rgba.pink} ${colors.rgba.blue} 45deg
        col.inactive_border = ${colors.transparent.surface1_67}
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
        dim_strength = 0.15
        dim_special = 0.3

        shadow {
            enabled = true
            range = 25
            render_power = 3
            color = ${colors.transparent.crust_93}
            color_inactive = rgba(11111b99)
            offset = 0 8
            scale = 1.0
        }

        blur {
            enabled = true
            size = 10
            passes = 4
            new_optimizations = true
            ignore_opacity = true
            xray = false
            noise = 0.015
            contrast = 1.0
            brightness = 1.0
            vibrancy = 0.4
            vibrancy_darkness = 0.3
            popups = true
            popups_ignorealpha = 0.2
            special = true
        }
    }

    misc {
        force_default_wallpaper = 0
        disable_hyprland_logo = true
        background_color = ${colors.rgba.base}
        vfr = true
        vrr = ${vrr}  # VRR/G-Sync (0=off, 1=on, 2=fullscreen only)
    }
  '';

  # Waybar configuration
  xdg.configFile."waybar/config".text = builtins.toJSON {
    layer = "top";
    position = "top";
    height = 38;
    margin-top = 4;
    margin-left = 8;
    margin-right = 8;
    spacing = 4;

    modules-left = [ "hyprland/workspaces" "hyprland/window" ];
    modules-center = [ "clock" "custom/swaync" ];
    modules-right = [ "tray" "network" "bluetooth" "pulseaudio" ];

    "custom/launcher" = {
      format = " ";
      tooltip = false;
      on-click = "fuzzel";
    };

    "hyprland/workspaces" = {
      format = "{id}";
    };

    "hyprland/window" = {
      format = "{}";
      max-length = 50;
      separate-outputs = true;
      icon = true;
      icon-size = 18;
    };

    clock = {
      format = "{:%H:%M}";
      format-alt = "{:%A, %B %d, %Y}";
      tooltip-format = "<tt><small>{calendar}</small></tt>";
      calendar = {
        mode = "month";
        mode-mon-col = 3;
        weeks-pos = "right";
        format = {
          months = "<span color='${colors.text}'><b>{}</b></span>";
          days = "<span color='${colors.subtext0}'>{}</span>";
          weeks = "<span color='${colors.mauve}'><b>W{}</b></span>";
          weekdays = "<span color='${colors.peach}'><b>{}</b></span>";
          today = "<span color='${colors.mauve}'><b><u>{}</u></b></span>";
        };
      };
    };

    "custom/swaync" = {
      tooltip = false;
      format = "{icon}";
      format-icons = {
        notification = "󰂚";
        none = "󰂜";
        dnd-notification = "󰂛";
        dnd-none = "󰪑";
        inhibited-notification = "󰂛";
        inhibited-none = "󰂜";
        dnd-inhibited-notification = "󰂛";
        dnd-inhibited-none = "󰪑";
      };
      return-type = "json";
      exec-if = "which swaync-client";
      exec = "swaync-client -swb";
      on-click = "swaync-client -t -sw";
      on-click-right = "swaync-client -C";
      escape = true;
    };

    tray = {
      spacing = 8;
      icon-size = 16;
    };

    network = {
      format-wifi = "󰤨 {essid}";
      format-ethernet = "󰈀 {ipaddr}";
      format-disconnected = "󰤭 ";
      tooltip-format-wifi = "{essid} ({signalStrength}%)\n{ipaddr}";
      tooltip-format-ethernet = "{ifname}\n{ipaddr}";
      on-click = "nm-connection-editor";
    };

    bluetooth = {
      format = "󰂯";
      format-disabled = "󰂲";
      format-connected = "󰂱 {num_connections}";
      tooltip-format = "{controller_alias}\t{controller_address}";
      tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{device_enumerate}";
      tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
      on-click = "blueman-manager";
    };

    pulseaudio = {
      format = "{icon} {volume}%";
      format-muted = "󰝟 ";
      format-icons = {
        default = [ "󰕿" "󰖀" "󰕾" ];
        headphone = "󰋋";
        headset = "󰋎";
      };
      tooltip-format = "{desc}\n{volume}%";
      on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      on-click-right = "pavucontrol";
      on-scroll-up = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
      on-scroll-down = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
    };
  };

  # Waybar CSS styling - Catppuccin Mocha theme
  xdg.configFile."waybar/style.css".text = ''
    /* Catppuccin Mocha Waybar Theme */
    @define-color base ${colors.base};
    @define-color mantle ${colors.mantle};
    @define-color crust ${colors.crust};
    @define-color surface0 ${colors.surface0};
    @define-color surface1 ${colors.surface1};
    @define-color surface2 ${colors.surface2};
    @define-color overlay0 ${colors.overlay0};
    @define-color text ${colors.text};
    @define-color subtext0 ${colors.subtext0};
    @define-color mauve ${colors.mauve};
    @define-color pink ${colors.pink};
    @define-color red ${colors.red};
    @define-color peach ${colors.peach};
    @define-color yellow ${colors.yellow};
    @define-color green ${colors.green};
    @define-color blue ${colors.blue};
    @define-color teal ${colors.teal};

    * {
      font-family: "JetBrainsMono Nerd Font";
      font-size: 14px;
      min-height: 0;
      border: none;
      border-radius: 0;
    }

    window#waybar {
      background: alpha(@base, 0.85);
      border-radius: 12px;
      border: none;
    }

    window#waybar.hidden {
      opacity: 0;
    }

    tooltip {
      background: @base;
      border: 2px solid @surface1;
      border-radius: 12px;
    }

    tooltip label {
      color: @text;
      padding: 4px;
    }

    /* Module styling */
    #custom-launcher,
    #workspaces,
    #window,
    #clock,
    #custom-swaync,
    #tray,
    #network,
    #bluetooth,
    #pulseaudio {
      background: @surface0;
      color: @text;
      border-radius: 12px;
      padding: 4px 12px;
      margin: 4px 2px;
    }

    /* Launcher button */
    #custom-launcher {
      color: @mauve;
      font-size: 18px;
      padding: 4px 14px;
    }

    #custom-launcher:hover {
      background: @surface1;
    }

    /* Workspaces */
    #workspaces {
      padding: 4px 6px;
    }

    #workspaces button {
      color: @text;
      background: transparent;
      padding: 2px 8px;
      margin: 0 2px;
      border-radius: 8px;
      min-width: 20px;
    }

    #workspaces button:hover {
      background: @surface1;
    }

    #workspaces button.empty {
      color: @overlay0;
    }

    #workspaces button.active {
      background: @mauve;
      color: @base;
    }

    #workspaces button.urgent {
      background: @red;
      color: @base;
    }

    /* Window title */
    #window {
      color: @text;
    }

    window#waybar.empty #window {
      background: transparent;
    }

    /* Clock */
    #clock {
      color: @text;
    }

    /* Notification center */
    #custom-swaync {
      color: @mauve;
      font-size: 16px;
      padding: 4px 10px;
    }

    #custom-swaync:hover {
      background: @surface1;
    }

    /* Tray */
    #tray {
      padding: 4px 8px;
    }

    #tray > .passive {
      -gtk-icon-effect: dim;
    }

    #tray > .needs-attention {
      -gtk-icon-effect: highlight;
    }

    /* Network */
    #network {
      color: @blue;
    }

    #network.disconnected {
      color: @red;
    }

    /* Bluetooth */
    #bluetooth {
      color: @blue;
    }

    #bluetooth.disabled {
      color: @overlay0;
    }

    #bluetooth.connected {
      color: @green;
    }

    /* Audio */
    #pulseaudio {
      color: @mauve;
    }

    #pulseaudio.muted {
      color: @overlay0;
    }

    /* Hover effects */
    #clock:hover,
    #network:hover,
    #bluetooth:hover,
    #pulseaudio:hover,
    #tray:hover {
      background: @surface1;
    }
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

  # btop configuration - Catppuccin Mocha theme
  xdg.configFile."btop/btop.conf".text = ''
    color_theme = "catppuccin_mocha"
    theme_background = True
    vim_keys = True
  '';

  xdg.configFile."btop/themes/catppuccin_mocha.theme".text = ''
    # Catppuccin Mocha theme for btop
    # https://github.com/catppuccin/btop

    theme[main_bg]="${colors.base}"
    theme[main_fg]="${colors.text}"
    theme[title]="${colors.text}"
    theme[hi_fg]="${colors.blue}"
    theme[selected_bg]="${colors.surface1}"
    theme[selected_fg]="${colors.blue}"
    theme[inactive_fg]="${colors.overlay1}"
    theme[graph_text]="${colors.rosewater}"
    theme[meter_bg]="${colors.surface1}"
    theme[proc_misc]="${colors.rosewater}"
    theme[cpu_box]="${colors.mauve}"
    theme[mem_box]="${colors.green}"
    theme[net_box]="${colors.maroon}"
    theme[proc_box]="${colors.blue}"
    theme[div_line]="${colors.overlay0}"
    theme[temp_start]="${colors.green}"
    theme[temp_mid]="${colors.yellow}"
    theme[temp_end]="${colors.red}"
    theme[cpu_start]="${colors.teal}"
    theme[cpu_mid]="${colors.sapphire}"
    theme[cpu_end]="${colors.lavender}"
    theme[free_start]="${colors.mauve}"
    theme[free_mid]="${colors.lavender}"
    theme[free_end]="${colors.blue}"
    theme[cached_start]="${colors.sapphire}"
    theme[cached_mid]="${colors.blue}"
    theme[cached_end]="${colors.lavender}"
    theme[available_start]="${colors.peach}"
    theme[available_mid]="${colors.maroon}"
    theme[available_end]="${colors.red}"
    theme[used_start]="${colors.green}"
    theme[used_mid]="${colors.teal}"
    theme[used_end]="${colors.sky}"
    theme[download_start]="${colors.peach}"
    theme[download_mid]="${colors.maroon}"
    theme[download_end]="${colors.red}"
    theme[upload_start]="${colors.green}"
    theme[upload_mid]="${colors.teal}"
    theme[upload_end]="${colors.sky}"
    theme[process_start]="${colors.sapphire}"
    theme[process_mid]="${colors.lavender}"
    theme[process_end]="${colors.mauve}"
  '';

  # lazygit configuration - Catppuccin Mocha theme
  xdg.configFile."lazygit/config.yml".text = ''
    # Catppuccin Mocha theme for lazygit
    # https://github.com/catppuccin/lazygit
    gui:
      nerdFontsVersion: "3"
      theme:
        activeBorderColor:
          - "${colors.blue}"
          - bold
        inactiveBorderColor:
          - "${colors.subtext0}"
        optionsTextColor:
          - "${colors.blue}"
        selectedLineBgColor:
          - "${colors.surface0}"
        cherryPickedCommitBgColor:
          - "${colors.surface1}"
        cherryPickedCommitFgColor:
          - "${colors.blue}"
        unstagedChangesColor:
          - "${colors.red}"
        defaultFgColor:
          - "${colors.text}"
        searchingActiveBorderColor:
          - "${colors.yellow}"
      authorColors:
        "*": "${colors.lavender}"
  '';

  # Alacritty configuration - Official Catppuccin Mocha theme
  xdg.configFile."alacritty/alacritty.toml".text = ''
    # Alacritty Configuration - Catppuccin Mocha Theme
    # https://github.com/catppuccin/alacritty

    [terminal.shell]
    program = "/run/current-system/sw/bin/zsh"

    [window]
    opacity = 0.95
    padding = { x = 4, y = 4 }
    decorations = "None"
    dynamic_padding = true

    [font]
    normal = { family = "${colors.fonts.monospace}", style = "Regular" }
    bold = { family = "${colors.fonts.monospace}", style = "Bold" }
    italic = { family = "${colors.fonts.monospace}", style = "Italic" }
    size = 14.0

    [cursor]
    style = { shape = "Block", blinking = "On" }
    blink_interval = 750

    [colors.primary]
    background = "${colors.base}"
    foreground = "${colors.text}"
    dim_foreground = "${colors.overlay1}"
    bright_foreground = "${colors.text}"

    [colors.cursor]
    text = "${colors.base}"
    cursor = "${colors.rosewater}"

    [colors.vi_mode_cursor]
    text = "${colors.base}"
    cursor = "${colors.lavender}"

    [colors.search.matches]
    foreground = "${colors.base}"
    background = "${colors.subtext0}"

    [colors.search.focused_match]
    foreground = "${colors.base}"
    background = "${colors.green}"

    [colors.footer_bar]
    foreground = "${colors.base}"
    background = "${colors.subtext0}"

    [colors.hints.start]
    foreground = "${colors.base}"
    background = "${colors.yellow}"

    [colors.hints.end]
    foreground = "${colors.base}"
    background = "${colors.subtext0}"

    [colors.selection]
    text = "${colors.base}"
    background = "${colors.rosewater}"

    [colors.normal]
    black = "${colors.surface1}"
    red = "${colors.red}"
    green = "${colors.green}"
    yellow = "${colors.yellow}"
    blue = "${colors.blue}"
    magenta = "${colors.pink}"
    cyan = "${colors.teal}"
    white = "${colors.subtext1}"

    [colors.bright]
    black = "${colors.surface2}"
    red = "${colors.red}"
    green = "${colors.green}"
    yellow = "${colors.yellow}"
    blue = "${colors.blue}"
    magenta = "${colors.pink}"
    cyan = "${colors.teal}"
    white = "${colors.subtext0}"

    [[colors.indexed_colors]]
    index = 16
    color = "${colors.peach}"

    [[colors.indexed_colors]]
    index = 17
    color = "${colors.rosewater}"
  '';

  # SwayNC notification center - config
  xdg.configFile."swaync/config.json".text = builtins.toJSON {
    "$schema" = "/etc/xdg/swaync/configSchema.json";
    # Notification popups - bottom right
    positionX = "right";
    positionY = "bottom";
    # Control center - top center (below bar, where the module is)
    control-center-positionX = "center";
    control-center-positionY = "top";
    control-center-margin-top = 50;
    control-center-margin-bottom = 10;
    control-center-margin-right = 10;
    control-center-margin-left = 10;
    notification-window-width = 450;
    notification-icon-size = 48;
    notification-body-image-height = 100;
    notification-body-image-width = 200;
    timeout = 8;
    timeout-low = 4;
    timeout-critical = 0;
    fit-to-screen = false;
    control-center-width = 450;
    control-center-height = 600;
    notification-2fa-action = true;
    keyboard-shortcuts = true;
    image-visibility = "when-available";
    transition-time = 200;
    hide-on-clear = false;
    hide-on-action = true;
    script-fail-notify = true;
  };

  # SwayNC notification center - Catppuccin Mocha style
  xdg.configFile."swaync/style.css".text = ''
    /* Catppuccin Mocha theme for SwayNC */
    @define-color base ${colors.base};
    @define-color mantle ${colors.mantle};
    @define-color crust ${colors.crust};
    @define-color surface0 ${colors.surface0};
    @define-color surface1 ${colors.surface1};
    @define-color surface2 ${colors.surface2};
    @define-color text ${colors.text};
    @define-color subtext0 ${colors.subtext0};
    @define-color mauve ${colors.mauve};
    @define-color pink ${colors.pink};
    @define-color red ${colors.red};
    @define-color peach ${colors.peach};
    @define-color yellow ${colors.yellow};
    @define-color green ${colors.green};
    @define-color blue ${colors.blue};

    * {
      font-family: "JetBrainsMono Nerd Font";
      font-size: 14px;
    }

    .notification-row {
      outline: none;
      background: transparent;
    }

    .notification-row:focus,
    .notification-row:hover {
      background: transparent;
    }

    .notification {
      border-radius: 12px;
      margin: 6px;
      padding: 0;
      background: @base;
      border: 2px solid @mauve;
    }

    .notification:hover {
      background: @surface0;
    }

    .notification-content {
      padding: 12px;
      border-radius: 12px;
    }

    .close-button {
      background: @surface1;
      color: @text;
      border-radius: 6px;
      margin: 6px;
      padding: 4px;
    }

    .close-button:hover {
      background: @red;
      color: @base;
    }

    .notification-default-action,
    .notification-action {
      padding: 6px;
      margin: 6px;
      border-radius: 8px;
      background: @surface0;
      color: @text;
      border: none;
    }

    .notification-default-action:hover,
    .notification-action:hover {
      background: @surface1;
    }

    .notification-action {
      margin-top: 0;
    }

    .summary {
      color: @text;
      font-weight: bold;
      font-size: 15px;
    }

    .body {
      color: @subtext0;
      font-size: 13px;
    }

    .critical {
      border-color: @red;
    }

    .control-center {
      background: @base;
      border: 2px solid @surface1;
      border-radius: 12px;
      padding: 12px;
    }

    .control-center-list {
      background: transparent;
    }

    .floating-notifications {
      background: transparent;
    }

    .widget-title {
      color: @text;
      font-weight: bold;
      font-size: 16px;
      margin: 8px;
    }

    .widget-title > button {
      background: @surface0;
      color: @text;
      border-radius: 8px;
      padding: 4px 8px;
      border: none;
    }

    .widget-title > button:hover {
      background: @surface1;
    }

    .widget-dnd {
      background: @surface0;
      border-radius: 8px;
      margin: 8px;
      padding: 8px;
    }

    .widget-dnd > switch {
      background: @surface1;
      border-radius: 8px;
    }

    .widget-dnd > switch:checked {
      background: @mauve;
    }

    .widget-dnd > switch slider {
      background: @text;
      border-radius: 8px;
    }
  '';

  # Zen Browser userChrome.css - Catppuccin Mocha theme
  # Note: Requires toolkit.legacyUserProfileCustomizations.stylesheets = true in about:config
  home.activation.zenBrowserTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Find Zen profile directory and install userChrome.css
    ZEN_DIR="$HOME/.zen"
    if [ -d "$ZEN_DIR" ]; then
      for profile in "$ZEN_DIR"/*.default* "$ZEN_DIR"/*release*; do
        if [ -d "$profile" ]; then
          $DRY_RUN_CMD mkdir -p "$profile/chrome"
          $DRY_RUN_CMD cp -f ${pkgs.writeText "userChrome.css" ''
            /* Catppuccin Mocha theme for Zen Browser */
            /* Enable in about:config: toolkit.legacyUserProfileCustomizations.stylesheets = true */

            :root {
              /* Catppuccin Mocha colors */
              --catppuccin-base: #1e1e2e;
              --catppuccin-mantle: #181825;
              --catppuccin-crust: #11111b;
              --catppuccin-surface0: #313244;
              --catppuccin-surface1: #45475a;
              --catppuccin-surface2: #585b70;
              --catppuccin-overlay0: #6c7086;
              --catppuccin-overlay1: #7f849c;
              --catppuccin-text: #cdd6f4;
              --catppuccin-subtext0: #a6adc8;
              --catppuccin-subtext1: #bac2de;
              --catppuccin-mauve: #cba6f7;
              --catppuccin-pink: #f5c2e7;
              --catppuccin-red: #f38ba8;
              --catppuccin-peach: #fab387;
              --catppuccin-yellow: #f9e2af;
              --catppuccin-green: #a6e3a1;
              --catppuccin-teal: #94e2d5;
              --catppuccin-blue: #89b4fa;
              --catppuccin-lavender: #b4befe;

              /* Apply to Firefox/Zen variables */
              --toolbar-bgcolor: var(--catppuccin-base) !important;
              --toolbar-color: var(--catppuccin-text) !important;
              --toolbar-field-background-color: var(--catppuccin-surface0) !important;
              --toolbar-field-color: var(--catppuccin-text) !important;
              --toolbar-field-border-color: var(--catppuccin-surface1) !important;
              --toolbar-field-focus-background-color: var(--catppuccin-surface0) !important;
              --toolbar-field-focus-border-color: var(--catppuccin-mauve) !important;
              --urlbar-box-bgcolor: var(--catppuccin-surface0) !important;
              --urlbar-box-hover-bgcolor: var(--catppuccin-surface1) !important;
              --urlbar-box-active-bgcolor: var(--catppuccin-surface1) !important;
              --urlbar-box-text-color: var(--catppuccin-text) !important;
              --lwt-accent-color: var(--catppuccin-base) !important;
              --lwt-text-color: var(--catppuccin-text) !important;
              --arrowpanel-background: var(--catppuccin-base) !important;
              --arrowpanel-color: var(--catppuccin-text) !important;
              --arrowpanel-border-color: var(--catppuccin-surface1) !important;
              --panel-separator-color: var(--catppuccin-surface1) !important;
              --tab-selected-bgcolor: var(--catppuccin-surface0) !important;
              --tab-selected-textcolor: var(--catppuccin-text) !important;
              --tab-loading-fill: var(--catppuccin-mauve) !important;
              --focus-outline-color: var(--catppuccin-mauve) !important;
            }

            /* Tab bar background */
            #TabsToolbar {
              background-color: var(--catppuccin-mantle) !important;
            }

            /* Navigation bar */
            #nav-bar {
              background-color: var(--catppuccin-base) !important;
              border-bottom: 1px solid var(--catppuccin-surface0) !important;
            }

            /* URL bar */
            #urlbar-background {
              background-color: var(--catppuccin-surface0) !important;
              border: 1px solid var(--catppuccin-surface1) !important;
            }

            #urlbar[focused="true"] > #urlbar-background {
              border-color: var(--catppuccin-mauve) !important;
            }

            /* Sidebar */
            #sidebar-box {
              background-color: var(--catppuccin-mantle) !important;
            }

            /* Context menus */
            menupopup, panel {
              --panel-background: var(--catppuccin-base) !important;
              --panel-color: var(--catppuccin-text) !important;
            }

            menuitem:hover, .panel-subview-body toolbarbutton:hover {
              background-color: var(--catppuccin-surface1) !important;
            }

            /* Bookmarks bar */
            #PersonalToolbar {
              background-color: var(--catppuccin-mantle) !important;
            }

            /* Selected tab indicator */
            .tabbrowser-tab[selected="true"] .tab-line {
              background-color: var(--catppuccin-mauve) !important;
            }

            /* Hover states */
            .tabbrowser-tab:hover .tab-background {
              background-color: var(--catppuccin-surface0) !important;
            }

            /* Scrollbar styling */
            * {
              scrollbar-color: var(--catppuccin-surface2) var(--catppuccin-base) !important;
            }
          ''} "$profile/chrome/userChrome.css"
          $DRY_RUN_CMD chmod 644 "$profile/chrome/userChrome.css"
        fi
      done
    fi
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

  # VSCode configuration with Catppuccin theme
  programs.vscode = {
    enable = true;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        catppuccin.catppuccin-vsc
        catppuccin.catppuccin-vsc-icons
      ];
      userSettings = {
        # Theme
        "workbench.colorTheme" = "Catppuccin Mocha";
        "workbench.iconTheme" = "catppuccin-mocha";

        # Font
        "editor.fontFamily" = "'JetBrainsMono Nerd Font', 'monospace', monospace";
        "editor.fontSize" = 14;
        "editor.fontLigatures" = true;
        "terminal.integrated.fontFamily" = "'JetBrainsMono Nerd Font'";
        "terminal.integrated.fontSize" = 14;

        # Editor appearance
        "editor.cursorBlinking" = "smooth";
        "editor.cursorSmoothCaretAnimation" = "on";
        "editor.smoothScrolling" = true;
        "workbench.list.smoothScrolling" = true;
        "terminal.integrated.smoothScrolling" = true;

        # Window
        "window.titleBarStyle" = "custom";
        "window.menuBarVisibility" = "toggle";

        # Catppuccin accent color (mauve)
        "catppuccin.accentColor" = "mauve";
      };
    };
  };
}
