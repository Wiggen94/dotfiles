# waydroid-nvidia — NVIDIA GPU acceleration for Waydroid
#
# nvidia-prolapse (the default and only mode packaged here): Mesa's NVK runs
# inside Android against the host's NVIDIA kernel module, so there is no host
# renderer and no socket relay. ANGLE still translates guest GLES on top of it.
# See docs/superpowers/specs/2026-11-02-waydroid-nvidia-0.2.0-prolapse-design.md
#
# Upstream: https://github.com/Shiro836/waydroid-nvidia
#
# Use upstream, not the fork (now at quinovax/waydroid-nvidia; the old
# CinQwQeggs01 URL redirects there). The fork was avoided because its v0.1.1
# host `virgl_test_server` lacked `vtest_gpu_alloc` and crash-looped with
# VTEST_CLIENT_ERROR_COMMAND_ID. That reason is spent — the prolapse path
# needs no host renderer — so this is now just "upstream is the maintained
# one". Note the fork does ship `guest-prebuilts`; that was never the issue.
#
# guest/prebuilts/houdini are plain hash-pinned fetchurls of upstream's own
# release tarballs — no vendored binaries, no auth-gated CI artifacts, no
# expiry.
{
  lib,
  stdenvNoCC,
  fetchurl,
  fetchFromGitHub,
  zstd,
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
  unzip,
  util-linux,
}:

let
  version = "0.2.0";
  releaseUrl = "https://github.com/Shiro836/waydroid-nvidia/releases/download/v${version}";

  # Venus Vulkan driver (both ABIs) + the gralloc wrapper.
  guestTarball = fetchurl {
    url = "${releaseUrl}/waydroid-nvidia-guest-android-x86_64-v${version}.tar.zst";
    hash = "sha256-e1enSUC7Hl2xBWoBVNKHXztJjrarZFZl9vbpCGn5Brc=";
  };

  # ANGLE (both ABIs), hwcomposer, patched surfaceflinger. Built on upstream's
  # self-hosted runner, which is why only real releases carry it.
  prebuiltsTarball = fetchurl {
    url = "${releaseUrl}/waydroid-nvidia-guest-prebuilts-v${version}.tar.zst";
    hash = "sha256-fdCYwB4AFZ2mazJJhy1IdzvTRJqq536sI6uR/Kvjztw=";
  };

  # CI-built nvidia-prolapse driver bundle. The tarball is the bundle only
  # (BUILD-RECORD.json, gate/, glibc-shim/, payload/); the Python tooling that
  # drives it lives in the source archive, so both are fetched.
  nativeTarball = fetchurl {
    url = "${releaseUrl}/waydroid-nvidia-native-x86_64-v${version}.tar.zst";
    hash = "sha256-M8n3X6IWxTgo6T6PsqTmNWLjqyeyTIEmiHnuSDkPzPg=";
  };

  vendorZip = fetchurl {
    url = "${releaseUrl}/waydroid-nvidia-vendor-x86_64-v${version}.zip";
    hash = "sha256-aSoO60XCiEkvZt26W3fqFfAPiOylNUsEjsSx51Ku4ps=";
  };

  vendorChannel = fetchurl {
    url = "${releaseUrl}/waydroid-nvidia-vendor-ota-v${version}.json";
    hash = "sha256-KUCgTXG6JuMvhexyI7GTRKicueyq/eSnFar5z/TuPGA=";
  };

  # Supplies dev/source-native, dev/driver-mode, packaging/native/*.py,
  # waydroid/nvidia_native.py and the media staging script that
  # install-native.sh installs alongside the bundle.
  sourceArchive = fetchurl {
    url = "https://github.com/Shiro836/waydroid-nvidia/archive/refs/tags/v${version}.tar.gz";
    hash = "sha256-tkOqJn54bBDQMaTYvYnTfaf8aWuyxD1jPDcSaiY7hUU=";
  };

  # libhoudini — Intel's proprietary ARM→x86 translator, needed for ARM-only
  # apps (a large share of the Play Store). Not in nixpkgs and not redistributed
  # by Intel; this is the same pinned commit archive and checksum that
  # casualsnek/waydroid_script uses, so it is hash-pinned like everything else
  # rather than fetched by a script at runtime. MD5 verified against upstream's
  # pin (3807fe029559db3037efe245d9e74270).
  #
  # Tracks the repo's `hpe-14` branch. Note the branch name is the Android
  # lineage of the *donor image*, not of our guest: both this commit and the
  # 9e77896 it replaced were pulled from UKW1 (Android 14) images, so the bump
  # stays within one houdini generation. An earlier revision of this comment
  # called 9e77896 "the Android 13 build", which its own commit message
  # ("GooglePlayGames PC UKW1.251130.001") contradicts — don't reintroduce
  # that. The `aow*`/`wsa*` branches are separate lineages, not newer.
  #
  # Bumped 2026-09-14 from 9e77896 (2026-01-02, GooglePlayGames PC
  # UKW1.251130.001) to chase an arm64 translation hang: an ARM64-only Unity
  # title wedged its main thread at a fixed PC inside lib64/libhoudini.so and
  # never made progress, ANR'ing on input dispatch every ~20s while burning
  # ~16 cores. Nothing on our side reaches that code, so a newer translator
  # build is the only lever. libhoudini.so (arm64) differs, 9323480 ->
  # 9421784 bytes; the houdini64 loader stub is byte-identical in size, as
  # expected since it is only a shim.
  #
  # This is NOT a confirmed fix — it is an upstream binary drop with no
  # changelog. If the hang persists, that is the expected-failure case and
  # reverting to 9e77896 costs nothing.
  #
  # No longer the same pin casualsnek/waydroid_script uses, so upstream's MD5
  # (3807fe029559db3037efe245d9e74270) no longer applies; the fetchurl hash
  # below is the only integrity check, which is what it was doing anyway.
  houdiniZip = fetchurl {
    url = "https://github.com/supremegamers/vendor_intel_proprietary_houdini/archive/2f8f088671182e17e67321e098e8411a3972a628.zip";
    hash = "sha256-LoLNyI3cTUGPf7hhruu3xJyDqRuX9X2hBRC14RRqTtU=";
  };
in
rec {
  # nvidia-prolapse driver tooling + CI-built driver bundle, laid out as
  # upstream's install-native.sh does. stage_release() copies every artifact to
  # a fresh destination under /var/lib/waydroid and writes nothing here, so a
  # read-only store prefix is fine for writing — but the tools carry absolute
  # /usr/lib/waydroid-nvidia and /usr/lib/waydroid constants that a store prefix
  # does not satisfy, so they are patched (see patches/nixos/).
  #
  # dontFixup is required, not stylistic: fixupPhase would run strip over
  # everything under $out/lib, rewriting the bionic ELFs in release/payload and
  # release/gate. That changes their sha256 and verify_bundle() then rejects the
  # bundle it just installed.
  native = stdenvNoCC.mkDerivation {
    pname = "waydroid-nvidia-native";
    inherit version;

    src = sourceArchive;
    dontFixup = true;

    nativeBuildInputs = [ zstd ];

    patches = [
      ./patches/nixos/store-paths.patch
      ./patches/nixos/no-etc-writes.patch
      ./patches/nixos/nvidia-native-paths.patch
    ];

    # The patches above only turn the hardcoded constants into placeholders;
    # these are the values they stand for. Grouped by which file contains which
    # placeholder, since --replace-fail errors on a placeholder a file lacks.
    # nvidia_native.py needs none: its paths are derived from its own location,
    # because waydroid-patched carries the same bytes (see nvidia-native-paths).
    postPatch = ''
      substituteInPlace dev/source-native \
        --replace-fail '@PYTHON@' "${python3}/bin/python3" \
        --replace-fail '@WAYDROID_PREFIX@' "${waydroid-patched}/lib/waydroid"

      substituteInPlace packaging/native/release_gate.py \
        --replace-fail '@NATIVE_ROOT@' "${placeholder "out"}/lib/waydroid-nvidia/native"
    '';

    installPhase = ''
      runHook preInstall

      nat=$out/lib/waydroid-nvidia/native
      mkdir -p "$nat"

      for f in \
        dev/source-native dev/driver-mode \
        waydroid/nvidia_native.py \
        tools/native_rust_profile.py \
        packaging/native/release_gate.py \
        packaging/native/vendor_image.py \
        packaging/native/glibc_shim.py \
        nvidia-prolapse/shim/tools/import-census.py \
        nvidia-prolapse/shim/dispositions.tsv \
        nvidia-prolapse/shim/dispositions-x86.tsv \
        nvidia-prolapse/media/stage-odm.sh \
        nvidia-prolapse/media/test/validate_xml.py; do
        install -Dm644 "$f" "$nat/$f"
      done
      chmod +x "$nat/dev/source-native" "$nat/dev/driver-mode" \
               "$nat/packaging/native/release_gate.py" \
               "$nat/packaging/native/vendor_image.py" \
               "$nat/packaging/native/glibc_shim.py" \
               "$nat/waydroid/nvidia_native.py" \
               "$nat/nvidia-prolapse/media/stage-odm.sh"

      cp -r nvidia-prolapse/media/odm "$nat/nvidia-prolapse/media/"

      # The bundle's own BUILD-RECORD.json is the integrity manifest the
      # install path verifies file-by-file; do not strip or rewrite it.
      mkdir -p "$nat/release"
      tar --zstd -xf ${nativeTarball} -C "$nat/release"

      # Marks a packaged install (dev/source-native branches on this).
      : > "$nat/PACKAGED"

      # NixOS: the module owns the container unit's drop-in and there is no alpm
      # hook directory, so the tools must not try to write either.
      : > "$nat/NO_SYSTEMD_WRITES"

      runHook postInstall
    '';

    meta = {
      description = "nvidia-prolapse driver tooling and CI-built driver bundle for Waydroid";
      homepage = "https://github.com/Shiro836/waydroid-nvidia";
      license = with lib.licenses; [ mit gpl3Plus asl20 ];
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };

  # Upstream's Android vendor image, installed as a vendor module by
  # waydroid-nvidia-setup. Hash-pinned like everything else; setup copies it
  # into /var/lib/waydroid/images at provisioning time. dontFixup skips a
  # pointless strip pass over 200 MB of zip and JSON, which only survives
  # because stripDirs tolerates a non-ELF failure.
  vendor = stdenvNoCC.mkDerivation {
    pname = "waydroid-nvidia-vendor";
    inherit version;

    dontUnpack = true;
    dontFixup = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/waydroid-nvidia/vendor"
      install -Dm644 ${vendorZip} \
        "$out/lib/waydroid-nvidia/vendor/waydroid-nvidia-vendor-x86_64-v${version}.zip"
      install -Dm644 ${vendorChannel} \
        "$out/lib/waydroid-nvidia/vendor/waydroid-nvidia-vendor-ota-v${version}.json"
      runHook postInstall
    '';

    meta = {
      description = "Android vendor image and OTA channel for the nvidia-prolapse Waydroid stack";
      homepage = "https://github.com/Shiro836/waydroid-nvidia";
      license = with lib.licenses; [ asl20 ];   # LineageOS-derived image
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

  # ARM translation payload, laid out as it must land in the guest's /system.
  # Bionic/ARM ELFs executed inside the container — never fixup them.
  houdini = stdenvNoCC.mkDerivation {
    pname = "waydroid-nvidia-houdini";
    version = "14-2f8f088";

    src = houdiniZip;

    nativeBuildInputs = [ unzip ];
    dontFixup = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      dest=$out/share/waydroid-nvidia/houdini/system
      mkdir -p "$dest"
      cp -r prebuilts/. "$dest/"

      # binfmt_misc registration for the four ARM ELF flavours. The archive's own
      # houdini.rc is replaced, matching what waydroid_script does — the guest
      # needs exactly these handlers and this mount.
      mkdir -p "$dest/etc/init"
      cat > "$dest/etc/init/houdini.rc" <<'RC'
      on early-init
          mount binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc

      on property:ro.enable.native.bridge.exec=1
          exec -- /system/bin/sh -c "echo ':arm_exe:M::\x7f\x45\x4c\x46\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28::/system/bin/houdini:P' > /proc/sys/fs/binfmt_misc/register"
          exec -- /system/bin/sh -c "echo ':arm_dyn:M::\x7f\x45\x4c\x46\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x03\x00\x28::/system/bin/houdini:P' >> /proc/sys/fs/binfmt_misc/register"
          exec -- /system/bin/sh -c "echo ':arm64_exe:M::\x7f\x45\x4c\x46\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7::/system/bin/houdini64:P' >> /proc/sys/fs/binfmt_misc/register"
          exec -- /system/bin/sh -c "echo ':arm64_dyn:M::\x7f\x45\x4c\x46\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x03\x00\xb7::/system/bin/houdini64:P' >> /proc/sys/fs/binfmt_misc/register"
      RC
      sed -i 's/^      //' "$dest/etc/init/houdini.rc"

      for f in bin/houdini bin/houdini64 lib/libhoudini.so lib64/libhoudini.so; do
        test -f "$dest/$f" || { echo "houdini payload missing $f" >&2; exit 1; }
      done

      runHook postInstall
    '';

    meta = {
      description = "Intel libhoudini ARM translation payload for Waydroid (hpe-14 branch, UKW1 donor image)";
      homepage = "https://github.com/supremegamers/vendor_intel_proprietary_houdini";
      license = lib.licenses.unfree;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };

  # Waydroid pinned to the commit upstream's patches target (nixpkgs ships
  # 1.6.3, which predates it). Both patches are upstream v0.2.0's, unmodified,
  # and must be applied in this order — 0002 patches context that 0001
  # introduces, so reversing them fails the session_manager.py and lxc.py
  # hunks:
  #   patches/waydroid/0001-nvidia-integration.patch
  #   waydroid/0001-lxc-nvidia-native-mounts.patch  (renumbered to 0002 here;
  #                                                  upstream keeps it outside
  #                                                  patches/ — see patches/BASE)
  # Upstream also ships waydroid/patches/0001-blobcache-reset-size-when-clearing
  # .patch, which neither their own packaging nor ours applies.
  #
  # Our own patches are the two under patches/nixos/, both NixOS-portability
  # fixes rather than behaviour changes: the shared nvidia_native.py paths, and
  # the mode that keeps nixpkgs from rewriting that file (see postPatch below).
  #
  # The guest-mount-skip patch this package used to carry is gone for a reason
  # that still holds: it existed because the generator emitted every layout-2
  # guest bind-mount unconditionally, and that is load-bearing for
  # --no-hwcomposer, which leaves hwcomposer out of GUEST_LIBS while upstream's
  # list includes it. In v0.2.0 the whole block is guarded by
  # `if venus_socket or (native and guest_layout)`, and the mode this config
  # provisions (nvidia-prolapse with install=vendor-image) reports guest_layout
  # False, so it is not reached; dev-root and glibc-shim do reach it, and
  # upstream's own not_in_native handles those.
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
      ./patches/0002-lxc-nvidia-native-mounts.patch
      # Same bytes as `native`'s copy, so waydroid_argv()'s byte-identity check
      # against the release bundle holds. Must come after 0002, which creates it.
      ./patches/nixos/nvidia-native-paths-waydroid.patch
    ];

    # 0002 creates tools/helpers/nvidia_native.py mode 755, and `make install`
    # cp -a's tools/ wholesale. nixpkgs' wrapPythonProgramsIn then runs
    # `find -perm -0100` over lib/waydroid and swaps every hit for an ELF
    # launcher — which changes the hash waydroid_argv() compares. The file is a
    # module there, never an entry point, so 644 is both correct and unwrapped.
    postPatch = (old.postPatch or "") + ''
      chmod 0644 tools/helpers/nvidia_native.py
    '';

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

  # Guest tweaks that need a running session (guest state, not properties):
  # the WebView Vulkan-draw-functor workaround, pointer speed, and the settings
  # DB tweaks. Driven through `waydroid shell` rather than adb over TCP.
  tweak = writeShellApplication {
    name = "waydroid-nvidia-tweak";

    runtimeInputs = [
      coreutils
      gnugrep
      waydroid-patched
    ];

    text = ''
      exec bash ${./tweak.sh} "$@"
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
      export WAYDROID_NVIDIA_HOUDINI_SRC=${houdini}/share/waydroid-nvidia/houdini
      exec bash ${./setup.sh} "$@"
    '';
  };
}
