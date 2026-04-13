# Work container launcher scripts — import this in your home.nix
#
# Provides: wup, wdown, wterm, wbrowser, wstatus

{ ... }:

{
  home.file.".local/bin/wup" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      if [ ! -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
        echo "ERROR: Wayland socket not found at $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
        echo "Make sure you are running this from within your Hyprland session."
        exit 1
      fi
      echo "Starting work container..."
      sudo nixos-container start work
      echo "Work container up. Use 'wterm' or 'wbrowser' to launch apps."
    '';
  };

  home.file.".local/bin/wdown" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      echo "Stopping work container..."
      sudo nixos-container stop work
      echo "Work container stopped."
    '';
  };

  home.file.".local/bin/wterm" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      sudo machinectl shell gjermund@work /run/current-system/sw/bin/env \
        WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
        XDG_RUNTIME_DIR=/var/wayland-socket \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/var/wayland-socket/bus" \
        WINIT_UNIX_BACKEND=wayland \
        GBM_BACKEND=nvidia-drm \
        __GLX_VENDOR_LIBRARY_NAME=nvidia \
        __EGL_VENDOR_LIBRARY_DIRS=/run/opengl-driver/share/glvnd/egl_vendor.d \
        HOME=/home/gjermund \
        alacritty
    '';
  };

  home.file.".local/bin/wbrowser" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      sudo machinectl shell gjermund@work /run/current-system/sw/bin/env \
        WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
        XDG_RUNTIME_DIR=/var/wayland-socket \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/var/wayland-socket/bus" \
        GBM_BACKEND=nvidia-drm \
        __GLX_VENDOR_LIBRARY_NAME=nvidia \
        __EGL_VENDOR_LIBRARY_DIRS=/run/opengl-driver/share/glvnd/egl_vendor.d \
        VK_DRIVER_FILES=/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json \
        HOME=/home/gjermund \
        vivaldi --ozone-platform=wayland --user-data-dir=/home/gjermund/work/.config/vivaldi &
    '';
  };

  home.file.".local/bin/wstatus" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      echo "=== Container status ==="
      sudo nixos-container status work
      echo ""
      echo "=== WireGuard status ==="
      sudo nixos-container run work -- wg show
    '';
  };
}
