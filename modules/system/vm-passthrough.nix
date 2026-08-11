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
let
  # nixpkgs pins looking-glass-client to the tagged B7 release (2025-03-06),
  # which predates the IDD (Indirect Display Driver) feature entirely — IDD
  # only exists on unreleased `master` commits (mid-2026 onward), and the
  # Windows host installer from looking-glass.io/downloads is currently
  # serving one of those pre-tag builds. A B7 client can't speak the IDD's
  # handshake at all (it just waits forever for "the host application" in
  # the old sense), so the client has to track master too until upstream
  # cuts a real B8 tag. Bump the rev/hash together when upstream moves.
  looking-glass-client-b8 = pkgs.looking-glass-client.overrideAttrs (old: {
    version = "unstable-2026-08-12";
    src = pkgs.fetchFromGitHub {
      owner = "gnif";
      repo = "LookingGlass";
      rev = "9469c087c9e3ecf3cf0537c880ed9c6b5caf9e0c";
      hash = "sha256-PcbHyhKALB/FvxJFB9hvy0d/v4sjV4Ok0GfC7mIGo9I=";
      fetchSubmodules = true;
    };
    # Both added upstream after the B7 tag, for crash-diagnostic stack
    # unwinding — not in nixpkgs' B7-era buildInputs list.
    buildInputs = old.buildInputs ++ [
      pkgs.libunwind
      pkgs.elfutils
    ];
  });
in
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
      # UEFI is required for GPU passthrough. No option needed — libvirtd now
      # exposes every OVMF image shipped with qemu unconditionally, and the
      # former `qemu.ovmf` submodule is a hard build error if set.
      #
      # Run qemu processes as the dedicated qemu-libvirtd user/group rather
      # than root — needed so the tmpfiles rule below can grant it access to
      # the Looking Glass shared-memory file without root involved.
      runAsRoot = false;
      # Windows 11 Setup hard-requires a TPM 2.0 device; libvirt provides one
      # via a per-VM swtpm instance.
      swtpm.enable = true;
    };
  };

  environment.systemPackages = [
    pkgs.virt-manager
    pkgs.libvirt # virsh, used by the win-vm launcher script (Task 2)
    looking-glass-client-b8
    (pkgs.writeShellScriptBin "win-vm" ''
      #!/usr/bin/env bash
      set -euo pipefail

      # The interactive user's default libvirt URI resolves to qemu:///session,
      # but win11 is defined on the system-wide daemon (qemu:///system) — force
      # it explicitly so this doesn't silently target the wrong connection.
      export LIBVIRT_DEFAULT_URI="qemu:///system"

      # Something (observed after nixos-rebuild switch's systemd-tmpfiles-resetup,
      # but also seen recurring without a rebuild in between) periodically chmods
      # ~/, which resets this ACL's ***mask*** to match the group bits — silently
      # zeroing qemu-libvirtd's effective traversal grant even though the entry
      # is still nominally present. Cheap and idempotent to just reassert it here
      # every time rather than chase down every place that could reset it.
      ${pkgs.acl}/bin/setfacl -m u:qemu-libvirtd:--x,m::--x "$HOME"

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

      # SPICE (used by Looking Glass for input/clipboard/audio) is on a
      # libvirt-assigned port, not its default of 5900 — read the real one
      # rather than hardcoding it.
      SPICE_PORT="$(${pkgs.libvirt}/bin/virsh domdisplay "$VM_NAME" | sed -n 's#spice://[^:]*:##p')"

      exec ${looking-glass-client-b8}/bin/looking-glass-client \
        win:borderless=yes \
        spice:port="$SPICE_PORT" \
        input:escapeKey=KEY_RIGHTCTRL
    '')
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
