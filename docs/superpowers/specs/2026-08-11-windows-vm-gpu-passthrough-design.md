# Windows 11 VM with Intel iGPU passthrough + Looking Glass — design

**Date:** 2026-08-11
**Host:** `desktop` only (Raptor Lake-S with Intel UHD 770 iGPU + standalone RTX 5070 Ti)

## Goal

Run a Windows 11 VM for light office/app-compatibility use (primary case:
Excel), with real GPU acceleration instead of software-rendered/RDP-class
graphics, **without** ever touching the monitor's physical input. The monitor
stays on the NVIDIA GPU exactly as today; the VM gets the otherwise-idle Intel
iGPU passed through, and Looking Glass shows its output in a window on the
Linux desktop.

## Why this is viable on this hardware

```
00:02.0 Display controller: Intel Corporation Raptor Lake-S GT1 [UHD Graphics 770]
01:00.0 VGA compatible controller: NVIDIA Corporation GB203 [GeForce RTX 5070 Ti]
```

The monitor is wired to `01:00.0` (NVIDIA) and nothing on the host uses
`00:02.0` (Intel) — `services.xserver.videoDrivers` is `[ "nvidia" ]` only, and
no cable is attached to the iGPU's outputs. Detaching it for passthrough is a
pure no-op for the current desktop session. `kvm-intel` is already loaded
(`hosts/desktop/hardware-configuration.nix`); IOMMU itself is not yet enabled
and is the first thing this design turns on.

No existing `virtualisation.libvirtd`/VFIO config exists anywhere in this repo
— this is new ground, not a modification of prior work.

## Non-goals

- Gaming performance. The UHD 770 is adequate for Office-class UI
  acceleration and video decode, not for passing through the NVIDIA GPU or
  running demanding titles. If that's ever wanted later, it's a different,
  much more invasive design (the NVIDIA GPU is the one driving the monitor).
- CPU pinning, hugepages, or other latency-sensitive tuning — unnecessary
  overhead for this workload, and skipped deliberately to keep the config
  simple.
- USB device passthrough / physical KVM switch — Looking Glass's own
  input-forwarding (keyboard/mouse captured from the host and sent to the
  guest) replaces this outright, which is the whole point of the ask.
- A pre-debloated third-party Windows image (e.g. Tiny11). The official
  Microsoft ISO is fetched directly (bypassing only the Media Creation Tool
  GUI), then debloated post-install with a standard script — keeps the base
  OS image on trusted, official media.

## Architecture

Everything that can be declarative lives in NixOS config. The VM itself
(libvirt domain XML, disk image) is created once, imperatively, through
virt-manager, because a Windows install is inherently interactive — it is
treated as long-lived host state, like `/home`, not something Nix
regenerates on rebuild.

### Host layer — new module `modules/system/vm-passthrough.nix` (desktop-only)

- **IOMMU:** `boot.kernelParams` gets `intel_iommu=on` and `iommu=pt`.
- **Detach the iGPU from the host before anything claims it:** add
  `vfio-pci` to `boot.initrd.availableKernelModules`, and bind PCI address
  `0000:00:02.0` to `vfio-pci` instead of `i915` — via a `driverctl`-based
  override applied early (a small systemd service ordered before
  `display-manager.service`/`graphical.target`), rather than a global
  `vfio-pci.ids=8086:a780` kernel param. The override approach is chosen
  because it targets this one PCI address specifically and stays inert if
  any other Intel device ever shares that ID; a global ID-based claim would
  not.
- **Assertion:** fail the build if `services.xserver.videoDrivers` ever
  includes `"i915"`/`"modesetting"` targeting this card, so an accidental
  future change can't silently fight the VFIO binding for the same device.
- **libvirt/QEMU:** `virtualisation.libvirtd.enable = true`,
  `virtualisation.libvirtd.qemu.ovmf.enable = true` (UEFI is required for GPU
  passthrough — legacy BIOS doesn't support it reliably), package
  `qemu_kvm`.
- **Packages:** `virt-manager`, `looking-glass-client`.
- **IVSHMEM shared-memory file:** `systemd.tmpfiles.rules` creates
  `/dev/shm/looking-glass` (group-writable, owned by a group that includes
  both the interactive user and the qemu process user) at boot — this is the
  zero-copy frame buffer the Looking Glass client reads from and the guest's
  Looking Glass host application writes into.
- **Group membership:** add the user to `libvirtd` for GUI access to
  virt-manager without `sudo`.

### VM definition (created once via virt-manager, not declared in Nix)

| Setting | Value |
|---|---|
| Chipset / firmware | Q35 + OVMF (UEFI), Secure Boot off |
| vCPUs / RAM | 4 / 8GB |
| Disk | qcow2, VirtIO bus, `/home/gjermund/games/vms/win11.qcow2` |
| Network | default libvirt NAT (`virbr0`) |
| GPU | PCI hostdev `0000:00:02.0` (Intel iGPU) |
| Sound | separate `ich9-intel-hda` virtual device (independent of the passed-through GPU — the iGPU has no separate audio function to pass through on this chipset) |
| Extra device | `ivshmem-plain`, backed by `/dev/shm/looking-glass`, 32MB (sized for 1080p Office use; Looking Glass's sizing formula covers bumping this later for higher resolutions) |

Installer media: the Windows 11 ISO, fetched with a Fido-style script
(pulls the genuine ISO directly from Microsoft's CDN with a chosen
edition/language, skipping the Media Creation Tool GUI and any bundled
installer). This is a one-time download step, not part of the Nix config.

### Guest setup, in order

1. **VirtIO drivers** (`virtio-win` ISO) — needed for the VirtIO disk/NIC to
   be visible during and after install.
2. **IddSampleDriver** (open-source virtual display driver) — makes Windows
   believe a monitor is attached to the passed-through iGPU. This is what
   makes Looking Glass's capture possible with zero physical hardware (no
   dummy HDMI/DP plug needed).
3. **Looking Glass host application** — runs as a Windows service, writes
   frames into the IVSHMEM buffer.
4. **Scream** (virtual audio driver in the guest + network receiver on the
   host) for low-latency audio — the standard Looking Glass audio pairing,
   avoiding conflicts with SPICE audio once the GPU is fully passed through.
5. Debloat pass (e.g. Chris Titus WinUtil or equivalent) to strip
   Xbox/Teams/ads/telemetry from the official image.

Input needs no separate handling: the Looking Glass client itself captures
host keyboard/mouse and forwards them to the guest in real time.

### Host client — launcher script

A `win-vm` command (`writeShellScriptBin`, alongside the repo's other custom
scripts in `modules/system/packages.nix`) that:

1. `virsh start win11` (no-op if already running).
2. Polls until `/dev/shm/looking-glass` is writable, so the client doesn't
   race the VM's boot.
3. Launches `looking-glass-client` borderless, sized to a sensible region of
   the 5120×1440 monitor rather than the full width.

No keybind/Vicinae entry yet — a single command is enough to validate the
workflow; wiring it into a keybind is a trivial follow-up once it's proven
out.

## Validation plan

Ordered so a failure is caught at the earliest possible stage:

1. After the NixOS rebuild: `lspci -nnk -s 00:02.0` shows
   `Kernel driver in use: vfio-pci`, and the existing NVIDIA-driven desktop
   session is unaffected (sanity check — nothing should change here, since
   nothing currently uses the iGPU).
2. IOMMU group check (`/sys/kernel/iommu_groups/*/devices/*`) — the iGPU
   should be isolated (alone, or only with genuinely inert devices). If
   something load-bearing shares its group, passthrough would drag that
   device away from the host too, and the plan needs revisiting.
3. Boot the freshly created VM in virt-manager and confirm Windows installs
   and boots — checked via virt-manager's own console, before Looking Glass
   is involved at all.
4. Install VirtIO drivers, then IddSampleDriver, then the Looking Glass host
   app, confirming each in Device Manager before moving to the next.
5. First `looking-glass-client` connection: confirm a picture appears and
   mouse/keyboard tracking works.
6. Confirm Scream audio round-trips (play a sound in the guest, hear it on
   the host).
7. Re-confirm the normal (non-VM) desktop session still behaves exactly as
   before.

## Risks

- **This host's IOMMU only supports 39-bit addressing (`DMAR: Host address
  width 39`, confirmed via `journalctl -k`), while `-cpu host` passes through
  the CPU's real 46-bit physical addressing to the guest.** OVMF places its
  64-bit PCI MMIO window near the top of whatever address width it sees
  (~36 TiB here), which is far beyond what a 39-bit IOMMU can map. Every BAR
  placed there fails `VFIO_IOMMU_MAP_DMA` with `EINVAL`. The passed-through
  GPU's own BAR failure is silently tolerated (VFIO treats "ram device"
  region DMA-map failures as soft warnings), but the Looking Glass `ivshmem`
  device's identical failure is **not** tolerated and crashes the whole VM
  with `qemu: hardware error: vfio: DMA mapping failed, unable to continue`
  the moment OVMF enables its BAR during boot.

  **Fix, required in the domain XML (`virsh edit win11`) any time the VM is
  recreated from scratch:**
  ```xml
  <cpu mode='host-passthrough' check='none' migratable='on'>
    <maxphysaddr mode='passthrough' limit='39'/>
  </cpu>
  ```
  This caps the guest's reported address width to match the IOMMU. It must be
  `mode='passthrough'` + `limit=`, not `mode='emulate'` + `bits=` — the
  latter maps to QEMU's plain `phys-bits=` property, which `-cpu host`
  silently re-derives from the real host value afterward and so has no
  effect; `mode='passthrough'` + `limit=` maps to `host-phys-bits-limit=`,
  which is the one that actually survives the host-model CPU's override
  logic. Confirm with:
  ```bash
  virsh domxml-to-native --format qemu-argv --domain win11 | grep -o '\-cpu [^ ]*'
  ```
  — must show `host-phys-bits-limit=39`, not just `phys-bits=39`.

  Also note: if the VM already crashed and rebooted with the wrong CPU
  config before this fix is applied, OVMF's persistent NVRAM
  (`win11_VARS.fd`) does **not** actually cache the bad BAR layout in a way
  that blocks the fix (confirmed empirically — clearing NVRAM had no effect
  on its own) — but if in doubt, `virsh undefine win11 --nvram` then
  redefine is a safe way to force a fully fresh OVMF state.
- **IOMMU grouping is unverified until step 2 of validation.** If the iGPU
  shares a group with something the host needs, the detach approach (driver
  override on one PCI address) may need to change to also cover the group's
  other members, or passthrough may not be clean. This is the main
  go/no-go point in the whole plan and should be checked before any guest
  work is invested.
- **IddSampleDriver is a community project, not Microsoft-signed by
  default** — may need test-signing mode or a signed fork enabled in
  Windows. If it proves unreliable, the fallback is a physical dummy
  HDMI/DP plug (cheap, more hardware-reliable, previously discussed and
  passed over only for convenience).
- Fido-style ISO fetching depends on Microsoft's CDN endpoints, which have
  shifted before; if the script breaks, the fallback is the official
  Microsoft ISO download page directly.

## Looking Glass: IddSampleDriver abandoned, IDD-only host used instead

**IddSampleDriver was never actually needed.** The Looking Glass host
installer (from looking-glass.io/downloads) now bundles its own Indirect
Display Driver ("Looking Glass Indirect Display Device"), which creates its
virtual monitor itself — no third-party IDD, no dummy plug, no
`looking-glass-host.exe` capture service (that's now legacy). Installing
IddSampleDriver alongside it was redundant and actively confusing (two
phantom monitors); uninstall it if present.

**nixpkgs' `looking-glass-client` (B7) cannot talk to this driver at all.**
The IDD feature was merged into upstream `master` in mid-2026, long after the
B7 tag (2025-03-06) nixpkgs pins to. A B7 client just waits forever for "the
host application" — it doesn't understand the IDD's handshake. The client
must track `master` too, via `pkgs.looking-glass-client.overrideAttrs` in
`modules/system/vm-passthrough.nix` (bump `rev`/`hash` together whenever this
stops working, since development here moves in dozens of commits per day —
check `gh api repos/gnif/LookingGlass/commits/master` for the current tip).

### Bugs found and fixed in this exact IDD + client combination

All three were found by reading the actual upstream C++/C source (fetched
live via `gh api`), not by guessing from documentation:

1. **`ivshmem` too small for the new protocol.** 32MB (the old host.exe-era
   default) makes the guest's `CLGMPControl::Initialize` fail outright with
   `LGMP_ERR_NO_SHARED_MEM` — no monitor, no connection, nothing. 128MB
   fixed it. Upstream issue #1318 confirms this generally (their fix needed
   256MB for a wider resolution) — size to your actual resolution with
   headroom. The `<shmem>` size in the domain XML AND the actual backing
   file at `/dev/shm/looking-glass` both need to match (`truncate -s <N>M
   /dev/shm/looking-glass` — QEMU requires the backing file to already be at
   least the requested size, it does not grow it).
2. **`BGR_32` packed-format render crash.** The IDD adaptively benchmarks
   native (`BGRA`) vs. a bandwidth-saving packed format
   (`CRGB24Effect`/`BGR_32`, still 4 bytes/pixel but squeezed to 3/4 width)
   and locks into whichever is faster — automatically, a few seconds into
   any session with real content changes (mouse movement, window opens).
   Whenever it locks into packed mode, the Linux client's damage-rect
   render path (`egl_texFBUpdate` in `client/renderers/EGL/
   texture_framebuffer.c`) eventually fails with `Failed to to update the
   desktop` and disconnects. No registry workaround exists —
   `HKLM\SOFTWARE\LookingGlass\IDD\AllowRGB24=0` (DWORD) disables the whole
   effect rather than just picking native mode, which breaks something else
   downstream and hangs the session after the first frame instead. Enabling
   HDR (which also structurally disables the packed path, since
   `CRGB24Effect::IsEligible()` requires non-HDR) hangs too, differently.
   Patched around in `vm-passthrough.nix` by forcing the client's
   proven-reliable full-frame read path for `BGR_32` specifically
   (`looking-glass-bgr32-workaround.patch`) rather than the buggy
   damage-rect accumulation path.
3. **The real root cause, found by live-debugging with gdb (not just
   reading source):** attached to a running `looking-glass-client` (built
   with `dontStrip = true` to get inline symbols — the project's own
   CMake-generated `.gnu_debuglink` intermittently doesn't CRC-match the
   binary after Nix's own fixup passes, so a plain nixpkgs debug split
   isn't reliable for this package; note also that the embedded DWARF
   source path is the ephemeral build sandbox path
   `/build/source/...`, not any Nix store path — that's what a breakpoint
   needs to target), with a breakpoint on `framebuffer_wait_timed`'s
   timeout branch (`common/src/framebuffer.c`). At the exact moment of
   "timeout", `frame->wp` (the guest's write-progress pointer) had *already
   reached* the frame's full expected byte size (`height × pitch`,
   confirmed numerically equal in the debugger). The data had arrived —
   the wait just gave up first. `FB_SPIN_LIMIT` (`common/include/common/
   framebuffer.h`) is 10,000 spin iterations of `usleep(1)`, nominally
   10ms — far too tight for VFIO/shared-memory latency under any real load,
   and reproduces on plain `BGRA` frames too, not just `BGR_32` (confirmed
   by catching the exact same breakpoint on a `BGRA` frame in the same
   debugging session). A single timeout here is fatal (no retry). Bumped to
   200,000 (~200ms nominal) via `postPatch`/`substituteInPlace` in
   `vm-passthrough.nix`. **This is very likely the actual fix** — the
   `BGR_32` patch may turn out to be unnecessary once this is applied, but
   both are kept for now since removing either wasn't re-tested in
   isolation under the time available.

With both patches applied, the VM was stable under sustained real use
(sustained mouse movement, opening multiple windows, several minutes) for
the first time in this whole investigation.

## Out of scope

Gaming-oriented tuning (CPU pinning, hugepages, passing through the NVIDIA
GPU instead), USB/physical KVM passthrough, Tiny11 or other pre-debloated
images, and any change to `laptop` or `sikt`.
