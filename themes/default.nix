# Theme registry - exports all available themes
{
  # All available themes
  themes = {
    catppuccin-mocha = import ./catppuccin-mocha.nix;
    nord = import ./nord.nix;
    dracula = import ./dracula.nix;
    tokyo-night = import ./tokyo-night.nix;
    gruvbox-dark = import ./gruvbox-dark.nix;
    rose-pine = import ./rose-pine.nix;
  };

  # Default theme (used for non-switchable configs)
  default = import ./catppuccin-mocha.nix;

  # List of theme names (for theme switcher)
  themeNames = [
    "catppuccin-mocha"
    "nord"
    "dracula"
    "tokyo-night"
    "gruvbox-dark"
    "rose-pine"
  ];
}
