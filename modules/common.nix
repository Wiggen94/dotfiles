# Common NixOS configuration shared between all hosts
{ config, pkgs, lib, inputs, hostName, ... }:

{
  nixpkgs.config.allowUnfree = true;

  # Enable flakes and binary caches
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    warn-dirty = false;
    # Binary caches for faster builds
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };

  # Dolphin overlay to fix "Open with" menu outside KDE (preserves theming)
  nixpkgs.overlays = [ (import ../dolphin-fix.nix) ];

  # State version - DON'T change this after initial install
  system.stateVersion = "25.11";

  # Timezone and Locale
  time.timeZone = "Europe/Oslo";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "nb_NO.UTF-8";  # Norwegian time format (week starts Monday, 24hr)
    LC_MEASUREMENT = "nb_NO.UTF-8";  # Metric system
  };

  # Enforce declarative password management
  users.mutableUsers = false;

  users.users.gjermund = {
    isNormalUser = true;
    home = "/home/gjermund";
    extraGroups = [ "wheel" ];
    hashedPassword = "$6$XJUUySKdUJMXg4mp$TZE6y2N/t0U./GvhLlC8WNY1T8GIW9bedUENaGuKbd8BcTxLbAlvzAvD6tnsxaTH1oROOWGStReyPMK4ldyUJ/";
    shell = pkgs.zsh;
  };

  # Zsh configuration
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    ohMyZsh = {
      enable = true;
      plugins = [ "git" ];
    };
    shellAliases = {
      ls = "eza -a --icons --group-directories-first";
      ll = "eza -al --icons --group-directories-first --git";
      la = "eza -a --icons --group-directories-first --git";
      lt = "eza -a --tree --level=2 --icons --group-directories-first";
      lg = "eza -al --icons --git --git-repos";
      cat = "bat";
      nrs = "nixos-rebuild-flake";
      nano = "nvim";
      sudo = "sudo ";  # trailing space expands aliases after sudo
      gridcoinresearch = "command gridcoinresearch -datadir=\"/home/gjermund/games/GridCoin/GridCoinResearch/\" -boincdatadir=\"/home/gjermund/boinc/\"";
    };
    promptInit = ''
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
    '';
  };

  # Boot loader
  boot.loader.systemd-boot.enable = true;

  # Plymouth boot splash (Catppuccin theme)
  boot.plymouth = {
    enable = true;
    theme = "catppuccin-mocha";
    themePackages = [
      (pkgs.catppuccin-plymouth.override { variant = "mocha"; })
    ];
  };
  boot.initrd.systemd.enable = true;  # Required for smooth plymouth

  # SSH
  services.openssh.enable = true;

  # Hyprland
  programs.hyprland.enable = true;

  # NH - Nix Helper with automatic cleanup
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep 5 --keep-since 3d";
    };
  };

  # dconf - required for GTK/GNOME settings
  programs.dconf.enable = true;

  # nix-ld - allows running unpatched dynamic binaries (needed for BOINC, etc.)
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    # Standard libraries for most binaries
    stdenv.cc.cc.lib
    zlib
    # CUDA support for BOINC GPU tasks
    cudaPackages.cuda_cudart
    cudaPackages.libcublas
    cudaPackages.libcufft
  ];

  # XDG Desktop Portal (for screen sharing, file pickers, etc.)
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
      pkgs.kdePackages.xdg-desktop-portal-kde
    ];
    config.common.default = "*";
  };

  # Disable IPv6 at kernel level (more reliable than sysctl alone)
  # quiet and splash for clean Plymouth boot
  boot.kernelParams = [ "ipv6.disable=1" "quiet" "splash" ];

  # NetworkManager
  networking.enableIPv6 = false;
  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = [
    pkgs.networkmanager-openvpn
    pkgs.networkmanager-l2tp
  ];

  # Static DNS - AdGuard primary, Cloudflare fallback
  # Prevents slow DNS when DHCP-provided server becomes unresponsive
  networking.nameservers = [ "192.168.0.185" "1.1.1.1" ];
  networking.networkmanager.dns = "none";  # Don't let NM override resolv.conf

  # WireGuard
  networking.wireguard.enable = true;

  # Firewall - open ports for KDE Connect and WireGuard
  networking.firewall = {
    allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
    allowedUDPPortRanges = [ { from = 1714; to = 1764; } ];
    allowedUDPPorts = [ 51820 ];  # WireGuard
    checkReversePath = "loose";   # Required for WireGuard
  };

  # Sudo - remember privileges per terminal session
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=-1
  '';

  # Polkit authentication agent
  security.polkit.enable = true;

  # Enable Bluetooth
  hardware.bluetooth.enable = true;
  hardware.ledger.enable = true;  # Ledger hardware wallet udev rules
  services.blueman.enable = true;

  # Allow passwordless sudo for nixos-rebuild and VPN routing
  security.sudo.extraRules = [
    {
      users = [ "gjermund" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/ip route *";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/ip rule *";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Enable SDDM display manager with auto-login
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    autoNumlock = true;
    theme = "catppuccin-mocha";
    package = pkgs.kdePackages.sddm;
  };
  services.displayManager.defaultSession = "hyprland";
  services.displayManager.autoLogin = {
    enable = true;
    user = "gjermund";
  };

  # Enable gnome-keyring for secrets (but disable its SSH agent)
  services.gnome.gnome-keyring.enable = true;
  services.gnome.gcr-ssh-agent.enable = false;
  security.pam.services.sddm.enableGnomeKeyring = true;
  security.pam.services.hyprlock = {};

  # SSH agent - use NixOS built-in
  programs.ssh = {
    startAgent = true;
    askPassword = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";
    extraConfig = ''
      AddKeysToAgent yes
    '';
  };

  # Set SSH_ASKPASS for GUI prompts
  environment.sessionVariables = {
    SSH_ASKPASS_REQUIRE = "prefer";
    # Catppuccin Mocha theme for bat
    BAT_THEME = "Catppuccin Mocha";
    # Catppuccin Mocha theme for fzf
    FZF_DEFAULT_OPTS = builtins.concatStringsSep " " [
      "--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8"
      "--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc"
      "--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
      "--color=selected-bg:#45475a"
      "--border=rounded"
    ];
  };
  environment.variables = {
    SSH_ASKPASS = lib.mkForce "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";
  };

  # 1Password
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "gjermund" ];
  };
  environment.etc."1password/custom_allowed_browsers" = {
    text = ''
      zen
      .zen-wrapped
    '';
    mode = "0755";
  };

  # Enable Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  # Neovim with Nixvim (LazyVim-like setup)
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # Colorscheme - Catppuccin Mocha (matches system theme)
    colorschemes.catppuccin = {
      enable = true;
      settings = {
        flavour = "mocha";
        term_colors = true;
        integrations = {
          cmp = true;
          gitsigns = true;
          neo_tree = true;
          treesitter = true;
          notify = true;
          which_key = true;
          telescope.enabled = true;
          native_lsp.enabled = true;
        };
      };
    };

    # General settings
    opts = {
      number = true;
      relativenumber = true;
      shiftwidth = 2;
      tabstop = 2;
      expandtab = true;
      mouse = "a";
      clipboard = "unnamedplus";
      termguicolors = true;
      signcolumn = "yes";
      cursorline = true;
      scrolloff = 8;
    };

    globals.mapleader = " ";

    # Plugins (LazyVim-like)
    plugins = {
      # UI
      web-devicons.enable = true;
      lualine.enable = true;
      bufferline.enable = true;
      neo-tree.enable = true;
      which-key.enable = true;
      noice.enable = true;
      notify.enable = true;

      # Fuzzy finder
      telescope = {
        enable = true;
        keymaps = {
          "<leader>ff" = "find_files";
          "<leader>fg" = "live_grep";
          "<leader>fb" = "buffers";
          "<leader>fh" = "help_tags";
        };
      };

      # Syntax highlighting
      treesitter = {
        enable = true;
        settings.highlight.enable = true;
      };

      # LSP
      lsp = {
        enable = true;
        servers = {
          nixd.enable = true;
          lua_ls.enable = true;
          pyright.enable = true;
          ts_ls.enable = true;
          rust_analyzer = {
            enable = true;
            installCargo = true;
            installRustc = true;
          };
        };
      };

      # Completion
      cmp = {
        enable = true;
        autoEnableSources = true;
        settings.sources = [
          { name = "nvim_lsp"; }
          { name = "path"; }
          { name = "buffer"; }
        ];
      };

      # Git
      gitsigns.enable = true;
      lazygit.enable = true;

      # Quality of life
      autopairs.enable = true;
      comment.enable = true;
      indent-blankline.enable = true;
      todo-comments.enable = true;
      trouble.enable = true;
    };

    # Keymaps
    keymaps = [
      { mode = "n"; key = "<leader>e"; action = "<cmd>Neotree toggle<CR>"; options.desc = "Toggle file explorer"; }
      { mode = "n"; key = "<leader>gg"; action = "<cmd>LazyGit<CR>"; options.desc = "LazyGit"; }
      { mode = "n"; key = "<S-l>"; action = "<cmd>BufferLineCycleNext<CR>"; options.desc = "Next buffer"; }
      { mode = "n"; key = "<S-h>"; action = "<cmd>BufferLineCyclePrev<CR>"; options.desc = "Previous buffer"; }
      { mode = "n"; key = "<leader>bd"; action = "<cmd>bdelete<CR>"; options.desc = "Delete buffer"; }
      { mode = "n"; key = "<leader>xx"; action = "<cmd>Trouble diagnostics toggle<CR>"; options.desc = "Diagnostics"; }
    ];
  };

  environment.systemPackages = [
    # System utilities
    pkgs.git
    pkgs.jq
    pkgs.htop
    pkgs.btop  # System monitor with Catppuccin theme
    pkgs.hollywood  # Fake Hollywood hacker terminal
    pkgs.nvd  # Nix/NixOS package version diff tool (used by nh)
    pkgs.bluez  # Package needed for D-Bus files, but service disabled
    pkgs.eza  # Modern ls replacement with icons
    pkgs.fzf  # Fuzzy finder
    pkgs.seahorse  # GNOME keyring GUI + SSH askpass
    pkgs.shared-mime-info  # MIME type database
    pkgs.glib  # For gio and other utilities
    pkgs.traceroute
    pkgs.bind

    # SDDM Catppuccin theme
    (pkgs.catppuccin-sddm.override {
      flavor = "mocha";
      font = "JetBrainsMono Nerd Font";
      fontSize = "12";
      loginBackground = true;
    })

    # GTK Catppuccin theme
    (pkgs.catppuccin-gtk.override {
      accents = [ "mauve" ];
      variant = "mocha";
    })

    # Shell (zsh + oh-my-zsh + powerlevel10k)
    pkgs.zsh
    pkgs.oh-my-zsh
    pkgs.zsh-powerlevel10k
    pkgs.zsh-autosuggestions
    pkgs.zsh-syntax-highlighting

    # Desktop environment & UI
    pkgs.fuzzel  # App launcher
    pkgs.alacritty
    pkgs.kdePackages.dolphin
    pkgs.kdePackages.ark  # Archive manager (integrates with Dolphin)
    pkgs.kdePackages.gwenview  # Image viewer
    pkgs.kdePackages.kservice  # KDE service framework (kbuildsycoca6)
    pkgs.waybar

    # Clipboard & Screenshots
    pkgs.wl-clipboard  # Wayland clipboard utilities
    pkgs.cliphist  # Clipboard history manager
    pkgs.wl-clip-persist  # Keep clipboard after programs close
    pkgs.grim  # Screenshot utility
    pkgs.slurp  # Region selection
    pkgs.libnotify  # For notifications (notify-send)
    pkgs.swaynotificationcenter  # Notification center

    # Lock screen & Power menu
    pkgs.hyprlock  # Screen locker for Hyprland
    pkgs.wlogout  # Graphical power menu
    pkgs.hypridle  # Idle daemon for auto-lock

    # Polkit authentication agent
    pkgs.polkit_gnome

    # Network manager applet
    pkgs.networkmanagerapplet

    # KDE Connect
    pkgs.kdePackages.kdeconnect-kde

    # Media control
    pkgs.playerctl

    # Notification sounds
    pkgs.sound-theme-freedesktop
    pkgs.libcanberra-gtk3

    # Brightness control (useful for laptops)
    pkgs.brightnessctl

    # Calculator
    pkgs.qalculate-gtk  # Powerful calculator with unit conversions

    # Clipboard history picker script
    (pkgs.writeShellScriptBin "cliphist-paste" ''
      #!/usr/bin/env bash
      selected=$(${pkgs.cliphist}/bin/cliphist list | ${pkgs.fuzzel}/bin/fuzzel --dmenu)
      if [ -n "$selected" ]; then
        content=$(${pkgs.cliphist}/bin/cliphist decode <<< "$selected")
        printf '%s' "$content" | ${pkgs.wl-clipboard}/bin/wl-copy --type text/plain
        printf '%s' "$content" | ${pkgs.wl-clipboard}/bin/wl-copy --primary --type text/plain
      fi
    '')

    # Screenshot script with notification and save action
    (pkgs.writeShellScriptBin "screenshot" ''
      #!/usr/bin/env bash
      SCREENSHOTS_DIR="$HOME/Pictures/Screenshots"
      mkdir -p "$SCREENSHOTS_DIR"
      TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
      TEMP_FILE="/tmp/screenshot_$TIMESTAMP.png"

      # Take screenshot
      ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" "$TEMP_FILE"

      if [ -f "$TEMP_FILE" ]; then
        # Copy to clipboard
        ${pkgs.wl-clipboard}/bin/wl-copy < "$TEMP_FILE"

        # Show notification with save action
        ACTION=$(${pkgs.libnotify}/bin/notify-send \
          --app-name="Screenshot" \
          --icon="$TEMP_FILE" \
          --action="save=Save" \
          --action="discard=Discard" \
          "Screenshot captured" \
          "Copied to clipboard. Click Save to keep.")

        if [ "$ACTION" = "save" ]; then
          SAVE_PATH="$SCREENSHOTS_DIR/screenshot_$TIMESTAMP.png"
          mv "$TEMP_FILE" "$SAVE_PATH"
          ${pkgs.libnotify}/bin/notify-send "Screenshot saved" "$SAVE_PATH"
        else
          rm -f "$TEMP_FILE"
        fi
      fi
    '')

    # Notification sound daemon
    (pkgs.writeShellScriptBin "notification-sound-daemon" ''
      #!/usr/bin/env bash
      SOUND_FILE="${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/message.oga"
      # Monitor D-Bus for notifications and play a sound
      ${pkgs.dbus}/bin/dbus-monitor "interface=org.freedesktop.Notifications" | \
      while read -r line; do
        if echo "$line" | grep -q "member=Notify"; then
          ${pkgs.pipewire}/bin/pw-play "$SOUND_FILE" &
        fi
      done
    '')

    # Volume control with sound feedback
    (pkgs.writeShellScriptBin "volume-up" ''
      #!/usr/bin/env bash
      ${pkgs.wireplumber}/bin/wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
      ${pkgs.pipewire}/bin/pw-play ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/audio-volume-change.oga &
    '')

    (pkgs.writeShellScriptBin "volume-down" ''
      #!/usr/bin/env bash
      ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
      ${pkgs.pipewire}/bin/pw-play ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/audio-volume-change.oga &
    '')

    (pkgs.writeShellScriptBin "volume-mute" ''
      #!/usr/bin/env bash
      ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      # Check if muted and play appropriate sound
      MUTED=$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED && echo "yes" || echo "no")
      if [ "$MUTED" = "yes" ]; then
        ${pkgs.pipewire}/bin/pw-play ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/audio-volume-change.oga &
      else
        ${pkgs.pipewire}/bin/pw-play ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/audio-volume-change.oga &
      fi
    '')

    # Gaming mode toggle script
    (pkgs.writeShellScriptBin "gaming-mode-toggle" ''
      #!/usr/bin/env bash
      STATE_FILE="/tmp/gaming-mode-state"

      # Check if gaming mode is currently enabled
      if [ -f "$STATE_FILE" ]; then
        # Currently in gaming mode, switch back to normal
        # Only restore panel if we hid it
        if grep -q "panel_hidden=1" "$STATE_FILE" 2>/dev/null; then
          pkill -SIGUSR1 waybar
        fi
        hyprctl keyword animations:enabled true
        hyprctl keyword decoration:blur:enabled true
        hyprctl keyword decoration:shadow:enabled true
        hyprctl keyword decoration:dim_inactive true
        hyprctl keyword decoration:rounding 12
        hyprctl keyword decoration:active_opacity 0.98
        hyprctl keyword decoration:inactive_opacity 0.90
        hyprctl keyword general:gaps_in 6
        hyprctl keyword general:gaps_out 12
        hyprctl keyword general:border_size 3
        hyprctl keyword 'general:col.active_border' 'rgba(cba6f7ff) rgba(f5c2e7ff) rgba(89b4faff) 45deg'
        hyprctl keyword 'general:col.inactive_border' 'rgba(45475aaa)'
        rm -f "$STATE_FILE"
        ${pkgs.libnotify}/bin/notify-send -u low "Gaming Mode" "Disabled - effects restored"
      else
        # Currently normal mode, switch to gaming mode
        # Check if waybar is running
        PANEL_HIDDEN=0
        if pgrep waybar > /dev/null; then
          pkill -SIGUSR1 waybar
          PANEL_HIDDEN=1
        fi
        hyprctl keyword animations:enabled false
        hyprctl keyword decoration:blur:enabled false
        hyprctl keyword decoration:shadow:enabled false
        hyprctl keyword decoration:dim_inactive false
        hyprctl keyword decoration:rounding 0
        hyprctl keyword decoration:active_opacity 1.0
        hyprctl keyword decoration:inactive_opacity 1.0
        hyprctl keyword general:gaps_in 0
        hyprctl keyword general:gaps_out 0
        hyprctl keyword general:border_size 1
        hyprctl keyword 'general:col.active_border' 'rgba(ffffff10)'
        hyprctl keyword 'general:col.inactive_border' 'rgba(00000000)'
        echo "panel_hidden=$PANEL_HIDDEN" > "$STATE_FILE"
        ${pkgs.libnotify}/bin/notify-send -u low "Gaming Mode" "Enabled - max performance"
      fi
    '')

    # Work applications
    pkgs.teams-for-linux
    pkgs.slack
    pkgs.zoom-us
    pkgs.discord
    pkgs.chromium  # For Outlook PWA
    pkgs.eduvpn-client
    (pkgs.writeShellScriptBin "outlook" ''
      #!/usr/bin/env bash
      exec chromium --app=https://outlook.office.com/mail/ "$@"
    '')

    # Development tools
    pkgs.claude-code
    pkgs.bat
    pkgs.gnome-text-editor  # Simple GUI editor

    # Gaming & Entertainment
    (pkgs.callPackage ../curseforge.nix {})
    pkgs.lutris
    (pkgs.retroarch.withCores (cores: with cores; [
      mupen64plus      # Nintendo 64
      parallel-n64     # Nintendo 64 (ParaLLEl - better accuracy, Vulkan)
    ]))
    pkgs.mpv
    pkgs.wineWowPackages.stagingFull
    pkgs.winetricks

    # Work tools (Sikt/Zino)
    (pkgs.callPackage ../curitz.nix {})
    pkgs.wireguard-tools
    pkgs.kubectl

    # curitz-vpn: Run curitz with split-tunnel VPN (only Zino traffic goes through VPN)
    (pkgs.writeShellScriptBin "curitz-vpn" ''
      #!/usr/bin/env bash
      set -e

      ZINO_HOST="hugin.uninett.no"
      ZINO_IP="158.38.0.175"
      VPN_IFACE="eduVPN"

      cleanup() {
        echo ""
        echo "Disconnecting VPN..."
        ${pkgs.eduvpn-client}/bin/eduvpn-cli disconnect 2>/dev/null || true
        exit 0
      }
      trap cleanup EXIT INT TERM

      echo "Connecting to EduVPN..."
      ${pkgs.eduvpn-client}/bin/eduvpn-cli connect -n 1 2>&1 | grep -v "^time=" &

      # Wait for VPN interface to come up
      for i in {1..30}; do
        if ip link show "$VPN_IFACE" &>/dev/null; then
          break
        fi
        sleep 1
      done

      if ! ip link show "$VPN_IFACE" &>/dev/null; then
        echo "Error: VPN interface did not come up"
        exit 1
      fi

      # Wait for routing to be set up
      sleep 3

      echo "Modifying routes for split-tunnel..."

      # EduVPN uses policy routing - find and remove the rules that send all traffic to VPN
      # The rule looks like: "not from all fwmark 0xca94 lookup <table>"
      VPN_TABLE=$(ip rule show | grep -oP 'fwmark.*lookup \K[0-9]+' | head -1)
      if [ -n "$VPN_TABLE" ]; then
        # Delete IPv4 policy rule that routes everything through VPN
        sudo ip rule del priority 3 2>/dev/null || true
        sudo ip rule del not fwmark 0xca94 lookup "$VPN_TABLE" 2>/dev/null || true

        # Delete IPv6 policy rule that routes everything through VPN
        sudo ip -6 rule del priority 3 2>/dev/null || true
        sudo ip -6 rule del not fwmark 0xca94 lookup "$VPN_TABLE" 2>/dev/null || true

        # Add rules to only route Zino traffic through VPN (IPv4)
        sudo ip rule add to "$ZINO_IP/32" lookup "$VPN_TABLE" priority 100 2>/dev/null || true

        # Add rule for Zino IPv6 if needed
        sudo ip -6 rule add to 2001:700:0:503:230:48ff:fef5:1580/128 lookup "$VPN_TABLE" priority 100 2>/dev/null || true
      fi

      # Also ensure direct route to Zino exists
      sudo ip route replace "$ZINO_IP/32" dev "$VPN_IFACE" 2>/dev/null || true

      # Restore local DNS - VPN pushes Uninett DNS which refuses queries from non-VPN IPs
      echo "Restoring local DNS..."
      echo -e "# Generated by curitz-vpn (split-tunnel)\nnameserver 192.168.0.185\noptions edns0" | sudo tee /etc/resolv.conf > /dev/null

      echo "Split-tunnel active. Only traffic to $ZINO_HOST goes through VPN."
      echo "Starting curitz..."
      echo ""

      # Run curitz
      curitz "$@"
    '')

    # 3D Printing
    pkgs.bambu-studio
    # OrcaSlicer wrapped with zink to fix NVIDIA Wayland preview rendering
    (pkgs.symlinkJoin {
      name = "orca-slicer-wrapped";
      paths = [ pkgs.orca-slicer ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/orca-slicer \
          --set __GLX_VENDOR_LIBRARY_NAME mesa \
          --set __EGL_VENDOR_LIBRARY_FILENAMES /run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json \
          --set MESA_LOADER_DRIVER_OVERRIDE zink \
          --set GALLIUM_DRIVER zink \
          --set WEBKIT_DISABLE_DMABUF_RENDERER 1
      '';
    })

    # Distributed computing
    pkgs.boinc              # BOINC client
    pkgs.boinctui           # BOINC terminal UI
    pkgs.fahclient          # Folding@home client

    # BOINC Manager wrapper (uses ~/boinc as data directory, starts in advanced mode)
    # GDK_BACKEND=x11 forces XWayland to avoid wxWidgets/Pango font crash on native Wayland
    # LD_LIBRARY_PATH includes CUDA/OpenCL libs for GPU detection by the BOINC client
    (pkgs.writeShellScriptBin "boinc-manager" ''
      export GDK_BACKEND=x11
      export LD_LIBRARY_PATH="/run/opengl-driver/lib:''${LD_LIBRARY_PATH:-}"
      exec ${pkgs.boinc}/bin/boincmgr -a -d "$HOME/boinc" "$@"
    '')

    # Cryptocurrency
    pkgs.gridcoin-research  # Gridcoin wallet
    pkgs.sparrow            # Sparrow Bitcoin wallet
    pkgs.ledger-live-desktop  # Ledger hardware wallet

    # Proton-GE management (auto-update latest version)
    pkgs.protonup-ng

    # Flake-based rebuild script
    (pkgs.writeShellScriptBin "nixos-rebuild-flake" ''
      #!/usr/bin/env bash
      set -e

      CONFIG_DIR="/home/gjermund/nix-config"

      # Check if we're in a git repo
      if [ ! -d "$CONFIG_DIR/.git" ]; then
        echo "Error: $CONFIG_DIR is not a git repository"
        exit 1
      fi

      # Auto-update CurseForge version from Arch AUR
      echo "Checking for CurseForge updates..."
      NIX_FILE="$CONFIG_DIR/curseforge.nix"
      if [ -f "$NIX_FILE" ]; then
        AUR_VERSION=$(${pkgs.curl}/bin/curl -sf "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=curseforge" | grep "^pkgver=" | cut -d= -f2 || true)
        if [ -n "$AUR_VERSION" ]; then
          VERSION="''${AUR_VERSION//_/-}"
          CURRENT=$(grep 'version = "' "$NIX_FILE" | ${pkgs.gnused}/bin/sed 's/.*version = "\(.*\)";/\1/')
          if [ "$VERSION" != "$CURRENT" ]; then
            echo "CurseForge update available: $CURRENT -> $VERSION"
            URL="https://curseforge.overwolf.com/electron/linux/CurseForge_''${VERSION}_amd64.deb"
            HASH=$(nix-prefetch-url "$URL" 2>/dev/null || true)
            if [ -n "$HASH" ]; then
              ${pkgs.gnused}/bin/sed -i "s/version = \".*\";/version = \"$VERSION\";/" "$NIX_FILE"
              ${pkgs.gnused}/bin/sed -i "s/sha256 = \".*\";/sha256 = \"$HASH\";/" "$NIX_FILE"
              echo "CurseForge updated to $VERSION"
            fi
          else
            echo "CurseForge is up to date ($VERSION)"
          fi
        fi
      fi

      # Run nh os switch with flake
      # Detect hostname to select the correct flake output
      HOSTNAME=$(hostname)
      echo "Running nh os switch for host '$HOSTNAME'..."
      nh os switch --ask -H "$HOSTNAME" "$CONFIG_DIR" "$@" || {
        echo "nh os switch failed, not committing changes"
        exit 1
      }

      # Restart Waybar to apply config changes
      if pgrep -x waybar > /dev/null; then
        echo "Restarting Waybar..."
        pkill waybar
        sleep 0.5
        waybar &>/dev/null &
        disown
        echo "Waybar restarted"
      fi

      # If successful, commit and push as the regular user
      cd "$CONFIG_DIR"

      # Check if there are changes to commit
      if git diff --quiet && git diff --cached --quiet; then
        echo "No changes to commit"
        exit 0
      fi

      # Stage all changes
      git add -A

      # Generate dynamic commit message based on changes
      CHANGED_FILES=$(git diff --cached --name-only)
      DIFF_STAT=$(git diff --cached --stat --stat-width=80 | tail -1)

      # Analyze the diff for meaningful changes
      DIFF_CONTENT=$(git diff --cached -U0)

      # Extract added packages (lines starting with + containing pkgs.)
      ADDED_PKGS=$(echo "$DIFF_CONTENT" | grep -E '^[+].*pkgs[.]' | grep -v '^[+][+][+]' | sed 's/.*pkgs[.]\([a-zA-Z0-9_-]*\).*/\1/' | sort -u | head -5 | tr '\n' ', ' | sed 's/,$//')

      # Extract removed packages
      REMOVED_PKGS=$(echo "$DIFF_CONTENT" | grep -E '^[-].*pkgs[.]' | grep -v '^[-][-][-]' | sed 's/.*pkgs[.]\([a-zA-Z0-9_-]*\).*/\1/' | sort -u | head -5 | tr '\n' ', ' | sed 's/,$//')

      # Build commit message
      COMMIT_MSG=""

      if [ -n "$ADDED_PKGS" ] && [ -n "$REMOVED_PKGS" ]; then
        COMMIT_MSG="Add $ADDED_PKGS; Remove $REMOVED_PKGS"
      elif [ -n "$ADDED_PKGS" ]; then
        COMMIT_MSG="Add $ADDED_PKGS"
      elif [ -n "$REMOVED_PKGS" ]; then
        COMMIT_MSG="Remove $REMOVED_PKGS"
      else
        # Check for config changes in specific files
        if echo "$CHANGED_FILES" | grep -q "hyprland.conf"; then
          COMMIT_MSG="Update Hyprland config"
        elif echo "$CHANGED_FILES" | grep -q "alacritty"; then
          COMMIT_MSG="Update Alacritty config"
        elif echo "$CHANGED_FILES" | grep -q "waybar"; then
          COMMIT_MSG="Update Waybar config"
        elif echo "$CHANGED_FILES" | grep -q "configuration.nix"; then
          COMMIT_MSG="Update NixOS configuration"
        else
          COMMIT_MSG="Update config"
        fi
      fi

      # Add file count info
      FILE_COUNT=$(echo "$CHANGED_FILES" | wc -l)
      if [ "$FILE_COUNT" -gt 1 ]; then
        COMMIT_MSG="$COMMIT_MSG ($FILE_COUNT files)"
      fi

      # Commit
      git commit -m "$COMMIT_MSG"
      echo "Changes committed: $COMMIT_MSG"

      # Push to remote (if configured)
      if git remote | grep -q .; then
        echo "Pushing to remote..."
        git push || echo "Warning: Push failed, but rebuild was successful"
      else
        echo "No remote configured, skipping push"
      fi
    '')

    # Zen browser from flake input
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
