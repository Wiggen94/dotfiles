# Desktop services: greetd, portal, keyring, file services, printing, docker, 1Password
{
  config,
  pkgs,
  lib,
  inputs,
  hostName,
  ...
}:
{

  # Faster D-Bus implementation
  services.dbus.implementation = "broker";

  # Docker
  virtualisation.docker.enable = true;

  # Hyprland
  programs.hyprland.enable = true;

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

  # Virtual filesystem support (trash, MTP phones, network mounts in file managers)
  services.gvfs.enable = true;

  # Thumbnail generation for file managers
  services.tumbler.enable = true;

  # Printing support
  services.printing = {
    enable = true;
    drivers = [
      pkgs.gutenprint
      pkgs.hplip
    ]; # Common printer drivers
  };

  # Fast file search (updatedb runs daily, use 'locate' command)
  services.locate = {
    enable = true;
    package = pkgs.plocate; # Faster than mlocate
    interval = "daily";
  };

  # Auto-mount USB drives and manage disks without root
  services.udisks2.enable = true;

  # Enable Flatpak
  services.flatpak.enable = true;

  # Claude Desktop Cowork backend (Dispatch + socket-based session management)
  services.claude-cowork = {
    enable = true;
    extraPath = [ pkgs.claude-code ];
  };

  # greetd with tuigreet — simple terminal-based login, no GPU/GTK dependencies
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --asterisks --remember --remember-session --cmd start-hyprland";
        user = "greeter";
      };
    };
  };

  # Enable gnome-keyring for secrets (but disable its SSH agent)
  services.gnome.gnome-keyring.enable = true;
  services.gnome.gcr-ssh-agent.enable = false;
  security.pam.services.greetd.enableGnomeKeyring = true;
  security.pam.services.login = { }; # PAM for quickshell lockscreen

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
      vivaldi-bin
      zen
      .zen-wrapped
    '';
    mode = "0755";
  };

  # KF6 moved applications.menu out of kservice and into plasma-workspace
  # (renamed to plasma-applications.menu). Outside a Plasma session, Dolphin's
  # "Open With" is empty. Fix: install plasma-workspace (provides
  # plasma-applications.menu in XDG_CONFIG_DIRS via /run/current-system/sw/etc/xdg)
  # and set XDG_MENU_PREFIX=plasma- so KService looks for the plasma- variant.
  # See: https://github.com/NixOS/nixpkgs/issues/409986
  environment.sessionVariables.XDG_MENU_PREFIX = "plasma-";
}
