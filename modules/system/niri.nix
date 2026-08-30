# niri — scrollable-tiling Wayland compositor, offered as an ALTERNATIVE to
# Hyprland on every host. This module only makes niri installable and
# selectable at the SDDM greeter (a "Niri" session); Hyprland stays the
# default and is completely untouched. The user-level config — keybinds
# ported 1:1 from the Hyprland setup, outputs, autostart — lives in
# modules/home/niri.nix.
{
  pkgs,
  inputs,
  ...
}:
{
  imports = [ inputs.niri.nixosModules.niri ];

  # Installs niri, the wayland-session file (SDDM shows "Niri"), polkit and
  # portal wiring. Does not change the default session.
  programs.niri.enable = true;

  # nixpkgs' own niri, not niri-flake's bundled package: both niri-flake's
  # niri-stable (v25.08) and its niri-unstable pin still build against
  # libdisplay-info_0_2, which nixos-unstable has removed. nixpkgs tracks niri
  # closely (currently 26.04) and, being built from this same nixpkgs, always
  # links the right deps. niri-flake is kept only for its NixOS + home-manager
  # config modules (the typed programs.niri.settings in modules/home/niri.nix).
  programs.niri.package = pkgs.niri;

  # The niri session reuses the omarchy quickshell shell (bar, launcher, menu,
  # notifications, clipboard, wallpaper, lock, polkit) — all installed already
  # by omarchy-nix — so the only thing niri needs on top is Xwayland.
  environment.systemPackages = [ pkgs.xwayland-satellite ];
}
