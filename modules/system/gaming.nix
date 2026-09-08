# Steam, gamescope, ananicy (not on work host); Folding@home (desktop only)
{
  config,
  pkgs,
  lib,
  inputs,
  hostName,
  ...
}:
let
  isWorkHost = hostName == "sikt";
  # Folding@home is desktop-only. On the hybrid laptop, fah-client holds
  # /dev/nvidia0 + /dev/nvidia-uvm open permanently to enumerate the dGPU as a
  # folding slot, which blocks runtime D3cold and burns ~12W at idle on
  # battery — and spikes to 60-80W the moment it gets a GPU work unit.
  foldingHost = hostName == "desktop";
in
{

  # Folding@home client (desktop only — see foldingHost above).
  # Runs fahclient as the 'foldingathome' user; web UI at http://localhost:7396
  services.foldingathome.enable = foldingHost;

  # The upstream nixpkgs foldingathome module sets DynamicUser=true, which
  # implicitly enables PrivateTmp, ProtectSystem=strict, ProtectHome, etc.
  # The downloaded OpenMM GPU cores (FahCore_27 / FahCore_24) can't operate
  # under that sandbox and crash immediately with FAILED_3 (255) and "did
  # not produce any log output". Switch to a static system user.
  # See: https://github.com/NixOS/nixpkgs/issues/304868
  users.users.foldingathome = lib.mkIf foldingHost {
    isSystemUser = true;
    group = "foldingathome";
    description = "Folding@home";
    home = "/var/lib/foldingathome";
  };
  users.groups.foldingathome = lib.mkIf foldingHost { };

  # Expose the NVIDIA userspace driver (libcuda.so) to the bwrap-sandboxed
  # fah-client so the CUDA folding core can find it. /run is bind-mounted
  # into the sandbox, but the dynamic linker won't search
  # /run/opengl-driver/lib unless told.
  systemd.services.foldingathome = lib.mkIf foldingHost {
    environment.LD_LIBRARY_PATH = "/run/opengl-driver/lib:/run/opengl-driver-32/lib";
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "foldingathome";
      Group = "foldingathome";
    };
  };

  # Enable Steam (disabled on work hosts)
  programs.steam = lib.mkIf (!isWorkHost) {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true; # Better gamescope integration
    protontricks.enable = true; # Winetricks wrapper for Proton prefixes
    # Prevent system GIO modules from leaking into Steam's pressure-vessel container
    # Fixes glib version mismatch errors with Proton
    package = pkgs.steam.override {
      extraEnv = {
        GIO_MODULE_DIR = "";
        # Expose locale archive to pressure-vessel containers
        LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
      };
    };
  };

  # Gamescope - Valve's micro-compositor for gaming (disabled on work hosts)
  # Provides resolution scaling, frame limiting, VRR, and HDR support
  programs.gamescope = lib.mkIf (!isWorkHost) {
    enable = true;
    # capSysNice disabled - Steam bypasses the NixOS capability wrapper
    # causing "failed to inherit capabilities" errors
    capSysNice = false;
  };

  # Ananicy-cpp - Auto-nice daemon for process prioritization
  # Automatically adjusts nice/ionice/cgroups for known processes
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos; # CachyOS community rules
  };
}
