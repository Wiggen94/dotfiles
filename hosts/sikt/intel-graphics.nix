# Intel Graphics Configuration (no NVIDIA)
# For Intel integrated graphics only
{ config, lib, pkgs, ... }:

{
  # Enable graphics
  hardware.graphics = {
    enable = true;
    enable32Bit = true;  # For compatibility with some apps
    extraPackages = with pkgs; [
      intel-media-driver      # Hardware video acceleration (modern Intel)
      intel-vaapi-driver      # Older Intel hardware acceleration
      libva-vdpau-driver      # VDPAU backend for VA-API
      libvdpau-va-gl          # OpenGL/VDPAU backend
    ];
  };

  # Environment variables for Intel graphics
  environment.sessionVariables = {
    # Hint Electron apps to use Wayland
    NIXOS_OZONE_WL = "1";
    # Intel VA-API driver
    LIBVA_DRIVER_NAME = "iHD";
  };

  # Additional packages for Intel graphics
  environment.systemPackages = with pkgs; [
    vulkan-tools          # Vulkan utilities (vulkaninfo)
    mesa-demos            # OpenGL info (glxinfo, glxgears)
    libva-utils           # VA-API info (vainfo)
    intel-gpu-tools       # Intel GPU tools (intel_gpu_top)
  ];
}
