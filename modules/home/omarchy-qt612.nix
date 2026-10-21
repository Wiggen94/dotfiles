# Qt 6.12 compatibility for the omarchy shell.
#
# Two independent breakages land together when nixpkgs moves qtbase to 6.12:
#
# 1. quickshell 0.3.1 (what omarchy-nix pins) does not compile. Its MOC data
#    carried opaque-pointer definitions, and Qt 6.12 tightened qmetatype.h to
#    reject incomplete types in a QMetaType conversion:
#      qmetatype.h:381: error: static assertion failed: Meta Types must be fully defined
#      TypeIsCompleteOrVoid<qs::hyprland::ipc::HyprlandMonitor, void> == false
#    Fixed upstream in 0.3.2 (quickshell-mirror/quickshell@5d5d498, "use MOC
#    includes instead of opaque pointer definitions"). Handled in flake.nix by
#    pointing omarchy-nix's quickshell input at 0.3.2 rather than patching C++.
#
# 2. The shell QML loses its whole palette. Qt 6.12 adds a builtin QtQuick
#    `Color` singleton that shadows qs.Commons' own `Color` in every file with
#    an unversioned `import QtQuick`, so Color.bar.*, Color.menu.* resolve to
#    undefined — invisible bar, Super+Space rendering black. Upstream fixed it
#    in PR #14553 (shipped in Omarchy 4.0.5) by qualifying palette refs as
#    Commons.Color; patches/omarchy-shell-qt612-color.patch is that transform
#    applied to our vendored tree, which predates it.
#
# Remove this module, the patch, and the quickshell input change once
# omarchy-nix syncs upstream quattro >= 4.0.5 and bumps its own quickshell pin.
{ config
, lib
, pkgs
, inputs
, ...
}: let
  omarchySrc = inputs.omarchy-nix.outPath;

  # Mirrors omarchy-shell.nix's shellTree: copy the vendored tree to a store
  # path of real files, drop the elsewhen plugin in beside the built-ins, and
  # patch the bar's hard-coded 1..10 workspace range. Kept in sync by hand —
  # if omarchy-nix changes how it builds that tree, this needs the same change.
  # It cannot be reused directly: shellTree is a `let` binding private to their
  # module, and overriding only the deployed `home.file` source is the one seam
  # their options expose.
  workspaceCount = config.omarchy.shell.workspace_count;

  patchWorkspaces = lib.optionalString (workspaceCount != 10) ''
    substituteInPlace $out/plugins/bar/widgets/Workspaces.qml \
      --replace-fail 'id <= 10' 'id <= ${toString workspaceCount}'
  '';

  elsewhen = pkgs.callPackage "${omarchySrc}/packages/elsewhen.nix" {};

  patchedShell = pkgs.runCommand "omarchy-shell-tree-qt612" {} ''
    cp -r ${omarchySrc}/shell $out
    chmod -R u+w $out
    cp -r ${elsewhen}/share/omarchy/shell/plugins/omacom.elsewhen $out/plugins/
    chmod -R u+w $out/plugins/omacom.elsewhen
    ${patchWorkspaces}
    patch -p1 --batch --forward -d $out \
      < ${../../patches/omarchy-shell-qt612-color.patch}

    # Fail loudly if an executable palette reference survived the patch: a
    # missed one is a silently undefined colour at runtime, not a build error.
    if grep -rnE '(^|[^A-Za-z0-9_.$])Color\.[A-Za-z]' --include='*.qml' $out \
        | grep -vE ':[0-9]+:[[:space:]]*//'; then
      echo "omarchy-shell: unqualified Color reference left after Qt 6.12 patch" >&2
      exit 1
    fi
  '';
in {
  # Same deployment path omarchy-nix uses, still a single symlink to a real-file
  # copy: PluginRegistry discovers plugins with `find -type f`, which
  # per-file home-manager symlinks would not satisfy. Only `source` is forced —
  # mkForce on the whole attribute would drop omarchy's `onChange`, which is
  # what restarts the shell so the new QML actually loads.
  home.file.".local/share/omarchy/shell".source = lib.mkForce patchedShell;
}
