# Omarchy 4 (quattro) shell — all hosts.
#
# Takes over the desktop stack: SDDM (greetd off), zplug zsh (Oh-My-Zsh off),
# quickshell-based shell, and Hyprland config generation. The user's
# keybindings and looknfeel are preserved via omarchy-hm.nix, which takes over
# the hypr/hm.lua layer (loaded last — its binds win) and reuses the shared
# Lua fragments from modules/home/_common.nix.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [ inputs.omarchy-nix.nixosModules.default ];

  omarchy = {
    username = "gjermund";
    full_name = "Gjermund Wiggen";
    email_address = "gjermund.wiggen@sikt.no";
    theme = "catppuccin";
    scale = 1;
    # Framework keybindings are off anyway (shadow file in omarchy-hm.nix);
    # keep this empty so the generated bindings.lua binds nothing.
    quick_app_bindings = [ ];
    light_theme_detection = {
      enable = false; # no light-theme switching
    };
    # omarchy's docker_protection inserts a DROP-all rule into Docker's
    # DOCKER-USER chain (only intra-docker/host/established allowed), which
    # cuts ALL container internet access — including the trading firm's
    # LLM API calls. Disable it; the firm's containers need egress.
    firewall.docker_protection = false;
    # NOT enabled: omarchy's nvidia.nix sets the removed
    # `hardware.opengl.driSupport` option, which nixpkgs 25.11 asserts
    # against (mkRemovedOptionModule — any definition errors). Everything
    # that module provides is already covered by the per-host GPU modules
    # (hosts/desktop/nvidia.nix, hosts/laptop/nvidia-prime.nix,
    # hosts/sikt/intel-graphics.nix); its only unique adds (nvtop, WLR_*
    # env vars) are already installed / inert on Hyprland.
    nvidia.enable = false;
    browser = "chromium"; # omarchy's default; zen stays the user's browser via BROWSER env + mimeapps
    terminal = "alacritty";
  };

  # Trim omarchy's default app suite: modules/packages.nix installs these
  # unconditionally with no enable switch. Stubbing beats patching the pinned
  # input — the change stays local and survives upstream bumps. The real
  # packages leave the closure entirely (github-desktop takes its ~2 GiB CEF
  # with it); the error message surfaces any omarchy feature that still calls
  # one of them (the framework's own binds are already dropped by the shadow
  # in omarchy-hm.nix, and nothing autostarts these).
  # chromium is special: nixpkgs' electron (VSCode, CurseForge) builds from
  # chromium.override, so the stub forwards override/overrideAttrs to the real
  # derivation — Electron keeps building, the installed browser is the stub.
  nixpkgs.overlays = [
    (final: prev: {
      chromium = (final.writeShellScriptBin "chromium" "echo 'chromium: removed in modules/omarchy.nix' >&2; exit 1") // {
        override = args: prev.chromium.override args;
        overrideAttrs = f: prev.chromium.overrideAttrs f;
      };
      github-desktop = final.writeShellScriptBin "github-desktop" "echo 'github-desktop: removed in modules/omarchy.nix' >&2; exit 1";
      krita = final.writeShellScriptBin "krita" "echo 'krita: removed in modules/omarchy.nix' >&2; exit 1";
      signal-desktop = final.writeShellScriptBin "signal-desktop" "echo 'signal-desktop: removed in modules/omarchy.nix' >&2; exit 1";
      obs-studio = final.writeShellScriptBin "obs-studio" "echo 'obs-studio: removed in modules/omarchy.nix' >&2; exit 1";
      vlc = final.writeShellScriptBin "vlc" "echo 'vlc: removed in modules/omarchy.nix' >&2; exit 1";
      pinta = final.writeShellScriptBin "pinta" "echo 'pinta: removed in modules/omarchy.nix' >&2; exit 1";
      spotify = final.writeShellScriptBin "spotify" "echo 'spotify: removed in modules/omarchy.nix' >&2; exit 1";
      # dropbox's FHS env drags in firefox-bin (~310 MiB) — both leave.
      dropbox = final.writeShellScriptBin "dropbox" "echo 'dropbox: removed in modules/omarchy.nix' >&2; exit 1";
    })
  ];

  # Tier 1: display manager + zsh. The user's choices (greetd, Oh-My-Zsh) are
  # overridden by omarchy's (SDDM, zplug).
  services.greetd.enable = lib.mkForce false;
  programs.zsh.ohMyZsh.enable = lib.mkForce false;
  # These also auto-add their packages/init via programs.zsh (shell.nix) —
  # zplug owns zsh. autosuggestions comes from omarchy's own zsh module;
  # syntax-highlighting is a zplug plugin in omarchy-hm.nix (it must load
  # after zplug, which the /etc/zshrc init can't guarantee).
  programs.zsh.autosuggestions.enable = lib.mkForce false;
  programs.zsh.syntaxHighlighting.enable = lib.mkForce false;

  # Tier 1: SDDM greeter. omarchy-nix sets `theme = "omarchy"` (a NAME) but
  # nixpkgs 25.11 dropped themePackages, and omarchy's extraPackages wiring
  # only puts the theme in sddm's environment — never the themes dir — so the
  # greeter silently fell back to a stock theme. The theme option accepts a
  # full path: point it at a writable copy that follows the active omarchy
  # theme via omarchy-sddm-sync (boot activation + theme-set hook).
  services.displayManager.sddm.theme = lib.mkForce "${config.home-manager.users.gjermund.home.homeDirectory}/.local/share/sddm/themes/omarchy";

  # omarchy's HM modules keep claiming real files the old setup left on disk
  # (user-dirs.dirs, alacritty.toml, gh config.yml, ...). Live tools re-create
  # these at login/runtime, so plain backups became whack-a-mole: the first
  # activation renames the file to <file>.pre-omarchy, the next one FATALs the
  # whole activation with "would be clobbered" because that backup name is
  # occupied again.
  #
  # backupCommand makes this self-healing: with it set, HM's collision check
  # skips real files entirely (check-link-targets.sh only errors when no
  # backup command is configured) and the link engine hands the move to this
  # wrapper, which rotates any occupied <file>.pre-omarchy aside with a
  # timestamp before backing the live file up. Every activation completes
  # whatever the live files look like; nothing is ever lost.
  home-manager.backupFileExtension = "pre-omarchy";
  home-manager.backupCommand = pkgs.writeShellScript "hm-backup-rotate" ''
    target="$1"
    backup="$target.${config.home-manager.backupFileExtension}"
    if [ -e "$backup" ]; then
      i="$(date +%s)"
      while [ -e "$backup.$i" ]; do i="$((i + 1))"; done
      mv "$backup" "$backup.$i"
    fi
    mv "$target" "$backup"
  '';

  # Tier 1: xdg portal. The shared desktop.nix lists the nixpkgs
  # xdg-desktop-portal-hyprland and omarchy's HM module adds its own git build
  # (portalPackage) — both ship the same user unit name, which makes the
  # user-units derivation fail with "File exists". Keep the GTK/KDE portals,
  # swap in omarchy's newer git xdph, drop the nixpkgs one.
  xdg.portal.extraPortals = lib.mkForce [
    pkgs.xdg-desktop-portal-gtk
    pkgs.kdePackages.xdg-desktop-portal-kde
    config.programs.hyprland.portalPackage
    # For the niri session (modules/system/niri.nix): niri has no portal of
    # its own, so screencast/screenshot fall back to the GNOME portal. Inert
    # under Hyprland — the portal frontend keys on XDG_CURRENT_DESKTOP, which
    # niri sets to "niri" and Hyprland to "Hyprland", so each session picks
    # its own backend.
    pkgs.xdg-desktop-portal-gnome
  ];

  # Icons follow the theme: omarchy themes ship an icons.theme naming a Yaru
  # accent variant (Yaru-blue, Yaru-purple, ...) which a theme-set hook
  # applies via dconf (the gsettings path is dead on NixOS — no
  # gsettings-desktop-schemas; see omarchy-hm.nix). Install the Yaru icon
  # set so those names resolve. ark stays because the user's mimeapps
  # reference org.kde.ark.desktop for archives.
  environment.systemPackages = [
    pkgs.yaru-theme
    pkgs.kdePackages.ark
  ];

  # The user's home-manager config stays the base; omarchy's HM modules and
  # the conflict-resolution port (mkForces, hm.lua, shadow, monitors seed)
  # are added on top.
  home-manager.users.gjermund.imports = [
    inputs.omarchy-nix.homeManagerModules.default
    ./omarchy-hm.nix
  ];
}
