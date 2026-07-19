# Laptop-specific configuration
# Intel + NVIDIA hybrid graphics, 2560x1440@60Hz
#
# Shared laptop config (thermald/power-profiles/upower, powertop, lid suspend,
# low-battery notifier) lives in modules/common.nix under `isLaptopHost`.
{ config, pkgs, lib, ... }:

{
  # TLP for better battery life (alternative to power-profiles-daemon)
  # Uncomment if you prefer TLP over the power-profiles-daemon set in common.nix
  # services.tlp.enable = true;
  # services.power-profiles-daemon.enable = false;

  # Accelerometer, gyroscope (laptop-only sensor)
  hardware.sensor.iio.enable = true;
}
