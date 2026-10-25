# Compass — a Chrome/Chromium command bar + sidebar ("a chrome extension for
# arc lovers"), https://github.com/justin22/compass. MIT.
#
# Not on the Chrome Web Store and not in nixpkgs, so it is pinned by flake input
# and shipped as the unpacked extension directory. Helium loads it through
# --load-extension (see pkgs/helium-webgpu), which is why it needs no manual
# "Load unpacked" step in chrome://extensions.
#
# Upstream's own README states no human has reviewed this code and that it asks
# for tabs, history and bookmarks. It has no remote endpoints or telemetry: the
# only fetch() is a local captureVisibleTab blob for tab-switcher previews.
#
# The extension ID of an unpacked extension is derived from its absolute path,
# so it stays stable across rebuilds as long as the pinned rev does — bumping
# the input changes the ID and loses Compass's stored settings.
{ lib, stdenvNoCC, src }:

stdenvNoCC.mkDerivation {
  pname = "compass-extension";
  version = "0.1.1";

  inherit src;

  # The repo root is the extension (manifest.json at top level). Drop the dev
  # files the browser has no use for so the loaded directory is just the addon.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/compass-extension
    cp -r manifest.json *.js *.html icons $out/share/compass-extension/
    runHook postInstall
  '';

  meta = {
    description = "Command bar and sidebar for Chromium browsers";
    homepage = "https://github.com/justin22/compass";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
