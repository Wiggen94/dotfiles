# Vendored prebuilt binaries

## host/ — Venus render server (host side)

`virgl_test_server`, `virgl_render_server`, `libvirglrenderer.so.1` — patched
virglrenderer with upstream's vtest GPU allocator. Ubuntu 24.04-built glibc ELFs;
`autoPatchelfHook` relinks them onto nixpkgs libraries at build time, which is
why these three (unlike the guest payload) must live in the store and therefore
in this repo. 4.2 MB total.

| | |
|---|---|
| Upstream | <https://github.com/CinQwQeggs01/waydroid-nvidia> |
| Workflow run | `30415334277` (`build.yml`, artifact `host-venus-server`) |
| Upstream commit | `36867e1` — "fix: harden release verify, fedora build, wd-deploy and vtest fd handling" (2026-07-29) |
| Retrieved | 2026-08-05 |

| File | sha256 |
|---|---|
| `virgl_test_server` | `647a7c77fbe5a31fca9dca6478b50c68c41f058c6958c0996b159609c1972105` |
| `virgl_render_server` | `09d8fc82edd5348a19341b59f631dcfe9c9eb8cf084420d1381f5819490cc837` |
| `libvirglrenderer.so.1` | `90d858203d8bab3466b670b4f79d71d10ad9741c24a51daff8d191f3e4ddf915` |

Re-download with:

```sh
gh run download 30415334277 -R CinQwQeggs01/waydroid-nvidia -n host-venus-server
```

### Why not the newest run

Upstream's host artifact has been **broken since 2026-07-31**. Runs
`30633405529`, `30637081023` and `30735717707` all emit a byte-identical
`virgl_test_server` (`e17ee62db874…`) with the vtest GPU allocator missing:

```sh
strings virgl_test_server | grep -c vtest_gpu_alloc
# 8 in run 30415334277 (this one), 6 in the v0.1.0 release, 0 in all three
# runs from 2026-07-31 onward
```

The guest's gralloc backend issues upstream's custom allocation command over the
vtest socket; a host without it answers `VTEST_CLIENT_ERROR_COMMAND_ID` and the
session crash-loops at 100% CPU. The regression coincides with commit `67ec6a8`
("...+ update patch numbering"), which suggests CI stopped applying the net-new
`src/virglrenderer-vtest/` sources.

Cost of staying here: this run predates two guest Venus fixes (`6bd05a7`
codeSize truncate, `67ec6a8` vkCreateDevice -3 retry). Building the host from
source at a newer rev would get both — that is the durable fix if upstream does
not repair CI.

## Why the guest payload is NOT here

The guest half (`vulkan.virtio.so` ×2 ABIs, `libgbm_mesa_wrapper.so`,
`hwcomposer.waydroid.so`) totals ~55 MB and upstream rebuilds it weekly. Git
history is permanent, so vendoring it would add ~55 MB per refresh forever. It
lives in `/var/lib/waydroid-nvidia/guest` instead, fetched by
`waydroid-nvidia-fetch-payload`.

**Host and guest must come from the same upstream build.** v0.1.0's binaries
predate two Venus fixes (`6bd05a7` codeSize truncate, `67ec6a8` vkCreateDevice
-3 retry); running a mixed set produces `VTEST_CLIENT_ERROR_COMMAND_DISPATCH`
and a SurfaceFlinger crash loop. When bumping, update `upstreamRev`/`ciRunId` in
`default.nix`, re-vendor `host/`, and re-run the fetch helper together.

The guest payload must come from the same run as `host/` above
(`30415334277`); `waydroid-nvidia-fetch-payload` defaults to it and warns if
told to use another. For reference, the payload from the *broken-host* run
`30735717707`, which must **not** be paired with this host:

| File | sha256 (run 30735717707 — do not pair with this host) |
|---|---|
| `vendor/lib64/hw/vulkan.virtio.so` | `72dcfe6288f3c2ef5b445a31d07d18ae885874935e4606b07e01f58825caf80d` |
| `vendor/lib/hw/vulkan.virtio.so` | `6f6b6fb0bca1bdb3db6bb0eeec0f379f508a934f5ad020ad391a21613d7174da` |
| `vendor/lib64/libgbm_mesa_wrapper.so` | `44e26d1fe775002653788b12a5c125ebb6b830832cac43e9dd5f3a2c87c296ae` |
| `vendor/lib64/hw/hwcomposer.waydroid.so` | `cff146920c4b8fd09d7c9b6e7097dc87917ae2074f532a7fd8719de40fbd1b74` |

Switch both halves to release tarballs (`fetchurl`, no vendoring at all) once
upstream publishes a release that includes the Venus fixes — the AUR PKGBUILD at
upstream HEAD already anticipates `v0.1.2`.
