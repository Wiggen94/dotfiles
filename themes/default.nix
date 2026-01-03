# Theme registry - exports all available themes
{
  # All available themes
  themes = {
    catppuccin-mocha = import ./catppuccin-mocha.nix;
    catppuccin-frappe = import ./catppuccin-frappe.nix;
    nord = import ./nord.nix;
    dracula = import ./dracula.nix;
    tokyo-night = import ./tokyo-night.nix;
    gruvbox-dark = import ./gruvbox-dark.nix;
    rose-pine = import ./rose-pine.nix;
    everforest = import ./everforest.nix;
    kanagawa = import ./kanagawa.nix;
    one-dark = import ./one-dark.nix;
    solarized-dark = import ./solarized-dark.nix;
    monokai = import ./monokai.nix;
  };

  # Default theme (used for non-switchable configs)
  default = import ./catppuccin-mocha.nix;

  # List of theme names (for theme switcher)
  themeNames = [
    "catppuccin-mocha"
    "catppuccin-frappe"
    "nord"
    "dracula"
    "tokyo-night"
    "gruvbox-dark"
    "rose-pine"
    "everforest"
    "kanagawa"
    "one-dark"
    "solarized-dark"
    "monokai"
  ];
}
