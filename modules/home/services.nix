# Quickshell restart unit, protonup auto-update, TESS miner
{
  config,
  pkgs,
  lib,
  hostName,
  ...
}:
let
  inherit (import ./_common.nix { inherit lib hostName; })
    isWorkHost
    isLaptopHost
    themeRegistry
    allThemes
    themeNames
    colors
    hostConfig
    currentHost
    terminalCmd
    termCmd
    mkHyprThemeColors
    mkAlacrittyConfig
    mkWlogoutStyle
    mkStarshipConfig
    mkQuickshellThemeJson
    mkThemeFiles
    allThemeFiles
    ;
in
{
  # Quickshell bar - restartIfChanged ensures it restarts on rebuild
  systemd.user.services.quickshell-bar = {
    Unit = {
      Description = "Quickshell bar";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStartPre = "-/run/current-system/sw/bin/killall quickshell";
      ExecStart = "/run/current-system/sw/bin/quickshell -p %h/.config/quickshell/bar";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Proton-GE auto-update service (disabled on work hosts)
  systemd.user.services.protonup = lib.mkIf (!isWorkHost) {
    Unit = {
      Description = "Update Proton-GE";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.protonup-ng}/bin/protonup";
      Environment = "PATH=${pkgs.coreutils}/bin";
    };
  };

  # Run on login and weekly (disabled on work hosts)
  systemd.user.timers.protonup = lib.mkIf (!isWorkHost) {
    Unit = {
      Description = "Update Proton-GE weekly and on login";
    };
    Timer = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1week";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  # TESS Miner autonomous pipeline — desktop only
  systemd.user.services.tess-miner-automine = lib.mkIf (hostName == "desktop") {
    Unit = {
      Description = "TESS Miner Autonomous Mining Run";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      WorkingDirectory = "%h/tess-miner";
      ExecStart = "%h/tess-miner/automine-cron.sh";
      TimeoutSec = 1800;
    };
  };

  systemd.user.timers.tess-miner-automine = lib.mkIf (hostName == "desktop") {
    Unit = {
      Description = "Run TESS Miner automine every 30 minutes";
    };
    Timer = {
      OnCalendar = "*:0/30";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

}
