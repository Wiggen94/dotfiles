{ config, pkgs, ... }:

let
  # Static Catppuccin Mocha (the 12-theme system is gone — omarchy owns
  # theming; Qt keeps its fixed catppuccin scheme).
  rgb = {
    base = "30,30,46";
    mantle = "24,24,37";
    crust = "17,17,27";
    surface0 = "49,50,68";
    surface1 = "69,71,90";
    text = "205,214,244";
    subtext0 = "166,173,200";
    peach = "250,179,135";
    red = "243,139,168";
    yellow = "249,226,175";
    green = "166,227,161";
    mauve = "203,166,247";
  };
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
    Color=${rgb.base}
    ColorAmount=0.3
    ColorEffect=2
    ContrastAmount=0.1
    ContrastEffect=0
    IntensityAmount=-1
    IntensityEffect=0

    [ColorEffects:Inactive]
    ChangeSelectionColor=true
    Color=${rgb.base}
    ColorAmount=0.5
    ColorEffect=3
    ContrastAmount=0
    ContrastEffect=0
    Enable=true
    IntensityAmount=0
    IntensityEffect=0

    [Colors:Button]
    BackgroundAlternate=${rgb.mauve}
    BackgroundNormal=${rgb.surface0}
    DecorationFocus=${rgb.mauve}
    DecorationHover=${rgb.surface0}
    ForegroundActive=${rgb.peach}
    ForegroundInactive=${rgb.subtext0}
    ForegroundLink=${rgb.mauve}
    ForegroundNegative=${rgb.red}
    ForegroundNeutral=${rgb.yellow}
    ForegroundNormal=${rgb.text}
    ForegroundPositive=${rgb.green}
    ForegroundVisited=${rgb.mauve}

    [Colors:Complementary]
    BackgroundAlternate=${rgb.crust}
    BackgroundNormal=${rgb.mantle}
    DecorationFocus=${rgb.mauve}
    DecorationHover=${rgb.surface0}
    ForegroundActive=${rgb.peach}
    ForegroundInactive=${rgb.subtext0}
    ForegroundLink=${rgb.mauve}
    ForegroundNegative=${rgb.red}
    ForegroundNeutral=${rgb.yellow}
    ForegroundNormal=${rgb.text}
    ForegroundPositive=${rgb.green}
    ForegroundVisited=${rgb.mauve}

    [Colors:Header]
    BackgroundAlternate=${rgb.crust}
    BackgroundNormal=${rgb.mantle}
    DecorationFocus=${rgb.mauve}
    DecorationHover=${rgb.surface0}
    ForegroundActive=${rgb.peach}
    ForegroundInactive=${rgb.subtext0}
    ForegroundLink=${rgb.mauve}
    ForegroundNegative=${rgb.red}
    ForegroundNeutral=${rgb.yellow}
    ForegroundNormal=${rgb.text}
    ForegroundPositive=${rgb.green}
    ForegroundVisited=${rgb.mauve}

    [Colors:Selection]
    BackgroundAlternate=${rgb.mauve}
    BackgroundNormal=${rgb.mauve}
    DecorationFocus=${rgb.mauve}
    DecorationHover=${rgb.surface0}
    ForegroundActive=${rgb.peach}
    ForegroundInactive=${rgb.mantle}
    ForegroundLink=${rgb.mauve}
    ForegroundNegative=${rgb.red}
    ForegroundNeutral=${rgb.yellow}
    ForegroundNormal=${rgb.crust}
    ForegroundPositive=${rgb.green}
    ForegroundVisited=${rgb.mauve}

    [Colors:Tooltip]
    BackgroundAlternate=${rgb.mantle}
    BackgroundNormal=${rgb.base}
    DecorationFocus=${rgb.mauve}
    DecorationHover=${rgb.surface0}
    ForegroundActive=${rgb.peach}
    ForegroundInactive=${rgb.subtext0}
    ForegroundLink=${rgb.mauve}
    ForegroundNegative=${rgb.red}
    ForegroundNeutral=${rgb.yellow}
    ForegroundNormal=${rgb.text}
    ForegroundPositive=${rgb.green}
    ForegroundVisited=${rgb.mauve}

    [Colors:View]
    BackgroundAlternate=${rgb.mantle}
    BackgroundNormal=${rgb.base}
    DecorationFocus=${rgb.mauve}
    DecorationHover=${rgb.surface0}
    ForegroundActive=${rgb.peach}
    ForegroundInactive=${rgb.subtext0}
    ForegroundLink=${rgb.mauve}
    ForegroundNegative=${rgb.red}
    ForegroundNeutral=${rgb.yellow}
    ForegroundNormal=${rgb.text}
    ForegroundPositive=${rgb.green}
    ForegroundVisited=${rgb.mauve}

    [Colors:Window]
    BackgroundAlternate=${rgb.crust}
    BackgroundNormal=${rgb.mantle}
    DecorationFocus=${rgb.mauve}
    DecorationHover=${rgb.surface0}
    ForegroundActive=${rgb.peach}
    ForegroundInactive=${rgb.subtext0}
    ForegroundLink=${rgb.mauve}
    ForegroundNegative=${rgb.red}
    ForegroundNeutral=${rgb.yellow}
    ForegroundNormal=${rgb.text}
    ForegroundPositive=${rgb.green}
    ForegroundVisited=${rgb.mauve}

    [General]
    ColorScheme=CatppuccinMochaMauve
    Name=Catppuccin Mocha Mauve

    [Icons]
    # Default matches the catppuccin theme (Yaru-purple); the theme-set hook
    # in omarchy-hm.nix overrides this per active theme via the user's
    # ~/.config/kdeglobals.
    Theme=Yaru-purple

    [KDE]
    contrast=4

    [WM]
    activeBackground=${rgb.base}
    activeBlend=${rgb.text}
    activeForeground=${rgb.text}
    inactiveBackground=${rgb.crust}
    inactiveBlend=${rgb.subtext0}
    inactiveForeground=${rgb.subtext0}
  '';

  # Fonts - Nerd Fonts for icons
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    noto-fonts
    inter
  ];

  # Theming packages (icons are Yaru, installed via pkgs.yaru-theme in
  # modules/omarchy.nix — the icon theme follows the active omarchy theme)
  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    hicolor-icon-theme
    bibata-cursors
    kdePackages.breeze
    kdePackages.breeze-icons
    kdePackages.breeze-gtk
  ];
}
