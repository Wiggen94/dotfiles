# Gjermund's NixOS Dotfiles

A declarative NixOS configuration featuring Hyprland, Home Manager, and the Catppuccin Mocha theme. Supports multiple machines via Nix flakes.

## Quick Start

### Fresh NixOS Install

1. Install NixOS with your preferred method
2. Clone this repo:
   ```bash
   git clone https://github.com/Wiggen94/dotfiles.git ~/nix-config
   cd ~/nix-config
   ```
3. Copy your hardware configuration:
   ```bash
   cp /etc/nixos/hardware-configuration.nix hosts/desktop/  # or hosts/laptop/
   ```
4. Rebuild with flakes:
   ```bash
   sudo nixos-rebuild switch --flake .#desktop  # or .#laptop
   ```
5. Reboot and log into Hyprland

### Rebuilding

Use the `nrs` alias for rebuilds:
```bash
nrs   # Rebuilds, shows diff, confirms, commits & pushes
```

## What's Included

| Component | Choice |
|-----------|--------|
| Window Manager | Hyprland (with fancy animations) |
| Status Bar | HyprPanel |
| Notifications | SwayNotificationCenter (swaync) |
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
| `Super+W` | Toggle Floating |
| `Super+V` | Clipboard History |
| `Super+P` | Screenshot |
| `Super+L` | Power Menu |
| `Super+G` | Gaming Mode (disable effects) |
| `Super+N` | Notification Center |
| `Super+J` | Toggle Split |
| `Super+1-0` | Switch Workspace |
| `Super+Shift+Arrows` | Resize Window |
| `Super+Ctrl+Arrows` | Move Window |
| `Super+Tab` | Cycle Windows |

## File Structure

```
nix-config/
├── flake.nix              # Flake definition (hosts & inputs)
├── flake.lock             # Pinned dependencies
├── colors.nix             # Catppuccin Mocha color palette
├── modules/
│   ├── common.nix         # Shared NixOS configuration
│   └── home.nix           # Home Manager (dotfiles)
├── hosts/
│   ├── desktop/           # Desktop-specific config
│   │   ├── default.nix
│   │   ├── nvidia.nix
│   │   └── hardware-configuration.nix
│   └── laptop/            # Laptop-specific config
│       ├── default.nix
│       ├── nvidia-prime.nix
│       └── hardware-configuration.nix
├── theming.nix            # Qt/KDE theming
├── curseforge.nix         # CurseForge launcher
├── curitz.nix             # Curitz CLI for work
├── dolphin-fix.nix        # Dolphin "Open with" fix
└── CLAUDE.md              # Detailed documentation
```

## Theming

Unified **Catppuccin Mocha** across all applications:
- Colors defined in `colors.nix` (hex, RGB, RGBA formats)
- Primary accent: Mauve (`#cba6f7`)
- Animated gradient borders on windows

Themed applications: Hyprland, HyprPanel, swaync, Alacritty, Neovim, VSCode, Fuzzel, wlogout, hyprlock, SDDM.

## Customization

### Change weather location
In `modules/home.nix`, find the HyprPanel config:
```nix
"menus.clock.weather.location" = "Your City";
```

### Add a new host
1. Create `hosts/newhost/` with `default.nix` and `hardware-configuration.nix`
2. Add the host to `flake.nix`
3. Rebuild: `sudo nixos-rebuild switch --flake .#newhost`

## Notes

- Hardware configs are tracked in git (required for flakes)
- 1Password configured with Zen browser integration
- IPv6 disabled to prevent slow DNS resolution
- See `CLAUDE.md` for comprehensive documentation

## License

Feel free to use and modify for your own setup.
