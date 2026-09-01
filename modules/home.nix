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
  ]
  # No niri session on `sikt` (see modules/common.nix) — and without the
  # system module, niri-flake's home-manager module isn't wired in either,
  # so ./home/niri.nix would fail on config.lib.niri.
  ++ lib.optional (hostName != "sikt") ./home/niri.nix;
}
