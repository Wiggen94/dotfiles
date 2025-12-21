# PLACEHOLDER - Copy your actual hardware-configuration.nix here!
#
# On your laptop, run:
#   nixos-generate-config --show-hardware-config > ~/nix-config/hosts/laptop/hardware-configuration.nix
#
# Or after installing NixOS on the laptop:
#   cp /etc/nixos/hardware-configuration.nix ~/nix-config/hosts/laptop/
#
# This file is auto-generated and contains hardware-specific settings.

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # PLACEHOLDER - Replace with your actual hardware config
  # Run: nixos-generate-config --show-hardware-config

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usbhid" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Root filesystem - UPDATE THIS with your actual config
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/PLACEHOLDER-UPDATE-ME";
    fsType = "btrfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/PLACEHOLDER-UPDATE-ME";
    fsType = "vfat";
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
