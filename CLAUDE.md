# NixOS Hyprland Configuration

This is Gjermund's NixOS configuration with Hyprland as the window manager.

## System Overview

- **OS**: NixOS 25.11 (unstable)
- **WM**: Hyprland (Wayland compositor)
- **Shell**: Zsh with Oh-My-Zsh + Powerlevel10k
- **Terminal**: Alacritty
- **Bar**: HyprPanel
- **App Launcher**: Fuzzel
- **File Manager**: Dolphin (KDE)
- **Browser**: Zen Browser
- **Editor**: Neovim (via nixvim) + VSCode

## Key Files

| File | Purpose |
|------|---------|
| `configuration.nix` | Main NixOS configuration |
| `theming.nix` | Qt/KDE theming (Catppuccin Mocha) |
| `battlenet.nix` | Battle.net launcher with Wine |
| `curseforge.nix` | CurseForge launcher |
| `hyprpanel-no-bluetooth.nix` | Custom HyprPanel build (bluetooth disabled for VM) |
| `~/.config/hypr/hyprland.conf` | Hyprland window manager config |
| `~/.config/hypr/visuals-vm.conf` | Visual settings (blur, gaps, etc.) |
| `~/.config/hyprpanel/config.json` | HyprPanel bar configuration |

## Rebuilding

```bash
# Standard rebuild
sudo nixos-rebuild switch -I nixos-config=/home/gjermund/nix-config/configuration.nix

# Or use the custom script (commits to git on success)
nixos-rebuild-git
```

## Key Bindings (Hyprland)

| Keybind | Action |
|---------|--------|
| `Super+T` | Terminal (Alacritty) |
| `Super+B` | Browser (Zen) |
| `Super+E` | File Manager (Dolphin) |
| `Super+R` / `Super+A` | App Launcher (Fuzzel) |
| `Super+Q` | Close window |
| `Super+F` | Fullscreen |
| `Super+W` | Toggle floating |
| `Super+V` | Clipboard history |
| `Super+P` | Screenshot (region select, copies to clipboard) |
| `Super+1-0` | Switch workspace |
| `Super+Shift+1-0` | Move window to workspace |

## Installed Applications

### Work
- Teams for Linux
- Slack
- Zoom
- Discord
- Chromium (for Outlook PWA)
- EduVPN client

### Gaming
- Steam (with Proton)
- Battle.net (via Wine)
- CurseForge
- MPV

### Development
- Claude Code
- VSCode
- Neovim (nixvim)
- Git

### Utilities
- 1Password (with CLI and browser integration for Zen)
- wl-clipboard + cliphist (clipboard history)
- grim + slurp (screenshots)
- Seahorse (keyring/SSH askpass)

## Theming

- **Theme**: Catppuccin Mocha
- **Qt Platform**: KDE (reads kdeglobals)
- **Cursor**: Bibata-Modern-Ice
- **Icons**: Papirus-Dark

## Locale Settings

- **Timezone**: Europe/Oslo
- **Default Locale**: en_US.UTF-8
- **Time Format**: nb_NO.UTF-8 (24hr, week starts Monday)
- **Measurements**: Metric (Celsius)

## HyprPanel Layout

```
Left: [Dashboard] [Workspaces] [Window Title]
Middle: [Clock] [Notifications]
Right: [Volume] [Network] [Systray]
```

## Notes

- Hardware configuration is in `/etc/nixos/hardware-configuration.nix` (not tracked in git)
- This setup was initially created in a VM (spice-vdagent enabled)
- SSH askpass uses Seahorse with `SSH_ASKPASS_REQUIRE=prefer`
- 1Password browser integration requires entries in `/etc/1password/custom_allowed_browsers`
