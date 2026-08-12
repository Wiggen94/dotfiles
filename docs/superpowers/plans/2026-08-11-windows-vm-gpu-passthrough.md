# Windows 11 VM with Intel iGPU Passthrough + Looking Glass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the `desktop` host a Windows 11 VM with the idle Intel UHD 770 iGPU passed through via VFIO, displayed on the Linux desktop through Looking Glass, with no physical monitor/input switching.

**Architecture:** A new desktop-only NixOS module (`modules/system/vm-passthrough.nix`) declares the host side — IOMMU, VFIO binding of the iGPU, libvirtd/QEMU, and a launcher script. The VM itself (libvirt domain, disk image, guest OS) is created once, imperatively, through virt-manager and `virsh`, since a Windows install and its in-guest driver setup are inherently interactive and are not something Nix regenerates on rebuild.

**Tech Stack:** NixOS, libvirt/QEMU (OVMF/UEFI), VFIO, Looking Glass, Scream (guest audio), Windows 11.

**Design doc:** `docs/superpowers/specs/2026-08-11-windows-vm-gpu-passthrough-design.md`

---

## Execution note

**Tasks 1-2 are automatable** — Nix module + shell script, buildable and checkable without touching hardware.

**Tasks 3-9 are hands-on** — they involve a real reboot, virt-manager's GUI, and driver installs inside a Windows guest. No coding agent can click through virt-manager or drive a Windows session, so these are written as exact steps and commands for *you* to run, in order, with concrete expected output at each point. Do not skip ahead — each task's "why" depends on the previous one having actually worked (e.g. there is no point creating the VM before the iGPU is confirmed detached from the host).

---

### Task 1: Host NixOS module — IOMMU, VFIO binding, libvirt

**Files:**
- Create: `modules/system/vm-passthrough.nix`
- Modify: `hosts/desktop/default.nix` (add to `imports`)

- [ ] **Step 1: Write the module**

```nix
# modules/system/vm-passthrough.nix
#
# Intel iGPU (UHD 770, 00:02.0) passthrough for a Windows VM, viewed via
# Looking Glass. Desktop-only: the monitor is wired to the standalone NVIDIA
# GPU (01:00.0) and nothing on the host uses the iGPU, so detaching it is a
# no-op for the existing desktop session.
#
# Design: docs/superpowers/specs/2026-08-11-windows-vm-gpu-passthrough-design.md
{
  config,
  lib,
  pkgs,
  ...
}:
{
  # IOMMU is required for VFIO to isolate the iGPU into its own group.
  boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
  ];

  # Claim the iGPU for vfio-pci instead of i915. Blacklisting i915 outright
  # is safe here because nothing on this host uses the iGPU for display —
  # the monitor is on the NVIDIA card. 8086:a780 is this CPU's only device
  # with that PCI ID, so an ID-based claim is equivalent to targeting the
  # specific PCI address, and far simpler to reason about than a per-address
  # driver override.
  boot.blacklistedKernelModules = [ "i915" ];
  boot.kernelModules = [
    "vfio_pci"
    "vfio"
    "vfio_iommu_type1"
  ];
  boot.extraModprobeConfig = "options vfio-pci ids=8086:a780";

  # Fails the build (not just at runtime) if a future change ever tries to
  # put i915/modesetting back in the X driver list, which would fight
  # vfio-pci for the same device.
  assertions = [
    {
      assertion =
        !(lib.elem "i915" config.services.xserver.videoDrivers)
        && !(lib.elem "modesetting" config.services.xserver.videoDrivers);
      message = "vm-passthrough: an i915/modesetting X driver would fight vfio-pci for the passed-through Intel iGPU.";
    }
  ];

  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      # UEFI is required for GPU passthrough.
      ovmf.enable = true;
      # Run qemu processes as the dedicated qemu-libvirtd user/group rather
      # than root — needed so the tmpfiles rule below can grant it access to
      # the Looking Glass shared-memory file without root involved.
      runAsRoot = false;
    };
  };

  environment.systemPackages = [
    pkgs.virt-manager
    pkgs.libvirt # virsh, used by the win-vm launcher script (Task 2)
    pkgs.looking-glass-client
  ];

  users.users.gjermund.extraGroups = [ "libvirtd" ];

  # Looking Glass's zero-copy frame buffer. The Looking Glass host app inside
  # the guest writes into this file; looking-glass-client on the host reads
  # from it. Group ownership assumes qemu runs as qemu-libvirtd (set above) —
  # if `ps -o user,group -C qemu-system-x86_64` ever shows a different
  # group after the VM is running, update this rule to match.
  systemd.tmpfiles.rules = [
    "f /dev/shm/looking-glass 0660 gjermund qemu-libvirtd -"
  ];
}
```

- [ ] **Step 2: Wire the module into the desktop host**

Modify `hosts/desktop/default.nix`. Current imports block (near the top of
the file):

```nix
  imports = [
    # Waydroid + NVIDIA GPU acceleration. Desktop only: the stack needs the
    # compositor running on the NVIDIA GPU.
    ../../modules/system/waydroid.nix
  ];
```

Change to:

```nix
  imports = [
    # Waydroid + NVIDIA GPU acceleration. Desktop only: the stack needs the
    # compositor running on the NVIDIA GPU.
    ../../modules/system/waydroid.nix

    # Windows VM with Intel iGPU passthrough (see module for detail).
    ../../modules/system/vm-passthrough.nix
  ];
```

- [ ] **Step 3: Build-check (no switch yet)**

Run:

```bash
sudo nixos-rebuild build --flake ~/nix-config#desktop
```

Expected: build completes with no evaluation errors (exit code 0). This
only builds the closure — it does not activate anything, so it's safe to
run before the reboot in Task 3.

- [ ] **Step 4: Commit**

```bash
git -C ~/nix-config add modules/system/vm-passthrough.nix hosts/desktop/default.nix
git -C ~/nix-config commit -m "Add Intel iGPU VFIO passthrough + libvirt for a Windows VM"
```

---

### Task 2: `win-vm` launcher script

**Files:**
- Modify: `modules/system/vm-passthrough.nix` (add to `environment.systemPackages`)

- [ ] **Step 1: Add the script**

Add this entry to the `environment.systemPackages` list in
`modules/system/vm-passthrough.nix` (alongside `virt-manager`, `libvirt`,
`looking-glass-client` added in Task 1):

```nix
    (pkgs.writeShellScriptBin "win-vm" ''
      #!/usr/bin/env bash
      set -euo pipefail

      VM_NAME="win11"
      SHM_FILE="/dev/shm/looking-glass"

      if ! ${pkgs.libvirt}/bin/virsh domstate "$VM_NAME" 2>/dev/null | grep -q running; then
        ${pkgs.libvirt}/bin/virsh start "$VM_NAME"
      fi

      # Wait for the guest's Looking Glass host app to open the shared-memory
      # file before attaching the client, so we don't race the VM's boot.
      for _ in $(seq 1 60); do
        [ -w "$SHM_FILE" ] && break
        sleep 1
      done

      exec ${pkgs.looking-glass-client}/bin/looking-glass-client win:borderless=yes
    '')
```

- [ ] **Step 2: Syntax-check the script before rebuilding**

Write the same body to a temp file and check it with `bash -n`, so a typo
doesn't surface only after a full rebuild:

```bash
cat > /tmp/win-vm.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

VM_NAME="win11"
SHM_FILE="/dev/shm/looking-glass"

if ! virsh domstate "$VM_NAME" 2>/dev/null | grep -q running; then
  virsh start "$VM_NAME"
fi

for _ in $(seq 1 60); do
  [ -w "$SHM_FILE" ] && break
  sleep 1
done

exec looking-glass-client win:borderless=yes
EOF
bash -n /tmp/win-vm.sh
```

Expected: no output (bash -n prints nothing and exits 0 on valid syntax).
This checks shell syntax only — the real thing (with store paths
substituted for `virsh`/`looking-glass-client`) is exercised for real in
Task 9.

- [ ] **Step 3: Build-check again**

```bash
sudo nixos-rebuild build --flake ~/nix-config#desktop
```

Expected: build completes with no evaluation errors.

- [ ] **Step 4: Commit**

```bash
git -C ~/nix-config add modules/system/vm-passthrough.nix
git -C ~/nix-config commit -m "Add win-vm launcher script for the Looking Glass VM"
```

---

### Task 3: Rebuild, reboot, and verify the iGPU is detached

**This is the go/no-go checkpoint for the whole plan.** If the IOMMU
grouping is unclean, stop here and reassess before investing in VM/guest
work.

- [ ] **Step 1: Rebuild and switch**

```bash
nrs
```

This activates the new kernel params and boots into them on the next
restart — a reboot is required for `intel_iommu=on`/the blacklist to take
effect (they're boot-time kernel params, not something `switch` alone
applies live).

- [ ] **Step 2: Reboot**

```bash
sudo reboot
```

- [ ] **Step 3: Verify the iGPU is bound to vfio-pci**

```bash
lspci -nnk -s 00:02.0
```

Expected output includes:

```
Kernel driver in use: vfio-pci
```

(Not `i915`.) If it still shows `i915`, the blacklist or `extraModprobeConfig`
didn't take — check `cat /proc/cmdline` for `intel_iommu=on` and re-check
Task 1's module content before continuing.

- [ ] **Step 4: Verify IOMMU grouping is clean**

```bash
for g in /sys/kernel/iommu_groups/*/devices/*; do
  n=$(basename "$(dirname "$(dirname "$g")")")
  echo "IOMMU group $n: $(basename "$g")"
done | grep -A0 -B0 "" | sort -t' ' -k3
```

Look specifically at the group containing `0000:00:02.0`:

```bash
group=$(basename "$(dirname "$(readlink -f /sys/bus/pci/devices/0000:00:02.0/iommu_group)")")
ls /sys/kernel/iommu_groups/"$group"/devices/
```

Expected: only `0000:00:02.0` (and possibly its integrated audio/display
companions, which are also fine to pass through — this CPU's iGPU does not
share a group with anything the host depends on, like the NVMe controller
or NVIDIA GPU). If something load-bearing appears in this list, stop and
reassess — passthrough would drag that device away from the host too.

- [ ] **Step 5: Confirm the existing desktop session is unaffected**

Log back into the normal Hyprland session as usual and confirm nothing
changed — no missing outputs, no graphical glitches. This should be a
non-event, since nothing previously used the iGPU.

- [ ] **Step 6: Confirm libvirtd is running**

```bash
systemctl status libvirtd --no-pager
```

Expected: `Active: active (running)`.

---

### Task 4: Fetch the Windows 11 ISO

- [ ] **Step 1: Create the VM storage directory**

```bash
mkdir -p ~/games/vms
```

- [ ] **Step 2: Download the Fido script**

```bash
curl -fsSL -o /tmp/Fido.ps1 https://raw.githubusercontent.com/pbatard/Fido/master/Fido.ps1
```

Expected: the file downloads with no error; `wc -l /tmp/Fido.ps1` should
show a few thousand lines.

- [ ] **Step 3: Get the direct Microsoft CDN URL (no GUI, so explicit params are required)**

```bash
, pwsh -NoProfile -ExecutionPolicy Bypass -File /tmp/Fido.ps1 \
  -Win 11 -Rel 24H2 -Ed Home/Pro -Lang "English International" -Arch x64 -GetUrl
```

Expected: a single `https://...` URL printed to stdout, pointing at
Microsoft's software-download CDN.

If Fido instead prints an error listing valid values for `-Rel` (Windows
release names shift over time — this plan was written against `24H2`),
rerun the same command with the newest release name from that list.

- [ ] **Step 4: Download the ISO**

```bash
curl -fL -o ~/games/vms/win11.iso "<URL from Step 3>"
```

- [ ] **Step 5: Verify it's a real ISO**

```bash
file ~/games/vms/win11.iso
```

Expected output contains `ISO 9660 CD-ROM filesystem data`.

---

### Task 5: Create the VM in virt-manager

- [ ] **Step 1: Launch virt-manager and start the "New VM" wizard**

```bash
virt-manager
```

Click "Create a new virtual machine" → "Local install media (ISO image or
CDROM)" → browse to `~/games/vms/win11.iso`. Let it auto-detect the OS as
Windows 11 (or select it manually if detection fails).

- [ ] **Step 2: Set memory and CPU**

On the "Memory and CPU" step: **8192 MiB** RAM, **4** CPUs.

- [ ] **Step 3: Create the disk**

On the storage step, choose "Select or create custom storage", set the path
to `/home/gjermund/games/vms/win11.qcow2`, size **80 GiB** (adjust later if
needed — qcow2 grows on demand, so this is a ceiling, not allocated
up-front).

- [ ] **Step 4: Name it and finish**

Name the VM exactly **`win11`** (the `win-vm` script from Task 2 hardcodes
this name). On the final step, check "Customize configuration before
install" so the next steps can be done before first boot.

- [ ] **Step 5: Switch firmware to UEFI**

In the customization view, under "Overview" → "Firmware", select **UEFI**
(OVMF). Under "CPUs", confirm the model is left at the default (`host-passthrough`
is fine and gives best performance, but is not required for this light
workload).

**Cap the guest's reported physical address width to match this host's
IOMMU.** `-cpu host` passes through the CPU's real 46-bit physical
addressing, but this host's IOMMU only supports 39-bit addressing (`DMAR:
Host address width 39`, confirmed via `journalctl -k`). Without this cap,
OVMF places its 64-bit PCI MMIO window near the top of the 46-bit space —
around 36 TiB — which the IOMMU cannot map, and the VM hardware-crashes the
moment the ivshmem device (added in Step 9 below) gets its BAR enabled
during boot (`qemu: hardware error: vfio: DMA mapping failed`). virt-manager
has no GUI for this, so it's a `virsh edit win11` XML edit once the VM is
first defined (after Step 4's Finish, before or after customizing further):

```xml
<cpu mode='host-passthrough' check='none' migratable='on'>
  <maxphysaddr mode='passthrough' limit='39'/>
</cpu>
```

Must be `mode='passthrough'` + `limit=`, not `mode='emulate'` + `bits=` —
the latter maps to QEMU's plain `phys-bits=` property, which `-cpu host`
silently re-derives from the real host value afterward and so has no
effect. Confirm it actually took with:

```bash
virsh domxml-to-native --format qemu-argv --domain win11 | grep -o '\-cpu [^ ]*'
```

— must show `host-phys-bits-limit=39`, not just `phys-bits=39`.

- [ ] **Step 6: Switch the disk to VirtIO**

Under the disk device, set "Disk bus" to **VirtIO**.

- [ ] **Step 6b: Add a TPM device**

Windows 11 Setup hard-requires TPM 2.0. "Add Hardware" → "TPM" → Type
**Emulated**, Model **CRB**, Version **2.0**. This needs
`virtualisation.libvirtd.qemu.swtpm.enable = true;` in
`modules/system/vm-passthrough.nix` (not part of Tasks 1-2 above — add it
there if it's missing) and a `sudo systemctl restart libvirtd` after
rebuilding, since `nixos-rebuild switch` does not restart `libvirtd.service`
on its own if a VM is currently running under it.

**Storage permission note:** once `libvirtd` restarts with
`runAsRoot = false` in effect, qemu runs as the unprivileged
`qemu-libvirtd` user (uid/gid 301), not root. Any disk image created by an
*earlier* boot (while qemu was still running as root, before this setting
took effect) will be `root:root` mode `600` and unreadable by that user —
fix with `sudo chown gjermund:qemu-libvirtd win11.qcow2 && sudo chmod 660
win11.qcow2`. Separately, since the image lives under
`/home/gjermund/games/vms/` and `/home/gjermund` itself is mode `700`,
`qemu-libvirtd` also needs explicit traversal via a POSIX ACL (does not
require sudo, since it's a grant on your own directory):
```bash
setfacl -m u:qemu-libvirtd:--x /home/gjermund
```

- [ ] **Step 7: Add the Intel iGPU as a PCI host device**

"Add Hardware" → "PCI Host Device" → select the entry matching
`Intel Corporation Raptor Lake-S GT1 [UHD Graphics 770]` (bus address
`0000:00:02.0`) → Finish.

- [ ] **Step 8: Add a VirtIO CD-ROM for the driver ISO**

"Add Hardware" → "Storage" → create a second CD-ROM device, and set its
source to the `virtio-win` ISO. Download it first if not already present:

```bash
curl -fL -o ~/games/vms/virtio-win.iso \
  https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
```

Then point the CD-ROM device at `~/games/vms/virtio-win.iso`.

- [ ] **Step 9: Add the IVSHMEM device for Looking Glass**

virt-manager's GUI has no "shared memory" device type, so this one XML edit
is done via `virsh` after closing the customization window and letting the
VM definition save (don't start the VM yet):

```bash
virsh edit win11
```

Inside the `<devices>` block, add:

```xml
<shmem name='looking-glass'>
  <model type='ivshmem-plain'/>
  <size unit='M'>32</size>
</shmem>
```

Save and exit the editor. `virsh` validates the XML on save — if it
complains, re-open with `virsh edit win11` and fix the `<shmem>` block
before proceeding.

- [ ] **Step 10: Boot the VM and install Windows normally**

```bash
virsh start win11
virt-viewer win11
```

Proceed through the standard Windows 11 setup. When Windows Setup can't
find a disk (expected — VirtIO isn't a driver Windows ships with), click
"Load driver", browse to the `virtio-win` CD-ROM's `viostor\w11\amd64`
folder, and load it there. Finish the install as normal (local account is
fine, no Microsoft account needed for an Excel-only VM, though Office 365
activation will need a Microsoft login later inside the guest).

---

### Task 6: Guest driver setup — VirtIO, network

- [ ] **Step 1: Open Device Manager inside the guest**

Right-click Start → Device Manager. Expect to see unknown/exclamation-mark
devices for the network adapter and possibly others (chipset devices under
VirtIO aren't all auto-detected).

- [ ] **Step 2: Install the remaining VirtIO drivers**

From the mounted `virtio-win` CD-ROM (still attached from Task 5), run
`virtio-win-guest-tools.exe` from the ISO root. This installs the network,
balloon, and QEMU guest agent drivers in one pass.

- [ ] **Step 3: Verify**

In Device Manager, confirm no devices remain under "Other devices" with a
yellow warning icon, and that "Network adapters" shows a Red Hat VirtIO
Ethernet Adapter. Confirm network connectivity: open a browser in the guest
and load any page.

---

### Task 7: Guest display + Looking Glass + audio

**Superseded — see the design doc's "Looking Glass: IddSampleDriver
abandoned, IDD-only host used instead" section for what actually worked.**
Skip Steps 1-2 below entirely (IddSampleDriver was never needed — the
Looking Glass host installer bundles its own IDD) and go straight to
installing the Looking Glass host app (which now IS the IDD driver). The
real remaining work was: sizing `<shmem>` correctly (128MB, not 32MB — see
design doc), and two client-side patches for bugs found via source reading
and live gdb debugging (`looking-glass-bgr32-workaround.patch` and the
`FB_SPIN_LIMIT` bump), both already wired into `modules/system/
vm-passthrough.nix`. The steps below are kept for historical context only.

- [ ] **Step 1: Install the IddSampleDriver virtual display (SKIP — see above)**

Inside the guest, download and install the IddSampleDriver release from
<https://github.com/fufesou/IddSampleDriver> (or a currently-maintained
fork if that repo has moved — check its README for the latest install
steps, since driver-signing requirements around Windows virtual display
drivers shift between builds). This is a test-signed driver, so Windows
must have test-signing mode enabled first:

Open an elevated Command Prompt in the guest and run:

```
bcdedit /set testsigning on
```

Reboot the guest, then install the driver's `.inf` via Device Manager
("Add legacy hardware" → "Display adapters" → "Have Disk").

- [ ] **Step 2: Verify a virtual monitor is now present**

In the guest, open Settings → Display. A second display should now be
listed even though nothing is physically connected. Set it as the primary
display if it isn't already.

- [ ] **Step 3: Install the Looking Glass host application**

Download the Looking Glass Windows host installer matching the
`looking-glass-client` version installed on the Linux host (check with
`looking-glass-client --version` on the host first, then get the matching
release from <https://looking-glass.io/downloads>). Run the installer
inside the guest; it installs as a Windows service and starts
automatically.

- [ ] **Step 4: First connection test**

On the host:

```bash
win-vm
```

Expected: a `looking-glass-client` window opens and shows the guest's
virtual display (the Windows desktop). Move the mouse into the window and
confirm it's tracked in the guest without needing to click to "capture" the
mouse.

- [ ] **Step 5: Install Scream for audio**

Inside the guest, install Scream from
<https://github.com/duncanthrax/scream/releases> (the Windows driver half).
On the host:

```bash
nix run nixpkgs#scream -- -o pulse
```

Leave that running in a terminal (or wrap it in a user systemd unit later
once confirmed working). Play a sound in the guest (e.g. a YouTube video)
and confirm it's audible on the host.

---

### Task 8: Debloat pass

- [ ] **Step 1: Run a debloat script inside the guest**

Open an elevated PowerShell inside the guest and run:

```powershell
irm "https://christitus.com/win" | iex
```

This launches Chris Titus Tech's WinUtil. Use its "Recommended" debloat
selections (removes Xbox, Teams, Copilot, ad-related components and
telemetry services) and apply them.

- [ ] **Step 2: Reboot the guest and confirm it still boots cleanly**

Restart from inside the guest, then repeat Task 7 Step 4 (`win-vm` from the
host) to confirm Looking Glass still connects after the debloat pass.

---

### Task 9: End-to-end validation

- [ ] **Step 1: Full cold-start test**

From a state where the VM is shut down (`virsh shutdown win11` from the
host, wait for it to stop):

```bash
win-vm
```

Expected: VM starts, Looking Glass window appears showing the Windows
desktop, all within roughly 30-60 seconds.

- [ ] **Step 2: Open Excel and confirm smooth rendering**

Install/open Excel (or any Office app) in the guest, open a spreadsheet
with some content, and scroll. Confirm scrolling and window animations feel
smooth rather than choppy — this is the acceleration the iGPU passthrough
was for.

- [ ] **Step 3: Confirm audio round-trip**

Play any sound in the guest, confirm it's audible on the host via the
Scream receiver started in Task 7 Step 5.

- [ ] **Step 4: Confirm the host desktop is unaffected**

Close the Looking Glass window, shut the VM down
(`virsh shutdown win11`), and confirm the normal Hyprland session on the
NVIDIA-driven monitor behaves exactly as it did before this whole project —
no missing outputs, no performance change, nothing to undo.

---

## Follow-ups (not part of this plan)

- Wrapping the Scream receiver in a proper systemd user service instead of
  a foreground terminal command.
- A Hyprland keybind or Vicinae launcher entry for `win-vm`.
- Bumping the IVSHMEM size if a resolution higher than 1080p is ever used in
  the guest.
