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
| `dolphin-fix.nix` | Dolphin overlay to fix "Open with" menu outside KDE |
| `nvidia.nix` | NVIDIA GPU configuration (disabled by default, for production) |
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

**IMPORTANT**: Always use the `nixos-rebuild-git` script (or `nrs` alias) to rebuild. This script uses `nh` (nix-helper) for pretty output and diffs, then automatically commits/pushes changes to git on success. Never use plain `nixos-rebuild switch`.

```bash
nrs                    # Alias for nixos-rebuild-git
nixos-rebuild-git      # Full command
```

The script uses `nh os switch --ask` which:
1. Builds the new configuration
2. Shows a diff of package changes (via nvd)
3. Asks for confirmation before switching

## NH (Nix Helper)

`nh` provides a nicer CLI experience for Nix operations. Configured via `programs.nh` in `configuration.nix`.

```bash
nh os switch --ask -f '<nixpkgs/nixos>' -- -I nixos-config=...  # What nrs uses
nh search <package>    # Search for packages
nh clean all           # Manual garbage collection
nh clean all --dry     # Preview what would be cleaned
```

**Automatic cleanup**: `programs.nh.clean` runs weekly, keeping 5 generations and anything from the last 3 days.

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

## Switching to Production (NVIDIA GPU)

When moving from VM to production hardware with NVIDIA RTX 5070 Ti:

### 1. Enable NVIDIA driver

In `configuration.nix`, add `nvidia.nix` to imports:

```nix
imports = [
    /etc/nixos/hardware-configuration.nix
    nixvim.nixosModules.nixvim
    ./theming.nix
    ./nvidia.nix  # Add this line
    (import "${home-manager}/nixos")
];
```

### 2. Switch visual config

In `home.nix`, change the visuals source line from:

```
source = ~/.config/hypr/visuals-vm.conf
```

to:

```
source = ~/.config/hypr/visuals-production.conf
```

### 3. Rebuild

```bash
nrs
```

### NVIDIA Troubleshooting

If you experience issues after enabling NVIDIA:

- **Cursor issues**: Uncomment `cursor:no_hardware_cursors = true` in `visuals-production.conf`
- **Firefox crashes**: Comment out `GBM_BACKEND` in `nvidia.nix`
- **Discord/Zoom screenshare issues**: Comment out `__GLX_VENDOR_LIBRARY_NAME` in `nvidia.nix`
- **Flickering in XWayland games**: Ensure explicit sync is enabled (already configured in `visuals-production.conf`)

## Dolphin Overlay (dolphin-fix.nix)

Dolphin's "Open with" menu doesn't work outside KDE because it can't find installed applications. This is fixed with a custom overlay in `dolphin-fix.nix` (based on [rumboon/dolphin-overlay](https://github.com/rumboon/dolphin-overlay)).

**The problem**: Dolphin needs the Qt5 KService `applications.menu` file to discover installed apps, but NixOS puts it in a non-standard location.

**The solution**: The overlay wraps Dolphin to:
1. Set `XDG_CONFIG_DIRS` to include Qt5 KService's `etc/xdg` (for the applications.menu)
2. Also include `/etc/xdg` (to preserve kdeglobals theming from `theming.nix`)
3. Run `kbuildsycoca6` on startup to rebuild the service database

**Key detail**: Uses Qt5 `libsForQt5.kservice` for the menu file path, but Qt6 `kprev.kservice` for the `kbuildsycoca6` binary. This combination is required for both "Open with" and theming to work.

## Notes

- Hardware configuration is in `/etc/nixos/hardware-configuration.nix` (not tracked in git)
- This setup was initially created in a VM (spice-vdagent enabled)
- SSH askpass uses Seahorse with `SSH_ASKPASS_REQUIRE=prefer`
- 1Password browser integration requires entries in `/etc/1password/custom_allowed_browsers`
- Home Manager version mismatch warning is suppressed (`home.enableNixpkgsReleaseCheck = false`) - expected when using NixOS unstable with Home Manager master
- hyprlock may show black screen in VM due to DRM buffer issues - works on real hardware
