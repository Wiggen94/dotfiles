{ pkgs }:

pkgs.hyprpanel.overrideAttrs (oldAttrs: {
  postPatch = (oldAttrs.postPatch or "") + ''
    # Patch out bluetooth initialization for VM
    sed -i 's|execAsync(\`python3 .*bluetooth\.py\`)|// execAsync(\`python3 - bluetooth disabled for VM\`)|' src/core/initialization/index.ts

    echo "Patched bluetooth initialization out of HyprPanel"
  '';
})
