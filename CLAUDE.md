# NixOS Hyprland Configuration

Gjermund's NixOS configuration with Hyprland as the window manager. Supports multiple machines via Nix flakes.

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

## Hosts

| Host | GPU | Monitor | Notes |
|------|-----|---------|-------|
| `desktop` | RTX 5070 Ti (standalone) | 5120x1440@240Hz | 4TB games drive, VRR enabled |
| `laptop` | Intel + NVIDIA (Prime) | 2560x1440@60Hz | Power management, offload mode |

## Directory Structure

```
nix-config/
├── flake.nix                 # Defines hosts and inputs
├── flake.lock                # Pinned dependencies
├── colors.nix                # Centralized Catppuccin Mocha color palette
├── modules/
│   ├── common.nix            # Shared system configuration
│   └── home.nix              # Shared Home Manager (per-host monitors)
├── hosts/
│   ├── desktop/
│   │   ├── default.nix       # Desktop-specific (games mount)
│   │   ├── nvidia.nix        # Standalone NVIDIA config
│   │   └── hardware-configuration.nix
│   └── laptop/
│       ├── default.nix       # Laptop-specific (power, lid)
│       ├── nvidia-prime.nix  # Intel + NVIDIA Prime
│       └── hardware-configuration.nix
├── theming.nix               # Qt/KDE theming (Catppuccin Mocha)
├── curseforge.nix            # CurseForge launcher (auto-updated)
├── curitz.nix                # Curitz CLI for Zino/Sikt
├── dolphin-fix.nix           # Dolphin "Open with" fix
└── configuration.nix         # Legacy (kept for reference)
```

## Rebuilding

**IMPORTANT**: Always use `nrs` to rebuild. This uses the flake-based configuration.

```bash
nrs                    # Rebuild current host, show diff, confirm, commit & push
```

Or manually:
```bash
sudo nixos-rebuild switch --flake .#desktop   # Desktop
sudo nixos-rebuild switch --flake .#laptop    # Laptop
```

The `nrs` script (`nixos-rebuild-flake`):
1. Auto-updates CurseForge version from Arch AUR
2. Runs `nh os switch --ask` with flake (builds, shows diff via nvd, confirms)
3. On success: commits changes with auto-generated message and pushes to git

**Automatic cleanup**: `programs.nh.clean` runs weekly, keeping 5 generations and anything from last 3 days.

## Setting Up a New Host

### Laptop Setup

1. Install NixOS on the laptop
2. Clone this repo: `git clone <repo-url> ~/nix-config`
3. Copy hardware config:
   ```bash
   cp /etc/nixos/hardware-configuration.nix ~/nix-config/hosts/laptop/
   ```
4. Find GPU bus IDs:
   ```bash
   lspci | grep -E "(VGA|3D)"
   # Example output:
   # 00:02.0 VGA compatible controller: Intel...  -> PCI:0:2:0
   # 01:00.0 3D controller: NVIDIA...             -> PCI:1:0:0
   ```
5. Update `hosts/laptop/nvidia-prime.nix` with your bus IDs
6. Rebuild: `sudo nixos-rebuild switch --flake .#laptop`

### NVIDIA Prime Modes (Laptop)

**Offload mode** (default): Intel by default, NVIDIA on demand
```bash
nvidia-offload <application>   # Run app on NVIDIA GPU
```

**Sync mode**: Always use NVIDIA (better performance, worse battery)
- Edit `hosts/laptop/nvidia-prime.nix`: comment `offload`, uncomment `sync.enable`

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

**Unified Catppuccin Mocha** theme across the entire system.

### Color Palette

Centralized in `colors.nix` with hex, RGB, and RGBA formats:
- **Base**: `#1e1e2e` (backgrounds)
- **Surface**: `#313244` (elevated surfaces)
- **Mauve**: `#cba6f7` (primary accent)
- **Pink**: `#f5c2e7` (secondary accent)
- **Blue**: `#89b4fa` (tertiary accent)
- **Text**: `#cdd6f4` (foreground)

### Themed Applications

| App | Theme Source | Notes |
|-----|--------------|-------|
| Qt/KDE apps | `theming.nix` | kdeglobals with Catppuccin colors |
| GTK apps | `home.nix` | Breeze-Dark + dark mode |
| Hyprland | `home.nix` | Uses `colors.nix` for borders/shadows |
| Neovim | `common.nix` | Catppuccin Mocha via nixvim |
| VSCode | `home.nix` | Catppuccin extension + icon theme |
| Alacritty | `home.nix` | Full Catppuccin palette |
| Fuzzel | `home.nix` | Catppuccin colors |
| Wlogout | `home.nix` | Catppuccin with colored hover states |
| Hyprlock | `home.nix` | Catppuccin colors |
| SDDM | `common.nix` | catppuccin-sddm theme |

### Other Settings

- **Qt Platform**: KDE (reads kdeglobals from `/etc/xdg/kdeglobals`)
- **Cursor**: Bibata-Modern-Ice (24px)
- **Icons**: Papirus-Dark
- **Font**: JetBrainsMono Nerd Font (system-wide)

## NVIDIA Troubleshooting

### Desktop (standalone NVIDIA)
- **Cursor issues**: Uncomment `cursor:no_hardware_cursors = true` in `modules/home.nix` (visuals.conf section)
- **Firefox crashes**: Comment out `GBM_BACKEND` in `hosts/desktop/nvidia.nix`
- **Discord/Zoom screenshare**: Comment out `__GLX_VENDOR_LIBRARY_NAME` in `hosts/desktop/nvidia.nix`

### Laptop (Prime hybrid)
- **Check which GPU is active**: `glxinfo | grep "OpenGL renderer"`
- **Force NVIDIA for an app**: `nvidia-offload <app>`
- **GPU monitoring**: `nvtop` or `intel_gpu_top`
- **Finegrained power issues**: Disable `powerManagement.finegrained` in `hosts/laptop/nvidia-prime.nix`

## Dolphin Overlay (dolphin-fix.nix)

Fixes "Open with" menu outside KDE by wrapping Dolphin to set `XDG_CONFIG_DIRS` and run `kbuildsycoca6`. Uses Qt5 kservice for menu path + Qt6 kservice for binary.

## Automations

- **Proton-GE auto-update**: Systemd user timer runs `protonup` 5 minutes after login and weekly. Check status with `systemctl --user status protonup.timer`
- **CurseForge auto-update**: The `nrs` script checks AUR for new versions before each rebuild
- **Garbage collection**: `nh clean` runs weekly, keeps 5 generations and last 3 days

## Notes

- Hardware configs are now in `hosts/<hostname>/hardware-configuration.nix` (tracked in git for flakes)
- SSH askpass: Seahorse with `SSH_ASKPASS_REQUIRE=prefer`
- 1Password browser integration requires `/etc/1password/custom_allowed_browsers`
- Home Manager version warning suppressed (expected with unstable + HM master)
- Bluetooth enabled via `hardware.bluetooth.enable` and blueman
- Flake inputs are pinned in `flake.lock` - run `nix flake update` to update dependencies
