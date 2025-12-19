{ pkgs }:

pkgs.hyprpanel.overrideAttrs (oldAttrs: {
  postPatch = (oldAttrs.postPatch or "") + ''
    # Patch out bluetooth initialization for VM
    sed -i 's@python3.*bluetooth\.py@true@' src/core/initialization/index.ts

    # Patch out bluetooth menu import to prevent AstalBluetooth from being loaded
    sed -i "/import BluetoothMenu/d" src/components/menus/index.ts
    sed -i "/BluetoothMenu/d" src/components/menus/index.ts

    # Patch out bluetooth bar component (this is what loads AstalBluetooth)
    sed -i "/import.*Bluetooth.*from.*bluetooth/d" src/components/bar/layout/coreWidgets.tsx
    sed -i "/bluetooth:.*Bluetooth/d" src/components/bar/layout/coreWidgets.tsx

    # Patch out bluetooth from dashboard controls - don't remove, just don't import AstalBluetooth
    sed -i "/import AstalBluetooth from/d" src/components/menus/dashboard/controls/ControlButtons.tsx
    sed -i "/const bluetoothService = AstalBluetooth/d" src/components/menus/dashboard/controls/ControlButtons.tsx
    # Remove the BluetoothButton from the index exports
    sed -i "/export.*BluetoothButton/d" src/components/menus/dashboard/controls/index.tsx

    echo "Patched all bluetooth references out of HyprPanel for VM"
  '';
})
