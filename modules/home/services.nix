# Quickshell restart unit, protonup auto-update, TESS miner
{
  config,
  pkgs,
  lib,
  hostName,
  ...
}:
let
  inherit (import ./_common.nix { inherit lib hostName; }) isWorkHost;
in
{
  # (the user's own quickshell bar unit is gone — omarchy's shell owns the bar)

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

  # (tess-miner automine service removed — ~/tess-miner was deleted, so the
  # every-30-min timer only ever failed with 203/EXEC)

  # KDE Connect tray indicator, for the Hyprland session.
  #
  # niri keeps its own spawn-at-startup entry for this (modules/home/niri.nix)
  # — it works there, so it's left alone; the ConditionEnvironment below is
  # what keeps this unit from starting a second copy under niri.
  #
  # This used to be a bare `hl.exec_cmd("kdeconnect-indicator")` in the
  # hyprland.start autostart, which didn't stick: the indicator is a
  # StatusNotifierItem client, and at hyprland.start the omarchy shell's tray
  # host doesn't exist yet, so it comes up with nowhere to register and goes
  # away again. There was nothing to bring it back, so the tray icon was
  # simply absent until started by hand.
  #
  # As a unit it gets restarted until it sticks. `Restart = "always"` rather
  # than "on-failure" on purpose: the failure mode above is a *clean* exit,
  # which on-failure would ignore.
  systemd.user.services.kdeconnect-indicator = {
    Unit = {
      Description = "KDE Connect tray indicator";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      # graphical-session.target is reached under niri too, so gate on the
      # compositor rather than the target. uwsm finalizes
      # XDG_CURRENT_DESKTOP into the systemd user environment; niri's session
      # doesn't go through uwsm at all. An unmet Condition* marks the unit
      # skipped rather than failed, so under niri this stays quietly inactive
      # instead of logging errors or tripping the start limit.
      #
      # ConditionEnvironment rather than an ExecCondition shell test: systemd
      # expands `$VAR` in Exec lines itself before the shell would see it, so
      # the shell form is both redundant and broken when the variable is unset.
      ConditionEnvironment = "XDG_CURRENT_DESKTOP=Hyprland";
      # Don't hammer it if something is genuinely broken.
      StartLimitIntervalSec = 300;
      StartLimitBurst = 20;
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnect-indicator";
      Restart = "always";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Hold a Wayland idle inhibitor whenever anything plays audio through
  # PipeWire. The omarchy-shell idle service locks after 5 minutes and
  # respects idle inhibitors, but Zen only raises one for *fullscreen*
  # video — so windowed YouTube/Twitch/etc. would lock mid-watch. This
  # covers every audio-playing app (browsers, mpv, ...) regardless.
  systemd.user.services.wayland-pipewire-idle-inhibit = {
    Unit = {
      Description = "Inhibit Wayland idle while audio plays via PipeWire";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.wayland-pipewire-idle-inhibit}/bin/wayland-pipewire-idle-inhibit --wayland";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

}
