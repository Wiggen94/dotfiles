# Common NixOS configuration shared between all hosts
{ config, pkgs, lib, inputs, hostName, ... }:

let
  # Work hosts don't get gaming/personal packages
  isWorkHost = hostName == "sikt";
in
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

  # Custom overlays
  nixpkgs.overlays = [
    # Dolphin overlay to fix "Open with" menu outside KDE (preserves theming)
    (import ../dolphin-fix.nix)

    # EDMarketConnector overlay to add SQLAlchemy for Pioneer/ExploData/BioScan plugins
    (final: prev: {
      edmarketconnector = prev.edmarketconnector.overrideAttrs (oldAttrs: let
        pythonEnv = prev.python3.buildEnv.override {
          extraLibs = with prev.python3.pkgs; [
            tkinter
            requests
            pillow
            watchdog
            semantic-version
            psutil
            tomli-w
            sqlalchemy  # For Pioneer/ExploData/BioScan plugins
          ];
        };
      in {
        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin $out/share/applications $out/share/icons/hicolor/512x512/apps
          makeWrapper ${pythonEnv}/bin/python $out/bin/edmarketconnector \
            --add-flags "$src/EDMarketConnector.py"
          ln -s $src/io.edcd.EDMarketConnector.png $out/share/icons/hicolor/512x512/apps/
          ln -s $src/io.edcd.EDMarketConnector.desktop $out/share/applications/
          runHook postInstall
        '';
      });
    })
  ];

  # State version - DON'T change this after initial install
  system.stateVersion = "25.11";

  # Timezone and Locale
  time.timeZone = "Europe/Oslo";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "nb_NO.UTF-8/UTF-8"  # Required for LC_TIME/LC_MEASUREMENT
  ];
  i18n.extraLocaleSettings = {
    LC_TIME = "nb_NO.UTF-8";  # Norwegian time format (week starts Monday, 24hr)
    LC_MEASUREMENT = "nb_NO.UTF-8";  # Metric system
  };

  # Enforce declarative password management
  users.mutableUsers = false;

  users.users.gjermund = {
    isNormalUser = true;
    home = "/home/gjermund";
    extraGroups = [ "wheel" "docker" ];
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
      plugins = [ "git" "sudo" "docker" "kubectl" ];
    };
    shellAliases = {
      # Modern replacements
      ls = "eza -a --icons --group-directories-first";
      ll = "eza -al --icons --group-directories-first --git";
      la = "eza -a --icons --group-directories-first --git";
      lt = "eza -a --tree --level=2 --icons --group-directories-first";
      lg = "eza -al --icons --git --git-repos";
      # cat is defined as function in initExtra (renders .md with glow, else bat)
      find = "fd";
      grep = "rg";
      du = "dust";
      df = "duf";
      top = "btop";
      ps = "procs";
      # Directory navigation with zoxide
      cd = "z";
      cdi = "zi";
      # Quick shortcuts
      nrs = "nixos-rebuild-flake";
      nano = "nvim";
      v = "nvim";
      g = "git";
      sudo = "sudo ";  # trailing space expands aliases after sudo
      # File manager
      y = "yazi";
      # System info
      fetch = "fastfetch";
      sysinfo = "system-info";
      # Quick edits
      nixconf = "cd ~/nix-config && nvim .";
      # Application-specific
      gridcoinresearch = "command gridcoinresearch -datadir=\"/home/gjermund/games/GridCoin/GridCoinResearch/\" -boincdatadir=\"/home/gjermund/boinc/\"";
      # Quick commands
      weather = "curl -sf 'wttr.in/Trondheim?format=3' && echo";
      myip = "curl -sf 'https://ipinfo.io/ip' && echo";
      ports = "sudo lsof -i -P -n | grep LISTEN";
      # Git shortcuts
      gs = "git status";
      gc = "git commit";
      gp = "git push";
      gpl = "git pull";
      gd = "git diff";
      ga = "git add";
      gco = "git checkout";
      gl = "git log --oneline -10";
      # Docker shortcuts
      dps = "docker ps";
      dpa = "docker ps -a";
      di = "docker images";
      # Nix shortcuts
      nfu = "nix flake update";
      ncg = "sudo nix-collect-garbage -d";
      nsh = "nix-shell";
    };
    promptInit = ''
      # Initialize zoxide (smart cd)
      eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"
      # Initialize atuin (better shell history)
      eval "$(${pkgs.atuin}/bin/atuin init zsh --disable-up-arrow)"
      # Initialize direnv (per-directory environments)
      eval "$(${pkgs.direnv}/bin/direnv hook zsh)"
      # Initialize starship prompt
      eval "$(${pkgs.starship}/bin/starship init zsh)"

      # Smart cat: render markdown with glow, everything else with bat
      cat() {
        for file in "$@"; do
          if [[ "$file" == *.md ]]; then
            ${pkgs.glow}/bin/glow "$file"
          else
            ${pkgs.bat}/bin/bat "$file"
          fi
        done
      }
    '';
  };

  # Boot loader
  boot.loader.systemd-boot.enable = true;

  # Use latest stable kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Plymouth boot splash (Catppuccin theme)
  boot.plymouth = {
    enable = true;
    theme = "catppuccin-mocha";
    themePackages = [
      (pkgs.catppuccin-plymouth.override { variant = "mocha"; })
    ];
  };
  boot.initrd.systemd.enable = true;  # Required for smooth plymouth

  # Zram - compressed swap in RAM for emergency overflow
  # Prevents hard freezes when memory fills up during gaming
  zramSwap = {
    enable = true;
    memoryPercent = 15;  # ~5GB compressed swap on 32GB system (sufficient for gaming)
  };

  # SSD health - periodic TRIM for NVMe longevity and performance
  services.fstrim.enable = true;

  # Btrfs integrity - monthly scrub to detect silent data corruption
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" "/home/gjermund/games" "/backup" ];
  };

  # Early OOM killer - prevents system freezes when RAM fills up
  # More responsive than kernel OOM, kills least important process first
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
    enableNotifications = true;
  };

  # Resolve conflict between earlyoom and smartd
  services.systembus-notify.enable = lib.mkForce true;

  # Balance IRQs across CPU cores for better multi-threaded performance
  services.irqbalance.enable = true;

  # Firmware updates via LVFS (fwupdmgr refresh && fwupdmgr get-updates)
  services.fwupd.enable = true;

  # Faster D-Bus implementation
  services.dbus.implementation = "broker";

  # Hardware sensors (for btop, sensors command)
  hardware.sensor.iio.enable = true;  # Accelerometer, gyroscope, etc.

  # Periodic nix store optimization (hardlinks identical files)
  nix.optimise.automatic = true;

  # Use tmpfs for /tmp (faster, auto-clears on reboot)
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "50%";  # Up to 50% of RAM

  # SSH
  services.openssh.enable = true;

  # Docker
  virtualisation.docker.enable = true;

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

  # Comma - run any program without installing it (e.g., ", cowsay hello")
  programs.nix-index-database.comma.enable = true;
  programs.command-not-found.enable = false;  # Replaced by nix-index

  # dconf - required for GTK/GNOME settings
  programs.dconf.enable = true;

  # AppImage support - allows running AppImages directly
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # nix-ld - allows running unpatched dynamic binaries (needed for BOINC, etc.)
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    # Standard libraries for most binaries
    stdenv.cc.cc.lib
    zlib
    glib
    # CUDA support for BOINC GPU tasks
    cudaPackages.cuda_cudart
    cudaPackages.libcublas
    cudaPackages.libcufft
    # Electron app support (EDHM-UI, etc.)
    nss
    nspr
    alsa-lib
    cups
    libdrm
    mesa
    libgbm
    libxkbcommon
    gtk3
    pango
    cairo
    gdk-pixbuf
    at-spi2-atk
    at-spi2-core
    dbus
    expat
    libxcb
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxshmfence
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

  # Static DNS on home machines (AdGuard primary, Cloudflare fallback)
  # Work laptop (sikt) uses DHCP DNS
  networking.nameservers = lib.mkIf (hostName != "sikt") [ "192.168.0.185" "1.1.1.1" ];
  networking.networkmanager.dns = if hostName == "sikt" then "default" else "none";

  # WireGuard
  networking.wireguard.enable = true;

  # Firewall - open ports for KDE Connect and WireGuard
  networking.firewall = {
    allowedTCPPorts = [ 5900 ];  # VNC (wayvnc)
    allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
    allowedUDPPortRanges = [ { from = 1714; to = 1764; } ];
    allowedUDPPorts = [ 51820 ];  # WireGuard
    checkReversePath = "loose";   # Required for WireGuard
  };

  # Kernel tuning for performance
  boot.kernel.sysctl = {
    # Network performance - BBR congestion control + TCP fastopen
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_fastopen" = 3;  # Enable for both client and server

    # Reduce swap tendency (you have zram + earlyoom)
    "vm.swappiness" = 10;

    # Better SSD performance - don't cache directory entries as long
    "vm.vfs_cache_pressure" = 50;

    # Increase inotify limits (for IDEs, file watchers)
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 1024;
  };

  # Sudo - remember privileges per terminal session
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=-1
  '';

  # Polkit authentication agent
  security.polkit.enable = true;

  # Enable Bluetooth
  hardware.bluetooth.enable = true;
  hardware.ledger.enable = !isWorkHost;  # Ledger hardware wallet udev rules (disabled on work hosts)
  services.blueman.enable = true;

  # All available firmware (broader hardware support)
  hardware.enableAllFirmware = true;

  # Hardware monitoring (lm_sensors package provides 'sensors' command)
  hardware.fancontrol.enable = false;

  # SMART disk monitoring - alerts on disk health issues
  services.smartd = {
    enable = true;
    autodetect = true;
    notifications.wall.enable = true;  # Broadcast warnings to terminals
  };

  # Virtual filesystem support (trash, MTP phones, network mounts in file managers)
  services.gvfs.enable = true;

  # Thumbnail generation for file managers
  services.tumbler.enable = true;

  # mDNS/DNS-SD for local network discovery (find NAS, printers, Chromecast)
  services.avahi = {
    enable = true;
    nssmdns4 = true;  # Allow .local hostname resolution
    openFirewall = true;
  };

  # Printing support
  services.printing = {
    enable = true;
    drivers = [ pkgs.gutenprint pkgs.hplip ];  # Common printer drivers
  };

  # Fast file search (updatedb runs daily, use 'locate' command)
  services.locate = {
    enable = true;
    package = pkgs.plocate;  # Faster than mlocate
    interval = "daily";
  };

  # Auto-mount USB drives and manage disks without root
  services.udisks2.enable = true;

  # Enable Flatpak
  services.flatpak.enable = true;

  # Lemokey keyboard HID access for Lemokey Launcher
  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0666", TAG+="uaccess", TAG+="udev-acl"
  '';

  # Allow passwordless sudo for nixos-rebuild and VPN routing (curitz-vpn split-tunnel)
  security.sudo.extraRules = [
    {
      users = [ "gjermund" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = [ "NOPASSWD" ];
        }
        # Narrow ip rule permissions for curitz-vpn split-tunnel
        {
          command = "/run/current-system/sw/bin/ip rule add *";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/ip rule del *";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/ip -6 rule add *";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/ip -6 rule del *";
          options = [ "NOPASSWD" ];
        }
        # Only allow route replace (not add/del/flush)
        {
          command = "/run/current-system/sw/bin/ip route replace *";
          options = [ "NOPASSWD" ];
        }
        # Allow tee for DNS restore
        {
          command = "/run/current-system/sw/bin/tee /etc/resolv.conf";
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
    SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
    SSH_ASKPASS_REQUIRE = "prefer";
    # Catppuccin Mocha theme for bat
    BAT_THEME = "Catppuccin Mocha";
    # EDMC Modern Overlay - use steam-run wrapper for NixOS compatibility
    EDMC_OVERLAY_PYTHON = "$HOME/.local/share/EDMarketConnector/plugins/EDMCModernOverlay/overlay-python-wrapper.sh";
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
      vivaldi
      .vivaldi-wrapped
    '';
    mode = "0755";
  };

  # Enable Steam (disabled on work hosts)
  programs.steam = lib.mkIf (!isWorkHost) {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;  # Better gamescope integration
    protontricks.enable = true;  # Winetricks wrapper for Proton prefixes
    # Prevent system GIO modules from leaking into Steam's pressure-vessel container
    # Fixes glib version mismatch errors with Proton
    package = pkgs.steam.override {
      extraEnv = {
        GIO_MODULE_DIR = "";
        # Expose locale archive to pressure-vessel containers
        LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
      };
    };
  };

  # Gamescope - Valve's micro-compositor for gaming (disabled on work hosts)
  # Provides resolution scaling, frame limiting, VRR, and HDR support
  programs.gamescope = lib.mkIf (!isWorkHost) {
    enable = true;
    # capSysNice disabled - Steam bypasses the NixOS capability wrapper
    # causing "failed to inherit capabilities" errors
    capSysNice = false;
  };

  # Ananicy-cpp - Auto-nice daemon for process prioritization
  # Automatically adjusts nice/ionice/cgroups for known processes
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos;  # CachyOS community rules
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
    # ═══════════════════════════════════════════════════════════════════════════
    # MODERN CLI TOOLS - Rust-powered replacements for classic Unix utilities
    # ═══════════════════════════════════════════════════════════════════════════
    pkgs.eza           # ls replacement with icons, git integration
    pkgs.bat           # cat replacement with syntax highlighting
    pkgs.glow          # Terminal markdown renderer
    pkgs.fd            # find replacement, faster and more intuitive
    pkgs.ripgrep       # grep replacement, blazingly fast
    pkgs.dust          # du replacement, visual disk usage
    pkgs.duf           # df replacement, modern disk usage
    pkgs.procs         # ps replacement, better process viewer
    pkgs.sd            # sed replacement, simpler syntax
    pkgs.choose        # cut/awk replacement, human-friendly field selection
    pkgs.hyperfine     # Command benchmarking tool
    pkgs.tokei         # Code statistics (lines of code by language)
    pkgs.bottom        # System monitor (alternative to htop/btop)
    pkgs.gping         # ping with graph visualization
    pkgs.doggo         # dig replacement, modern DNS client
    pkgs.hexyl         # Modern hex viewer
    pkgs.delta         # Better git diff viewer
    pkgs.zoxide        # Smart cd that learns your habits
    pkgs.atuin         # Shell history with sync and fuzzy search
    pkgs.direnv        # Per-directory environment variables
    pkgs.nix-direnv    # Direnv integration for Nix
    pkgs.yazi          # Terminal file manager (blazingly fast)
    pkgs.tealdeer      # tldr pages - simplified man pages
    pkgs.navi          # Interactive cheatsheet tool
    pkgs.fzf           # Fuzzy finder

    # ═══════════════════════════════════════════════════════════════════════════
    # SYSTEM INFORMATION & MONITORING
    # ═══════════════════════════════════════════════════════════════════════════
    pkgs.fastfetch     # System info like neofetch but faster
    pkgs.htop          # Interactive process viewer
    pkgs.btop          # System monitor with Catppuccin theme
    pkgs.nvtopPackages.full  # NVIDIA GPU monitor
    pkgs.lm_sensors    # Hardware sensors (run 'sensors' command)
    pkgs.bandwhich     # Network utilization by process
    pkgs.lsof          # List open files

    # ═══════════════════════════════════════════════════════════════════════════
    # GIT TOOLS
    # ═══════════════════════════════════════════════════════════════════════════
    pkgs.git
    pkgs.lazygit       # Terminal UI for git
    pkgs.gh            # GitHub CLI
    pkgs.git-crypt     # Encrypt files in git repos

    # ═══════════════════════════════════════════════════════════════════════════
    # SYSTEM UTILITIES
    # ═══════════════════════════════════════════════════════════════════════════
    pkgs.jq            # JSON processor
    pkgs.yq-go         # YAML processor (like jq but for YAML)
    pkgs.nvd           # Nix/NixOS package version diff tool (used by nh)
    pkgs.bluez         # Package needed for D-Bus files
    pkgs.seahorse      # GNOME keyring GUI + SSH askpass
    pkgs.shared-mime-info  # MIME type database
    pkgs.glib          # For gio and other utilities
    pkgs.traceroute
    pkgs.bind
    pkgs.socat          # For Hyprland socket monitoring (monitor-handler)
    pkgs.wayvnc        # VNC server for Wayland (remote desktop)
    pkgs.rdesktop      # RDP client for Windows Remote Desktop
    pkgs.freerdp       # Modern RDP client (xfreerdp) with NLA/CredSSP support
    pkgs.rclone        # Cloud storage sync (SharePoint, OneDrive, etc.)
    pkgs.unzip
    pkgs.zip
    pkgs.p7zip         # 7zip support
    pkgs.unrar         # RAR archive extraction
    pkgs.python3
    pkgs.tree          # Directory tree visualization
    pkgs.hollywood     # Fake Hollywood hacker terminal
    pkgs.gearlever     # AppImage manager with desktop integration

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
    pkgs.kdePackages.ffmpegthumbs  # Video thumbnails in Dolphin
    pkgs.kdePackages.kdegraphics-thumbnailers  # Image/PDF thumbnails in Dolphin
    pkgs.kdePackages.kio-extras  # Extra thumbnails and file previews
    pkgs.kdePackages.ark  # Archive manager (integrates with Dolphin)
    pkgs.loupe  # GNOME image viewer
    pkgs.kdePackages.kservice  # KDE service framework (kbuildsycoca6)
    pkgs.waybar
    pkgs.pavucontrol  # PulseAudio/PipeWire volume control GUI

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

    # ═══════════════════════════════════════════════════════════════════════════
    # ANIMATED WALLPAPER & VISUAL EFFECTS
    # ═══════════════════════════════════════════════════════════════════════════
    pkgs.swww           # Animated wallpaper daemon with transitions
    pkgs.waypaper       # GUI wallpaper picker with preview
    pkgs.pyprland       # Scratchpads, dropdown terminals, and more

    # ═══════════════════════════════════════════════════════════════════════════
    # MODERN TERMINAL OPTIONS
    # ═══════════════════════════════════════════════════════════════════════════
    pkgs.starship       # Cross-shell prompt (alternative to p10k)

    # ═══════════════════════════════════════════════════════════════════════════
    # DEVELOPMENT ENVIRONMENT TOOLS
    # ═══════════════════════════════════════════════════════════════════════════
    pkgs.devenv         # Fast, declarative development environments
    pkgs.nodejs_22      # Node.js 22 (required for openclaw)

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

    # Theme switcher - shows fuzzel picker and switches theme
    (pkgs.writeShellScriptBin "theme-switcher" ''
      #!/usr/bin/env bash
      THEMES_DIR="$HOME/.local/share/themes"
      CURRENT_FILE="$HOME/.config/current-theme"

      # Get available themes
      if [ ! -d "$THEMES_DIR" ]; then
        ${pkgs.libnotify}/bin/notify-send -u critical "Theme Switcher" "No themes found. Run a rebuild first."
        exit 1
      fi

      themes=$(ls "$THEMES_DIR")

      # Get current theme for display
      current=""
      if [ -f "$CURRENT_FILE" ]; then
        current=$(cat "$CURRENT_FILE")
      fi

      # Show fuzzel picker
      selected=$(echo "$themes" | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt="Theme ($current): ")
      [ -z "$selected" ] && exit 0

      # Don't switch if same theme
      if [ "$selected" = "$current" ]; then
        ${pkgs.libnotify}/bin/notify-send "Theme" "Already using $selected"
        exit 0
      fi

      # Verify theme exists
      if [ ! -d "$THEMES_DIR/$selected" ]; then
        ${pkgs.libnotify}/bin/notify-send -u critical "Theme Switcher" "Theme '$selected' not found"
        exit 1
      fi

      # Copy theme configs to active locations (install -m 644 overwrites read-only files)
      mkdir -p ~/.config/hypr ~/.config/waybar ~/.config/alacritty ~/.config/wlogout ~/.config/fuzzel

      install -m 644 "$THEMES_DIR/$selected/hypr/theme-colors.conf" ~/.config/hypr/theme-colors.conf
      install -m 644 "$THEMES_DIR/$selected/waybar/style.css" ~/.config/waybar/style.css
      install -m 644 "$THEMES_DIR/$selected/alacritty/alacritty.toml" ~/.config/alacritty/alacritty.toml
      install -m 644 "$THEMES_DIR/$selected/wlogout/style.css" ~/.config/wlogout/style.css
      install -m 644 "$THEMES_DIR/$selected/fuzzel/fuzzel.ini" ~/.config/fuzzel/fuzzel.ini
      install -m 644 "$THEMES_DIR/$selected/starship/starship.toml" ~/.config/starship.toml

      # Save current theme preference
      echo "$selected" > "$CURRENT_FILE"

      # Reload apps that support it
      hyprctl reload
      # Restart Waybar to pick up new style (SIGUSR2 doesn't reliably reload CSS)
      pkill waybar 2>/dev/null; sleep 0.2; waybar &

      # Notify success
      ${pkgs.libnotify}/bin/notify-send "Theme" "Switched to $selected"
    '')

    # ═══════════════════════════════════════════════════════════════════════════
    # WALLPAPER MANAGEMENT SCRIPTS
    # ═══════════════════════════════════════════════════════════════════════════

    # Wallpaper setter with animated transitions
    (pkgs.writeShellScriptBin "wallpaper-set" ''
      #!/usr/bin/env bash
      # Set wallpaper with beautiful transition effects
      # Usage: wallpaper-set <path-to-image> [transition-type]

      WALLPAPER="$1"
      TRANSITION="''${2:-wipe}"  # Default: wipe transition

      if [ -z "$WALLPAPER" ]; then
        echo "Usage: wallpaper-set <path-to-image> [transition]"
        echo "Transitions: wipe, wave, grow, center, any, random, simple, outer"
        exit 1
      fi

      if [ ! -f "$WALLPAPER" ]; then
        echo "Error: File not found: $WALLPAPER"
        exit 1
      fi

      # Ensure swww daemon is running
      if ! pgrep -x swww-daemon > /dev/null; then
        ${pkgs.swww}/bin/swww-daemon &
        sleep 0.5
      fi

      # Apply wallpaper with transition
      ${pkgs.swww}/bin/swww img "$WALLPAPER" \
        --transition-type "$TRANSITION" \
        --transition-duration 2 \
        --transition-fps 60 \
        --transition-step 2

      # Save current wallpaper path
      echo "$WALLPAPER" > "$HOME/.config/current-wallpaper"

      ${pkgs.libnotify}/bin/notify-send -t 2000 "Wallpaper" "Applied: $(basename "$WALLPAPER")"
    '')

    # Wallpaper picker using fuzzel with directory browser
    (pkgs.writeShellScriptBin "wallpaper-picker" ''
      #!/usr/bin/env bash
      # GUI wallpaper picker with preview
      # Ensure swww daemon is running
      if ! pgrep -x swww-daemon > /dev/null; then
        ${pkgs.swww}/bin/swww-daemon &
        sleep 0.5
      fi
      # Launch waypaper GUI
      ${pkgs.waypaper}/bin/waypaper --backend swww
    '')

    # Random wallpaper from collection
    (pkgs.writeShellScriptBin "wallpaper-random" ''
      #!/usr/bin/env bash
      WALLPAPER_DIRS=(
        "$HOME/Pictures/Wallpapers"
        "$HOME/Pictures/wallpapers"
        "$HOME/Wallpapers"
      )

      # Collect all wallpapers
      WALLPAPERS=()
      for dir in "''${WALLPAPER_DIRS[@]}"; do
        if [ -d "$dir" ]; then
          while IFS= read -r -d $'\0' file; do
            WALLPAPERS+=("$file")
          done < <(find "$dir" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) -print0 2>/dev/null)
        fi
      done

      if [ ''${#WALLPAPERS[@]} -eq 0 ]; then
        ${pkgs.libnotify}/bin/notify-send "Wallpaper" "No wallpapers found"
        exit 1
      fi

      # Pick random wallpaper
      RANDOM_WALL="''${WALLPAPERS[$RANDOM % ''${#WALLPAPERS[@]}]}"

      # Apply with random transition
      TRANSITIONS=(wipe wave grow center outer)
      RANDOM_TRANS="''${TRANSITIONS[$RANDOM % ''${#TRANSITIONS[@]}]}"

      wallpaper-set "$RANDOM_WALL" "$RANDOM_TRANS"
    '')

    # ═══════════════════════════════════════════════════════════════════════════
    # SYSTEM INFORMATION & DASHBOARD
    # ═══════════════════════════════════════════════════════════════════════════

    # Beautiful system info dashboard (like fastfetch but custom)
    (pkgs.writeShellScriptBin "system-info" ''
      #!/usr/bin/env bash
      # Catppuccin Mocha colors for output
      MAUVE='\033[38;2;203;166;247m'
      PINK='\033[38;2;245;194;231m'
      BLUE='\033[38;2;137;180;250m'
      TEAL='\033[38;2;148;226;213m'
      GREEN='\033[38;2;166;227;161m'
      YELLOW='\033[38;2;249;226;175m'
      PEACH='\033[38;2;250;179;135m'
      TEXT='\033[38;2;205;214;244m'
      SUBTEXT='\033[38;2;166;173;200m'
      RESET='\033[0m'
      BOLD='\033[1m'

      # Get system info
      HOSTNAME=$(hostname)
      KERNEL=$(uname -r)
      UPTIME=$(awk '{d=int($1/86400);h=int($1%86400/3600);m=int($1%3600/60);printf "%dd %dh %dm",d,h,m}' /proc/uptime)
      SHELL_NAME=$(basename "$SHELL")

      # CPU info
      CPU=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')
      CPU_CORES=$(nproc)
      CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}' | cut -d. -f1)

      # Memory info
      MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
      MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
      MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')

      # Disk info
      DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
      DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
      DISK_PERCENT=$(df -h / | awk 'NR==2 {gsub(/%/,""); print $5}')

      # GPU info
      GPU=""
      if command -v nvidia-smi &>/dev/null; then
        GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
      fi

      # NixOS info
      NIXOS_VERSION=$(nixos-version 2>/dev/null || echo "Unknown")
      NIX_GENERATIONS=$(ls -1 /nix/var/nix/profiles/system-* 2>/dev/null | wc -l)

      # Current theme
      CURRENT_THEME="Not set"
      if [ -f "$HOME/.config/current-theme" ]; then
        CURRENT_THEME=$(cat "$HOME/.config/current-theme")
      fi

      # Print dashboard
      echo ""
      printf "''${MAUVE}''${BOLD}╭─────────────────────────────────────────────────────╮''${RESET}\n"
      printf "''${MAUVE}│''${RESET}   ''${PINK}''${BOLD}󰣇 NixOS System Information''${RESET}                       ''${MAUVE}│''${RESET}\n"
      printf "''${MAUVE}╰─────────────────────────────────────────────────────╯''${RESET}\n"
      echo ""
      printf "  ''${BLUE}󰟀 ''${TEXT}Hostname:''${RESET}    %s\n" "$HOSTNAME"
      printf "  ''${TEAL}󰻀 ''${TEXT}Kernel:''${RESET}      %s\n" "$KERNEL"
      printf "  ''${GREEN} ''${TEXT}Uptime:''${RESET}      %s\n" "$UPTIME"
      printf "  ''${YELLOW} ''${TEXT}Shell:''${RESET}       %s\n" "$SHELL_NAME"
      printf "  ''${PEACH}󰏖 ''${TEXT}NixOS:''${RESET}       %s (%d generations)\n" "$NIXOS_VERSION" "$NIX_GENERATIONS"
      printf "  ''${PINK}󰔎 ''${TEXT}Theme:''${RESET}       %s\n" "$CURRENT_THEME"
      echo ""
      printf "''${MAUVE}─────────────────────────────────────────────────────────''${RESET}\n"
      echo ""
      printf "  ''${BLUE}󰍛 ''${TEXT}CPU:''${RESET}         %s\n" "$CPU"
      printf "  ''${SUBTEXT}              %d cores @ %d%% usage''${RESET}\n" "$CPU_CORES" "$CPU_USAGE"
      printf "  ''${GREEN}󰆼 ''${TEXT}Memory:''${RESET}      %s / %s (%d%%)''${RESET}\n" "$MEM_USED" "$MEM_TOTAL" "$MEM_PERCENT"
      printf "  ''${YELLOW}󰋊 ''${TEXT}Disk:''${RESET}        %s / %s (%d%%)''${RESET}\n" "$DISK_USED" "$DISK_TOTAL" "$DISK_PERCENT"
      if [ -n "$GPU" ]; then
        printf "  ''${PEACH}󰢮 ''${TEXT}GPU:''${RESET}         %s\n" "$GPU"
      fi
      echo ""
      printf "''${MAUVE}─────────────────────────────────────────────────────────''${RESET}\n"
      echo ""

      # Color palette preview
      printf "  "
      for i in {0..7}; do
        printf "\033[4%dm   \033[0m" "$i"
      done
      echo ""
      printf "  "
      for i in {0..7}; do
        printf "\033[10%dm   \033[0m" "$i"
      done
      echo ""
      echo ""
    '')

    # Welcome message for new terminal sessions
    (pkgs.writeShellScriptBin "welcome" ''
      #!/usr/bin/env bash
      MAUVE='\033[38;2;203;166;247m'
      PINK='\033[38;2;245;194;231m'
      TEXT='\033[38;2;205;214;244m'
      SUBTEXT='\033[38;2;166;173;200m'
      RESET='\033[0m'
      BOLD='\033[1m'

      # Simple one-liner welcome
      HOUR=$(date +%H)
      if [ "$HOUR" -lt 12 ]; then
        GREETING="Good morning"
      elif [ "$HOUR" -lt 18 ]; then
        GREETING="Good afternoon"
      else
        GREETING="Good evening"
      fi

      echo ""
      printf "  ''${MAUVE}$GREETING, ''${PINK}''${BOLD}$(whoami)''${RESET}''${SUBTEXT} @ $(hostname)''${RESET}\n"
      printf "  ''${SUBTEXT}$(date '+%A, %B %d') | $(awk '{d=int($1/86400);h=int($1%86400/3600);m=int($1%3600/60);if(d>0)printf "%dd %dh",d,h;else if(h>0)printf "%dh %dm",h,m;else printf "%dm",m}' /proc/uptime)''${RESET}\n"
      echo ""
    '')

    # Quick key bindings help
    (pkgs.writeShellScriptBin "keybinds" ''
      #!/usr/bin/env bash
      MAUVE='\033[38;2;203;166;247m'
      PINK='\033[38;2;245;194;231m'
      BLUE='\033[38;2;137;180;250m'
      TEXT='\033[38;2;205;214;244m'
      SUBTEXT='\033[38;2;166;173;200m'
      RESET='\033[0m'
      BOLD='\033[1m'

      echo ""
      printf "''${MAUVE}''${BOLD}╭─────────────────────────────────────────────────────╮''${RESET}\n"
      printf "''${MAUVE}│''${RESET}   ''${PINK}''${BOLD}󰌌 Hyprland Key Bindings''${RESET}                         ''${MAUVE}│''${RESET}\n"
      printf "''${MAUVE}╰─────────────────────────────────────────────────────╯''${RESET}\n"
      echo ""
      printf "  ''${BLUE}''${BOLD}Applications''${RESET}\n"
      printf "  ''${TEXT}Super+T''${RESET}             ''${SUBTEXT}Terminal (Alacritty)''${RESET}\n"
      printf "  ''${TEXT}Super+B''${RESET}             ''${SUBTEXT}Browser (Zen)''${RESET}\n"
      printf "  ''${TEXT}Super+E''${RESET}             ''${SUBTEXT}File Manager (Dolphin)''${RESET}\n"
      printf "  ''${TEXT}Super+R / A''${RESET}         ''${SUBTEXT}App Launcher (Fuzzel)''${RESET}\n"
      printf "  ''${TEXT}Super+C''${RESET}             ''${SUBTEXT}Calculator''${RESET}\n"
      printf "  ''${TEXT}Super+Y''${RESET}             ''${SUBTEXT}Dropdown Terminal''${RESET}\n"
      echo ""
      printf "  ''${BLUE}''${BOLD}Windows''${RESET}\n"
      printf "  ''${TEXT}Super+Q''${RESET}             ''${SUBTEXT}Close window''${RESET}\n"
      printf "  ''${TEXT}Super+F''${RESET}             ''${SUBTEXT}Fullscreen''${RESET}\n"
      printf "  ''${TEXT}Super+W''${RESET}             ''${SUBTEXT}Toggle floating''${RESET}\n"
      printf "  ''${TEXT}Super+J''${RESET}             ''${SUBTEXT}Toggle split direction''${RESET}\n"
      printf "  ''${TEXT}Super+Tab''${RESET}           ''${SUBTEXT}Cycle windows''${RESET}\n"
      printf "  ''${TEXT}Super+Arrows''${RESET}        ''${SUBTEXT}Move focus''${RESET}\n"
      printf "  ''${TEXT}Super+Shift+Arrows''${RESET}  ''${SUBTEXT}Resize window''${RESET}\n"
      printf "  ''${TEXT}Super+Ctrl+Arrows''${RESET}   ''${SUBTEXT}Move window''${RESET}\n"
      echo ""
      printf "  ''${BLUE}''${BOLD}Workspaces''${RESET}\n"
      printf "  ''${TEXT}Super+1-6''${RESET}           ''${SUBTEXT}Switch to workspace''${RESET}\n"
      printf "  ''${TEXT}Super+Shift+1-6''${RESET}     ''${SUBTEXT}Move window to workspace''${RESET}\n"
      printf "  ''${TEXT}Super+D''${RESET}             ''${SUBTEXT}Workspace overview (Expo)''${RESET}\n"
      printf "  ''${TEXT}Super+S''${RESET}             ''${SUBTEXT}Special workspace''${RESET}\n"
      echo ""
      printf "  ''${BLUE}''${BOLD}Utilities''${RESET}\n"
      printf "  ''${TEXT}Super+V''${RESET}             ''${SUBTEXT}Clipboard history''${RESET}\n"
      printf "  ''${TEXT}Super+P''${RESET}             ''${SUBTEXT}Screenshot (region)''${RESET}\n"
      printf "  ''${TEXT}Super+N''${RESET}             ''${SUBTEXT}Notification center''${RESET}\n"
      printf "  ''${TEXT}Super+L''${RESET}             ''${SUBTEXT}Power menu''${RESET}\n"
      printf "  ''${TEXT}Ctrl+Super+Tab''${RESET}      ''${SUBTEXT}Theme switcher''${RESET}\n"
      printf "  ''${TEXT}Super+Shift+W''${RESET}       ''${SUBTEXT}Wallpaper picker''${RESET}\n"
      echo ""
      printf "  ''${BLUE}''${BOLD}Gaming''${RESET}\n"
      printf "  ''${TEXT}Super+G''${RESET}             ''${SUBTEXT}Gaming mode toggle''${RESET}\n"
      echo ""
    '')

    # Waybar toggle script with state tracking
    (pkgs.writeShellScriptBin "waybar-toggle" ''
      #!/usr/bin/env bash
      # Tracks waybar visibility state for other scripts (like gaming mode)
      STATE_FILE="/tmp/waybar-visible"

      # Initialize state file if missing (assume visible on first run)
      if [ ! -f "$STATE_FILE" ]; then
        echo "1" > "$STATE_FILE"
      fi

      CURRENT=$(cat "$STATE_FILE")
      if [ "$CURRENT" = "1" ]; then
        # Currently visible, hide it
        pkill -SIGUSR1 waybar
        echo "0" > "$STATE_FILE"
      else
        # Currently hidden, show it
        pkill -SIGUSR1 waybar
        echo "1" > "$STATE_FILE"
      fi
    '')

    # Gaming mode toggle script
    (pkgs.writeShellScriptBin "gaming-mode-toggle" ''
      #!/usr/bin/env bash
      STATE_FILE="/tmp/gaming-mode-state"
      WAYBAR_STATE="/tmp/waybar-visible"

      # Helper: get waybar visibility from state file
      waybar_is_visible() {
        [ -f "$WAYBAR_STATE" ] && [ "$(cat "$WAYBAR_STATE")" = "1" ]
      }

      # Helper: set waybar visibility (updates state file)
      set_waybar_visible() {
        pkill -SIGUSR1 waybar
        echo "1" > "$WAYBAR_STATE"
      }

      set_waybar_hidden() {
        pkill -SIGUSR1 waybar
        echo "0" > "$WAYBAR_STATE"
      }

      # Check if gaming mode is currently enabled
      if [ -f "$STATE_FILE" ]; then
        # Currently in gaming mode, switch back to normal
        # Only restore panel if we hid it
        if grep -q "panel_was_visible=1" "$STATE_FILE" 2>/dev/null; then
          if ! waybar_is_visible; then
            set_waybar_visible
          fi
        fi
        hyprctl keyword animations:enabled true
        # Restore all blur settings
        hyprctl keyword decoration:blur:enabled true
        hyprctl keyword decoration:blur:size 10
        hyprctl keyword decoration:blur:passes 4
        hyprctl keyword decoration:blur:special true
        hyprctl keyword decoration:blur:popups true
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
        # Track if waybar was visible before we hide it
        PANEL_WAS_VISIBLE=0
        if waybar_is_visible; then
          set_waybar_hidden
          PANEL_WAS_VISIBLE=1
        fi
        hyprctl keyword animations:enabled false
        # Fully disable all blur (window blur, layer blur, special workspace blur, popup blur)
        hyprctl keyword decoration:blur:enabled false
        hyprctl keyword decoration:blur:size 0
        hyprctl keyword decoration:blur:passes 0
        hyprctl keyword decoration:blur:special false
        hyprctl keyword decoration:blur:popups false
        hyprctl keyword decoration:shadow:enabled false
        hyprctl keyword decoration:dim_inactive false
        hyprctl keyword decoration:rounding 0
        hyprctl keyword decoration:active_opacity 1.0
        hyprctl keyword decoration:inactive_opacity 1.0
        hyprctl keyword general:gaps_in 0
        hyprctl keyword general:gaps_out 0
        hyprctl keyword general:border_size 1
        hyprctl keyword 'general:col.active_border' 'rgba(ffffff30)'
        hyprctl keyword 'general:col.inactive_border' 'rgba(00000000)'
        echo "panel_was_visible=$PANEL_WAS_VISIBLE" > "$STATE_FILE"
        ${pkgs.libnotify}/bin/notify-send -u low "Gaming Mode" "Enabled - max performance"
      fi
    '')

    # Monitor hotplug handler - moves Waybar and workspaces when monitors change
    (pkgs.writeShellScriptBin "monitor-handler" ''
      #!/usr/bin/env bash
      # Listens to Hyprland socket for monitor events and handles hotplug
      # Run this at startup via exec-once

      DEBOUNCE_FILE="/tmp/monitor-handler-debounce"

      handle() {
        case $1 in
          monitorremoved*)
            # Debounce - ignore if we just handled an event
            if [ -f "$DEBOUNCE_FILE" ]; then
              LAST=$(cat "$DEBOUNCE_FILE")
              NOW=$(date +%s)
              if [ $((NOW - LAST)) -lt 2 ]; then
                return
              fi
            fi
            date +%s > "$DEBOUNCE_FILE"

            # A monitor was disconnected
            REMOVED="''${1#monitorremoved>>}"

            # Get remaining monitors
            REMAINING=$(hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[0].name')

            if [ -n "$REMAINING" ]; then
              # Move all existing workspaces to remaining monitor
              WORKSPACES=$(hyprctl workspaces -j | ${pkgs.jq}/bin/jq -r '.[].id')
              for ws in $WORKSPACES; do
                hyprctl dispatch moveworkspacetomonitor "$ws $REMAINING" 2>/dev/null
              done

              # Focus the remaining monitor
              hyprctl dispatch focusmonitor "$REMAINING"
            fi

            # Restart Waybar on remaining monitor
            pkill -9 waybar 2>/dev/null
            sleep 0.5
            waybar &
            disown
            ;;
          monitoradded*)
            # Debounce
            if [ -f "$DEBOUNCE_FILE" ]; then
              LAST=$(cat "$DEBOUNCE_FILE")
              NOW=$(date +%s)
              if [ $((NOW - LAST)) -lt 2 ]; then
                return
              fi
            fi
            date +%s > "$DEBOUNCE_FILE"

            # A monitor was connected - wait and reload
            sleep 1
            hyprctl reload

            # Restart Waybar
            pkill -9 waybar 2>/dev/null
            sleep 0.5
            waybar &
            disown
            ;;
        esac
      }

      # Listen to Hyprland socket (socket is in XDG_RUNTIME_DIR)
      SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
      ${pkgs.socat}/bin/socat -U - UNIX-CONNECT:"$SOCKET" | while read -r line; do
        handle "$line"
      done
    '')

    # Lid close handler for laptops - disables internal display when external monitors present
    (pkgs.writeShellScriptBin "lid-handler" ''
      #!/usr/bin/env bash
      # Called by Hyprland bindl for lid switch events
      # Usage: lid-handler open|close

      ACTION="$1"
      INTERNAL="eDP-1"

      # Count external monitors
      EXTERNAL_COUNT=$(hyprctl monitors -j | ${pkgs.jq}/bin/jq "[.[] | select(.name != \"$INTERNAL\")] | length")

      if [ "$ACTION" = "close" ]; then
        if [ "$EXTERNAL_COUNT" -gt 0 ]; then
          # Lid closed with external monitors: disable internal display
          hyprctl keyword monitor "$INTERNAL,disable"
          # Restart Waybar so it moves to external monitor
          pkill waybar; sleep 0.3; waybar &
          ${pkgs.libnotify}/bin/notify-send -t 2000 "Display" "Laptop screen disabled"
        fi
      elif [ "$ACTION" = "open" ]; then
        # Lid opened: re-enable internal display
        hyprctl keyword monitor "$INTERNAL,preferred,auto,1"
        # Restart Waybar to update layout
        pkill waybar; sleep 0.3; waybar &
        ${pkgs.libnotify}/bin/notify-send -t 2000 "Display" "Laptop screen enabled"
      fi
    '')

    # Work applications
    pkgs.teams-for-linux
    pkgs.slack
    pkgs.zoom-us
    pkgs.discord
    pkgs.mattermost-desktop
    pkgs.vivaldi
    pkgs.eduvpn-client
    (pkgs.writeShellScriptBin "outlook" ''
      #!/usr/bin/env bash
      exec vivaldi --app=https://outlook.office.com/mail/ "$@"
    '')

    # Development tools
    pkgs.claude-code
    pkgs.bat
    pkgs.gnome-text-editor  # Simple GUI editor

  ] ++ lib.optionals (!isWorkHost) [
    # ═══════════════════════════════════════════════════════════════════════════
    # GAMING & ENTERTAINMENT (excluded on work hosts)
    # ═══════════════════════════════════════════════════════════════════════════
    (pkgs.callPackage ../curseforge.nix {})
    # Lutris wrapped to prevent glib module conflicts with Proton
    (pkgs.symlinkJoin {
      name = "lutris-wrapped";
      paths = [ pkgs.lutris ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/lutris --set GIO_MODULE_DIR ""
      '';
    })
    (pkgs.retroarch.withCores (cores: with cores; [
      mupen64plus      # Nintendo 64
      parallel-n64     # Nintendo 64 (ParaLLEl - better accuracy, Vulkan)
    ]))
    pkgs.mpv
    pkgs.feishin  # Music player for Jellyfin/Navidrome
    pkgs.qbittorrent
    pkgs.bolt-launcher  # OSRS launcher (RuneLite, HDOS, official client)
    pkgs.edmarketconnector  # Elite Dangerous market data uploader
    # X11 tools for EDMC Modern Overlay window tracking
    pkgs.xorg.xwininfo
    pkgs.xorg.xprop
    pkgs.wmctrl
    pkgs.wineWowPackages.stagingFull
    pkgs.winetricks
  ] ++ [
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

  ] ++ lib.optionals (!isWorkHost) [
    # ═══════════════════════════════════════════════════════════════════════════
    # PERSONAL PACKAGES (excluded on work hosts)
    # ═══════════════════════════════════════════════════════════════════════════

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

    # Image upscaling
    pkgs.upscayl

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
    # pkgs.gridcoin-research  # Gridcoin wallet - TEMPORARILY DISABLED: broken in nixpkgs (bdb53 build failure)
    pkgs.sparrow            # Sparrow Bitcoin wallet
    pkgs.ledger-live-desktop  # Ledger hardware wallet

    # Proton-GE management (auto-update latest version)
    pkgs.protonup-ng
  ] ++ [
    # Flake-based rebuild script
    (pkgs.writeShellScriptBin "nixos-rebuild-flake" ''
      #!/usr/bin/env bash
      set -e

      CONFIG_DIR="/home/gjermund/nix-config"
      SILENT=false

      # Parse arguments
      ARGS=()
      for arg in "$@"; do
        case $arg in
          -s|--silent)
            SILENT=true
            ;;
          *)
            ARGS+=("$arg")
            ;;
        esac
      done

      # Check if we're in a git repo
      if [ ! -d "$CONFIG_DIR/.git" ]; then
        echo "Error: $CONFIG_DIR is not a git repository"
        exit 1
      fi

      # Auto-update CurseForge version from Arch AUR (skip in silent mode)
      if [ "$SILENT" = false ]; then
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
      fi

      # Run nh os switch with flake
      # Detect hostname to select the correct flake output
      HOSTNAME=$(hostname)
      if [ "$SILENT" = true ]; then
        nh os switch -H "$HOSTNAME" "$CONFIG_DIR" "''${ARGS[@]}" || {
          echo "nh os switch failed"
          exit 1
        }
        # Silent mode: skip git operations, exit here
        exit 0
      else
        echo "Running nh os switch for host '$HOSTNAME'..."
        nh os switch --ask -H "$HOSTNAME" "$CONFIG_DIR" "''${ARGS[@]}" || {
          echo "nh os switch failed, not committing changes"
          exit 1
        }
      fi

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
