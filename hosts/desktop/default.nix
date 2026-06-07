# Desktop-specific configuration
# RTX 5070 Ti, 5120x1440@240Hz ultrawide, 4TB games drive
{ config, pkgs, lib, ... }:

{
  # Autologin on boot only — after logout, regreet login screen is shown.
  # Use start-hyprland (the nixpkgs watchdog wrapper) instead of Hyprland directly,
  # otherwise Hyprland prints a "started without using start-hyprland" warning.
  services.greetd.settings.initial_session = {
    command = "${pkgs.hyprland}/bin/start-hyprland";
    user = "gjermund";
  };

  # Use sway instead of cage for the greeter — cage can't set output resolution,
  # causing the NVIDIA greeter to render at the wrong (low) resolution.
  # sway lets us explicitly configure the output mode.
  services.greetd.settings.default_session.command = lib.mkForce (
    let
      swayConfig = pkgs.writeText "sway-greetd.conf" ''
        output * scale 1
        output * mode 5120x1440@240Hz
        exec "${pkgs.greetd.regreet}/bin/regreet --style /etc/greetd/regreet.css"; exit
      '';
    in "${pkgs.sway}/bin/sway --config ${swayConfig}"
  );

  # NVIDIA env vars for sway/wlroots in the greeter session.
  # GBM_BACKEND is omitted — open drivers don't need it and it can cause mode negotiation failures.
  systemd.services.greetd.environment = {
    WLR_NO_HARDWARE_CURSORS = "1";
    WLR_DRM_DEVICES = "/dev/dri/card1";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    LIBVA_DRIVER_NAME = "nvidia";
    XDG_CURRENT_DESKTOP = "sway";
  };

  # Always run at full speed (desktop is always plugged in)
  powerManagement.cpuFreqGovernor = "performance";

  # Desktop-only packages
  environment.systemPackages = with pkgs; [
    (pkgs.symlinkJoin {
      name = "rustdesk";
      paths = [ rustdesk ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/rustdesk --set GDK_BACKEND x11
      '';
    })  # Remote desktop - force X11 to fix keyboard grab on Wayland
  ];

  # NFS client support
  boot.supportedFilesystems = [ "nfs" ];

  # Mount 4TB games drive (desktop-only)
  fileSystems."/home/gjermund/games" = {
    device = "/dev/disk/by-uuid/1c7bdee1-0f6d-4181-a13b-a8ee7237949a";
    fsType = "btrfs";
    options = [ "noatime" "compress=zstd" "nofail" ];
  };

  # Mount NFS share from NAS
  fileSystems."/zfs" = {
    device = "192.168.0.207:/share";
    fsType = "nfs";
    options = [ "defaults" "nofail" ];
  };

  # BEES deduplication for games drive (saves ~15-25GB on Proton prefixes)
  services.beesd.filesystems.games = {
    spec = "UUID=1c7bdee1-0f6d-4181-a13b-a8ee7237949a";
    hashTableSizeMB = 1024;  # 1GB hash table for 3.7TB drive
    extraOptions = [ "--loadavg-target" "2.0" ];
  };

  # Disable the system gateway service — gateway runs as a user service instead.
  systemd.services.hermes-agent.enable = lib.mkForce false;

  # The module sets HERMES_HOME=/var/lib/hermes/.hermes system-wide.
  # Keep the module default — CLI and gateway share the same home.
  # (Previously forced `~/.hermes` for shells, which broke `hermes dashboard`
  # and `hermes cron list` — they showed empty state while gateway had the real state.)

  # The module creates .managed at /var/lib/hermes/.hermes on every activation;
  # remove it so `hermes setup` and tool-calls aren't blocked.
  system.activationScripts.hermes-remove-managed = {
    deps = [ "hermes-agent-setup" ];
    text = ''
      rm -f /var/lib/hermes/.hermes/.managed
    '';
  };

  # Hermes AI agent (NousResearch) — package only, no system service.
  # Gateway runs as a user service, defined here via systemd.user.services
  # so it uses the hermes wrapper (which has HERMES_BUNDLED_PLUGINS set).
  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;
    extraDependencyGroups = [ "honcho" "messaging" ];
    user = "gjermund";
    group = "users";
    createUser = false;
  };

  # Hermes gateway user service — uses the `hermes` wrapper binary
  # so HERMES_BUNDLED_PLUGINS (set by makeWrapper in the derivation)
  # is always correct across Nix rebuilds.
  # Must use the overridden package (with extraDependencyGroups) so
  # Discord (discord.py) and other messaging deps are in the venv.
  systemd.user.services.hermes-gateway = let
    hermesPkg = config.services.hermes-agent.package.override {
      extraDependencyGroups = [ "honcho" "messaging" ];
    };
  in {
    description = "Hermes Agent Gateway - Messaging Platform Integration";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    startLimitIntervalSec = 0;
    serviceConfig = {
      Type = "simple";
      ExecStart = "${hermesPkg}/bin/hermes gateway run --replace";
      Environment = [
        "PATH=${pkgs.nodejs_22}/bin:${hermesPkg}/bin:/home/gjermund/.local/bin:/home/gjermund/.cargo/bin:/home/gjermund/go/bin:/home/gjermund/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      ];
      EnvironmentFile = "-/var/lib/hermes/.hermes/.env";
      Restart = "always";
      RestartSec = 5;
      RestartMaxDelaySec = 300;
      RestartSteps = 5;
      RestartForceExitStatus = 75;
      KillMode = "mixed";
      KillSignal = "SIGTERM";
      TimeoutStopSec = 90;
      StandardOutput = "journal";
      StandardError = "journal";
    };
    wantedBy = [ "default.target" ];
  };

  # Automated backups with rsync
  systemd.services.backup-home = {
    description = "Backup home directory to backup drive";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.rsync}/bin/rsync -aAXv --delete --exclude='.cache' --exclude='games' /home/gjermund/ /backup/home/";
    };
  };

  systemd.timers.backup-home = {
    description = "Daily home backup";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;  # Run if missed (e.g., system was off)
    };
  };
}
