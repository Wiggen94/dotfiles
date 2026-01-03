# Nord color palette
# https://www.nordtheme.com/docs/colors-and-palettes
{
  # Theme metadata
  meta = {
    name = "Nord";
    slug = "nord";
    variant = "Frost";
    accent = "#88c0d0";
  };

  # Polar Night (backgrounds) - mapped to base/surface
  base = "#2e3440";      # nord0
  mantle = "#2e3440";    # nord0
  crust = "#242933";     # darker than nord0

  # Polar Night (surfaces)
  surface0 = "#3b4252";  # nord1
  surface1 = "#434c5e";  # nord2
  surface2 = "#4c566a";  # nord3

  # Overlay colors (using nord3 variants)
  overlay0 = "#4c566a";  # nord3
  overlay1 = "#616e88";  # lighter nord3
  overlay2 = "#7b88a1";  # even lighter

  # Snow Storm (text)
  text = "#eceff4";      # nord6
  subtext0 = "#d8dee9";  # nord4
  subtext1 = "#e5e9f0";  # nord5

  # Frost (accents - blues/teals)
  lavender = "#b48ead"; # nord15 (purple, closest to lavender)
  blue = "#5e81ac";      # nord10
  sapphire = "#81a1c1";  # nord9
  sky = "#88c0d0";       # nord8
  teal = "#8fbcbb";      # nord7
  green = "#a3be8c";     # nord14

  # Aurora (highlights)
  yellow = "#ebcb8b";    # nord13
  peach = "#d08770";     # nord12
  maroon = "#bf616a";    # nord11 (darker red)
  red = "#bf616a";       # nord11
  mauve = "#b48ead";     # nord15
  pink = "#b48ead";      # nord15 (no pink in Nord, use purple)
  flamingo = "#d08770";  # nord12 (orange as flamingo)
  rosewater = "#d8dee9"; # nord4 (light tone)

  # RGB versions (for kdeglobals and other formats)
  rgb = {
    base = "46,52,64";
    mantle = "46,52,64";
    crust = "36,41,51";
    surface0 = "59,66,82";
    surface1 = "67,76,94";
    surface2 = "76,86,106";
    overlay0 = "76,86,106";
    overlay1 = "97,110,136";
    overlay2 = "123,136,161";
    text = "236,239,244";
    subtext0 = "216,222,233";
    subtext1 = "229,233,240";
    lavender = "180,142,173";
    blue = "94,129,172";
    sapphire = "129,161,193";
    sky = "136,192,208";
    teal = "143,188,187";
    green = "163,190,140";
    yellow = "235,203,139";
    peach = "208,135,112";
    maroon = "191,97,106";
    red = "191,97,106";
    mauve = "180,142,173";
    pink = "180,142,173";
    flamingo = "208,135,112";
    rosewater = "216,222,233";
  };

  # Hyprland rgb() format (hex without #)
  hypr = {
    base = "rgb(2e3440)";
    mantle = "rgb(2e3440)";
    crust = "rgb(242933)";
    surface0 = "rgb(3b4252)";
    surface1 = "rgb(434c5e)";
    surface2 = "rgb(4c566a)";
    text = "rgb(eceff4)";
    subtext0 = "rgb(d8dee9)";
    subtext1 = "rgb(e5e9f0)";
    blue = "rgb(5e81ac)";
    mauve = "rgb(b48ead)";
    pink = "rgb(b48ead)";
    red = "rgb(bf616a)";
    green = "rgb(a3be8c)";
    yellow = "rgb(ebcb8b)";
    peach = "rgb(d08770)";
    teal = "rgb(8fbcbb)";
  };

  # RGBA versions for Hyprland (with full opacity)
  rgba = {
    base = "rgba(2e3440ff)";
    mantle = "rgba(2e3440ff)";
    crust = "rgba(242933ff)";
    surface0 = "rgba(3b4252ff)";
    surface1 = "rgba(434c5eff)";
    surface2 = "rgba(4c566aff)";
    text = "rgba(eceff4ff)";
    subtext0 = "rgba(d8dee9ff)";
    subtext1 = "rgba(e5e9f0ff)";
    blue = "rgba(5e81acff)";
    mauve = "rgba(b48eadff)";
    pink = "rgba(b48eadff)";
    red = "rgba(bf616aff)";
    green = "rgba(a3be8cff)";
    yellow = "rgba(ebcb8bff)";
    peach = "rgba(d08770ff)";
    teal = "rgba(8fbcbbff)";
  };

  # Common transparency variants
  transparent = {
    base90 = "rgba(2e3440e6)";
    base85 = "rgba(2e3440d9)";
    base80 = "rgba(2e3440cc)";
    surface1_67 = "rgba(434c5eaa)";
    crust_93 = "rgba(242933ee)";
  };

  # Font configuration (shared across themes)
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
}
