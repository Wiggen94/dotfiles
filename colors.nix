# Catppuccin Mocha color palette
# Centralized color definitions for consistent theming across the system
{
  # Base colors
  base = "#1e1e2e";
  mantle = "#181825";
  crust = "#11111b";

  # Surface colors
  surface0 = "#313244";
  surface1 = "#45475a";
  surface2 = "#585b70";

  # Overlay colors
  overlay0 = "#6c7086";
  overlay1 = "#7f849c";
  overlay2 = "#9399b2";

  # Text colors
  text = "#cdd6f4";
  subtext0 = "#a6adc8";
  subtext1 = "#bac2de";

  # Accent colors
  lavender = "#b4befe";
  blue = "#89b4fa";
  sapphire = "#74c7ec";
  sky = "#89dceb";
  teal = "#94e2d5";
  green = "#a6e3a1";
  yellow = "#f9e2af";
  peach = "#fab387";
  maroon = "#eba0ac";
  red = "#f38ba8";
  mauve = "#cba6f7";
  pink = "#f5c2e7";
  flamingo = "#f2cdcd";
  rosewater = "#f5e0dc";

  # RGB versions (for kdeglobals and other formats)
  rgb = {
    base = "30,30,46";
    mantle = "24,24,37";
    crust = "17,17,27";
    surface0 = "49,50,68";
    surface1 = "69,71,90";
    surface2 = "88,91,112";
    overlay0 = "108,112,134";
    overlay1 = "127,132,156";
    overlay2 = "147,153,178";
    text = "205,214,244";
    subtext0 = "166,173,200";
    subtext1 = "186,194,222";
    lavender = "180,190,254";
    blue = "137,180,250";
    sapphire = "116,199,236";
    sky = "137,220,235";
    teal = "148,226,213";
    green = "166,227,161";
    yellow = "249,226,175";
    peach = "250,179,135";
    maroon = "235,160,172";
    red = "243,139,168";
    mauve = "203,166,247";
    pink = "245,194,231";
    flamingo = "242,205,205";
    rosewater = "245,224,220";
  };

  # Hyprland rgb() format (hex without #)
  hypr = {
    base = "rgb(1e1e2e)";
    mantle = "rgb(181825)";
    crust = "rgb(11111b)";
    surface0 = "rgb(313244)";
    surface1 = "rgb(45475a)";
    surface2 = "rgb(585b70)";
    text = "rgb(cdd6f4)";
    subtext0 = "rgb(a6adc8)";
    subtext1 = "rgb(bac2de)";
    blue = "rgb(89b4fa)";
    mauve = "rgb(cba6f7)";
    pink = "rgb(f5c2e7)";
    red = "rgb(f38ba8)";
    green = "rgb(a6e3a1)";
    yellow = "rgb(f9e2af)";
    peach = "rgb(fab387)";
    teal = "rgb(94e2d5)";
  };

  # RGBA versions for Hyprland (with full opacity)
  rgba = {
    base = "rgba(1e1e2eff)";
    mantle = "rgba(181825ff)";
    crust = "rgba(11111bff)";
    surface0 = "rgba(313244ff)";
    surface1 = "rgba(45475aff)";
    surface2 = "rgba(585b70ff)";
    text = "rgba(cdd6f4ff)";
    subtext0 = "rgba(a6adc8ff)";
    subtext1 = "rgba(bac2deff)";
    blue = "rgba(89b4faff)";
    mauve = "rgba(cba6f7ff)";
    pink = "rgba(f5c2e7ff)";
    red = "rgba(f38ba8ff)";
    green = "rgba(a6e3a1ff)";
    yellow = "rgba(f9e2afff)";
    peach = "rgba(fab387ff)";
    teal = "rgba(94e2d5ff)";
  };

  # Common transparency variants
  transparent = {
    base90 = "rgba(1e1e2ee6)";      # 90% opacity
    base85 = "rgba(1e1e2ed9)";      # 85% opacity
    base80 = "rgba(1e1e2ecc)";      # 80% opacity
    surface1_67 = "rgba(45475aaa)"; # 67% opacity (inactive borders)
    crust_93 = "rgba(11111bee)";    # 93% opacity (shadows)
  };

  # Font configuration
  fonts = {
    monospace = "JetBrainsMono Nerd Font";
    sansSerif = "Inter";
    serif = "Noto Serif";
    size = {
      small = 10;
      normal = 12;
      large = 14;
      xlarge = 16;
    };
  };

  # Theme metadata
  meta = {
    name = "Catppuccin Mocha";
    variant = "Mauve";
    accent = "#cba6f7";  # Primary accent color (mauve)
  };
}
