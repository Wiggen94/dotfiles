# Waydroid with NVIDIA GPU acceleration — design

Date: 2026-08-05
Host: `desktop` only (RTX 5070 Ti, standalone NVIDIA, 5120x1440@240Hz)
Upstream: <https://github.com/CinQwQeggs01/waydroid-nvidia> (v0.1.0, tag dated 2026-07-27)

## Goal

Run Android apps and games under Waydroid with real NVIDIA GPU acceleration
instead of SwiftShader software rendering.

## How the upstream stack works

Android apps issue Vulkan calls into a guest-side Mesa **Venus** driver
(`vulkan.virtio.so`). Venus serialises them over a Unix socket
(`/run/waydroid-venus/venus.sock`, bind-mounted into the container as
`/dev/venus`) to a host-side **virglrenderer vtest** server (`wd-venus`
systemd user unit) that replays them on the real NVIDIA GPU. The host
allocates NVIDIA block-linear DMA buffers the compositor imports directly, so
there are no CPU copies. **ANGLE** translates GLES to Vulkan inside the guest;
a compute shader emulates ASTC textures that desktop NVIDIA lacks.

Hard requirements, all satisfied on `desktop`:

| Requirement | Status |
|---|---|
| NVIDIA driver ≥ 535 (610.x recommended) | 610.43.03 open kernel module |
| `nvidia-drm.modeset=1` | `hardware.nvidia.modesetting.enable = true` |
| `CONFIG_ANDROID_BINDER_IPC`, `CONFIG_ANDROID_BINDERFS` | both `=y` in kernel 7.1.3 |
| `CONFIG_UDMABUF` | `=y`, `/dev/udmabuf` present |
| Wayland compositor **on the NVIDIA GPU** | Hyprland on `renderD129` (NVIDIA) |
| LXC containers | via `virtualisation.waydroid` |

The compositor-on-NVIDIA requirement is why this is desktop-only: `laptop` is
hybrid Intel+NVIDIA, which upstream documents as crashing; `sikt` is Intel-only.

## Component availability — the central constraint

The stack has seven components. At v0.1.0 only some are obtainable:

| Component | Source |
|---|---|
| Host renderer (`virgl_test_server`, `virgl_render_server`, `libvirglrenderer.so.1`) | v0.1.0 release tarball |
| Guest Venus Vulkan (`vulkan.virtio.so`, x86 + x86_64) | v0.1.0 release tarball |
| Guest gralloc (`libgbm_mesa_wrapper.so`) | v0.1.0 release tarball |
| Guest `hwcomposer.waydroid.so` | GitHub Actions artifact only (auth-gated, 90-day expiry) → vendored |
| Patched waydroid | built from upstream waydroid `a33a5c0b` + their patch |
| **ANGLE** (`libEGL_angle.so`, `libGLESv1_CM_angle.so`, `libGLESv2_angle.so`, ×2 ABIs) | **not prebuilt anywhere** — deferred to phase 3 |
| **Patched surfaceflinger** | **not prebuilt anywhere** — not needed (see below) |

The AUR `PKGBUILD` at upstream HEAD references a `v0.1.2` release with a
`guest-prebuilts` tarball containing ANGLE and surfaceflinger, but v0.1.1 and
v0.1.2 are unpublished (404), and no CI run has ever produced ANGLE or
surfaceflinger artifacts — both are built on the maintainer's self-hosted
runner (16 GB ANGLE checkout; 150 GB LineageOS tree).

Upstream's two install paths contradict each other at this tag:
`install-from-release.sh` treats prebuilts as optional and prints *"GL will use
software fallback"*, while `waydroid-nvidia-setup` hard-requires every ANGLE
library plus the patched surfaceflinger and aborts if one is missing. This
design follows the former.

**Patched surfaceflinger is genuinely unnecessary here.** Its only change is
reading `debug.sf.snap_to_same_vsync_within_ns`, needed above ~240 Hz where
stock SF's vsync snap window collapses. The monitor is exactly 240 Hz, so the
prop is not set and stock SF is correct.

Release artifact integrity was verified: both tarballs match upstream
`SHA256SUMS`, and `gh attestation verify` succeeds for both.

## Packaging (`pkgs/waydroid-nvidia/`)

- **`waydroid-nvidia-host`** — unpacks the host tarball, `autoPatchelfHook`
  against `libdrm`, `mesa` (libgbm), `libepoxy`, `libX11`, `expat`. The
  binaries are Ubuntu 24.04-built and link `/lib64/ld-linux-x86-64.so.2`.
  Vulkan loader is dlopened at runtime, supplied via the unit's
  `LD_LIBRARY_PATH`.
- **`waydroid-nvidia-fetch-payload`** — fetches the guest tree in
  Android-relative layout (`vendor/lib/…`, `vendor/lib64/…`) into
  `/var/lib/waydroid-nvidia/guest`. These are bionic ELFs that run inside the
  container against Android's linker, so they are never patchelf'd or stripped;
  keeping them out of the store makes that automatic.
- **`waydroid-nvidia`** — `pkgs.waydroid-nftables.overrideAttrs` with `src`
  pinned to upstream waydroid `a33a5c0b31d89d6ce687381104b30aff4dd2d330` (the
  base their patch targets; nixpkgs ships 1.6.3, which predates it), applying
  upstream's `0001-nvidia-integration.patch` and our `0002` (below).

  The **nftables** variant is mandatory, which is not obvious: this config does
  not set `networking.nftables.enable`, so the plain iptables build looks
  correct. It is not. Kernel 7.1.5 is built with
  `CONFIG_NETFILTER_XTABLES_LEGACY` unset, and `waydroid-net.sh` prefers
  `iptables-legacy` whenever it is on `$PATH` — which nixpkgs' `iptables`
  package always ships. The result is a container start that dies with
  `modprobe: FATAL: Module ip_tables not found` and `can't initialize iptables
  table 'nat': Table does not exist`. The nftables build sets
  `LXC_USE_NFT=true`, wraps the script with `nftables` instead of `iptables`,
  and emits its own `inet lxc` / `ip lxc` / `ip6 lxc` tables, which coexist with
  the firewall's iptables-nft tables (different table names, same nft engine).
  The trigger is the kernel's netfilter configuration, not the firewall backend.
- **`waydroid-nvidia-setup`** — upstream's setup script, Nix-ified: store
  paths instead of `/usr/lib/waydroid-nvidia`, SELinux and ABRT blocks removed
  (neither exists on NixOS), and guest-file validation tolerating absent
  ANGLE/surfaceflinger instead of aborting.

### Binary provenance: host vendored, guest in state

**Everything is pinned to upstream `67ec6a8` / CI run `30735717707`, not to the
v0.1.0 release.** This was learned the hard way: v0.1.0's binaries predate two
Venus fixes — `6bd05a7` "venus codeSize truncate" and `67ec6a8` "venus
vkCreateDevice -3 retry", both 2026-07-31 — and running them produced
`VTEST_CLIENT_ERROR_COMMAND_DISPATCH` with a client connect/disconnect loop that
saturated the CPU. All six binaries changed between v0.1.0 and that run (same
sizes, different content), so **host and guest halves must always be bumped
together**; a mixed set is a version skew that fails the same way.

The two halves are stored differently, for one reason — patchelf:

- **Host** (`virgl_test_server`, `virgl_render_server`, `libvirglrenderer.so.1`,
  4.2 MB) is vendored in `pkgs/waydroid-nvidia/prebuilt/host/`. These are
  Ubuntu-built glibc ELFs that `autoPatchelfHook` must relink at build time, so
  they have to be in the store and therefore in git.
- **Guest** (`vulkan.virtio.so` ×2 ABIs, `libgbm_mesa_wrapper.so`,
  `hwcomposer.waydroid.so`, ~55 MB) is **not** in git. The two Venus drivers
  alone are 54 MB and upstream rebuilds them weekly; git history is permanent,
  so vendoring would add ~55 MB per refresh forever. They live in
  `/var/lib/waydroid-nvidia/guest`, fetched by `waydroid-nvidia-fetch-payload`.
  ANGLE lands in the same directory in phase 3, which it must — a 16 GB ANGLE
  build's output was never going into git either.

`waydroid-nvidia-fetch-payload` runs as the normal user (CI artifacts are
auth-gated, so it needs the user's `gh` credentials) and elevates only to
install. It refuses to run as root, checks for expired artifacts before
downloading, warns when the run does not match the pinned one, and records
`run`/`head` in `$payloadDir/.provenance`, which the setup script echoes.

CI artifacts expire after 90 days. `--latest` resolves the newest successful
run; taking it means re-vendoring `prebuilt/host/` from the same run.

Switch both halves to release tarballs (`fetchurl`, nothing vendored) once
upstream publishes a release carrying the Venus fixes.

### Our `0002` patch

Upstream's `0001` emits the eleven guest bind-mounts as a hardcoded list,
deliberately **not** `optional`, so a missing file fails container start loudly
rather than surfacing as an opaque SurfaceFlinger crash loop. With ANGLE and
surfaceflinger absent, every container start would fail. `0002` makes the
generator emit a mount only for files that exist on the host at
config-generation time; files that are present still mount strictly. When
ANGLE lands in phase 3 its mounts appear automatically.

## NixOS module (`modules/system/waydroid.nix`)

Imported by `hosts/desktop/default.nix` only.

- `virtualisation.waydroid.enable = true` with `package = waydroid-nvidia`
  (this brings binder kernel-config assertions, `psi=1`, the gbinder config,
  LXC, the `waydroid0` firewall exemption, and `waydroid-container.service`).
- `systemd.user.services.wd-venus` — the vtest render server, with
  `RENDER_SERVER_EXEC_PATH` and `LD_LIBRARY_PATH` covering the host package,
  `vulkan-loader` and `/run/opengl-driver/lib`; `Restart=on-failure`.
- `systemd.tmpfiles.rules` — `d /run/waydroid-venus 1777 root root -`. Sticky
  world-writable because the server runs as the desktop user and chmods the
  socket itself after bind.
- `services.udev.extraRules` — `SUBSYSTEM=="misc", KERNEL=="udmabuf",
  TAG+="uaccess"`, granting the seated user the CPU-mappable buffers the
  render server needs for cursors and screenshots.
- `environment.systemPackages` — patched waydroid, setup script, host package.
- An assertion that the NVIDIA driver is in use, so enabling this on the wrong
  host fails at eval rather than at runtime.

`waydroid.cfg` is mutable state under `/var/lib/waydroid` — generated by
`waydroid init` and rewritten by the setup script. It is deliberately not
managed declaratively.

## Guest properties

As upstream, with one deviation. Upstream sets
`debug.renderengine.backend=skiaglthreaded`, routing SurfaceFlinger's
compositor through GL and therefore ANGLE. Without ANGLE that falls back to
SwiftShader on the CPU, so until phase 3 this uses **`skiavkthreaded`**,
compositing through Venus/Vulkan on the GPU instead. Apps' own rendering
already goes to Vulkan via `debug.hwui.renderer=skiavk`.

`ro.hardware.egl=angle` is set only once ANGLE libraries are actually present.
`persist.waydroid.refresh_rate=240`; no `snap_to_same_vsync_within_ns`.

The setup script also keeps upstream's three environment checks, each of which
guards a known crash-loop: NVIDIA render node discovery written to
`drm_device` (upstream `gpu.py` blacklists nvidia during auto-detection, so an
NVIDIA-only host otherwise gets no `/dev/dri` node and SurfaceFlinger
crash-loops), `nvidia-drm.modeset=Y` (without it the driver exposes no dma_buf
support at all), and a check that `vendor.img` carries the minigbm AIDL gralloc
(`gralloc.minigbm_gbm_mesa.so`) that this stack hooks.

## Phasing

**Phase 1 — Vulkan-accelerated session.** Everything above. Vulkan-native
apps and games are GPU-accelerated; GLES-only titles land on software GL.
Manual steps after rebuild: `sudo waydroid init -s GAPPS` (GAPPS for Play
Store, ~1 GB download), `waydroid-nvidia-fetch-payload` (as the normal user),
`sudo waydroid-nvidia-setup --refresh 240`, then `waydroid session start`. The
container and render server are declarative and need no enabling. Verify with
`waydroid shell dumpsys SurfaceFlinger | grep -i gles`.

**Phase 2 — check for in-image ANGLE.** Android 13 can ship ANGLE in-platform.
Inspect `system.img` and `vendor.img` with `debugfs` (no mounts, no root) for
`libEGL_angle.so`. If present, point `ro.hardware.egl=angle` at it and phase 3
is unnecessary. Upstream building their own suggests it is absent, but the
check is seconds.

**Phase 3 — build ANGLE.** Required for GLES-only games, which is the stated
use case. Upstream applies **no patches** to ANGLE: it is stock upstream at
`c1a25085dd9e4a8cd6c72be278c0b4bdf6ce2824` with `angle_libs_suffix="_angle"`,
`angle_enable_swiftshader=false`, `android64_ndk_api_level=30`, built for
`target_cpu` `x64` and `x86`. So a local stock build is exactly what upstream
ships. Runs in a `buildFHSEnv` (depot_tools/gclient need FHS; `nix-ld` is
already enabled): ~16 GB checkout, 1–2 h, 463 GB free. The six resulting
`.so` files join the guest tree, `ro.hardware.egl=angle` and
`debug.renderengine.backend=skiaglthreaded` switch on.

## Risks

- Upstream is nine days old and moving fast; v0.1.0's assets predate HEAD's
  scripts. A `v0.1.2` release would reduce phase 3 to a version-and-hash bump,
  so the derivations are parameterised by version.
- `skiavkthreaded` for SurfaceFlinger's RenderEngine is not a combination
  upstream tests. It is the most likely thing to need adjustment.
- Derivation builds and patch application can be verified before rebuilding,
  but a booting Android session cannot. A crash-looping SurfaceFlinger is a
  realistic first outcome; `waydroid logcat` is the diagnostic path.
- Vendoring a CI-artifact binary means it cannot be reproduced from the
  release; provenance is recorded instead.

## Out of scope

Magisk/Zygisk, device-identity spoofing, the mouse-relative-motion game fix
(upstream's `waydroid-guest-customize.sh`), Hyprland window rules for Waydroid
surfaces, and any change to `laptop` or `sikt`.
