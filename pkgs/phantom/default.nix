# phantom — keyboard/mouse to Android-touch mapper for fullscreen Waydroid
#
# Upstream: https://github.com/oliviermugishak/phantom
#
# Packaging notes (all derived from running the 1.1.0 release binaries on this
# NixOS host):
#
# 1. The release tarball is prebuilt, so the binaries keep their /lib64
#    interpreter and are run through nix-ld.
#
# 2. Both binaries `dlopen()` Wayland at runtime — the daemon spawns
#    `phantom --cursor-overlay`, a winit/EGL Wayland client, which needs
#    libwayland-client. The GUI needs the EGL dispatcher (libEGL.so.1) on top
#    of the vendor driver, otherwise winit reports NoGlutinConfigs. X11 is a
#    hard DT_NEEDED of `phantom`, so libX11 and libxkbcommon are needed too.
#
#    nix-ld's own library set covers libX11/libxkbcommon but supplies no
#    wayland and no glvnd dispatcher, and `sudo` strips NIX_LD_LIBRARY_PATH,
#    so the daemon (which must run as root) would lose them again. The
#    wrappers therefore set LD_LIBRARY_PATH explicitly, which nix-ld passes
#    straight through and which plain `sudo` (without -E) also preserves.
#
# 3. phantom runs the Android-side server with `app_process` inside the
#    Waydroid container. It ships phantom-server.jar next to the binary and
#    also resolves `../lib/phantom/` relative to the executable, so the jar is
#    installed at $out/lib/phantom/phantom-server.jar and the whole tree under
#    $out/libexec/phantom/ keeps that relative layout intact.
{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  wayland,
  libxkbcommon,
  libx11,
  libxcursor,
  libglvnd,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "phantom";
  version = "1.1.0";

  src = fetchurl {
    url = "https://github.com/oliviermugishak/phantom/releases/download/v${finalAttrs.version}/phantom-v${finalAttrs.version}-linux-x86_64.tar.gz";
    hash = "sha256-2teF+gUkaK2sdXijK7J+p3LmkwV34kq4/7INvgL2pOI=";
  };

  nativeBuildInputs = [ makeWrapper ];

  # The tarball is already the finished layout; nothing to compile.
  dontBuild = true;
  dontConfigure = true;
  dontPatchELF = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    # unpackPhase already cd'd into phantom-v${finalAttrs.version}-linux-x86_64.
    mkdir -p $out/libexec/phantom
    cp -a . $out/libexec/phantom/

    mkdir -p $out/bin $out/lib/phantom $out/share
    cp -a $out/libexec/phantom/lib/phantom/phantom-server.jar $out/lib/phantom/
    cp -a $out/libexec/phantom/share/applications $out/share/
    cp -a $out/libexec/phantom/share/icons $out/share/
    cp -a $out/libexec/phantom/share/phantom $out/share/

    for bin in phantom phantom-gui; do
      makeWrapper $out/libexec/phantom/bin/$bin $out/bin/$bin \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [
          wayland
          libxkbcommon
          libx11
          libxcursor
          libglvnd
        ]}"
    done

    runHook postInstall
  '';

  meta = {
    description = "Keyboard and mouse to Android touch mapper for fullscreen Waydroid";
    homepage = "https://github.com/oliviermugishak/phantom";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "phantom";
  };
})
