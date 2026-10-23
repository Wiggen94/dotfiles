# omasnap with a wider screenshot preview (pkgs/omasnap).
#
# Omasnap hardcodes the floating preview card at 200 logical pixels wide and
# offers no config key for it (`pinFrameSize` in src/pin-layout.cpp). That is
# fine on a 16:9 laptop, but the card keeps the display's aspect ratio, so on
# the 5120x1440 desktop it is 200x56 — small enough to hide its own controls,
# which then fall into pinControlRect's "compact" two-row layout.
#
# omarchy-nix vendors its own omasnap (modules/packages.nix does its own
# callPackage from packages/omasnap.nix), so patching `pkgs.omasnap` cannot
# reach the installed binary. This re-derives that same source with one
# substitution and is installed alongside it under lib.hiPrio, so it wins the
# /run/current-system/sw/bin/omasnap collision.
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  pkg-config,
  makeWrapper,
  wayland-scanner,
  wayland-protocols,
  wayland,
  qt6,
  layer-shell-qt,
  tesseract,
  wl-clipboard,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "omasnap";
  version = "1.21.0";

  # Keep byte-identical to omarchy-nix's packages/omasnap.nix so the two builds
  # share the fetched source, and a version bump there is obvious here.
  src = fetchFromGitHub {
    owner = "omacom";
    repo = "omasnap";
    tag = "v${finalAttrs.version}";
    hash = "sha256-kpoPb5F5yqcczBRUfENsEfv+BD67zQsTG9Ur6Bi3viE=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    makeWrapper
    wayland-scanner
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    wayland
    qt6.qtbase
    layer-shell-qt
  ];

  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail /usr/share/wayland-protocols/ \
        ${wayland-protocols}/share/wayland-protocols/

    # The preview card's width, aspect-locked to the captured display: 400 is
    # 400x113 on 5120x1440, up from the hardcoded 200x56.
    substituteInPlace src/pin-layout.cpp \
      --replace-fail 'constexpr int width = 200;' 'constexpr int width = 400;'
  '';

  cmakeFlags = [ (lib.cmakeBool "BUILD_TESTING" false) ];

  postFixup = ''
    wrapProgram $out/bin/omasnap \
      --prefix PATH : ${lib.makeBinPath [ tesseract wl-clipboard ]}
  '';

  meta = {
    description = "Native Wayland screenshot and annotation editor (400px preview card)";
    homepage = "https://github.com/omacom/omasnap";
    license = [ lib.licenses.mit lib.licenses.ofl ];
    mainProgram = "omasnap";
    platforms = lib.platforms.linux;
  };
})
