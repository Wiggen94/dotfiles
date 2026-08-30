# User account, sudo, polkit, ssh agent, session/env variables
{
  config,
  pkgs,
  lib,
  inputs,
  hostName,
  ...
}:
{

  # Enforce declarative password management
  users.mutableUsers = false;

  users.users.gjermund = {
    isNormalUser = true;
    home = "/home/gjermund";
    # 0711, not the default 0700: the SDDM greeter (user "sddm") and libvirt's
    # "qemu-libvirtd" both need to *traverse* $HOME to reach files they're
    # otherwise granted (the omarchy greeter theme under ~/.local/share/sddm,
    # the Windows VM disk image). That was done with per-user POSIX ACLs
    # (modules/omarchy-hm.nix, modules/system/vm-passthrough.nix), but every
    # `nixos-rebuild switch` re-runs `chmod 0700 ~` in user activation, which
    # recomputes the ACL mask down to `---` and silently kills those grants —
    # the greeter then can't read Main.qml and falls back to the stock theme.
    # `o+x` (traverse, not list/read) survives any chmod and needs no ACL.
    homeMode = "0711";
    extraGroups = [
      "wheel"
      "docker"
      "onepassword"
      "networkmanager"
      "video" # backlight brightness write access (brightnessctl udev rule)
    ];
    hashedPassword = "$6$XJUUySKdUJMXg4mp$TZE6y2N/t0U./GvhLlC8WNY1T8GIW9bedUENaGuKbd8BcTxLbAlvzAvD6tnsxaTH1oROOWGStReyPMK4ldyUJ/";
    shell = pkgs.zsh;
  };

  # Sudo - remember privileges per terminal session
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=30
  '';

  # Polkit authentication agent
  security.polkit.enable = true;

  # Hyprland runs outside a logind session (compositor lands in cgroup 0::/,
  # so `loginctl` reports its children as belonging to no session). That makes
  # udisks2's allow_active=yes path unreachable, so mounting a USB in Dolphin
  # falls back to allow_any=auth_admin and fails with "PolicyKit authentication
  # system appears to be not available" (no agent can register without a session).
  # Grant udisks2 device actions to the wheel group unconditionally so removable
  # media mounts/unmounts/unlocks without a password prompt.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      // Removable-media actions only — NOT a blanket grant on all udisks2.*
      // (which would also cover format/modify/loop-setup). Kept unconditional
      // for wheel because Hyprland has no active logind session, so an
      // allow_active/subject.active check would fail and break USB mounting.
      var allowed = [
        "org.freedesktop.udisks2.filesystem-mount",
        "org.freedesktop.udisks2.filesystem-mount-system",
        "org.freedesktop.udisks2.filesystem-unmount-others",
        "org.freedesktop.udisks2.encrypted-unlock",
        "org.freedesktop.udisks2.eject-media",
        "org.freedesktop.udisks2.power-off-drive"
      ];
      if (allowed.indexOf(action.id) !== -1 && subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  # Allow passwordless sudo for nixos-rebuild and evsieve (input remapping)
  security.sudo.extraRules = [
    {
      users = [ "gjermund" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/evsieve";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # SSH agent - disabled, 1Password handles SSH auth (SSH_AUTH_SOCK points to 1Password socket)
  programs.ssh = {
    startAgent = false;
    askPassword = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";
  };

  # Set SSH_ASKPASS for GUI prompts
  environment.sessionVariables = {
    # Hint Electron/Chromium apps to use Wayland (all hosts; was per-GPU-file)
    NIXOS_OZONE_WL = "1";
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
}
