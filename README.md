<p align="center">
  <img src="https://nixos.org/logo/nixos-logo-only-hires.png" width="100" alt="NixOS Logo">
</p>

<h1 align="center">NixOS Hyprland Configuration</h1>

<p align="center">
  <b>A modern, feature-rich NixOS desktop environment with Hyprland</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/NixOS-25.11-5277C3?style=for-the-badge&logo=nixos&logoColor=white">
  <img src="https://img.shields.io/badge/Hyprland-Wayland-00ADD8?style=for-the-badge&logo=wayland&logoColor=white">
  <img src="https://img.shields.io/badge/Theme-Catppuccin%20Mocha-f5c2e7?style=for-the-badge">
</p>

---

## Features

### Visual Experience
- **Animated Wallpapers** - swww with smooth transitions (wipe, wave, grow, center)
- **12 Color Themes** - Hot-switchable with `Ctrl+Super+Tab`
- **Rich Animations** - Bezier-curve window animations, gradient borders
- **Modern Bar** - Waybar with weather, media, CPU/RAM, workspace icons
- **Blur & Transparency** - Beautiful glassmorphism effects

### Productivity
- **Dropdown Terminal** - Press `Super+Y` for instant terminal access
- **Scratchpads** - Quick btop (`Super+Shift+Y`) and file manager
- **Clipboard History** - Searchable with `Super+V`
- **Screenshot Tool** - Region select with save option (`Super+P`)
- **Notification Center** - SwayNC with full theming

### Developer Tools
- **Neovim** - LazyVim-like setup with LSP, Treesitter, and Telescope
- **Modern CLI** - All tools replaced with Rust alternatives (eza, bat, fd, ripgrep)
- **devenv** - Fast, declarative development environments
- **Smart Shell** - Zoxide (learns your directories), Atuin (searchable history)
- **Multiple Terminals** - Alacritty, WezTerm (both themed)

### Gaming
- **Steam** with Gamescope integration
- **Proton-GE** auto-updates weekly
- **Gaming Mode** - `Super+G` disables all effects for maximum performance
- **CurseForge** auto-updated from AUR
- **Lutris** for non-Steam games

---

## Quick Start

### Prerequisites
- NixOS with flakes enabled
- NVIDIA GPU (configuration supports both standalone and Prime)

### Installation

```bash
# Clone the repository
git clone https://github.com/Wiggen94/dotfiles.git ~/nix-config
cd ~/nix-config

# Copy your hardware configuration
cp /etc/nixos/hardware-configuration.nix hosts/desktop/  # or hosts/laptop/

# Build and switch
sudo nixos-rebuild switch --flake .#desktop  # or .#laptop
```

### After Installation

```bash
# Rebuild with auto-commit (recommended)
nrs

# View system info
sysinfo

# Show keybindings
keybinds

# Pick a wallpaper
wallpaper-picker

# Switch theme
# Press Ctrl+Super+Tab
```

---

## Key Bindings

### Applications
| Key | Action |
|-----|--------|
| `Super+T` | Terminal (Alacritty) |
| `Super+B` | Browser (Zen) |
| `Super+E` | File Manager (Dolphin) |
| `Super+R` / `Super+A` | App Launcher (Fuzzel) |
| `Super+C` | Calculator |
| `Super+Y` | Dropdown Terminal |
| `Super+Shift+Y` | System Monitor (btop) |

### Windows
| Key | Action |
|-----|--------|
| `Super+Q` | Close window |
| `Super+F` | Fullscreen |
| `Super+W` | Toggle floating |
| `Super+J` | Toggle split direction |
| `Super+Tab` | Cycle windows |
| `Super+Arrows` | Move focus |
| `Super+Shift+Arrows` | Resize window |
| `Super+Ctrl+Arrows` | Move window |

### Workspaces
| Key | Action |
|-----|--------|
| `Super+1-6` | Switch workspace |
| `Super+Shift+1-6` | Move window to workspace |
| `Super+D` | Workspace overview (Expo) |
| `Super+S` | Special workspace (scratchpad) |

### Utilities
| Key | Action |
|-----|--------|
| `Super+V` | Clipboard history |
| `Super+P` | Screenshot (region) |
| `Super+N` | Notification center |
| `Super+L` | Power menu |
| `Ctrl+Super+Tab` | Theme switcher |
| `Super+Shift+W` | Wallpaper picker |
| `Super+G` | Gaming mode toggle |

---

## Themes

Switch themes instantly with `Ctrl+Super+Tab`:

| Theme | Description |
|-------|-------------|
| **catppuccin-mocha** | Default - Warm dark theme |
| **catppuccin-frappe** | Lighter Catppuccin variant |
| **nord** | Arctic blue palette |
| **dracula** | Dark purple theme |
| **tokyo-night** | Inspired by Tokyo nights |
| **gruvbox-dark** | Retro warm colors |
| **rose-pine** | Elegant dark rose |
| **everforest** | Comfortable green tones |
| **kanagawa** | Inspired by Katsushika Hokusai |
| **one-dark** | Atom's iconic theme |
| **solarized-dark** | Precision colors |
| **monokai** | Classic dark theme |

Themes automatically update: Hyprland, Waybar, Alacritty, Fuzzel, Wlogout

---

## Commands

### System
```bash
nrs              # Rebuild NixOS, commit, and push
sysinfo          # Beautiful system information
keybinds         # Show all key bindings
fetch            # Quick system info (fastfetch)
```

### Wallpaper
```bash
wallpaper-picker          # Interactive wallpaper selector
wallpaper-set <path>      # Set wallpaper with transition
wallpaper-random          # Random wallpaper
```

### Modern CLI (Aliases)
```bash
ls               # eza with icons
ll               # Long list with git status
cat              # bat with syntax highlighting
cd               # zoxide (learns your paths)
find             # fd (faster, simpler)
grep             # ripgrep (blazingly fast)
top              # btop (beautiful monitor)
y                # yazi (terminal file manager)
```

### Development
```bash
, <package>      # Run any package without installing
devenv init      # Create development environment
v                # nvim
g                # git
```

---

## Directory Structure

```
nix-config/
├── flake.nix             # Flake definition
├── colors.nix            # Color palette
├── modules/
│   ├── common.nix        # System packages, services
│   └── home.nix          # User config, Hyprland, Waybar
├── themes/               # 12 color themes
│   ├── default.nix       # Theme registry
│   ├── catppuccin-mocha.nix
│   ├── nord.nix
│   └── ...
├── hosts/
│   ├── desktop/          # Gaming desktop config
│   └── laptop/           # Mobile config with Prime
└── theming.nix           # Qt/KDE global theming
```

---

## Configuration Highlights

### Waybar Modules
- NixOS launcher icon
- Numbered workspace icons
- Now playing (Spotify, etc.)
- Weather (wttr.in)
- CPU & Memory with warning states
- Network with connection status
- Audio with mute indicator
- Notification bell
- Power button

### Hyprland Features
- Animated gradient borders (mauve -> pink -> blue)
- Smooth window animations with multiple bezier curves
- Blur on windows, popups, and layer surfaces
- VRR/G-Sync support (desktop)
- Per-workspace monitor binding
- Touch screen support (secondary monitor)

### Terminal Setup
- **Alacritty** - GPU-accelerated, theme-switchable
- **WezTerm** - Feature-rich alternative
- **Starship** - Beautiful prompt (disabled by default, p10k active)
- Zoxide, Atuin, direnv integration

---

## Customization

### Adding a Wallpaper Collection
```bash
mkdir -p ~/Pictures/Wallpapers
# Add your images there
wallpaper-picker  # They'll appear automatically
```

### Switching to Starship Prompt
In `modules/home.nix`, change:
```nix
programs.starship = {
  enable = true;
  enableZshIntegration = true;  # Change from false
};
```
And comment out the p10k source in `modules/common.nix`.

### Using WezTerm Instead of Alacritty
Change `$terminal` in `modules/home.nix`:
```nix
$terminal = wezterm
```

---

## Troubleshooting

### NVIDIA Cursor Issues
Uncomment in `modules/home.nix`:
```
cursor:no_hardware_cursors = true
```

### Firefox/Zen Crashes
Comment out in `hosts/desktop/nvidia.nix`:
```nix
# GBM_BACKEND = "nvidia-drm";
```

### Screen Sharing Issues
Comment out in `hosts/desktop/nvidia.nix`:
```nix
# __GLX_VENDOR_LIBRARY_NAME = "nvidia";
```

---

## Credits

- [Catppuccin](https://github.com/catppuccin) - Beautiful color schemes
- [Hyprland](https://hyprland.org/) - Amazing Wayland compositor
- [NixOS](https://nixos.org/) - The reproducible operating system

---

<p align="center">
  <sub>Made with Nix flakes</sub>
</p>
