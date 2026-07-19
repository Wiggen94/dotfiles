# NVIDIA GPU Configuration for Desktop
# For RTX 5070 Ti (Blackwell architecture) - standalone discrete GPU
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # OpenCL/VA-API support for BOINC and GPU compute.
  # graphics.enable / enable32Bit are set in common.nix.
  hardware.graphics.extraPackages = with pkgs; [
    nvidia-vaapi-driver # VA-API support
    ocl-icd # OpenCL ICD loader
  ];

  # Load NVIDIA driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Modesetting is required for Wayland
    modesetting.enable = true;

    # Power management - disabled for desktop
    powerManagement.enable = false;
    powerManagement.finegrained = false;

    # Use open-source kernel modules (recommended for RTX 20-series and newer)
    # RTX 5070 Ti (Blackwell) should use open drivers
    open = true;

    # Enable nvidia-settings GUI
    nvidiaSettings = true;

    # Use the latest driver for newest features/performance on RTX 5070 Ti
    # Fallback options: nvidiaPackages.stable (580.x) or nvidiaPackages.beta
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };

  # Environment variables for NVIDIA + Wayland
  environment.sessionVariables = {
    # NVIDIA-specific Wayland variables (NIXOS_OZONE_WL is set in common.nix)
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # Hardware video acceleration
    NVD_BACKEND = "direct";

    # If you experience issues with Discord/Zoom screenshare, try commenting out:
    # __GLX_VENDOR_LIBRARY_NAME (can cause XWayland conflicts)
    # GBM_BACKEND (can cause Firefox crashes)
  };

  # NVIDIA Container Toolkit — lets Docker/Podman pass GPUs into containers
  # (registers the "nvidia" runtime, enabling `--gpus all` and compose
  # `deploy.resources.reservations.devices: [{ driver: nvidia, ... }]`).
  hardware.nvidia-container-toolkit.enable = true;
}
