# Herdr World — browser/mobile workspace for Herdr (the agent runtime that
# omarchy-nix already installs as `herdr`). Upstream ships a prebuilt,
# checksum-verified standalone bundle per release: a small Rust bridge
# (`herdr-world-bridge`), a Bash launcher, and the static web assets. We unpack
# that bundle, patchelf the bridge for NixOS, and wrap the launcher.
#
# https://github.com/IvoryHeart/herdr-world  — release v0.1.1, requires
# Herdr >= 0.8.2 with terminal protocol 20 (omarchy-nix currently ships 0.8.2).
#
# Bump: change `version` + `src.hash` together. The hash for the .sha256 sidecar
# is on the release page; convert with `nix hash convert --to sri --hash-algo sha256 <hex>`.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  coreutils,
  gawk,
  gnugrep,
  curl,
  herdr,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "herdr-world";
  version = "0.1.1";

  src = fetchurl {
    url = "https://github.com/IvoryHeart/herdr-world/releases/download/v${finalAttrs.version}/herdr-world-v${finalAttrs.version}-linux-x86_64.tar.gz";
    hash = "sha256-c+hk2FQO97nZ1+pOus2wDX8F4jGN4hDj05i6KjPe9ww=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  # herdr-world-bridge only links libgcc_s / libm / libc.
  buildInputs = [ stdenv.cc.cc.lib ];

  # ghostty-web (the Canvas-2D terminal renderer) draws everything in a
  # devicePixelRatio-scaled space. On any fractional DPR (most phones, browser
  # zoom) that puts cell edges and the text baseline between device pixels:
  # adjacent coloured cells get a 1px anti-aliased seam (powerline prompt,
  # box-drawing art) and every glyph is drawn at a sub-pixel pen position and
  # comes out soft.
  #
  # Fix, all snapping to the device-pixel grid:
  #   1. renderCellBackground — snap the rect origin, size it from the *next*
  #      cell's snapped edge so neighbours share an exact boundary.
  #   2. renderCellText — snap the glyph pen (x and baseline y).
  #   3. resize / the render() dirty-check — round the canvas backing store to a
  #      whole pixel count (and keep the two comparisons consistent, or it
  #      re-resizes every frame).
  # `--replace-fail` so a version bump that reshapes any of these lines breaks
  # the build instead of silently regressing.
  postPatch = ''
    for f in share/herdr-world/web/assets/ghostty-web-*.js; do
      substituteInPlace "$f" \
        --replace-fail \
          'renderCellBackground(e,t,n){let r=t*this.metrics.width,i=n*this.metrics.height,a=this.metrics.width*e.width;' \
          'renderCellBackground(e,t,n){let ''$d=this.devicePixelRatio,''$s=''$x=>Math.round(''$x*''$d)/''$d,r=''$s(t*this.metrics.width),i=''$s(n*this.metrics.height),''$h=''$s((n+1)*this.metrics.height)-i,a=''$s((t+e.width)*this.metrics.width)-r;' \
        --replace-fail \
          'this.ctx.fillRect(r,i,a,this.metrics.height)' \
          'this.ctx.fillRect(r,i,a,''$h)' \
        --replace-fail \
          'let u=i,d=a+this.metrics.baseline,f;' \
          'let ''$D=this.devicePixelRatio,u=Math.round(i*''$D)/''$D,d=Math.round((a+this.metrics.baseline)*''$D)/''$D,f;' \
        --replace-fail \
          'this.canvas.width=n*this.devicePixelRatio,this.canvas.height=r*this.devicePixelRatio,this.ctx.scale(this.devicePixelRatio,this.devicePixelRatio)' \
          'this.canvas.width=Math.round(n*this.devicePixelRatio),this.canvas.height=Math.round(r*this.devicePixelRatio),this.ctx.scale(this.devicePixelRatio,this.devicePixelRatio)' \
        --replace-fail \
          'this.canvas.width!==s.cols*this.metrics.width*this.devicePixelRatio||this.canvas.height!==s.rows*this.metrics.height*this.devicePixelRatio' \
          'this.canvas.width!==Math.round(s.cols*this.metrics.width*this.devicePixelRatio)||this.canvas.height!==Math.round(s.rows*this.metrics.height*this.devicePixelRatio)'
    done
  '';

  installPhase = ''
    runHook preInstall

    # Keep the bundle intact — the launcher derives its static-asset and bridge
    # paths relative to its own resolved location (bin/..).
    mkdir -p "$out/libexec/herdr-world"
    cp -r bin docs share third_party vendor VERSION LICENSE README.md THIRD_PARTY_NOTICES.md UPSTREAM.md \
      "$out/libexec/herdr-world/"

    patchShebangs "$out/libexec/herdr-world/bin"

    # `herdr` (from omarchy-nix) and the plain userland the launcher shells out
    # to — appended, so a system herdr still wins.
    makeWrapper "$out/libexec/herdr-world/bin/herdr-world" "$out/bin/herdr-world" \
      --suffix PATH : ${lib.makeBinPath [ herdr coreutils gawk gnugrep curl ]}

    runHook postInstall
  '';

  # The wrapper is a script; nothing to strip beyond the already-patched bridge.
  dontStrip = true;

  meta = {
    description = "Browser and mobile workspace for Herdr (Spaces, Pixel Office, Graph themes)";
    homepage = "https://github.com/IvoryHeart/herdr-world";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "herdr-world";
  };
})
