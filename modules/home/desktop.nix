# Desktop entries, mimeapps, filetype associations, swaync
{
  config,
  pkgs,
  lib,
  hostName,
  ...
}:
let
  inherit (import ./_common.nix { inherit lib hostName; }) isWorkHost;
in
{
  # Desktop entries
  xdg.desktopEntries.outlook = {
    name = "Outlook";
    comment = "Microsoft Outlook Web";
    exec = "outlook";
    icon = "internet-mail";
    terminal = false;
    categories = [
      "Network"
      "Email"
      "Office"
    ];
  };

  # Override default BOINC Manager to use ~/boinc data directory (disabled on work hosts)
  xdg.desktopEntries.boinc = lib.mkIf (!isWorkHost) {
    name = "BOINC Manager";
    comment = "BOINC distributed computing manager";
    exec = "boinc-manager";
    icon = "boincmgr";
    terminal = false;
    categories = [
      "System"
      "Utility"
    ];
  };

  # Override Gridcoin wallet to use ~/games datadir when present (desktop), else default.
  xdg.desktopEntries.gridcoinresearch = lib.mkIf (!isWorkHost) {
    name = "Gridcoin";
    comment = "Gridcoin Research wallet";
    exec = "gridcoin-wallet";
    icon = "gridcoinresearch";
    terminal = false;
    categories = [
      "Office"
      "Finance"
    ];
  };

  # Fresco (modern BOINC manager) desktop entry
  xdg.desktopEntries.fresco = lib.mkIf (!isWorkHost) {
    name = "Fresco";
    comment = "Modern BOINC manager";
    exec = "fresco";
    icon = "fresco";
    terminal = false;
    categories = [
      "System"
      "Utility"
    ];
  };

  # Default applications
  xdg.configFile."mimeapps.list".force = true;
  xdg.mimeApps = {
    enable = true;
    # Note: associations.added removed - defaultApplications handles all MIME types
    defaultApplications = {
      # Web browser - Zen
      "x-scheme-handler/http" = "zen.desktop";
      "x-scheme-handler/https" = "zen.desktop";
      "x-scheme-handler/about" = "zen.desktop";
      "x-scheme-handler/unknown" = "zen.desktop";
      "text/html" = "zen.desktop";
      "application/xhtml+xml" = "zen.desktop";
      # File manager - Files (GNOME)
      "inode/directory" = "org.gnome.Nautilus.desktop";
      # Text files - VS Code
      "text/plain" = "code.desktop";
      "text/x-readme" = "code.desktop";
      "text/markdown" = "code.desktop";
      "text/x-log" = "code.desktop";
      "application/json" = "code.desktop";
      "application/xml" = "code.desktop";
      "application/x-yaml" = "code.desktop";
      "text/x-python" = "code.desktop";
      "text/x-shellscript" = "code.desktop";
      "text/x-c" = "code.desktop";
      "text/x-c++src" = "code.desktop";
      "text/x-java" = "code.desktop";
      "application/javascript" = "code.desktop";
      "application/x-nix" = "code.desktop";
      # Archives - Ark
      "application/zip" = "org.kde.ark.desktop";
      "application/x-tar" = "org.kde.ark.desktop";
      "application/x-gzip" = "org.kde.ark.desktop";
      "application/x-bzip2" = "org.kde.ark.desktop";
      "application/x-xz" = "org.kde.ark.desktop";
      "application/x-7z-compressed" = "org.kde.ark.desktop";
      "application/x-rar" = "org.kde.ark.desktop";
      "application/x-compressed-tar" = "org.kde.ark.desktop";
      "application/x-bzip-compressed-tar" = "org.kde.ark.desktop";
      "application/x-xz-compressed-tar" = "org.kde.ark.desktop";
      # Images - Loupe
      "image/png" = "org.gnome.Loupe.desktop";
      "image/jpeg" = "org.gnome.Loupe.desktop";
      "image/gif" = "org.gnome.Loupe.desktop";
      "image/webp" = "org.gnome.Loupe.desktop";
      "image/bmp" = "org.gnome.Loupe.desktop";
      "image/svg+xml" = "org.gnome.Loupe.desktop";
      "image/tiff" = "org.gnome.Loupe.desktop";
    };
  };

  # KDE file type associations (filetypesrc)
  xdg.configFile."filetypesrc".text = ''
    [AddedAssociations]
    application/zip=org.kde.ark.desktop;
    application/x-7z-compressed=org.kde.ark.desktop;
    application/x-tar=org.kde.ark.desktop;
    application/x-compressed-tar=org.kde.ark.desktop;
    application/gzip=org.kde.ark.desktop;
    application/x-rar=org.kde.ark.desktop;
    image/png=org.gnome.Loupe.desktop;
    image/jpeg=org.gnome.Loupe.desktop;
    image/gif=org.gnome.Loupe.desktop;
    image/webp=org.gnome.Loupe.desktop;
  '';

  # Alacritty config is owned by omarchy themes (theme-set writes
  # ~/.local/state/omarchy/current/theme/alacritty.toml)

}
