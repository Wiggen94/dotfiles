# Waydroid with NVIDIA GPU acceleration — design

Date: 2026-08-05
Host: `desktop` only (RTX 5070 Ti, standalone NVIDIA, 5120x1440@240Hz)
Upstream: <https://github.com/Shiro836/waydroid-nvidia> (release `v0.1.2`, 2026-07-24)

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

## Upstream: use Shiro836, not the fork

**The correct upstream is <https://github.com/Shiro836/waydroid-nvidia>.** This
work started from `CinQwQeggs01/waydroid-nvidia`, a fork, and that cost most of
the debugging time recorded below. Two concrete defects in the fork:

1. **Its releases omit `guest-prebuilts`** — the tarball holding ANGLE (both
   ABIs), the patched hwcomposer, and the patched surfaceflinger. Only
   `host` and `guest-android` are published, and no CI run has ever produced
   ANGLE or surfaceflinger artifacts (both build on a self-hosted runner). That
   produced the false conclusion that ANGLE required a ~16 GB local build.
2. **Its host binary has shipped without the vtest GPU allocator since
   2026-07-31.** Runs `30633405529`, `30637081023` and `30735717707` all emit a
   byte-identical `virgl_test_server` with `vtest_gpu_alloc` absent, coinciding
   with commit `67ec6a8` ("...+ update patch numbering"). The guest's gralloc
   backend issues that allocation command; a host without it answers
   `VTEST_CLIENT_ERROR_COMMAND_ID` and the session crash-loops.

Real upstream publishes all three tarballs per release. Every component is
therefore a plain hash-pinned `fetchurl` — nothing vendored in git, no
auth-gated CI artifacts, no 90-day expiry, no local state directory.

## Component availability

Everything comes from the single release `v0.1.2` (2026-07-24). Host and guest
halves must always be bumped together; a mixed set is a version skew that fails
with `VTEST_CLIENT_ERROR_COMMAND_DISPATCH`.

| Component | Source (all `v0.1.2`) |
|---|---|
| Host renderer (`virgl_test_server`, `virgl_render_server`, `libvirglrenderer.so.1`) | `host-x86_64` tarball |
| Guest Venus Vulkan (`vulkan.virtio.so`, x86 + x86_64) | `guest-android-x86_64` tarball |
| Guest gralloc (`libgbm_mesa_wrapper.so`) | `guest-android-x86_64` tarball |
| ANGLE (`libEGL_angle.so`, `libGLESv1_CM_angle.so`, `libGLESv2_angle.so`, ×2 ABIs) | `guest-prebuilts` tarball |
| Patched `hwcomposer.waydroid.so` | `guest-prebuilts` tarball |
| Patched surfaceflinger | `guest-prebuilts` tarball |
| Patched waydroid | waydroid `a33a5c0b` + the integration patch series |

The `guest-prebuilts` tarball carries its own `SHA256SUMS.prebuilts`, which the
guest derivation verifies after unpacking, on top of the outer `fetchurl` hash.

`ANGLE_SHA` is `c1a25085dd9e4a8cd6c72be278c0b4bdf6ce2824` in both repos, so the
shipped ANGLE is exactly the build a local `gclient` checkout would produce.

The host derivation asserts `vtest_gpu_alloc` is present in
`virgl_test_server` — cheap insurance against ever picking up one of the fork's
broken builds again.

## Packaging (`pkgs/waydroid-nvidia/`)

- **`waydroid-nvidia-host`** — built from source, not upstream's prebuilt
  tarball: `fetchFromGitLab` of virglrenderer at the exact commit
  `patches/virglrenderer/BASE` pins, Shiro836's 4-patch series applied in
  order (`0001`-`0004`; `0004` copies in the net-new `vtest_gpu_alloc.{c,h}`),
  plus our own `0005` (see "ARM translation stability" below), then
  `meson -Dvenus=true -Drender-server-worker=auto` + `ninja`. Reproduces
  upstream's own `build/virglrenderer/build.sh` recipe exactly.

  `postFixup` uses `patchelf --add-rpath`, never `--set-rpath`: the latter
  replaces the rpath wholesale, silently dropping the libdrm/libgbm/libepoxy/
  libX11/libGLU entries stdenv's linker wrapper already computed correctly.
  Learned the hard way — an early iteration used `--set-rpath` and
  `virgl_render_server` failed with `libdrm.so.2: cannot open shared object
  file`, which manifested as `virgl_test_server`'s attempt to spawn it as a
  subprocess failing with a plain, misleading "No such file or directory"
  (the exec itself failed before ever reaching the missing-library error).
  Vulkan loader is still dlopened at runtime (meson's `vulkan-dload` default),
  so its lib path is appended alongside `$out/lib/waydroid-nvidia` explicitly,
  same as before.
- **`waydroid-nvidia-guest`** — merges the `guest-android` and
  `guest-prebuilts` tarballs into one Android-relative tree (`vendor/lib/…`,
  `vendor/lib64/…`, `system/bin/surfaceflinger`) and verifies the prebuilts'
  own manifest. These are bionic ELFs that run inside the container against
  Android's linker, so `dontFixup` is mandatory — patchelf or strip would
  corrupt them.
- **`waydroid-nvidia-probe`** — bounded session probe: starts a session,
  captures guest logcat plus host renderer logs, then stops. A crash-looping
  guest can make the desktop unresponsive, so diagnosis needs a hard time
  budget (systemd `RuntimeMaxSec`, independent of the terminal) and a sudo
  prompt taken up front — `waydroid logcat` needs root, and the sudo credential
  cache is per-tty so it cannot be acquired later from inside a unit.
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
  paths instead of `/usr/lib/waydroid-nvidia`, and the SELinux and ABRT blocks
  removed (neither exists on NixOS). Adds `--no-hwcomposer`, a debug lever that
  omits the patched hwcomposer so the image's is used instead; it was what
  proved the hwcomposer innocent of the EGLImage crash.

### No vendored binaries

An earlier iteration vendored host binaries in git and fetched the guest payload
from auth-gated CI artifacts into `/var/lib/waydroid-nvidia`, because the fork
publishes no usable release. With real upstream all of that is gone: three
`fetchurl` pins, everything in the store, nothing in git, no state directory, no
`gh` dependency, no expiry. If a future release regresses, pin the older
`version` — do not reintroduce vendoring.

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
- `systemd.services.waydroid-binfmt-guard` — always-on from boot; see "ARM
  translation stability" below for why it exists and why it polls every 20ms.

`waydroid.cfg` is mutable state under `/var/lib/waydroid` — generated by
`waydroid init` and rewritten by the setup script. It is deliberately not
managed declaratively.

## ARM translation stability (`--arm-translation`)

Getting ARM translation from "host freezes" to "boots clean" took two
independent bugs, found and fixed the same night by live-testing against a
running session (root shell open, bounded canary/recovery scripts, coredump
analysis) rather than by inspection alone.

### Bug 1 — binfmt_misc leaks from container to host

The waydroid LXC container's `binfmt_misc` mount is not properly isolated
from the host's kernel namespace. When `--arm-translation` registers
houdini's ARM interpreters (`arm_exe`/`arm_dyn`/`arm64_exe`; `arm64_dyn`
itself fails to register), those registrations leak onto the *host's* shared
`/proc/sys/fs/binfmt_misc` table — confirmed by finding them there directly,
which a properly namespaced mount would never expose. Not NVIDIA-specific,
not particular to this patched waydroid:
[waydroid/waydroid#2221](https://github.com/waydroid/waydroid/issues/2221)
reports the identical whole-system-freeze pattern on Intel graphics / Pop!_OS.

For as long as the leaked entries remain, host-side `execve()` fails —
confirmed for everything from `grep` to `iptables`, no other symptom (no
PID/memory/disk exhaustion). A bounded test with the guard (below) stopped
confirmed the mechanism precisely: the *presence* of the leaked entries is
what destabilizes exec, not any particular action on them — a real host
freeze reappeared ~15s after the leak, with nothing touching it in between.

**Fix**: `waydroid-binfmt-guard`, an always-on systemd service that polls
`/proc/sys/fs/binfmt_misc/{arm_exe,arm_dyn,arm64_exe,arm64_dyn}` and clears
any that appear (`echo -1 > <entry>`). Detection (`[ -e file ]`) and
remediation are both pure shell builtins — no fork, no exec — so the guard
keeps working even during the exact execve() stall it exists to catch.
Polls every 20ms, not 1s: since presence (not clearing) is what's harmful,
a shorter exposure window directly reduces the odds of colliding with a
concurrent, unrelated exec — confirmed live, see Bug 2.

### Bug 2 — virgl_test_server SIGSEGV double-fault

Even with the guard prevent­ing the full freeze, `--arm-translation` sessions
still failed to complete boot: `system_server` crash-looped (Android's own
Watchdog killing it every ~71s, blocked waiting on SurfaceFlinger's binder
registration), and SurfaceFlinger itself sat at ~99.6% CPU, permanently
stuck right after successfully `dlopen`-ing ANGLE.

`coredumpctl` on the host showed `virgl_test_server` dying with `SIGSEGV`
inside `libnvidia-eglcore.so`, with the *same* NVIDIA-driver call chain
appearing twice in one backtrace — once from `vtest_main`'s normal EGL
context teardown, and again nested inside the crash handler itself. Root
cause: `vtest/vtest_server.c`'s stock (unmodified upstream, not one of
Shiro836's patches) `SIGSEGV` handler calls `exit()`, which is not
async-signal-safe — it runs atexit handlers, and the NVIDIA driver registers
one that tears down the current EGL context. That reenters the exact driver
state that just faulted. Since `SIGSEGV` is still blocked during the handler
(no `SA_NODEFER`), the second fault can't be delivered as a normal signal —
it escalates to an immediate, unconditional kernel kill of the whole
`--multi-clients` process, instead of just the one client whose context
actually failed.

Reproducibly triggered by ARM translation because it means more concurrent
Venus clients at boot (32-bit + 64-bit ANGLE, houdini-related processes),
raising the odds of hitting a context-create failure
(`VTEST_CLIENT_ERROR_CONTEXT_FAILED`) followed ~11s later by a retry that
crashes during cleanup.

**Fix**: patch `0005` (`patches/virglrenderer/0005-*.patch`) changes the
handler to `_exit()` — skips atexit entirely, so only the one faulting
client dies; `wd-venus`'s Main PID and every other client's context survive.
Confirmed live: post-fix coredumps for the same crash class show a single,
immediate, non-reentrant death instead of the old 38-frame double-fault
trace, and the parent process's PID/task count stays stable through it.

Also worth knowing for future debugging: virglrenderer's own `vkr_log()`
diagnostics (including the `0004` series' "CreateDevice: NOT_PERMITTED;
retrying without global queue priority" and similar messages) are emitted at
`VIRGL_LOG_LEVEL=info`, one level below the default `warning` threshold —
silently suppressed unless that env var is set on `wd-venus`. It's what
surfaced the exact NOT_PERMITTED-retry and render-server-exec-path bugs
during this investigation.

### End-to-end result

With both fixes deployed, an `--arm-translation` session boots clean:
SurfaceFlinger settles at idle CPU, `system_server` stops restarting, and
`waydroid show-full-ui` succeeds. Confirmed live, same night, same host.

## Guest properties

Exactly as upstream, including `debug.renderengine.backend=skiaglthreaded`.

**A deviation was tried here and it failed.** The original plan set
`skiavkthreaded` to route SurfaceFlinger's compositor through Venus/Vulkan and
so avoid a software fallback while ANGLE was missing. The LineageOS-20
surfaceflinger in the Waydroid image is built without a Vulkan RenderEngine and
rejects the value outright:

```
E SurfaceFlinger: Unrecognized RenderEngineType skiavkthreaded; ignoring!
D RenderEngine: Threaded RenderEngine with SkiaGL Backend
I RenderEngine: renderer  : llvmpipe (LLVM 22.0.0, 256 bits)
D RenderEngine: Shader cache generated 75 shaders in 5530.383301 ms
```

It falls back to SkiaGL silently, lands on **llvmpipe** — software compositing on
the CPU — and that shader-cache build is where the CPU saturation came from.

**Consequence: ANGLE is a prerequisite, not an enhancement.** GL is the only
compositor path this image offers, so ANGLE is what decides whether compositing
reaches the GPU at all. Without it the session boots and is nominally correct but
composites every frame on the CPU. The phase-1 premise — "Vulkan-native apps
accelerated, GLES-only apps fall back" — was wrong: the fallback applies to
SurfaceFlinger itself, and therefore to everything on screen.

`ro.hardware.egl=angle` is always set, since upstream's release ships ANGLE.

**Do not fall back to the image's own ANGLE.** The LineageOS `vendor.img` does
ship `libEGL_angle.so` and friends for both ABIs, and they load and even report
a correct renderer string. But that build (2.1.20440, git `353815e0d958`) fails
`eglCreateImageKHR` when the composer imports a gralloc buffer, then jumps
through a null pointer in its own `egl::Image::onDestroy` cleanup:

```
#09 libEGL_angle.so   (eglCreateImageKHR+48)
#03 libGLESv2_angle.so (egl::Display::createImage(...))
#01 libGLESv2_angle.so (egl::Image::onDestroy(egl::Display const*)+97)
#00 pc 0000000000000000 <unknown>
```

That kills `android.hardware.graphics.composer@2.1-service` ~20-30 s in and
takes SurfaceFlinger with it — the window appears for a moment and vanishes. The
crash is identical with the patched and the stock hwcomposer, which is how the
hwcomposer was ruled out. Upstream's bind-mounted ANGLE overrides the image copy.

`persist.waydroid.refresh_rate=240`; no `snap_to_same_vsync_within_ns` (that is
the >240 Hz path).

The setup script also keeps upstream's three environment checks, each of which
guards a known crash-loop: NVIDIA render node discovery written to
`drm_device` (upstream `gpu.py` blacklists nvidia during auto-detection, so an
NVIDIA-only host otherwise gets no `/dev/dri` node and SurfaceFlinger
crash-loops), `nvidia-drm.modeset=Y` (without it the driver exposes no dma_buf
support at all), and a check that `vendor.img` carries the minigbm AIDL gralloc
(`gralloc.minigbm_gbm_mesa.so`) that this stack hooks.

## Deployment

One rebuild plus two commands; there are no phases left.

```sh
nrs
sudo waydroid init -s GAPPS            # ~1 GB image download, once
sudo waydroid-nvidia-setup --refresh 240
waydroid session start                 # or: waydroid show-full-ui
```

Verify acceleration — the GLES line must name ANGLE on Venus, and must not name
llvmpipe or Lavapipe:

```sh
sudo waydroid shell dumpsys SurfaceFlinger | grep -i gles
```

For a bounded diagnostic run that stops itself and collects logs:

```sh
waydroid-nvidia-probe --seconds 90
```

Note that first boot is legitimately CPU-heavy for minutes while Android
optimises the GAPPS packages. `sys.boot_completed` (which the probe reports) is
the only trustworthy signal that Android finished booting — `waydroid status`
showing RUNNING only means the *container* started.

## Risks

- Upstream is young and moving fast. Bumping means changing `version` and three
  hashes together; never bump one tarball alone.
- The fork is easy to land on by mistake — it is what a web search surfaces, and
  its docs read identically. The host derivation's `vtest_gpu_alloc` assertion is
  the guard against silently adopting one of its broken builds.
- Derivation builds and patch application are verifiable before rebuilding; a
  booting Android session is not. Use `waydroid-nvidia-probe`, never a bare
  `waydroid session start`, for the first run after any change.
- The `0002` patch is inert with a complete payload. It only matters for
  `--no-hwcomposer` and for partial payloads, and must be re-checked if upstream
  changes the bind-mount list in `0001`.

## Out of scope

Magisk/Zygisk, device-identity spoofing, the mouse-relative-motion game fix
(upstream's `waydroid-guest-customize.sh`), Hyprland window rules for Waydroid
surfaces, and any change to `laptop` or `sikt`.
