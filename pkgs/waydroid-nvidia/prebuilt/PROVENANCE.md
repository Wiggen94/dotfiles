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
| Workflow run | `30735717707` (`build.yml`, artifact `host-venus-server`) |
| Upstream commit | `67ec6a8` — "fix: venus vkCreateDevice -3 retry + update patch numbering" (2026-07-31) |
| Retrieved | 2026-08-05 |

| File | sha256 |
|---|---|
| `virgl_test_server` | `e17ee62db87433591287620cd740924a574b5ec2a6fa27112b486492e05cc14e` |
| `virgl_render_server` | `5c925894da9b40b02dd808a90ddc8879e6979a887ebfc3efa569e311344a7283` |
| `libvirglrenderer.so.1` | `5e4c118abc54b73485c4c5c38c3260f0ba803fb8e32fc81b745e2fedf63e43dc` |

Re-download with:

```sh
gh run download 30735717707 -R CinQwQeggs01/waydroid-nvidia -n host-venus-server
```

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

For reference, the guest payload from run `30735717707`:

| File | sha256 |
|---|---|
| `vendor/lib64/hw/vulkan.virtio.so` | `72dcfe6288f3c2ef5b445a31d07d18ae885874935e4606b07e01f58825caf80d` |
| `vendor/lib/hw/vulkan.virtio.so` | `6f6b6fb0bca1bdb3db6bb0eeec0f379f508a934f5ad020ad391a21613d7174da` |
| `vendor/lib64/libgbm_mesa_wrapper.so` | `44e26d1fe775002653788b12a5c125ebb6b830832cac43e9dd5f3a2c87c296ae` |
| `vendor/lib64/hw/hwcomposer.waydroid.so` | `cff146920c4b8fd09d7c9b6e7097dc87917ae2074f532a7fd8719de40fbd1b74` |

Switch both halves to release tarballs (`fetchurl`, no vendoring at all) once
upstream publishes a release that includes the Venus fixes — the AUR PKGBUILD at
upstream HEAD already anticipates `v0.1.2`.
