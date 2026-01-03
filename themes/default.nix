# Theme registry - exports all available themes
{
  # All available themes
  themes = {
    catppuccin-mocha = import ./catppuccin-mocha.nix;
    nord = import ./nord.nix;
  };

  # Default theme (used for non-switchable configs)
  default = import ./catppuccin-mocha.nix;

  # List of theme names (for theme switcher)
  themeNames = [ "catppuccin-mocha" "nord" ];
}
