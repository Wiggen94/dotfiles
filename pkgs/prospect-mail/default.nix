# Unofficial Outlook desktop client (Electron wrapper around the Outlook web
# app, https://github.com/julian-alarcon/prospect-mail) for the work O365
# account. Distributed only as prebuilt binaries, so this is a hash-pinned
# fetchurl of the upstream x86_64 AppImage — no build from source, no vendored
# binary. Runs via the system's AppImage binfmt handler
# (programs.appimage.binfmt in modules/system/nix.nix), so no appimageTools
# extraction/wrapping is needed here.
{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation rec {
  pname = "prospect-mail";
  version = "1.2.1";

  src = fetchurl {
    url = "https://github.com/julian-alarcon/prospect-mail/releases/download/v${version}/Prospect-Mail-${version}.AppImage";
    hash = "sha256-QTzoRduEZyLCyowIVYcrLVCRrLDLWOq7JvEA+ffblnA=";
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/prospect-mail
    runHook postInstall
  '';

  meta = {
    description = "Unofficial Outlook desktop client (Electron wrapper around the Outlook web app)";
    homepage = "https://github.com/julian-alarcon/prospect-mail";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "prospect-mail";
  };
}
