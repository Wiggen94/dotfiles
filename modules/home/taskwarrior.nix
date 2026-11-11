# Taskwarrior 3, synced through the taskchampion-sync-server on k3s.lan
# (docker stack /zfs/stacks/taskchampion there, port 8085), via Caddy at
# tasks.gjermund.xyz — LAN + tailnet only, like git.gjermund.xyz.
#
# The client id and encryption secret come from sops (secret
# `taskwarrior_sync`, a taskrc fragment), so they never land in the nix store:
#   taskwarrior_sync: |
#     sync.server.client_id=<uuid, same as CLIENT_ID on the server>
#     sync.encryption_secret=<random string>
# Every host uses the same pair — that is what makes them one replica set.
#
# Two user timers:
#   task-sync    every 15 min, so a task added on one host shows up on the others
#   task-remind  09:00 and shortly after login: desktop notification for tasks
#                due today or overdue, on whichever host is in use
{ pkgs, ... }:
let
  # nixpkgs' taskwarrior 3.5.0 fails to link (`cannot find -lsqlite3`): its
  # rusqlite links the system libsqlite3 but sqlite is not in buildInputs.
  # Drop this override once nixpkgs carries the fix.
  taskwarrior = pkgs.taskwarrior3.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.sqlite ];
    # The C++ executables link the static taskchampion lib, which needs it too.
    env = (old.env or { }) // {
      NIX_LDFLAGS = "-lsqlite3";
    };
  });
  task = "${taskwarrior}/bin/task";

  remind = pkgs.writeShellScript "task-remind" ''
    set -u
    ${task} rc.verbose=nothing sync >/dev/null 2>&1 || true
    due=$(${task} rc.verbose=nothing rc.hooks=off status:pending due.before:tomorrow export \
      | ${pkgs.jq}/bin/jq -r '.[] | "• " + .description')
    if [ -n "$due" ]; then
      ${pkgs.libnotify}/bin/notify-send -u critical -a Taskwarrior "Tasks due" "$due"
    fi
  '';
in
{
  programs.taskwarrior = {
    enable = true;
    package = taskwarrior;
    config = {
      sync.server.url = "https://tasks.gjermund.xyz";
    };
    extraConfig = ''
      include /run/secrets/taskwarrior_sync
    '';
  };

  systemd.user.services.task-sync = {
    Unit.Description = "Taskwarrior sync";
    Service = {
      Type = "oneshot";
      ExecStart = "${task} rc.verbose=nothing sync";
    };
  };
  systemd.user.timers.task-sync = {
    Unit.Description = "Taskwarrior sync every 15 minutes";
    Timer = {
      OnBootSec = "2min";
      OnUnitActiveSec = "15min";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.task-remind = {
    Unit = {
      Description = "Notify about due Taskwarrior tasks";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${remind}";
    };
  };
  systemd.user.timers.task-remind = {
    Unit.Description = "Taskwarrior due-task reminder";
    Timer = {
      OnCalendar = "*-*-* 09:00";
      OnStartupSec = "3min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
