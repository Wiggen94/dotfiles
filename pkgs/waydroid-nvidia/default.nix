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
  version = "0.1.2";
  releaseUrl = "https://github.com/Shiro836/waydroid-nvidia/releases/download/v${version}";

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
  # We carry no patch of our own. The guest-mount-skip patch existed because
  # the generator emitted every layout-2 guest bind-mount unconditionally, and
  # that is load-bearing for --no-hwcomposer, which leaves hwcomposer out of
  # GUEST_LIBS while upstream's list includes it. In v0.2.0 the whole block is
  # guarded by `if venus_socket or (native and guest_layout)`, and the mode this
  # config provisions (nvidia-prolapse with install=vendor-image) reports
  # guest_layout False, so it is not reached; dev-root and glibc-shim do reach
  # it, and upstream's own not_in_native handles those.
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
