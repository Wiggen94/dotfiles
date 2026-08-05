# waydroid-nvidia — NVIDIA GPU acceleration for Waydroid
#
# Android apps issue Vulkan into a guest Mesa Venus driver, which forwards over
# a Unix socket to a host virglrenderer vtest server (wd-venus) that replays on
# the real NVIDIA GPU. See docs/superpowers/specs/2026-08-05-waydroid-nvidia-design.md
#
# Upstream: https://github.com/CinQwQeggs01/waydroid-nvidia
#
# Everything here is pinned to upstream commit 67ec6a8 / CI run 30735717707.
# Host and guest halves MUST come from the same build: mixing them across
# upstream's Venus fixes produces VTEST_CLIENT_ERROR_COMMAND_DISPATCH.
#
# Binary split, and why:
#   host  — vendored in prebuilt/host (4.2 MB). Ubuntu-built ELFs that need
#           Nix-time autoPatchelf, so they have to be in the store.
#   guest — NOT in this repo. The two Venus drivers alone are 54 MB and upstream
#           rebuilds them weekly; vendoring would grow git history permanently.
#           They live in /var/lib/waydroid-nvidia/guest, fetched by
#           `waydroid-nvidia-fetch-payload`. ANGLE lands there too (phase 3).
{
  lib,
  stdenv,
  autoPatchelfHook,
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
  fetchFromGitHub,
  writeShellApplication,
  binutils,
  coreutils,
  gh,
  gnugrep,
  gnused,
  python3,
  systemd,
  util-linux,
  zstd,
}:

let
  # Upstream commit the vendored host binaries and the guest payload both
  # come from. Bump these together, never individually.
  #
  # NOT the newest build, deliberately. Upstream's host artifact has been broken
  # since 2026-07-31 (commit 67ec6a8, "update patch numbering"): runs
  # 30633405529, 30637081023 and 30735717707 all emit a byte-identical
  # virgl_test_server with the vtest GPU allocator missing entirely
  # (`strings ... | grep -c vtest_gpu_alloc` → 0, vs 8 here). The guest sends
  # upstream's custom allocation command, the host does not implement it, and
  # the session dies with VTEST_CLIENT_ERROR_COMMAND_ID.
  #
  # This is the newest run whose host is intact, and its headline fix is "vtest
  # fd handling" — plausibly the cause of the VTEST_CLIENT_ERROR_COMMAND_DISPATCH
  # seen with the v0.1.0 pair. Trade-off: it predates two guest Venus fixes
  # (6bd05a7 codeSize truncate, 67ec6a8 vkCreateDevice -3 retry). Building the
  # host from source would get both; see the spec's phase notes.
  upstreamRev = "36867e1";
  ciRunId = "30415334277";

  # Where the guest payload lives on the host. The setup script installs from
  # here into /var/lib/waydroid/nv/guest, which the patched container config
  # generator bind-mounts into the container.
  #
  # ANGLE is a sibling rather than part of the payload: the fetch helper
  # replaces payloadDir wholesale on every run, and a 16 GB local build's output
  # must not be collateral damage.
  payloadDir = "/var/lib/waydroid-nvidia/guest";
  angleDir = "/var/lib/waydroid-nvidia/angle";
in
rec {
  inherit payloadDir angleDir;

  # Host-side renderer. CI-built on Ubuntu 24.04, so autoPatchelf it onto our
  # libraries. The Vulkan loader is dlopened rather than linked, hence the
  # appended runpath; it resolves NVIDIA's ICD via /run/opengl-driver.
  host = stdenv.mkDerivation {
    pname = "waydroid-nvidia-host";
    version = "0-unstable-${upstreamRev}";

    src = ./prebuilt/host;

    nativeBuildInputs = [ autoPatchelfHook ];

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

  # Downloads the guest payload from upstream CI into payloadDir. Uses the
  # invoking user's `gh` credentials (artifacts are auth-gated), then elevates
  # only to install, so this is run as your normal user.
  fetch-payload = writeShellApplication {
    name = "waydroid-nvidia-fetch-payload";

    runtimeInputs = [
      coreutils
      gh
      gnugrep
      gnused
      zstd
    ];

    text = ''
      export WAYDROID_NVIDIA_PAYLOAD_DIR=${lib.escapeShellArg payloadDir}
      export WAYDROID_NVIDIA_CI_RUN=${lib.escapeShellArg ciRunId}
      export WAYDROID_NVIDIA_REV=${lib.escapeShellArg upstreamRev}
      exec bash ${./fetch-payload.sh} "$@"
    '';
  };

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
      export WAYDROID_NVIDIA_PAYLOAD_DIR=${lib.escapeShellArg payloadDir}
      export WAYDROID_NVIDIA_ANGLE_DIR=${lib.escapeShellArg angleDir}
      export WAYDROID_NVIDIA_FETCH_HELPER=${fetch-payload}/bin/waydroid-nvidia-fetch-payload
      exec bash ${./setup.sh} "$@"
    '';
  };
}
