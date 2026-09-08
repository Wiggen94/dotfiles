# Common NixOS configuration shared between all hosts.
# Thin aggregator — the actual configuration lives in ./system/*.nix,
# split by domain. Host-specific config lives in ../hosts/<host>/.
{ lib, hostName, ... }:
{
  imports = [
    ./system/nix.nix
    ./system/boot.nix
    ./system/networking.nix
    ./system/hardware.nix
    ./system/desktop.nix
    ./system/shell.nix
    ./system/gaming.nix
    ./system/users.nix
    ./system/power.nix
    ./system/neovim.nix
    ./system/packages.nix
  ]
  # niri is offered as an alternative session on every host except `sikt`:
  # the work laptop stays Hyprland-only. Dropping the import (rather than
  # setting programs.niri.enable = false) also keeps niri-flake out of that
  # host's evaluation entirely — including the home-manager module it
  # auto-wires, which ./home/niri.nix needs (see modules/home.nix).
  ++ lib.optional (hostName != "sikt") ./system/niri.nix;

  # State version - DON'T change this after initial install
  system.stateVersion = "25.11";
}
