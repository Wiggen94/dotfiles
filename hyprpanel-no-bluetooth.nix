{ pkgs }:

pkgs.hyprpanel.overrideAttrs (oldAttrs: {
  postPatch = (oldAttrs.postPatch or "") + ''
    # Patch out bluetooth initialization for VM - replace python3 with true
    sed -i 's@python3.*bluetooth\.py@true@' src/core/initialization/index.ts

    echo "Patched bluetooth initialization out of HyprPanel"
  '';
})
