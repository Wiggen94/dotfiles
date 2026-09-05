# Laptop power management + low-battery notifier (laptop + sikt)
{
  config,
  pkgs,
  lib,
  inputs,
  hostName,
  ...
}:
let
  isLaptopHost = hostName != "desktop";
  isNvidiaLaptop = hostName == "laptop"; # hybrid Intel+NVIDIA; sikt is Intel-only
  nvidiaGpuPci = "0000:01:00.0";
  nvidiaAudioPci = "0000:01:00.1";

  # The NVIDIA dGPU never reaches PCI runtime-suspend on this hardware: Mesa's
  # eglQueryDevicesEXT (triggered once by Hyprland/Aquamarine at session start,
  # even though Aquamarine itself only renders on the Intel iGPU — see
  # AQ_DRM_DEVICES in modules/home/_common.nix) opens every /dev/dri/renderD*
  # node on the system and keeps the handle for the process lifetime, which
  # blocks the "nvidia" driver's runtime D3 indefinitely (~12-13W idle drain,
  # unaffected by AQ_DRM_DEVICES). No aquamarine/Mesa env var exists to avoid
  # this. Instead: hot-remove the GPU's PCI device on battery (forces the
  # kernel driver's .remove()/drm_dev_unplug path, cutting power regardless of
  # any open userspace fd) and rescan it back in on AC. Skips the remove if
  # nvidia-smi reports an active compute/graphics client (e.g. a running
  # nvidia-offload app) rather than yank the device out from under real work —
  # Hyprland's own passive Mesa handle never shows up there, only actual GPU
  # clients do.
  # Every external binary is called by absolute store path — this script's
  # content gets exec'd directly from nvidia-gpu-boot-check's process too (see
  # below), which doesn't carry the `path` set on this script's own systemd
  # unit, so bare command names aren't reliably on PATH here.
  nvidiaGpuOff = pkgs.writeShellScript "nvidia-gpu-off" ''
    set -eu
    DEV="/sys/bus/pci/devices/${nvidiaGpuPci}"
    [ -e "$DEV" ] || exit 0 # already removed

    NVIDIA_SMI="${config.hardware.nvidia.package}/bin/nvidia-smi"
    if [ -x "$NVIDIA_SMI" ] && ! "$NVIDIA_SMI" 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q "No running processes found"; then
      ${pkgs.util-linux}/bin/logger -t nvidia-gpu-power "skip: GPU has an active client (nvidia-offload app running)"
      exit 0
    fi

    echo 1 > "/sys/bus/pci/devices/${nvidiaAudioPci}/remove" 2>/dev/null || true
    echo 1 > "$DEV/remove"
    ${pkgs.util-linux}/bin/logger -t nvidia-gpu-power "removed NVIDIA GPU (on battery)"
  '';

  nvidiaGpuOn = pkgs.writeShellScript "nvidia-gpu-on" ''
    set -eu
    echo 1 > /sys/bus/pci/rescan
    ${pkgs.util-linux}/bin/logger -t nvidia-gpu-power "rescanned PCI bus (AC connected), NVIDIA GPU restored"
  '';
in
{

  # ═══════════════════════════════════════════════════════════════════════════
  # LAPTOP-ONLY (laptop + sikt): power management + low-battery notifier.
  # Desktop is a plugged-in workstation and skips all of this.
  # ═══════════════════════════════════════════════════════════════════════════
  services.thermald.enable = lib.mkIf isLaptopHost true;
  services.power-profiles-daemon.enable = lib.mkIf isLaptopHost true;
  services.upower.enable = lib.mkIf isLaptopHost true; # Battery info for Quickshell bar

  # Suspend on lid close, but not when on external power (lid closed while
  # plugged in). sikt additionally sets HandleLidSwitchDocked in its host file.
  services.logind.settings.Login = lib.mkIf isLaptopHost {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "ignore";
  };

  systemd.user.services.low-battery-notify = lib.mkIf isLaptopHost {
    description = "Low battery notification";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "low-battery-check" ''
        BATTERY_PATH="/sys/class/power_supply/BAT0"
        [ -d "$BATTERY_PATH" ] || BATTERY_PATH="/sys/class/power_supply/BAT1"
        [ -d "$BATTERY_PATH" ] || exit 0

        CAPACITY=$(cat "$BATTERY_PATH/capacity")
        STATUS=$(cat "$BATTERY_PATH/status")

        if [ "$STATUS" = "Discharging" ]; then
          if [ "$CAPACITY" -le 10 ]; then
            ${pkgs.libnotify}/bin/notify-send -u critical "Battery Critical" "Battery at $CAPACITY% - plug in now!"
          elif [ "$CAPACITY" -le 20 ]; then
            ${pkgs.libnotify}/bin/notify-send -u normal "Battery Low" "Battery at $CAPACITY%"
          fi
        fi
      '';
    };
    wantedBy = [ ];
  };

  systemd.user.timers.low-battery-notify = lib.mkIf isLaptopHost {
    description = "Check battery level every 2 minutes";
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "2min";
    };
    wantedBy = [ "timers.target" ];
  };

  # ═══════════════════════════════════════════════════════════════════════════
  # laptop only: hot-remove the NVIDIA dGPU on battery, rescan it back on AC.
  # See the nvidiaGpuOff/On comment above for why this exists instead of a
  # software runtime-PM fix. Reacts live to AC plug/unplug via udev; the
  # boot-time oneshot below also catches "booted already on battery" and
  # "booted already on AC after being removed", since the udev rule only
  # fires on a *transition*, not the state already in effect at boot.
  # ═══════════════════════════════════════════════════════════════════════════
  systemd.services.nvidia-gpu-off = lib.mkIf isNvidiaLaptop {
    description = "Power down NVIDIA dGPU (on battery)";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${nvidiaGpuOff}";
    };
  };

  systemd.services.nvidia-gpu-on = lib.mkIf isNvidiaLaptop {
    description = "Rescan PCI bus to restore NVIDIA dGPU (AC connected)";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${nvidiaGpuOn}";
    };
  };

  services.udev.extraRules = lib.mkIf isNvidiaLaptop ''
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", TAG+="systemd", ENV{SYSTEMD_WANTS}+="nvidia-gpu-off.service"
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", TAG+="systemd", ENV{SYSTEMD_WANTS}+="nvidia-gpu-on.service"
  '';

  systemd.services.nvidia-gpu-boot-check = lib.mkIf isNvidiaLaptop {
    description = "Match NVIDIA dGPU power state to AC status at boot";
    after = [ "local-fs.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "nvidia-gpu-boot-check" ''
        set -eu
        ONLINE=1
        for ac in /sys/class/power_supply/*; do
          [ "$(cat "$ac/type" 2>/dev/null)" = "Mains" ] || continue
          ONLINE=$(cat "$ac/online" 2>/dev/null || echo 1)
          break
        done
        if [ "$ONLINE" = "0" ]; then
          exec ${nvidiaGpuOff}
        else
          exec ${nvidiaGpuOn}
        fi
      '';
    };
  };
}
