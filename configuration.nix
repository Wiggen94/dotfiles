{ config, pkgs, inputs, ... }:
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

	# Enable gnome-keyring for SSH key management
	services.gnome.gnome-keyring.enable = true;
	security.pam.services.sddm.enableGnomeKeyring = true;

	# SSH config (agent provided by gnome-keyring)
	programs.ssh = {
		startAgent = false;  # gnome-keyring provides the agent
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
