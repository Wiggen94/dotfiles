# waydroid-nvidia — NVIDIA GPU acceleration for Waydroid
#
# Android apps issue Vulkan into a guest Mesa Venus driver, which forwards over
# a Unix socket to a host virglrenderer vtest server (wd-venus) that replays on
# the real NVIDIA GPU. See docs/superpowers/specs/2026-08-05-waydroid-nvidia-design.md
#
# Upstream: https://github.com/CinQwQeggs01/waydroid-nvidia
{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  fetchFromGitHub,
  autoPatchelfHook,
  zstd,
  expat,
  libdrm,
  libepoxy,
  libgbm,
  libx11,
  vulkan-loader,
  # The nftables variant is mandatory here, not a preference: this kernel is
  # built with CONFIG_NETFILTER_XTABLES_LEGACY unset, and waydroid-net.sh
  # prefers `iptables-legacy` whenever it is on PATH (nixpkgs' iptables ships
  # it), so the iptables build fails container start with "Table does not
  # exist". The nftables build sets LXC_USE_NFT=true and emits its own
  # `lxc` nft tables, which coexist with the firewall's iptables-nft ones.
  waydroid-nftables,
  writeShellApplication,
  binutils,
  coreutils,
  gnugrep,
  python3,
  util-linux,

  # Phase 3: a directory holding the ANGLE guest libraries in Android-relative
  # layout (vendor/lib/egl/libEGL_angle.so, vendor/lib64/egl/…). ANGLE is not
  # distributed prebuilt by upstream and must be built locally; until then GLES
  # falls back to software rendering. Set this to wire it in.
  angleGuest ? null,
}:

let
  version = "0.1.0";
  releaseUrl = "https://github.com/CinQwQeggs01/waydroid-nvidia/releases/download/v${version}";
in
rec {
  # Host-side renderer. CI-built on Ubuntu 24.04, so autoPatchelf it onto our
  # libraries. The Vulkan loader is dlopened rather than linked, hence the
  # appended runpath; it resolves NVIDIA's ICD via /run/opengl-driver.
  host = stdenv.mkDerivation {
    pname = "waydroid-nvidia-host";
    inherit version;

    src = fetchurl {
      url = "${releaseUrl}/waydroid-nvidia-host-x86_64-v${version}.tar.zst";
      hash = "sha256-BA/o3egaZGChN6U2Gn0+TC41AECQaoGjxiVlqp4SarE=";
    };

    # Tarball members sit at the archive root, so there is no directory to
    # descend into.
    sourceRoot = ".";

    nativeBuildInputs = [
      autoPatchelfHook
      zstd
    ];

    buildInputs = [
      expat
      libdrm
      libepoxy
      libgbm
      libx11
    ];

    appendRunpaths = [ "${vulkan-loader}/lib" ];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 virgl_test_server virgl_render_server -t $out/lib/waydroid-nvidia
      install -Dm755 libvirglrenderer.so.1 -t $out/lib/waydroid-nvidia
      runHook postInstall
    '';

    meta = {
      description = "Host Venus render server for Waydroid on NVIDIA";
      homepage = "https://github.com/CinQwQeggs01/waydroid-nvidia";
      license = lib.licenses.mit;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };

  # Guest driver payload, kept in Android-relative layout. These are bionic
  # ELFs that execute inside the container against Android's linker — fixup
  # would corrupt them, so it is disabled wholesale.
  guest = stdenvNoCC.mkDerivation {
    pname = "waydroid-nvidia-guest";
    inherit version;

    src = fetchurl {
      url = "${releaseUrl}/waydroid-nvidia-guest-android-x86_64-v${version}.tar.zst";
      hash = "sha256-1EQKfPleexebOeEiuVIHmRhitGlRM+JLFs/IR9SCwsU=";
    };

    sourceRoot = ".";

    nativeBuildInputs = [ zstd ];

    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;

    installPhase = ''
      runHook preInstall

      dest=$out/share/waydroid-nvidia/guest
      mkdir -p "$dest"
      cp -r vendor "$dest/"

      # Patched hwcomposer ships only as a CI artifact; see prebuilt/PROVENANCE.md
      install -Dm644 ${./prebuilt/hwcomposer.waydroid.so} \
        "$dest/vendor/lib64/hw/hwcomposer.waydroid.so"

      ${lib.optionalString (angleGuest != null) ''
        cp -r --no-preserve=mode,ownership ${angleGuest}/. "$dest/"
      ''}

      # Both ABIs of the Venus driver must survive: flattening them would let
      # one overwrite the other, which boots to a crash loop.
      test -f "$dest/vendor/lib/hw/vulkan.virtio.so"
      test -f "$dest/vendor/lib64/hw/vulkan.virtio.so"

      runHook postInstall
    '';

    meta = {
      description = "Guest Venus/gralloc/hwcomposer payload for Waydroid on NVIDIA";
      homepage = "https://github.com/CinQwQeggs01/waydroid-nvidia";
      license = lib.licenses.mit;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };

  # Waydroid pinned to the commit upstream's patch targets (nixpkgs ships
  # 1.6.3, which predates it). 0001 is upstream's integration patch; 0002 is
  # ours — see patches/0002-nv-guest-mounts-skip-absent.patch.
  waydroid-patched = waydroid-nftables.overrideAttrs (old: {
    pname = "waydroid-nvidia";
    version = "${old.version}-unstable-2026-07-13";

    src = fetchFromGitHub {
      owner = "waydroid";
      repo = "waydroid";
      rev = "a33a5c0b31d89d6ce687381104b30aff4dd2d330";
      hash = "sha256-V8TTnfnsujDnW9Q2SZN/+2jPxxtWLbiSTydK8Jv4QS0=";
    };

    patches = (old.patches or [ ]) ++ [
      ./patches/0001-nvidia-integration.patch
      ./patches/0002-nv-guest-mounts-skip-absent.patch
    ];

    # nix-update cannot track a pinned integration base.
    passthru = lib.removeAttrs (old.passthru or { }) [ "updateScript" ];
  });

  # Provisions an initialised Waydroid install for this stack: validates the
  # guest payload and host prerequisites, installs the payload where the
  # container's bind-mounts expect it, and writes waydroid.cfg.
  setup = writeShellApplication {
    name = "waydroid-nvidia-setup";

    runtimeInputs = [
      binutils # readelf, for the guest ELF validation
      coreutils
      gnugrep
      python3
      util-linux # mount, for inspecting vendor.img
      waydroid-patched
    ];

    text = ''
      export WAYDROID_NVIDIA_GUEST_SRC="${guest}/share/waydroid-nvidia/guest"
      exec bash ${./setup.sh} "$@"
    '';
  };
}
