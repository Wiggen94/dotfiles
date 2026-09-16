# KDE Plasma 6 — offered as an ALTERNATIVE session alongside Hyprland and
# niri (pick "Plasma (Wayland)" at the SDDM greeter). Hyprland stays the
# default session: omarchy-nix sets
# `services.displayManager.defaultSession = "hyprland-uwsm"` at normal
# priority, which beats plasma6's `mkDefault "plasma"`, so enabling this
# module changes nothing about how the machine boots — it only adds an
# entry to the greeter's session list.
{
  lib,
  pkgs,
  ...
}:
{
  services.desktopManager.plasma6.enable = true;

  # Both omarchy-nix and the plasma6 module define `sddm.package` at normal
  # priority with the *same* value (kdePackages.sddm), which is still a
  # conflict for a unique option. Force the value both of them want.
  services.displayManager.sddm.package = lib.mkForce pkgs.kdePackages.sddm;
}
