# Omarchy 4 (quattro) shell trial — desktop only.
#
# Takes over the desktop stack: SDDM (greetd off), zplug zsh (Oh-My-Zsh off),
# quickshell-based shell, and Hyprland config generation. The user's
# keybindings and looknfeel are preserved via omarchy-hm.nix, which takes over
# the hypr/hm.lua layer (loaded last — its binds win) and reuses the shared
# Lua fragments from modules/home/_common.nix.
#
# Rollback: nixos-rebuild switch --rollback && git revert
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
      enable = false; # no light-theme switching on the desktop
    };
    # NOT enabled: omarchy's nvidia.nix sets the removed
    # `hardware.opengl.driSupport` option, which nixpkgs 25.11 asserts
    # against (mkRemovedOptionModule — any definition errors). Everything
    # that module provides is already covered by hosts/desktop/nvidia.nix
    # (videoDrivers, modesetting, open, nvidiaSettings, package, extraPackages,
    # sessionVariables — identical or mkForce'd above); its only unique adds
    # (nvtop, WLR_* env vars) are already installed / inert on Hyprland.
    nvidia.enable = false;
    browser = "chromium"; # omarchy's default; zen stays the user's browser via BROWSER env + mimeapps
    terminal = "alacritty";
  };

  # Tier 1: display manager + zsh. The user's choices (greetd, Oh-My-Zsh) are
  # overridden by omarchy's (SDDM, zplug) per the trial's user decisions.
  services.greetd.enable = lib.mkForce false;
  programs.zsh.ohMyZsh.enable = lib.mkForce false;

  # Tier 1: xdg portal. The user's desktop.nix lists the nixpkgs
  # xdg-desktop-portal-hyprland and omarchy's HM module adds its own git build
  # (portalPackage) — both ship the same user unit name, which makes the
  # user-units derivation fail with "File exists". Keep the GTK/KDE portals,
  # swap in omarchy's newer git xdph, drop the nixpkgs one.
  xdg.portal.extraPortals = lib.mkForce [
    pkgs.xdg-desktop-portal-gtk
    pkgs.kdePackages.xdg-desktop-portal-kde
    config.programs.hyprland.portalPackage
  ];

  # Tier 1: NVIDIA. omarchy's nvidia.nix sets `open = mkDefault false` (the
  # user's plain `true` wins) but `package` (stable) and `powerManagement`
  # (true) are plain — mkForce the user's choices back. modesetting +
  # videoDrivers merge value-identically.
  hardware.nvidia.package = lib.mkForce config.boot.kernelPackages.nvidiaPackages.latest;
  hardware.nvidia.powerManagement.enable = lib.mkForce false;

  # The user's home-manager config stays the base; omarchy's HM modules and
  # the conflict-resolution port (mkForces, hm.lua, shadow, monitors seed)
  # are added on top.
  home-manager.users.gjermund.imports = [
    inputs.omarchy-nix.homeManagerModules.default
    ./omarchy-hm.nix
  ];
}
