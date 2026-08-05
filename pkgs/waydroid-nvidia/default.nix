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
# 2026-07-31.
#
# guest/prebuilts/houdini are plain hash-pinned fetchurls of upstream's own
# release tarballs — no vendored binaries, no auth-gated CI artifacts, no
# expiry. host is the one exception: built from source (see below) rather
# than upstream's tarball, to carry a local fix for a confirmed crash bug.
{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  fetchFromGitHub,
  fetchFromGitLab,
  zstd,
  libdrm,
  libepoxy,
  libgbm,
  libGLU,
  libx11,
  meson,
  ninja,
  patchelf,
  pkg-config,
  vulkan-headers,
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
  # Android 13 build, matching the LineageOS-20 image. The 11 archive is a
  # different commit and would be wrong here.
  houdiniZip = fetchurl {
    url = "https://github.com/supremegamers/vendor_intel_proprietary_houdini/archive/9e77896350caccd228b36b2e1b4a994aa4bd48da.zip";
    hash = "sha256-sJ5R9rQZxz9SOnnlANe0vlYTX3F+W9HR1wha6mVvWc0=";
  };
in
rec {
  # Host-side renderer, built from source rather than Shiro836's prebuilt
  # tarball. Recipe mirrors this project's own build/virglrenderer/build.sh
  # exactly (see patches/virglrenderer/BASE): virglrenderer at the pinned
  # base commit, Shiro836's 4-patch series applied in order, the net-new
  # vtest_gpu_alloc.{c,h} dropped into vtest/, then meson -Dvenus=true
  # -Drender-server-worker=auto + ninja.
  #
  # Patch 0005 is ours, not upstream's: a fix for a confirmed SIGSEGV ->
  # double-fault -> whole-process-killed bug. Reproduced and root-caused
  # live via coredumpctl (see docs/superpowers/specs/2026-08-05-waydroid-nvidia-design.md):
  # vtest_server.c's stock SIGSEGV handler calls exit() (not async-signal-
  # safe) after a context-create fault. exit() runs the NVIDIA driver's own
  # atexit hook, which tears down the same (already-faulted) EGL context
  # again; since SIGSEGV is still blocked in the handler (no SA_NODEFER),
  # that second fault can't be delivered normally and instead force-kills
  # the whole multi-client process — taking down every other client's
  # context along with the one that actually failed. This is why enabling
  # --arm-translation (more concurrent Venus clients at boot) reliably
  # broke session start even after waydroid-binfmt-guard fixed the
  # unrelated host-freeze bug: the crash was real, just misattributed.
  # _exit() skips atexit entirely, so only the one faulting client dies.
  host =
    let
      virglrendererSrc = fetchFromGitLab {
        domain = "gitlab.freedesktop.org";
        owner = "virgl";
        repo = "virglrenderer";
        rev = "dc35e4db03144f81637c5ad061f61d3334b078fe"; # patches/virglrenderer/BASE
        hash = "sha256-dhu1YNd9cukbUCBXjG3NL95u+lo8br1jap4+/kTAqEY=";
      };
    in
    stdenv.mkDerivation {
      pname = "waydroid-nvidia-host";
      inherit version;

      src = virglrendererSrc;

      patches = [
        ./patches/virglrenderer/0001-vtest-support-exporting-sync_file-fds-for-venus-sync.patch
        ./patches/virglrenderer/0002-vtest-support-importing-dmabufs-as-blob-resources-fo.patch
        ./patches/virglrenderer/0003-vtest-raise-listen-backlog-to-128.patch
        ./patches/virglrenderer/0004-wip-gpu-alloc-and-global-priority.patch
        ./patches/virglrenderer/0005-vtest-use-_exit-in-the-SIGSEGV-handler-not-exit.patch
      ];

      # Net-new source the 0004 series' vtest/meson.build change references;
      # upstream's own build.sh drops these into vtest/ the same way.
      postPatch = ''
        cp ${./patches/virglrenderer/vtest_gpu_alloc.c} vtest/vtest_gpu_alloc.c
        cp ${./patches/virglrenderer/vtest_gpu_alloc.h} vtest/vtest_gpu_alloc.h
      '';

      nativeBuildInputs = [
        meson
        ninja
        patchelf
        pkg-config
        (python3.withPackages (ps: [ ps.pyyaml ]))
      ];

      buildInputs = [
        libGLU
        libdrm
        libepoxy
        libgbm
        libx11
        vulkan-headers
        vulkan-loader
      ];

      mesonFlags = [
        "-Dvenus=true"
        "-Drender-server-worker=auto"
      ];

      installPhase = ''
        runHook preInstall
        install -Dm755 vtest/virgl_test_server server/virgl_render_server -t $out/lib/waydroid-nvidia
        install -Dm755 src/libvirglrenderer.so.1.11.0 -t $out/lib/waydroid-nvidia
        ln -s libvirglrenderer.so.1.11.0 $out/lib/waydroid-nvidia/libvirglrenderer.so.1

        # A host without the vtest GPU allocator answers the guest's allocation
        # command with VTEST_CLIENT_ERROR_COMMAND_ID and the session crash-loops.
        # Upstream's fork has shipped such builds, so check rather than trust.
        if ! strings $out/lib/waydroid-nvidia/virgl_test_server | grep -q vtest_gpu_alloc; then
          echo "virgl_test_server has no vtest GPU allocator — wrong or broken build" >&2
          exit 1
        fi
        runHook postInstall
      '';

      # meson's build-tree rpath ($ORIGIN/../src, where libvirglrenderer.so.1
      # sits relative to vtest/virgl_test_server before install) doesn't apply
      # once everything is flattened into one directory here. vulkan-loader is
      # dlopened rather than linked (meson's vulkan-dload default), and dlopen
      # consults the caller's rpath, so it needs to be on there explicitly too
      # — matching the prebuilt binary this replaces, which needed the same
      # appended runpath to resolve NVIDIA's ICD via /run/opengl-driver.
      #
      # --add-rpath, not --set-rpath: the latter replaces the rpath wholesale,
      # wiping out the libdrm/libgbm/libepoxy/libX11/libGLU entries stdenv's
      # linker wrapper already added for buildInputs. virgl_render_server
      # links libdrm and libgbm directly, so losing those isn't cosmetic —
      # it fails outright with "cannot open shared object file: libdrm.so.2"
      # the moment virgl_test_server tries to spawn it as its render-server
      # subprocess (confirmed live: this exact failure blocked every Venus
      # context creation and looked identical to the context-create bug
      # this same host package was rebuilt to fix).
      postFixup = ''
        for bin in virgl_test_server virgl_render_server; do
          patchelf --add-rpath "$out/lib/waydroid-nvidia:${vulkan-loader}/lib" \
            "$out/lib/waydroid-nvidia/$bin"
        done
      '';

      meta = {
        description = "Host Venus render server for Waydroid on NVIDIA";
        homepage = "https://github.com/Shiro836/waydroid-nvidia";
        license = lib.licenses.mit;
        platforms = [ "x86_64-linux" ];
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
    version = "13-9e77896";

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
      description = "Intel libhoudini ARM translation payload for Waydroid (Android 13)";
      homepage = "https://github.com/supremegamers/vendor_intel_proprietary_houdini";
      license = lib.licenses.unfree;
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
