# Vendored prebuilt binaries

## hwcomposer.waydroid.so

Patched Android hwcomposer HAL (display / refresh-rate / windowing fixes) for
the waydroid-nvidia stack. A bionic x86_64 shared object — it runs inside the
Android container and must never be patchelf'd or stripped.

Vendored because it exists **only** as a GitHub Actions artifact: artifacts are
auth-gated and expire after 90 days, so no Nix derivation can fetch it. The
`v0.1.0` release tarballs ship the Venus Vulkan drivers and the gralloc wrapper
but not this file.

| | |
|---|---|
| Upstream | <https://github.com/CinQwQeggs01/waydroid-nvidia> |
| Workflow run | `30735717707` (`build.yml`, artifact `guest-hwcomposer`) |
| Upstream commit | `67ec6a8` — "fix: venus vkCreateDevice -3 retry + update patch numbering" (2026-07-31) |
| Retrieved | 2026-08-05 |
| Size | 615360 bytes |
| sha256 | `cff146920c4b8fd09d7c9b6e7097dc87917ae2074f532a7fd8719de40fbd1b74` |

Reproduce with `build/hwcomposer/provision.sh` + `build/hwcomposer/build.sh`
from the upstream repo, or re-download with:

```sh
gh run download 30735717707 -R CinQwQeggs01/waydroid-nvidia -n guest-hwcomposer
```

Replace this with the release tarball copy once upstream publishes a
`guest-prebuilts` asset (see `docs/superpowers/specs/2026-08-05-waydroid-nvidia-design.md`).
