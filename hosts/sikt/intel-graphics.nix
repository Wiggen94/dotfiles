# Intel Graphics Configuration (no NVIDIA)
# For Intel integrated graphics only
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Intel VA-API/VDPAU drivers (graphics.enable / enable32Bit are in modules/system/hardware.nix)
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver # Hardware video acceleration (modern Intel)
    intel-vaapi-driver # Older Intel hardware acceleration
    libva-vdpau-driver # VDPAU backend for VA-API
    libvdpau-va-gl # OpenGL/VDPAU backend
  ];

  # Environment variables for Intel graphics (NIXOS_OZONE_WL is in modules/system/users.nix)
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD"; # Intel VA-API driver
  };

  # Intel GPU tooling (vulkan-tools/mesa-demos/libva-utils are in modules/system/packages.nix)
  environment.systemPackages = with pkgs; [
    intel-gpu-tools # Intel GPU tools (intel_gpu_top)
  ];
}
