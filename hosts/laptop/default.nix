# Laptop-specific configuration
# Intel + NVIDIA hybrid graphics, 2560x1440@60Hz
{ config, pkgs, lib, ... }:

{
  # Laptop power management
  services.thermald.enable = true;
  services.power-profiles-daemon.enable = true;

  # TLP for better battery life (alternative to power-profiles-daemon)
  # Uncomment if you prefer TLP over power-profiles-daemon
  # services.tlp.enable = true;
  # services.power-profiles-daemon.enable = false;

  # Laptop-specific packages
  environment.systemPackages = with pkgs; [
    powertop  # Power consumption analyzer
  ];

  # Laptop lid settings
  services.logind = {
    lidSwitch = "suspend";
    lidSwitchExternalPower = "ignore";  # Don't suspend when plugged in with lid closed
  };
}
