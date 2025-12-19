# Gjermund's NixOS Dotfiles

A declarative NixOS configuration featuring Hyprland, Home Manager, and the Catppuccin Mocha theme.

## Quick Start

### Fresh NixOS Install

1. Install NixOS with your preferred method
2. Clone this repo:
   ```bash
   git clone https://github.com/Wiggen94/dotfiles.git ~/nix-config
   ```
3. Copy your hardware configuration:
   ```bash
   cp /etc/nixos/hardware-configuration.nix ~/nix-config/
   ```
4. Rebuild:
   ```bash
   sudo nixos-rebuild switch -I nixos-config=~/nix-config/configuration.nix
   ```
5. Reboot and log into Hyprland

### Existing System

If you have existing dotfiles that conflict, back them up first:
```bash
mv ~/.config/hypr ~/.config/hypr.bak
mv ~/.config/hyprpanel ~/.config/hyprpanel.bak
mv ~/.config/alacritty ~/.config/alacritty.bak
mv ~/.p10k.zsh ~/.p10k.zsh.bak
```

Then rebuild as above.

## What's Included

| Component | Choice |
|-----------|--------|
| Window Manager | Hyprland |
| Status Bar | HyprPanel |
| Terminal | Alacritty |
| Shell | Zsh + Oh-My-Zsh + Powerlevel10k |
| App Launcher | Fuzzel |
| File Manager | Dolphin |
| Browser | Zen Browser |
| Editor | Neovim (nixvim) + VSCode |
| Theme | Catppuccin Mocha |

## Key Bindings

| Keybind | Action |
|---------|--------|
| `Super+T` | Terminal |
| `Super+B` | Browser |
| `Super+E` | File Manager |
| `Super+R` | App Launcher |
| `Super+Q` | Close Window |
| `Super+F` | Fullscreen |
| `Super+V` | Clipboard History |
| `Super+P` | Screenshot |
| `Super+1-0` | Switch Workspace |

## Making Changes

### System packages/services
Edit `configuration.nix`, then rebuild:
```bash
nixos-rebuild-git  # Rebuilds, commits, and pushes
```

### Dotfiles (Hyprland, Alacritty, etc.)
Edit `home.nix`, then rebuild. Dotfiles are managed by Home Manager and symlinked from the Nix store.

### Theming
Edit `theming.nix` for Qt/KDE themes, cursors, and icons.

## File Structure

```
~/nix-config/
├── configuration.nix          # Main NixOS config
├── home.nix                   # Home Manager (dotfiles)
├── theming.nix                # Qt/KDE theming
├── battlenet.nix              # Battle.net launcher
├── curseforge.nix             # CurseForge launcher
├── hyprpanel-no-bluetooth.nix # Custom HyprPanel build
├── p10k.zsh                   # Powerlevel10k config
├── CLAUDE.md                  # Detailed docs for AI assistants
└── README.md                  # This file
```

## Notes

- `hardware-configuration.nix` is machine-specific and not tracked in git
- Initially configured for a VM (spice-vdagent enabled, animations disabled)
- For production hardware, switch to `visuals-production.conf` in Hyprland config
- 1Password is configured with Zen browser integration

## Customization

### Switch to production visuals (real hardware)
In `home.nix`, change:
```nix
source = ~/.config/hypr/visuals-vm.conf
```
to:
```nix
source = ~/.config/hypr/visuals-production.conf
```

### Change weather location
In `home.nix`, find the HyprPanel config and update:
```nix
"menus.clock.weather.location" = "Your City";
```

## License

Feel free to use and modify for your own setup.
