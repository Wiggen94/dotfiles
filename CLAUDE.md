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
- **Dotfiles**: Managed by Home Manager

## Key Files

| File | Purpose |
|------|---------|
| `configuration.nix` | Main NixOS configuration (system-level) |
| `home.nix` | Home Manager configuration (dotfiles) |
| `theming.nix` | Qt/KDE theming (Catppuccin Mocha) |
| `battlenet.nix` | Battle.net launcher with Wine |
| `curseforge.nix` | CurseForge launcher |
| `hyprpanel-no-bluetooth.nix` | Custom HyprPanel build (bluetooth disabled for VM) |
| `p10k.zsh` | Powerlevel10k prompt configuration |

## Dotfiles (Managed by Home Manager)

All dotfiles are defined in `home.nix` and symlinked from the Nix store:

| Dotfile | Source in home.nix |
|---------|-------------------|
| `~/.config/hypr/hyprland.conf` | `xdg.configFile."hypr/hyprland.conf"` |
| `~/.config/hypr/hyprlock.conf` | `xdg.configFile."hypr/hyprlock.conf"` |
| `~/.config/hypr/hypridle.conf` | `xdg.configFile."hypr/hypridle.conf"` |
| `~/.config/hypr/visuals-vm.conf` | `xdg.configFile."hypr/visuals-vm.conf"` |
| `~/.config/hypr/visuals-production.conf` | `xdg.configFile."hypr/visuals-production.conf"` |
| `~/.config/hyprpanel/config.json` | `xdg.configFile."hyprpanel/config.json"` |
| `~/.config/wlogout/layout` | `xdg.configFile."wlogout/layout"` |
| `~/.config/wlogout/style.css` | `xdg.configFile."wlogout/style.css"` |
| `~/.config/alacritty/alacritty.toml` | `xdg.configFile."alacritty/alacritty.toml"` |
| `~/.p10k.zsh` | `home.file.".p10k.zsh"` |

To modify dotfiles, edit `home.nix` and rebuild.

## Rebuilding

**IMPORTANT**: Always use the `nixos-rebuild-git` script (or `nrs` alias) to rebuild. This script rebuilds and automatically commits/pushes changes to git on success. Never use plain `nixos-rebuild switch`.

```bash
nrs                    # Alias for nixos-rebuild-git
nixos-rebuild-git      # Full command
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
| `Super+L` | Power menu (wlogout) |
| `Super+G` | Gaming mode (disable blur/animations) |
| `Super+Shift+G` | Exit gaming mode |
| `Super+1-0` | Switch workspace |
| `Super+Shift+1-0` | Move window to workspace |
| `XF86AudioRaiseVolume` | Volume up |
| `XF86AudioLowerVolume` | Volume down |
| `XF86AudioMute` | Toggle mute |
| `XF86AudioPlay` | Play/pause media |
| `XF86AudioNext/Prev` | Next/previous track |

## Power Menu (wlogout)

Press `Super+L` to open. Keybinds in menu:
- `l` - Lock (hyprlock)
- `e` - Logout
- `u` - Suspend
- `h` - Hibernate
- `r` - Reboot
- `s` - Shutdown

## Idle Behavior (hypridle)

- **5 minutes**: Screen off (DPMS)
- **10 minutes**: Lock screen (hyprlock)
- **Never**: Auto-suspend (disabled)

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
- hyprlock (screen locker)
- wlogout (power menu)
- hypridle (idle daemon)
- playerctl (media control)
- nm-applet (NetworkManager systray)
- polkit-gnome (authentication dialogs)

## System Services

- **NetworkManager**: Network management (nm-applet in systray)
- **XDG Portal**: hyprland + gtk portals for screen sharing, file pickers
- **Polkit**: GUI authentication agent (polkit-gnome)
- **PipeWire**: Audio (with WirePlumber)

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
- Home Manager version mismatch warning is suppressed (`home.enableNixpkgsReleaseCheck = false`) - expected when using NixOS unstable with Home Manager master
- hyprlock may show black screen in VM due to DRM buffer issues - works on real hardware
