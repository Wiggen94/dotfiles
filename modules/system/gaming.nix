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

  # GameMode - launch games with `gamemoderun %command%` in Steam.
  # While a game runs: CPU governor -> performance (EPP follows under
  # intel_pstate) and the game is pinned to the P-cores. The desktop's
  # i5-14600K otherwise lets a render-thread-bound game (Witcher 3 5.0)
  # hop onto the E-cores 12-19, which shows up as uneven frame pacing.
  # renice stays off: it can't raise priority without CAP_SYS_NICE /
  # RLIMIT_NICE anyway. Games run at nice 0 because the ananicy override
  # below stops steam's "Launcher" nice 16 from being inherited.
  programs.gamemode = lib.mkIf (!isWorkHost) {
    enable = true;
    settings = {
      general.renice = 0;
      cpu = {
        pin_cores = "yes"; # autodetects P/E cores
        park_cores = "no";
      };
    };
  };
  # gamemode's polkit rule only lets the `gamemode` group run its governor /
  # split-lock helpers via pkexec; without it they fail "Not authorized"
  # and the governor silently stays on powersave.
  users.users.gjermund.extraGroups = lib.mkIf (!isWorkHost) [ "gamemode" ];

  # MangoHud - FPS / frame-time overlay: `mangohud %command%` in Steam
  environment.systemPackages = lib.mkIf (!isWorkHost) [ pkgs.mangohud ];

  # Ananicy-cpp - Auto-nice daemon for process prioritization
  # Automatically adjusts nice/ionice/cgroups for known processes
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    # CachyOS community rules, minus their `steam` rule. That rule types
    # steam as "Launcher" (nice 16, ioclass idle), and every game Steam
    # starts inherits it: ananicy only matches by process name, so a game
    # with no rule of its own (AION2, most Proton titles) ran the whole
    # session at nice 16 with idle IO. Dropped here rather than overridden
    # via extraRules: ananicy-cpp loads rule files in directory-iteration
    # order, so which of two same-name rules wins isn't defined.
    rulesProvider = pkgs.ananicy-rules-cachyos.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        sed -i '/"name": "steam",/d' \
          $out/etc/ananicy.d/00-default/Games/launchers.rules
      '';
    });
    # Explicit nice 0 / best-effort, so the change also resets an already
    # running steam that the old rule had pushed to 16.
    extraRules = [
      {
        name = "steam";
        nice = 0;
        ioclass = "best-effort";
      }
    ];
  };
}
