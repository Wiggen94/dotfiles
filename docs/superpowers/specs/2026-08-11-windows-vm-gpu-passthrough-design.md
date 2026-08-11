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

## Out of scope

Gaming-oriented tuning (CPU pinning, hugepages, passing through the NVIDIA
GPU instead), USB/physical KVM passthrough, Tiny11 or other pre-debloated
images, and any change to `laptop` or `sikt`.
