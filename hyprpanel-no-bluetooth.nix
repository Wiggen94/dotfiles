{ pkgs }:

pkgs.hyprpanel.overrideAttrs (oldAttrs: {
  postPatch = (oldAttrs.postPatch or "") + ''
    # Patch out bluetooth initialization for VM
    sed -i 's@python3.*bluetooth\.py@true@' src/core/initialization/index.ts

    # Patch out bluetooth menu import to prevent AstalBluetooth from being loaded
    sed -i "/import BluetoothMenu/d" src/components/menus/index.ts
    sed -i "/BluetoothMenu/d" src/components/menus/index.ts

    echo "Patched bluetooth initialization and menu out of HyprPanel"
  '';
})
