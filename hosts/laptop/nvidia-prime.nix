# NVIDIA Prime (Hybrid Graphics) Configuration for Laptop
# Intel iGPU + NVIDIA dGPU with offload mode
{ config, lib, pkgs, ... }:

{
  # Enable graphics
  hardware.graphics = {
    enable = true;
    enable32Bit = true;  # For Steam/Wine 32-bit games
  };

  # Load NVIDIA driver
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Modesetting is required for Wayland
    modesetting.enable = true;

    # Power management - ENABLE for laptop battery life
    powerManagement.enable = true;
    # Fine-grained power management - turns off GPU when not in use
    # May cause issues on some systems, disable if you experience problems
    powerManagement.finegrained = true;

    # Use open-source kernel modules (recommended for RTX 20-series and newer)
    open = true;

    # Enable nvidia-settings GUI
    nvidiaSettings = true;

    # Use the latest stable driver
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # NVIDIA Prime configuration for hybrid graphics
    prime = {
      # Offload mode: Uses Intel by default, NVIDIA on demand
      # Run apps on NVIDIA with: nvidia-offload <app>
      offload = {
        enable = true;
        enableOffloadCmd = true;  # Adds nvidia-offload command
      };

      # Sync mode alternative: Always use NVIDIA (better performance, worse battery)
      # Uncomment below and comment out offload section to use sync mode
      # sync.enable = true;

      # IMPORTANT: You MUST set these to your actual bus IDs!
      # Find them with: lspci | grep -E "(VGA|3D)"
      # Format: "PCI:X:Y:Z" where X:Y.Z is from lspci output
      # Example: "01:00.0" becomes "PCI:1:0:0"

      # Intel iGPU bus ID (usually 0:2:0)
      intelBusId = "PCI:0:2:0";

      # NVIDIA dGPU bus ID (usually 1:0:0, but check with lspci!)
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # Environment variables for NVIDIA + Wayland
  environment.sessionVariables = {
    # Hint Electron apps to use Wayland
    NIXOS_OZONE_WL = "1";

    # For Prime offload, we DON'T set NVIDIA as default
    # These are only used when running with nvidia-offload
    # LIBVA_DRIVER_NAME = "nvidia";  # Uncomment for sync mode
    # GBM_BACKEND = "nvidia-drm";     # Uncomment for sync mode
    # __GLX_VENDOR_LIBRARY_NAME = "nvidia";  # Uncomment for sync mode

    # Hardware video acceleration (use Intel by default for better battery)
    LIBVA_DRIVER_NAME = "iHD";  # Intel driver
    NVD_BACKEND = "direct";
  };

  # Additional packages for NVIDIA
  environment.systemPackages = with pkgs; [
    nvtopPackages.full    # GPU monitoring
    vulkan-tools          # Vulkan utilities (vulkaninfo)
    mesa-demos            # OpenGL info (glxinfo, glxgears)
    libva-utils           # VA-API info (vainfo)
    intel-gpu-tools       # Intel GPU tools (intel_gpu_top)
  ];
}
