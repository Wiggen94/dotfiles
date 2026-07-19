# Home Manager configuration (shared across hosts).
# Thin aggregator — actual config lives in ./home/*.nix, split by domain.
# Shared helpers (per-host config + theme generators) live in ./home/_common.nix,
# imported directly by the sub-modules that need them.
{ ... }:
{
  imports = [
    ./home/base.nix
    ./home/hyprland.nix
    ./home/desktop.nix
    ./home/programs.nix
    ./home/services.nix
  ];
}
