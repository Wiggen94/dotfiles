# Helium wrapper that makes hardware WebGPU work on NVIDIA + NixOS.
#
# Helium ships its own Vulkan loader and SwiftShader ICD, but two things are
# missing from its closure that stock nixpkgs Chromium has, and without them
# Dawn can only ever return SwiftShader ("No available adapters"):
#
#   1. libpci (pciutils). ANGLE's gpu_info_util/SystemInfo_libpci.cpp dlopens
#      libpci to read real PCI IDs. Without it the GPU is reported as
#      0x0000/0x0000, which makes Chromium set hardwareSupportsVulkan=false and
#      force-disable the webgpu_on_vk_via_gl_interop feature. nixpkgs puts
#      pciutils/lib on Chromium's RUNPATH for exactly this reason; Helium's
#      RUNPATH has no pciutils at all.
#   2. An ICD list that excludes Helium's bundled SwiftShader. Its
#      vk_swiftshader_icd.json advertises api_version 1.0.5, which is below what
#      Dawn/ANGLE request, so instance creation fails with
#      VK_ERROR_INCOMPATIBLE_DRIVER (-9).
#
# Verified on desktop (RTX 5070 Ti, 615.78.08): requestAdapter() returns
# nvidia/blackwell 5/5 runs with this wrapper, and SwiftShader-or-NULL without.
# /run/opengl-driver is the NixOS path to the enabled Vulkan ICD set (Mesa +
# NVIDIA), so this stays correct per host.
#
# --disable-gpu-sandbox is part of the fix, not an extra. With the default GPU
# sandbox the adapter is NULL even with the variables above (and stock nixpkgs
# Chromium fails the same way, so this is not Helium-specific): the sandboxed GPU
# process cannot bring up the NVIDIA Vulkan device. Both halves are required —
# vars without the flag and the flag without vars each still yield NULL. The
# renderer sandbox and the rest of the process tree are unaffected; only the GPU
# process is unsandboxed.
{ lib, writeShellScriptBin, heliumBrowser, pciutils, extensions ? [ ] }:

writeShellScriptBin "helium" ''
  export LD_LIBRARY_PATH="/run/opengl-driver/lib:${lib.getLib pciutils}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export VK_ICD_FILENAMES="/run/opengl-driver/share/vulkan/icd.d"
  exec ${heliumBrowser}/bin/helium --disable-gpu-sandbox ${lib.escapeShellArgs (map (e: "--load-extension=${e}") extensions)} "$@"
''
