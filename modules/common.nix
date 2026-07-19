# Common NixOS configuration shared between all hosts.
# Thin aggregator — the actual configuration lives in ./system/*.nix,
# split by domain. Host-specific config lives in ../hosts/<host>/.
{ ... }:
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
  ];

  # State version - DON'T change this after initial install
  system.stateVersion = "25.11";
}
