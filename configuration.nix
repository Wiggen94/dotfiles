{ config, pkgs, lib, inputs, ... }:
let
	nixvim = import (builtins.fetchTarball {
		url = "https://github.com/nix-community/nixvim/archive/main.tar.gz";
	});
	home-manager = builtins.fetchTarball {
		url = "https://github.com/nix-community/home-manager/archive/master.tar.gz";
	};
in
        {
	nixpkgs.config.allowUnfree = true;

	# Enable experimental features for nh and modern nix CLI
	nix.settings.experimental-features = [ "nix-command" "flakes" ];

	# Dolphin overlay to fix "Open with" menu outside KDE (preserves theming)
	nixpkgs.overlays = [ (import ./dolphin-fix.nix) ];

	# State version - DON'T change this after initial install
	system.stateVersion = "25.11";

	# Mount 4TB games drive
	fileSystems."/home/gjermund/games" = {
		device = "/dev/disk/by-uuid/1c7bdee1-0f6d-4181-a13b-a8ee7237949a";
		fsType = "btrfs";
		options = [ "defaults" "nofail" ];
	};

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
			ls = "eza -a --icons";
			ll = "eza -al --icons";
			lt = "eza -a --tree --level=1 --icons";
			cat = "bat";
			nrs = "nixos-rebuild-git";
			nano = "nvim";
		};
		promptInit = ''
			source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
		'';
	};
        imports = [
		/etc/nixos/hardware-configuration.nix
		nixvim.nixosModules.nixvim
		./theming.nix
		./nvidia.nix  # NVIDIA RTX 5070 Ti (safe to include in VM, driver just won't load)
		(import "${home-manager}/nixos")
        ];

	# Home Manager configuration
	home-manager.useGlobalPkgs = true;
	home-manager.useUserPackages = true;
	home-manager.users.gjermund = import ./home.nix;
        #boot.loader.grub.enable = true;
	#boot.loader.grub.device = "/dev/sdc1";
	boot.loader.systemd-boot.enable = true;
	services.spice-vdagentd.enable = true;
	services.qemuGuest.enable = true;
	services.openssh.enable = true;
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

	# NetworkManager
	networking.networkmanager.enable = true;
	networking.networkmanager.plugins = [
		pkgs.networkmanager-openvpn
		pkgs.networkmanager-l2tp
	];

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
	services.blueman.enable = true;

	# Allow passwordless sudo for nixos-rebuild (for automation)
	security.sudo.extraRules = [
		{
			users = [ "gjermund" ];
			commands = [
				{
					command = "/run/current-system/sw/bin/nixos-rebuild";
					options = [ "NOPASSWD" ];
				}
			];
		}
	];

	# Enable SDDM display manager with auto-login
	services.displayManager.sddm = {
		enable = true;
		wayland.enable = true;
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

		# Colorscheme
		colorschemes.tokyonight = {
			enable = true;
			settings.style = "night";
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
		pkgs.nvd  # Nix/NixOS package version diff tool (used by nh)
		pkgs.bluez  # Package needed for D-Bus files, but service disabled
		pkgs.eza  # Modern ls replacement with icons
		pkgs.fzf  # Fuzzy finder
		pkgs.seahorse  # GNOME keyring GUI + SSH askpass
		pkgs.shared-mime-info  # MIME type database
		pkgs.glib  # For gio and other utilities
    		pkgs.traceroute
		pkgs.bind

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
		pkgs.ags
		pkgs.hyprpanel

		# Clipboard & Screenshots
		pkgs.wl-clipboard  # Wayland clipboard utilities
		pkgs.cliphist  # Clipboard history manager
		pkgs.wl-clip-persist  # Keep clipboard after programs close
		pkgs.grim  # Screenshot utility
		pkgs.slurp  # Region selection
		pkgs.libnotify  # For notifications (notify-send)

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

		# Gaming mode toggle script
		(pkgs.writeShellScriptBin "gaming-mode-toggle" ''
			#!/usr/bin/env bash
			STATE_FILE="/tmp/gaming-mode-state"

			# Check if gaming mode is currently enabled
			if [ -f "$STATE_FILE" ]; then
				# Currently in gaming mode, switch back to normal
				# Only restore panel if we hid it
				if grep -q "panel_hidden=1" "$STATE_FILE" 2>/dev/null; then
					hyprpanel t bar-0
				fi
				hyprctl keyword animations:enabled true
				hyprctl keyword decoration:blur:enabled true
				hyprctl keyword decoration:shadow:enabled true
				hyprctl keyword decoration:rounding 12
				hyprctl keyword general:gaps_in 6
				hyprctl keyword general:gaps_out 12
				hyprctl keyword general:border_size 2
				hyprctl keyword 'general:col.active_border' 'rgba(cba6f7ff) rgba(f5c2e7ff) 45deg'
				hyprctl keyword 'general:col.inactive_border' 'rgba(313244aa)'
				rm -f "$STATE_FILE"
				${pkgs.libnotify}/bin/notify-send -u low "Gaming Mode" "Disabled"
			else
				# Currently normal mode, switch to gaming mode
				# Check if panel is visible (layer surface with namespace bar-0 exists)
				PANEL_HIDDEN=0
				if hyprctl layers | grep -q "namespace: bar-0"; then
					hyprpanel t bar-0
					PANEL_HIDDEN=1
				fi
				hyprctl keyword animations:enabled false
				hyprctl keyword decoration:blur:enabled false
				hyprctl keyword decoration:shadow:enabled false
				hyprctl keyword decoration:rounding 0
				hyprctl keyword general:gaps_in 0
				hyprctl keyword general:gaps_out 0
				hyprctl keyword general:border_size 1
				hyprctl keyword 'general:col.active_border' 'rgba(ffffff10)'
				hyprctl keyword 'general:col.inactive_border' 'rgba(00000000)'
				echo "panel_hidden=$PANEL_HIDDEN" > "$STATE_FILE"
				${pkgs.libnotify}/bin/notify-send -u low "Gaming Mode" "Enabled"
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
		pkgs.vscode
		pkgs.gnome-text-editor  # Simple GUI editor

		# Gaming & Entertainment
		(pkgs.callPackage ./curseforge.nix {})
		pkgs.lutris
		pkgs.mpv
		pkgs.wineWowPackages.stagingFull
		pkgs.winetricks

		# Work tools (Sikt/Zino)
		(pkgs.callPackage ./curitz.nix {})

		# 3D Printing
		pkgs.bambu-studio

		# Cryptocurrency
		pkgs.gridcoin-research  # Gridcoin wallet

		# Proton-GE management (auto-update latest version)
		pkgs.protonup-ng

		# VM tools
		pkgs.spice-vdagent
		(pkgs.writeShellScriptBin "nixos-rebuild-git" ''
			#!/usr/bin/env bash
			set -e

			CONFIG_DIR="/home/gjermund/nix-config"

			# Check if we're in a git repo
			if [ ! -d "$CONFIG_DIR/.git" ]; then
				echo "Error: $CONFIG_DIR is not a git repository"
				exit 1
			fi

			# Run nh os switch with classic config (--ask shows diff and confirms)
			echo "Running nh os switch..."
			nh os switch --ask -f '<nixpkgs/nixos>' -- -I nixos-config="$CONFIG_DIR/configuration.nix" "$@" || {
				echo "nh os switch failed, not committing changes"
				exit 1
			}

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
				elif echo "$CHANGED_FILES" | grep -q "hyprpanel"; then
					COMMIT_MSG="Update HyprPanel config"
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
	] ++ (let zen-browser = import (builtins.fetchTarball "https://github.com/youwen5/zen-browser-flake/archive/master.tar.gz") {
	inherit pkgs;
	system = pkgs.stdenv.hostPlatform.system;
	};
	in [
	zen-browser.default
	]);
}
