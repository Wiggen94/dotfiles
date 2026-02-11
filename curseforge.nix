{ lib
, stdenv
, fetchurl
, dpkg
, autoPatchelfHook
, makeWrapper
, alsa-lib
, at-spi2-atk
, at-spi2-core
, atk
, cairo
, cups
, dbus
, expat
, gcc
, glib
, glibc
, gtk3
, libdrm
, libxkbcommon
, mesa
, nss
, openssl
, pango
, systemd
, libx11
, libxcomposite
, libxdamage
, libxext
, libxfixes
, libxrandr
, libxcb
, zlib
, icu
}:

stdenv.mkDerivation rec {
  pname = "curseforge";
  version = "1.297.3-30829";

  src = fetchurl {
    url = "https://curseforge.overwolf.com/electron/linux/CurseForge_${version}_amd64.deb";
    sha256 = "177x313dsp42h1b30zvx1qdmm51999snmpc5hac32xh0cc9466nh";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    gcc.cc.lib
    glib
    glibc
    gtk3
    icu
    libdrm
    libxkbcommon
    mesa
    nss
    openssl
    pango
    systemd
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxcb
    zlib
  ];

  dontBuild = true;
  dontConfigure = true;

  # Ensure autoPatchelfHook patches all binaries including the Agent
  autoPatchelfIgnoreMissingDeps = [ "libc.so.6" ];
  appendRunpaths = [ "${lib.makeLibraryPath buildInputs}" ];

  unpackPhase = ''
    dpkg-deb -x $src .
  '';

  installPhase = ''
    runHook preInstall

    # Create directory structure
    mkdir -p $out/opt
    mkdir -p $out/bin
    mkdir -p $out/share/applications
    mkdir -p $out/share/icons/hicolor
    mkdir -p $out/share/licenses/${pname}

    # Move main application
    cp -r opt/CurseForge $out/opt/${pname}

    # Fix desktop file
    sed -i "s:/opt/CurseForge:$out/opt/${pname}:" usr/share/applications/${pname}.desktop
    cp usr/share/applications/${pname}.desktop $out/share/applications/

    # Copy icons
    cp -r usr/share/icons/hicolor/* $out/share/icons/hicolor/

    # Create wrapper script
    makeWrapper $out/opt/${pname}/${pname} $out/bin/${pname} \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}" \
      --set SSL_CERT_FILE "/etc/ssl/certs/ca-certificates.crt"

    # Install licenses
    cp $out/opt/${pname}/LICENSE.electron.txt $out/share/licenses/${pname}/
    cp $out/opt/${pname}/LICENSES.chromium.html $out/share/licenses/${pname}/

    runHook postInstall
  '';

  # Update with: update-curseforge (fetches latest version from Arch AUR)

  meta = with lib; {
    description = "CurseForge desktop client for Linux";
    homepage = "https://curseforge.com";
    license = with licenses; [ unfree mit ];
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
}
