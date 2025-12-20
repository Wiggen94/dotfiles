# Custom Dolphin overlay - fixes "Open with" menu and preserves theming
# Based on rumboon/dolphin-overlay but keeps system XDG_CONFIG_DIRS

final: prev: {
  kdePackages = prev.kdePackages.overrideScope (kfinal: kprev: {
    dolphin = kprev.dolphin.overrideAttrs (oldAttrs: {
      nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ prev.makeWrapper ];
      postInstall = (oldAttrs.postInstall or "") + ''
        wrapProgram $out/bin/dolphin \
          --prefix XDG_CONFIG_DIRS : "${prev.kdePackages.kservice}/etc/xdg:/etc/xdg" \
          --run "${prev.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental ${prev.kdePackages.kservice}/etc/xdg/menus/applications.menu 2>/dev/null || true"
      '';
    });
  });
}
