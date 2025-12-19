{ config, pkgs, inputs, ... }:
let
	nixvim = import (builtins.fetchGit {
		url = "https://github.com/nix-community/nixvim";
	});
in
        {
	nixpkgs.config.allowUnfree = true;

	# State version - DON'T change this after initial install
	system.stateVersion = "25.11";
        users.users.gjermund = {
		isNormalUser = true;
                home = "/home/gjermund";
		extraGroups = [ "wheel" ];
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
		};
		promptInit = ''
			source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
		'';
	};
        imports = [
		/etc/nixos/hardware-configuration.nix
		nixvim.nixosModules.nixvim
        ];
        boot.loader.grub.enable = true;
	boot.loader.grub.device = "/dev/vda";
	services.spice-vdagentd.enable = true;
	services.qemuGuest.enable = true;
	services.openssh.enable = true;
        programs.hyprland.enable = true;

	# Enable Bluetooth (service enabled so HyprPanel doesn't error, but won't do anything in VM)
	hardware.bluetooth.enable = true;
	services.blueman.enable = false;  # Keep blueman GUI disabled for VM

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

	# SSH agent - use NixOS built-in
	programs.ssh = {
		startAgent = true;
		askPassword = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";
		extraConfig = ''
			AddKeysToAgent yes
		'';
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
		};

		# Keymaps
		keymaps = [
			{ mode = "n"; key = "<leader>e"; action = "<cmd>Neotree toggle<CR>"; options.desc = "Toggle file explorer"; }
			{ mode = "n"; key = "<leader>gg"; action = "<cmd>LazyGit<CR>"; options.desc = "LazyGit"; }
			{ mode = "n"; key = "<S-l>"; action = "<cmd>BufferLineCycleNext<CR>"; options.desc = "Next buffer"; }
			{ mode = "n"; key = "<S-h>"; action = "<cmd>BufferLineCyclePrev<CR>"; options.desc = "Previous buffer"; }
			{ mode = "n"; key = "<leader>bd"; action = "<cmd>bdelete<CR>"; options.desc = "Delete buffer"; }
		];
	};

	# Fonts - Nerd Fonts for icons
	fonts.packages = with pkgs; [
		nerd-fonts.jetbrains-mono
		nerd-fonts.fira-code
	];

        environment.systemPackages = [
		# System utilities
		pkgs.git
		pkgs.jq
		pkgs.htop
		pkgs.bluez  # Package needed for D-Bus files, but service disabled
		pkgs.eza  # Modern ls replacement with icons
		pkgs.fzf  # Fuzzy finder
		pkgs.seahorse  # GNOME keyring GUI + SSH askpass

		# Shell (zsh + oh-my-zsh + powerlevel10k)
		pkgs.zsh
		pkgs.oh-my-zsh
		pkgs.zsh-powerlevel10k
		pkgs.zsh-autosuggestions
		pkgs.zsh-syntax-highlighting

		# Desktop environment & UI
		pkgs.alacritty
		pkgs.kdePackages.dolphin
		pkgs.ags
		(pkgs.callPackage ./hyprpanel-no-bluetooth.nix {})  # Custom HyprPanel without bluetooth for VM

		# Icon themes & cursors
		pkgs.papirus-icon-theme  # Icon theme with symbolic icons for HyprPanel
		pkgs.adwaita-icon-theme  # GNOME Adwaita - required for GTK symbolic icons
		pkgs.hicolor-icon-theme  # Fallback icon theme
		pkgs.bibata-cursors      # Standard looking cursor theme

		# Work applications
		pkgs.teams-for-linux
		pkgs.slack
		pkgs.zoom-us
		pkgs.discord
		pkgs.chromium  # For Outlook PWA
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
		pkgs.mpv

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

			# Run nixos-rebuild with sudo (user will enter password)
			echo "Running nixos-rebuild switch..."
			sudo nixos-rebuild switch "$@" || {
				echo "nixos-rebuild failed, not committing changes"
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
