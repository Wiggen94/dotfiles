# Desktop services: keyring, file services, printing, docker, 1Password
# (portals are owned by omarchy — see modules/omarchy.nix)
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

  # Claude Desktop (official Linux build, via inputs.claude-desktop).
  # Cowork runs sessions in a QEMU/KVM VM; the module links the OVMF firmware
  # and virtiofsd into the FHS paths the app hardcodes and adds users to kvm
  # (needs a re-login to take effect).
  programs.claude-desktop = {
    enable = true;
    # NVIDIA Blackwell open driver + kernel 6.18+: V8's memory protection keys
    # SEGV the bundled Electron, so keep PKU off. Carried over from the old
    # stslex repack; drop it once a launch without it is confirmed stable.
    # A wrapper on top, not overrideAttrs, so the base package keeps its
    # danielbodart.cachix.org hash. The .desktop Exec points at the base
    # package's bin, so it is re-pointed at the wrapper.
    package =
      let
        base = inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop;
        desktopFile = "share/applications/com.anthropic.Claude.desktop";
      in
      pkgs.symlinkJoin {
        name = "claude-desktop-${base.version}";
        inherit (base) version meta;
        paths = [ base ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          rm $out/bin/claude-desktop $out/${desktopFile}
          makeWrapper ${base}/bin/claude-desktop $out/bin/claude-desktop \
            --add-flags --js-flags=--no-memory-protection-keys
          substitute ${base}/${desktopFile} $out/${desktopFile} \
            --replace-fail "Exec=${base}/bin/claude-desktop" "Exec=$out/bin/claude-desktop"
        '';
      };
    cowork = {
      enable = true;
      users = [ "gjermund" ];
    };
  };

  # Claude Desktop Cowork backend (Dispatch + socket-based session management).
  # Built for the old macOS-repack app; kept until the official build's own
  # Cowork VM is confirmed working, then likely removable.
  services.claude-cowork = {
    enable = true;
    extraPath = [ pkgs.claude-code ];
    # Set explicitly so the input's own default is never evaluated. That
    # default reads `flake.packages.${pkgs.system}`, and `pkgs.system` is a
    # nixpkgs alias that warns ("'system' has been renamed to/replaced by
    # 'stdenv.hostPlatform.system'") on every evaluation. Same package the
    # default resolves to; drop this once the input switches to hostPlatform.
    package = inputs.claude-cowork-service.packages.${pkgs.stdenv.hostPlatform.system}.claude-cowork-service;
  };

  # Enable gnome-keyring for secrets (but disable its SSH agent)
  services.gnome.gnome-keyring.enable = true;
  services.gnome.gcr-ssh-agent.enable = false;

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
      helium
    '';
    mode = "0755";
  };

  # omarchy-theme-set-browser writes a BrowserThemeColor policy on every theme
  # switch, which applies a *managed* theme and locks the user out of changing
  # the browser theme ("managed by organization") — Helium reads the same
  # /etc/chromium/policies path and inherited it. The writer is shadowed to a
  # no-op in modules/omarchy-hm.nix; these rules clear what it left behind.
  # They run at every activation and boot, and `r` on an absent path is a no-op.
  # environment.etc cannot do this — it only ever removes symlinks it owns
  # under /etc/static, never a foreign regular file like these.
  systemd.tmpfiles.rules = [
    "r /etc/chromium/policies/managed/color.json"
    "r /etc/brave/policies/managed/color.json"
  ];

}
