{ waydroid-helper, applyPatches, ... }:

# The keymapper overlay sizes itself only when the compositor reports the
# window as 'maximized', which a tiling WM never does -- so under Hyprland it
# keeps a corner-sized window (waydroid-helper#106). See overlay-size.patch.
waydroid-helper.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./overlay-size.patch ];
})
