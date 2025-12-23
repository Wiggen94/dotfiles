# NVIDIA GPU Configuration for Desktop
# For RTX 5070 Ti (Blackwell architecture) - standalone discrete GPU
{ config, lib, pkgs, ... }:

{
  # Enable graphics (replaces deprecated hardware.opengl)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;  # For Steam/Wine 32-bit games
    # OpenCL support for BOINC and other GPU compute
    extraPackages = with pkgs; [
      nvidia-vaapi-driver  # VA-API support
      ocl-icd              # OpenCL ICD loader
    ];
  };

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

    # Use the latest stable driver (required for RTX 50 series)
    # If you have issues, try: nvidiaPackages.beta or nvidiaPackages.latest
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Environment variables for NVIDIA + Wayland
  environment.sessionVariables = {
    # Hint Electron apps to use Wayland
    NIXOS_OZONE_WL = "1";

    # NVIDIA-specific Wayland variables
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # Hardware video acceleration
    NVD_BACKEND = "direct";

    # If you experience issues with Discord/Zoom screenshare, try commenting out:
    # __GLX_VENDOR_LIBRARY_NAME (can cause XWayland conflicts)
    # GBM_BACKEND (can cause Firefox crashes)
  };

  # Additional packages for NVIDIA
  environment.systemPackages = with pkgs; [
    nvtopPackages.full  # GPU monitoring
    vulkan-tools          # Vulkan utilities (vulkaninfo)
    mesa-demos            # OpenGL info (glxinfo, glxgears)
    libva-utils           # VA-API info (vainfo)
  ];
}
