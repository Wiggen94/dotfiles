# Home Manager configuration (shared across hosts).
# Thin aggregator — actual config lives in ./home/*.nix, split by domain.
# Shared helpers (per-host config + theme generators) live in ./home/_common.nix,
# imported directly by the sub-modules that need them.
{ lib, hostName, ... }:
{
  imports = [
    ./home/base.nix
    ./home/desktop.nix
    ./home/programs.nix
    ./home/services.nix
    ./home/claude-settings.nix
    ./home/claude-mcp.nix
    ./home/claude-codegraph.nix
    ./home/pi-settings.nix
    ./home/omarchy-qt612.nix
  ];
}
