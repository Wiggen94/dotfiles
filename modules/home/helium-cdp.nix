# Headless Helium on a CDP port — the attach target for chrome-devtools-mcp.
#
# Why this exists at all: `chrome-devtools-mcp` cannot launch the browser
# itself here. Letting it (`--executablePath`) fails with
#   Protocol error (Target.setDiscoverTargets): Target closed
# because it navigates by passing a URL on Chromium's command line, and
# Helium's headless mode rejects that outright:
#   ERROR:chrome/app/chrome_main.cc:204 Multiple targets are not supported
#   in headless mode.
# Helium's profile ships uBlock Origin, so background targets already exist and
# headless new-mode refuses to combine them with argv targets. Start the browser
# with NO url and drive it over CDP instead — then attaching works, and one warm
# browser serves every Claude Code session rather than one Chromium per session.
#
# Why Helium and not Chromium: this config stubs `pkgs.chromium` out entirely
# (modules/omarchy.nix), so the MCP server's default `--channel stable` launch
# path has no browser to find. Helium is a real Chromium 154 already installed
# for the webapp launcher, so this adds no new browser to the closure.
#
# Cost: ~455 MB PSS idle (measured, 10 processes) for as long as it runs. That is
# why it is desktop-only by default — see `enable` below. To reclaim it:
#   systemctl --user stop helium-cdp.service
# The MCP server re-attaches on its next tool call once the unit is started
# again; nothing needs re-registering.
{
  config,
  pkgs,
  lib,
  hostName,
  inputs,
  ...
}:

let
  helium = inputs.helium-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;

  cdpPort = 9222;
  profileDir = "${config.home.homeDirectory}/.cache/helium-cdp";

  # Desktop only by default. The laptops are battery-constrained and this repo
  # deliberately turns down iGPU-cost features there (see the borderangle note
  # in modules/home/_common.nix); a permanent Chromium is the same kind of cost.
  # Flip this to `true`, or drop the lib.mkIf below, to have the tool on laptops
  # too — it works identically, it just keeps ~455 MB resident.
  enable = hostName == "desktop";

  # Passed to systemd as a real argv (see ExecStart) — no shell, so no quoting
  # to get wrong. Flag order carries no meaning here; the ONE thing that does is
  # that there is no URL argument (see the header).
  launchArgs = [
    "--headless=new" # no window
    "--disable-gpu" # nothing composites here; keeps the GPU idle
    "--no-first-run"
    "--no-default-browser-check"
    "--remote-debugging-port=${toString cdpPort}"
    # A dedicated profile, so it never locks or contends with the Helium you
    # browse in. Also keeps the CDP endpoint's cookies separate from yours.
    "--user-data-dir=${profileDir}"
  ];

  # 0 = port free (go ahead and start), 1 = something already answers (skip).
  # Written as a script rather than inline shell so ExecCondition stays a single
  # path with no interpretation.
  portFree = pkgs.writeShellScript "helium-cdp-port-free" ''
    if ${pkgs.curl}/bin/curl -sf --max-time 1 \
         http://127.0.0.1:${toString cdpPort}/json/version >/dev/null 2>&1
    then
      exit 1 # already serving — skip, don't fight over the port
    fi
    exit 0
  '';
in
{
  systemd.user.services.helium-cdp = lib.mkIf enable {
    Unit = {
      Description = "Headless Helium CDP endpoint for chrome-devtools-mcp";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      # graphical-session.target is reached under niri too; gate on the
      # compositor, matching the kdeconnect unit's reasoning. An unmet
      # Condition* marks the unit skipped, not failed, so niri stays quiet.
      ConditionEnvironment = "XDG_CURRENT_DESKTOP=Hyprland";
      StartLimitIntervalSec = 300;
      StartLimitBurst = 20;
    };

    Service = {
      Type = "simple";
      # ExecCondition (not a probe inside ExecStart) so a browser you started by
      # hand makes the unit skip cleanly instead of failing and restart-looping
      # on an occupied port. A non-zero ExecCondition marks the unit skipped,
      # which is exactly the intent here.
      ExecCondition = "${portFree}";
      # argv, not a shell string: systemd execs the binary directly. Its stderr
      # goes to the journal, so `journalctl --user -u helium-cdp` shows the
      # "Multiple targets" error if a URL ever creeps back in.
      ExecStart = [ "${helium}/bin/helium" ] ++ launchArgs;
      Restart = "on-failure";
      RestartSec = 5;
      # The flag is deliberately in the pattern: it only matches the browser
      # this unit started, never the Helium you are browsing in.
      ExecStop = "${pkgs.procps}/bin/pkill -f 'remote-debugging-port=${toString cdpPort}'";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
