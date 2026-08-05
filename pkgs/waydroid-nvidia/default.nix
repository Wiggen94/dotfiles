# waydroid-nvidia — NVIDIA GPU acceleration for Waydroid
#
# Android apps issue Vulkan into a guest Mesa Venus driver, which forwards over
# a Unix socket to a host virglrenderer vtest server (wd-venus) that replays on
# the real NVIDIA GPU. ANGLE translates guest GLES to Vulkan on top of that.
# See docs/superpowers/specs/2026-08-05-waydroid-nvidia-design.md
#
# Upstream: https://github.com/Shiro836/waydroid-nvidia
#
# Use THIS repo, not the CinQwQeggs01 fork. The fork's releases omit the
# guest-prebuilts tarball (ANGLE, hwcomposer, patched surfaceflinger) and its CI
# has shipped host binaries with the vtest GPU allocator missing since
# 2026-07-31. Upstream publishes all three tarballs per release, so everything
# here is a plain hash-pinned fetchurl — no vendored binaries, no auth-gated CI
# artifacts, no expiry.
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
  gnused,
  python3,
  systemd,
  util-linux,
}:

let
  version = "0.1.2";
  releaseUrl = "https://github.com/Shiro836/waydroid-nvidia/releases/download/v${version}";

  hostTarball = fetchurl {
    url = "${releaseUrl}/waydroid-nvidia-host-x86_64-v${version}.tar.zst";
    hash = "sha256-Y3LU94/06UQuMqYNmx6tEfI4Ek9azVepK7tP10ydYeg=";
  };

  # Venus Vulkan driver (both ABIs) + the gralloc wrapper.
  guestTarball = fetchurl {
    url = "${releaseUrl}/waydroid-nvidia-guest-android-x86_64-v${version}.tar.zst";
    hash = "sha256-wKbuemnGvGB19xl9bDzC4hO/GwYbAy8g2m90QfhwRXQ=";
  };

  # ANGLE (both ABIs), hwcomposer, patched surfaceflinger. Built on upstream's
  # self-hosted runner, which is why only real releases carry it.
  prebuiltsTarball = fetchurl {
    url = "${releaseUrl}/waydroid-nvidia-guest-prebuilts-v${version}.tar.zst";
    hash = "sha256-YYmfVsIDt1DUH3wUGh7iZMtoJBdIzJzaUS7UXymXy9E=";
  };
in
rec {
  # Host-side renderer. CI-built on Ubuntu 24.04, so autoPatchelf it onto our
  # libraries. The Vulkan loader is dlopened rather than linked, hence the
  # appended runpath; it resolves NVIDIA's ICD via /run/opengl-driver.
  host = stdenv.mkDerivation {
    pname = "waydroid-nvidia-host";
    inherit version;

    src = hostTarball;
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

      # A host without the vtest GPU allocator answers the guest's allocation
      # command with VTEST_CLIENT_ERROR_COMMAND_ID and the session crash-loops.
      # Upstream's fork has shipped such builds, so check rather than trust.
      if ! strings $out/lib/waydroid-nvidia/virgl_test_server | grep -q vtest_gpu_alloc; then
        echo "virgl_test_server has no vtest GPU allocator — wrong or broken build" >&2
        exit 1
      fi
      runHook postInstall
    '';

    meta = {
      description = "Host Venus render server for Waydroid on NVIDIA";
      homepage = "https://github.com/Shiro836/waydroid-nvidia";
      license = lib.licenses.mit;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };

  # Guest driver payload in Android-relative layout. These are bionic ELFs that
  # execute inside the container against Android's linker, so fixup is disabled
  # wholesale — patchelf would corrupt them.
  guest = stdenvNoCC.mkDerivation {
    pname = "waydroid-nvidia-guest";
    inherit version;

    dontUnpack = true;
    dontFixup = true;

    nativeBuildInputs = [ zstd ];

    installPhase = ''
      runHook preInstall

      dest=$out/share/waydroid-nvidia/guest
      mkdir -p "$dest"
      tar --zstd -xf ${guestTarball} -C "$dest"
      tar --zstd -xf ${prebuiltsTarball} -C "$dest"

      # The prebuilts tarball ships its own manifest; use it.
      ( cd "$dest" && sha256sum -c --ignore-missing SHA256SUMS.prebuilts )
      rm -f "$dest/SHA256SUMS.prebuilts" "$dest/README.txt"

      # Both ABIs of every app-facing driver must survive: flattening them would
      # let one overwrite the other, which boots to a crash loop.
      for f in \
        vendor/lib/hw/vulkan.virtio.so vendor/lib64/hw/vulkan.virtio.so \
        vendor/lib/egl/libEGL_angle.so vendor/lib64/egl/libEGL_angle.so \
        vendor/lib/egl/libGLESv2_angle.so vendor/lib64/egl/libGLESv2_angle.so \
        vendor/lib64/libgbm_mesa_wrapper.so \
        vendor/lib64/hw/hwcomposer.waydroid.so \
        system/bin/surfaceflinger; do
        test -f "$dest/$f" || { echo "missing guest payload: $f" >&2; exit 1; }
      done

      runHook postInstall
    '';

    meta = {
      description = "Guest Venus/ANGLE/gralloc payload for Waydroid on NVIDIA";
      homepage = "https://github.com/Shiro836/waydroid-nvidia";
      license = lib.licenses.mit;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };

  # Waydroid pinned to the commit upstream's patch targets (nixpkgs ships
  # 1.6.3, which predates it). 0001 is the integration patch, taken from the
  # CinQwQeggs01 fork because it is a strict superset of upstream's — it adds a
  # D-Bus NameHasNoOwner fallback and retries the Venus socket preflight, and
  # both repos pin the same waydroid base. 0002 is ours.
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

  # Bounded session probe: starts a session, captures guest + host logs, stops.
  # Exists because a crash-looping guest can make the desktop unresponsive, so
  # diagnosis needs a hard time budget and a sudo prompt taken up front.
  probe = writeShellApplication {
    name = "waydroid-nvidia-probe";

    runtimeInputs = [
      coreutils
      gnugrep
      gnused
      systemd
      waydroid-patched
    ];

    text = ''
      exec bash ${./probe.sh} "$@"
    '';
  };

  # Provisions an initialised Waydroid install for this stack: validates the
  # guest payload and host prerequisites, installs the payload where the
  # container's bind-mounts expect it, and writes waydroid.cfg.
  setup = writeShellApplication {
    name = "waydroid-nvidia-setup";

    runtimeInputs = [
      binutils # readelf, for the guest ELF validation
      coreutils
      gnugrep
      gnused
      python3
      util-linux # mount, for inspecting vendor.img
      waydroid-patched
    ];

    text = ''
      export WAYDROID_NVIDIA_GUEST_SRC=${guest}/share/waydroid-nvidia/guest
      exec bash ${./setup.sh} "$@"
    '';
  };
}
