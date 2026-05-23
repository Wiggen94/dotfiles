# Fresco - Fast, lightweight BOINC Manager (Tauri / Vue / Rust)
# Upstream uses a rolling "latest" release tag; bump `version` (date) and `hash`
# together when you want a newer one. Compute a fresh hash with:
#   nix-prefetch-url https://github.com/AufarZakiev/Fresco/releases/download/latest/Fresco_Linux_x86_64.AppImage
{ pkgs }:

let
  pname = "fresco";
  version = "2026-05-10";

  src = pkgs.fetchurl {
    url = "https://github.com/AufarZakiev/Fresco/releases/download/latest/Fresco_Linux_x86_64.AppImage";
    hash = "sha256:0rqb1g5aw1ci0f8liw61n0k917jfa92qy0yk9fjbqshihfmwpzzh";
  };

  appimageContents = pkgs.appimageTools.extractType2 { inherit pname version src; };
in
pkgs.appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm444 "${appimageContents}/Fresco.desktop" -t "$out/share/applications/"
    for size in 16 32 64 128 256 512; do
      icon="${appimageContents}/usr/share/icons/hicolor/''${size}x''${size}/apps/${pname}.png"
      if [ -f "$icon" ]; then
        install -Dm444 "$icon" "$out/share/icons/hicolor/''${size}x''${size}/apps/${pname}.png"
      fi
    done
  '';

  meta = with pkgs.lib; {
    description = "Fast, lightweight BOINC Manager";
    homepage = "https://github.com/AufarZakiev/Fresco";
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
