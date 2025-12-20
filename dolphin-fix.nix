# Custom Dolphin overlay - fixes "Open with" menu and preserves theming
# Based on rumboon/dolphin-overlay
# Uses Qt5 KService for applications.menu AND /etc/xdg for theming (kdeglobals)

final: prev: {
  kdePackages = prev.kdePackages.overrideScope (kfinal: kprev: {
    dolphin = kprev.dolphin.overrideAttrs (oldAttrs: {
      nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ prev.makeWrapper ];
      postInstall = (oldAttrs.postInstall or "") + ''
        wrapProgram $out/bin/dolphin \
          --prefix XDG_CONFIG_DIRS : "${prev.libsForQt5.kservice}/etc/xdg:/etc/xdg" \
          --run "${kprev.kservice}/bin/kbuildsycoca6 --noincremental ${prev.libsForQt5.kservice}/etc/xdg/menus/applications.menu 2>/dev/null || true"
      '';
    });
  });
}
