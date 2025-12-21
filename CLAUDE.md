# NixOS Hyprland Configuration

Gjermund's NixOS configuration with Hyprland as the window manager.

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
| `nvidia.nix` | NVIDIA RTX 5070 Ti configuration |
| `curseforge.nix` | CurseForge launcher (auto-updated by nrs script) |
| `curitz.nix` | Curitz CLI for Zino/Sikt work |
| `dolphin-fix.nix` | Dolphin overlay to fix "Open with" menu outside KDE |
| `p10k.zsh` | Powerlevel10k prompt configuration |

## Rebuilding

**IMPORTANT**: Always use `nrs` (alias for `nixos-rebuild-git`) to rebuild. Never use plain `nixos-rebuild switch`.

```bash
nrs                    # Rebuild, show diff, confirm, commit & push on success
```

The script:
1. Auto-updates CurseForge version from Arch AUR
2. Runs `nh os switch --ask` (builds, shows diff via nvd, confirms)
3. On success: commits changes with auto-generated message and pushes to git

**Automatic cleanup**: `programs.nh.clean` runs weekly, keeping 5 generations and anything from last 3 days.

## Networking

- **IPv6**: Disabled (`networking.enableIPv6 = false`) - prevents slow DNS when IPv6 routes unavailable
- **DNS**: DHCP-provided (AdGuard at 192.168.0.185)
- **WireGuard**: Enabled with firewall port 51820
- **KDE Connect**: Firewall ports 1714-1764 TCP/UDP open

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
| `Super+G` | Gaming mode toggle (disables blur/animations/gaps) |
| `Super+1-0` | Switch workspace |
| `Super+Shift+1-0` | Move window to workspace |

## Power Menu (wlogout)

`Super+L` opens menu. Keys: `l` lock, `e` logout, `u` suspend, `h` hibernate, `r` reboot, `s` shutdown

## Idle Behavior (hypridle)

- **5 min**: Screen off (DPMS)
- **10 min**: Lock screen (hyprlock)
- **Never**: Auto-suspend disabled

## Installed Applications

### Work
- Teams for Linux, Slack, Zoom, Discord
- Chromium (for Outlook PWA via `outlook` command)
- EduVPN client
- Curitz (`curitz-vpn` for split-tunnel access to Zino)

### Gaming
- Steam (with Proton)
- Lutris
- CurseForge
- Protonup-ng (Proton-GE management)
- MPV

### Development
- Claude Code
- VSCode
- Neovim (nixvim with LazyVim-like setup)
- Git

### Other
- 1Password (with CLI and Zen browser integration)
- Bambu Studio (3D printing)
- Gridcoin wallet

## Work: Curitz/Zino Access

For accessing Zino (hugin.uninett.no), use the split-tunnel VPN script:

```bash
curitz-vpn              # Connects EduVPN, routes only Zino traffic through VPN
curitz                  # Direct access (if on allowed network)
```

The `curitz-vpn` script:
1. Connects to EduVPN
2. Modifies routing to only send Zino traffic (158.38.0.175) through VPN
3. Keeps normal internet traffic on regular connection
4. Auto-disconnects VPN on exit

## Theming

- **Theme**: Catppuccin Mocha
- **Qt Platform**: KDE (reads kdeglobals from `/etc/xdg/kdeglobals`)
- **Cursor**: Bibata-Modern-Ice
- **Icons**: Papirus-Dark

## NVIDIA Troubleshooting

- **Cursor issues**: Uncomment `cursor:no_hardware_cursors = true` in `visuals.conf`
- **Firefox crashes**: Comment out `GBM_BACKEND` in `nvidia.nix`
- **Discord/Zoom screenshare**: Comment out `__GLX_VENDOR_LIBRARY_NAME` in `nvidia.nix`

## Dolphin Overlay (dolphin-fix.nix)

Fixes "Open with" menu outside KDE by wrapping Dolphin to set `XDG_CONFIG_DIRS` and run `kbuildsycoca6`. Uses Qt5 kservice for menu path + Qt6 kservice for binary.

## Automations

- **Proton-GE auto-update**: Systemd user timer runs `protonup` 5 minutes after login and weekly. Check status with `systemctl --user status protonup.timer`
- **CurseForge auto-update**: The `nrs` script checks AUR for new versions before each rebuild
- **Garbage collection**: `nh clean` runs weekly, keeps 5 generations and last 3 days

## Notes

- Hardware config: `/etc/nixos/hardware-configuration.nix` (not in git)
- SSH askpass: Seahorse with `SSH_ASKPASS_REQUIRE=prefer`
- 1Password browser integration requires `/etc/1password/custom_allowed_browsers`
- Home Manager version warning suppressed (expected with unstable + HM master)
- Bluetooth enabled via `hardware.bluetooth.enable` and blueman
