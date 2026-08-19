# Home identity, dconf (theming is owned by omarchy — see modules/omarchy.nix)
{
  config,
  pkgs,
  lib,
  ...
}:
{
  # Home Manager needs a bit of information about you and the paths it should manage
  home.username = "gjermund";
  home.homeDirectory = "/home/gjermund";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  home.stateVersion = "25.11";

  # Suppress version mismatch warning (expected when using NixOS unstable with Home Manager master)
  home.enableNixpkgsReleaseCheck = false;

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  home.file = {
    ".zen/native-messaging-hosts/com.1password.1password.json".text = builtins.toJSON {
      name = "com.1password.1password";
      description = "1Password BrowserSupport";
      path = "/run/wrappers/bin/1Password-BrowserSupport";
      type = "stdio";
      allowed_extensions = [
        "{0a75d802-9aed-41e7-8daa-24c067386e82}"
        "{25fc87fa-4d31-4fee-b5c1-c32a7844c063}"
        "{d634138d-c276-4fc8-924b-40a0ea21d284}"
      ];
    };
  };

  # dconf basics. color-scheme/icon-theme are also written by
  # omarchy-theme-set-gnome (theme switches); gtk-theme/icon-theme keys are
  # deliberately NOT set here — omarchy owns theming.
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      cursor-theme = "Bibata-Modern-Ice";
      font-name = "Noto Sans 10";
      monospace-font-name = "JetBrainsMono Nerd Font 10";
    };
  };
}
