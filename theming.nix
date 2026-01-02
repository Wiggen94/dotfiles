{ config, pkgs, ... }:

let
  colors = import ./colors.nix;
in
{
  # Qt theming - use kde platform to read kdeglobals
  qt = {
    enable = true;
    platformTheme = "kde";
  };

  # KDE/Qt color scheme - Catppuccin Mocha Mauve
  environment.etc."xdg/kdeglobals".text = ''
    [ColorEffects:Disabled]
    Color=${colors.rgb.base}
    ColorAmount=0.3
    ColorEffect=2
    ContrastAmount=0.1
    ContrastEffect=0
    IntensityAmount=-1
    IntensityEffect=0

    [ColorEffects:Inactive]
    ChangeSelectionColor=true
    Color=${colors.rgb.base}
    ColorAmount=0.5
    ColorEffect=3
    ContrastAmount=0
    ContrastEffect=0
    Enable=true
    IntensityAmount=0
    IntensityEffect=0

    [Colors:Button]
    BackgroundAlternate=${colors.rgb.mauve}
    BackgroundNormal=${colors.rgb.surface0}
    DecorationFocus=${colors.rgb.mauve}
    DecorationHover=${colors.rgb.surface0}
    ForegroundActive=${colors.rgb.peach}
    ForegroundInactive=${colors.rgb.subtext0}
    ForegroundLink=${colors.rgb.mauve}
    ForegroundNegative=${colors.rgb.red}
    ForegroundNeutral=${colors.rgb.yellow}
    ForegroundNormal=${colors.rgb.text}
    ForegroundPositive=${colors.rgb.green}
    ForegroundVisited=${colors.rgb.mauve}

    [Colors:Complementary]
    BackgroundAlternate=${colors.rgb.crust}
    BackgroundNormal=${colors.rgb.mantle}
    DecorationFocus=${colors.rgb.mauve}
    DecorationHover=${colors.rgb.surface0}
    ForegroundActive=${colors.rgb.peach}
    ForegroundInactive=${colors.rgb.subtext0}
    ForegroundLink=${colors.rgb.mauve}
    ForegroundNegative=${colors.rgb.red}
    ForegroundNeutral=${colors.rgb.yellow}
    ForegroundNormal=${colors.rgb.text}
    ForegroundPositive=${colors.rgb.green}
    ForegroundVisited=${colors.rgb.mauve}

    [Colors:Header]
    BackgroundAlternate=${colors.rgb.crust}
    BackgroundNormal=${colors.rgb.mantle}
    DecorationFocus=${colors.rgb.mauve}
    DecorationHover=${colors.rgb.surface0}
    ForegroundActive=${colors.rgb.peach}
    ForegroundInactive=${colors.rgb.subtext0}
    ForegroundLink=${colors.rgb.mauve}
    ForegroundNegative=${colors.rgb.red}
    ForegroundNeutral=${colors.rgb.yellow}
    ForegroundNormal=${colors.rgb.text}
    ForegroundPositive=${colors.rgb.green}
    ForegroundVisited=${colors.rgb.mauve}

    [Colors:Selection]
    BackgroundAlternate=${colors.rgb.mauve}
    BackgroundNormal=${colors.rgb.mauve}
    DecorationFocus=${colors.rgb.mauve}
    DecorationHover=${colors.rgb.surface0}
    ForegroundActive=${colors.rgb.peach}
    ForegroundInactive=${colors.rgb.mantle}
    ForegroundLink=${colors.rgb.mauve}
    ForegroundNegative=${colors.rgb.red}
    ForegroundNeutral=${colors.rgb.yellow}
    ForegroundNormal=${colors.rgb.crust}
    ForegroundPositive=${colors.rgb.green}
    ForegroundVisited=${colors.rgb.mauve}

    [Colors:Tooltip]
    BackgroundAlternate=27,25,35
    BackgroundNormal=${colors.rgb.base}
    DecorationFocus=${colors.rgb.mauve}
    DecorationHover=${colors.rgb.surface0}
    ForegroundActive=${colors.rgb.peach}
    ForegroundInactive=${colors.rgb.subtext0}
    ForegroundLink=${colors.rgb.mauve}
    ForegroundNegative=${colors.rgb.red}
    ForegroundNeutral=${colors.rgb.yellow}
    ForegroundNormal=${colors.rgb.text}
    ForegroundPositive=${colors.rgb.green}
    ForegroundVisited=${colors.rgb.mauve}

    [Colors:View]
    BackgroundAlternate=${colors.rgb.mantle}
    BackgroundNormal=${colors.rgb.base}
    DecorationFocus=${colors.rgb.mauve}
    DecorationHover=${colors.rgb.surface0}
    ForegroundActive=${colors.rgb.peach}
    ForegroundInactive=${colors.rgb.subtext0}
    ForegroundLink=${colors.rgb.mauve}
    ForegroundNegative=${colors.rgb.red}
    ForegroundNeutral=${colors.rgb.yellow}
    ForegroundNormal=${colors.rgb.text}
    ForegroundPositive=${colors.rgb.green}
    ForegroundVisited=${colors.rgb.mauve}

    [Colors:Window]
    BackgroundAlternate=${colors.rgb.crust}
    BackgroundNormal=${colors.rgb.mantle}
    DecorationFocus=${colors.rgb.mauve}
    DecorationHover=${colors.rgb.surface0}
    ForegroundActive=${colors.rgb.peach}
    ForegroundInactive=${colors.rgb.subtext0}
    ForegroundLink=${colors.rgb.mauve}
    ForegroundNegative=${colors.rgb.red}
    ForegroundNeutral=${colors.rgb.yellow}
    ForegroundNormal=${colors.rgb.text}
    ForegroundPositive=${colors.rgb.green}
    ForegroundVisited=${colors.rgb.mauve}

    [General]
    ColorScheme=CatppuccinMochaMauve
    Name=${colors.meta.name} ${colors.meta.variant}

    [Icons]
    Theme=Papirus-Dark

    [KDE]
    contrast=4

    [WM]
    activeBackground=${colors.rgb.base}
    activeBlend=${colors.rgb.text}
    activeForeground=${colors.rgb.text}
    inactiveBackground=${colors.rgb.crust}
    inactiveBlend=${colors.rgb.subtext0}
    inactiveForeground=${colors.rgb.subtext0}
  '';

  # Fonts - Nerd Fonts for icons
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
  ];

  # Theming packages
  environment.systemPackages = with pkgs; [
    papirus-icon-theme
    adwaita-icon-theme
    hicolor-icon-theme
    bibata-cursors
    kdePackages.breeze
    kdePackages.breeze-icons
    kdePackages.breeze-gtk
  ];
}
