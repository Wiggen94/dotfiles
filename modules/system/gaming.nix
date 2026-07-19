# Steam, gamescope, ananicy, Folding@home (excluded on work host)
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
in
{

  # Folding@home client (disabled on work host).
  # Runs fahclient as the 'foldingathome' user; web UI at http://localhost:7396
  services.foldingathome.enable = !isWorkHost;

  # The upstream nixpkgs foldingathome module sets DynamicUser=true, which
  # implicitly enables PrivateTmp, ProtectSystem=strict, ProtectHome, etc.
  # The downloaded OpenMM GPU cores (FahCore_27 / FahCore_24) can't operate
  # under that sandbox and crash immediately with FAILED_3 (255) and "did
  # not produce any log output". Switch to a static system user.
  # See: https://github.com/NixOS/nixpkgs/issues/304868
  users.users.foldingathome = lib.mkIf (!isWorkHost) {
    isSystemUser = true;
    group = "foldingathome";
    description = "Folding@home";
    home = "/var/lib/foldingathome";
  };
  users.groups.foldingathome = lib.mkIf (!isWorkHost) { };

  # Expose the NVIDIA userspace driver (libcuda.so) to the bwrap-sandboxed
  # fah-client so the CUDA folding core can find it. /run is bind-mounted
  # into the sandbox, but the dynamic linker won't search
  # /run/opengl-driver/lib unless told.
  systemd.services.foldingathome = lib.mkIf (!isWorkHost) {
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
