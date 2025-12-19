{ config, pkgs, inputs, ... }:
        {
	nixpkgs.config.allowUnfree = true;

	# State version - DON'T change this after initial install
	system.stateVersion = "25.11";
        users.users.gjermund = {
		isNormalUser = true;
                home = "/home/gjermund";
		extraGroups = [ "wheel" ];
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

	# Enable SSH agent and add keys automatically
	programs.ssh = {
		startAgent = true;
		agentTimeout = "1h";
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

        environment.systemPackages = [
		pkgs.git
		pkgs.alacritty
		pkgs.kdePackages.dolphin
		pkgs.spice-vdagent
		pkgs.claude-code
		pkgs.ags
		(pkgs.callPackage ./curseforge.nix {})
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

			# Generate commit message with timestamp
			COMMIT_MSG="NixOS rebuild $(date '+%Y-%m-%d %H:%M:%S')"

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
	};
	in [
	zen-browser.default
	]);
}
