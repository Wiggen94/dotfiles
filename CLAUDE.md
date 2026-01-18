# NixOS Hyprland Configuration

Gjermund's NixOS configuration with Hyprland as the window manager. Supports multiple machines via Nix flakes.

## System Overview

- **OS**: NixOS 25.11 (unstable)
- **WM**: Hyprland (Wayland compositor)
- **Shell**: Zsh with Oh-My-Zsh + Starship prompt
- **Terminal**: Per-host (Alacritty on laptop, WezTerm on desktop)
- **Bar**: Waybar
- **App Launcher**: Fuzzel
- **File Manager**: Dolphin (GUI), Yazi (terminal)
- **Browser**: Zen Browser
- **Editor**: Neovim (via nixvim) + VSCode
- **Dotfiles**: Managed by Home Manager

## Hosts

| Host | GPU | Monitor | Scale | Terminal | Notes |
|------|-----|---------|-------|----------|-------|
| `desktop` | RTX 5070 Ti (standalone) | 5120x1440@240Hz | 1.0 | WezTerm | VRR enabled |
| `laptop` | Intel + NVIDIA (Prime) | 2560x1440@60Hz | 1.33 | Alacritty | Power management, WezTerm has GPU issues |

## Directory Structure

```
nix-config/
├── flake.nix                 # Defines hosts and inputs
├── flake.lock                # Pinned dependencies
├── colors.nix                # Backwards-compatible pointer to active theme
├── modules/
│   ├── common.nix            # Shared system configuration (~2200 lines)
│   └── home.nix              # Shared Home Manager (~1500 lines)
├── hosts/
│   ├── desktop/
│   │   ├── default.nix       # Desktop-specific (games mount)
│   │   ├── nvidia.nix        # Standalone NVIDIA config
│   │   └── hardware-configuration.nix
│   └── laptop/
│       ├── default.nix       # Laptop-specific (power, lid)
│       ├── nvidia-prime.nix  # Intel + NVIDIA Prime
│       └── hardware-configuration.nix
├── themes/                   # 12 color themes
│   ├── default.nix           # Theme registry
│   ├── catppuccin-mocha.nix  # Default theme (Mauve accent)
│   ├── catppuccin-frappe.nix
│   ├── nord.nix
│   ├── dracula.nix
│   ├── tokyo-night.nix
│   ├── gruvbox-dark.nix
│   ├── rose-pine.nix
│   ├── everforest.nix
│   ├── kanagawa.nix
│   ├── one-dark.nix
│   ├── solarized-dark.nix
│   └── monokai.nix
├── theming.nix               # Qt/KDE theming
├── curseforge.nix            # CurseForge launcher (auto-updated)
├── curitz.nix                # Curitz CLI for Zino/Sikt
└── dolphin-fix.nix           # Dolphin "Open with" fix
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

## Comma - Run Any Program Instantly

Run any program from nixpkgs without installing it:

```bash
, cowsay "hello"       # Runs cowsay without installing
, ncdu /home           # Disk usage analyzer
, python311 script.py  # Specific Python version
```

Also replaces "command not found" - if you type a command that doesn't exist, it tells you which package provides it.

## Setting Up a New Host

### Quick Setup Checklist

1. **Install NixOS** on the new machine
2. **Clone this repo**: `git clone git@github.com:Wiggen94/dotfiles ~/nix-config`
3. **Copy hardware config**:
   ```bash
   mkdir -p ~/nix-config/hosts/<hostname>/
   cp /etc/nixos/hardware-configuration.nix ~/nix-config/hosts/<hostname>/
   ```
4. **Get monitor info** (run in a TTY or basic session):
   ```bash
   hyprctl monitors   # or wlr-randr
   # Note: resolution, refresh rate, output name (e.g., eDP-1, DP-1)
   ```
5. **Configure host in `modules/home.nix`** - add entry to `hostConfig`:
   ```nix
   hostConfig = {
     # ... existing hosts ...
     newhostname = {
       monitor = "monitor=,1920x1080@60,auto,1";  # resolution@refresh,position,scale
       primaryOutput = "eDP-1";                    # output name from hyprctl
       scale = 1.25;                               # 1.0 for large screens, 1.25-1.5 for laptops
       cursorSize = 30;                            # scale accordingly (24 for 1x, 30-36 for HiDPI)
       vrr = false;                                # variable refresh rate
       terminal = "alacritty";                     # alacritty works everywhere, wezterm may have GPU issues
     };
   };
   ```
6. **Create host directory** with `default.nix` (copy from laptop/desktop as template)
7. **Add to `flake.nix`** if needed
8. **First rebuild**: `sudo nixos-rebuild switch --flake .#<hostname>`
9. **Post-install**:
   - Enable SSH agent in 1Password: Settings → Developer → "Use the SSH agent"
   - Set git remote to SSH: `git remote set-url origin git@github.com:Wiggen94/dotfiles.git`

### Scaling Guidelines

| Screen Size | Resolution | Recommended Scale | Cursor Size |
|-------------|------------|-------------------|-------------|
| 32"+ desktop | 5120x1440 | 1.0 | 24 |
| 27" desktop | 2560x1440 | 1.0-1.1 | 24 |
| 15" laptop | 2560x1440 | 1.25-1.5 | 30-36 |
| 14" laptop | 1920x1080 | 1.0-1.1 | 24 |

### Terminal Notes

- **Alacritty**: Works reliably on all GPUs, recommended default
- **WezTerm**: Better features (tabs, splits) but may show black screen on some Intel/NVIDIA combos

### Laptop-Specific Setup

1. Find GPU bus IDs:
   ```bash
   lspci | grep -E "(VGA|3D)"
   # Example output:
   # 00:02.0 VGA compatible controller: Intel...  -> PCI:0:2:0
   # 01:00.0 3D controller: NVIDIA...             -> PCI:1:0:0
   ```
2. Update `hosts/<hostname>/nvidia-prime.nix` with your bus IDs

### NVIDIA Prime Modes (Laptop)

**Offload mode** (default): Intel by default, NVIDIA on demand
```bash
nvidia-offload <application>   # Run app on NVIDIA GPU
```

**Sync mode**: Always use NVIDIA (better performance, worse battery)
- Edit `hosts/laptop/nvidia-prime.nix`: comment `offload`, uncomment `sync.enable`

## Networking

- **IPv6**: Disabled at kernel level - prevents slow DNS when IPv6 routes unavailable
- **DNS**: Static - 192.168.0.185 (AdGuard primary), 1.1.1.1 (Cloudflare fallback)
- **WireGuard**: Enabled with firewall port 51820
- **KDE Connect**: Firewall ports 1714-1764 TCP/UDP open
- **Reverse path**: Loose mode for WireGuard compatibility

## Key Bindings (Hyprland)

### Applications
| Keybind | Action |
|---------|--------|
| `Super+T` | Terminal (Alacritty) |
| `Super+B` | Browser (Zen) |
| `Super+E` | File Manager (Dolphin) |
| `Super+R` / `Super+A` | App Launcher (Fuzzel) |
| `Super+C` | Calculator (qalculate-gtk) |
| `Super+Y` | Dropdown Terminal (pyprland scratchpad) |
| `Super+Shift+Y` | System Monitor scratchpad (btop) |

### Window Management
| Keybind | Action |
|---------|--------|
| `Super+Q` | Close window |
| `Super+F` | Fullscreen |
| `Super+W` | Toggle floating |
| `Super+J` | Toggle split direction |
| `Super+Tab` | Cycle to next window |
| `Super+Shift+Tab` | Cycle to previous window |
| `Super+Arrows` | Move focus |
| `Super+Shift+Arrows` | Resize focused window |
| `Super+Ctrl+Arrows` | Move window in direction |
| `Super+Mouse1 Drag` | Move window |
| `Super+Mouse2 Drag` | Resize window |

### Workspaces
| Keybind | Action |
|---------|--------|
| `Super+1-6` | Switch workspace |
| `Super+Shift+1-6` | Move window to workspace |
| `Super+S` | Special workspace (scratchpad) |
| `Super+Shift+S` | Move window to special workspace |
| `Super+Mouse Wheel` | Scroll through workspaces |

### Utilities
| Keybind | Action |
|---------|--------|
| `Super+V` | Clipboard history |
| `Super+P` | Screenshot (region select, copies to clipboard) |
| `Super+L` | Power menu (wlogout) |
| `Super+N` | Toggle notification center (swaync) |
| `Ctrl+Super+Tab` | Theme switcher (12 themes) |
| `Super+Shift+W` | Wallpaper picker |
| `Super+G` | Gaming mode toggle (disables blur/animations/gaps) |
| `Super+Shift+B` | Toggle Waybar visibility |

### Media Keys
| Keybind | Action |
|---------|--------|
| `XF86AudioRaiseVolume` | Volume up (+5%) with sound feedback |
| `XF86AudioLowerVolume` | Volume down (-5%) with sound feedback |
| `XF86AudioMute` | Mute toggle with sound feedback |
| `XF86AudioMicMute` | Microphone mute toggle |
| `XF86AudioPlay/Pause` | Play/pause |
| `XF86AudioNext/Prev` | Next/previous track |
| `XF86MonBrightnessUp/Down` | Brightness control (laptop) |

## Custom Commands

| Command | Description |
|---------|-------------|
| `nrs` | Rebuild NixOS, commit, and push |
| `sysinfo` | Beautiful system information dashboard |
| `keybinds` | Show all key bindings with colors |
| `fetch` | Quick system info (fastfetch) |
| `wallpaper-picker` | Interactive wallpaper selector |
| `wallpaper-set <path>` | Set wallpaper with transition |
| `wallpaper-random` | Random wallpaper with random transition |
| `y` | Launch Yazi file manager |
| `outlook` | Open Outlook PWA in Chromium |
| `curitz-vpn` | Connect EduVPN with split-tunnel for Zino |

## Shell Aliases

### Modern Tool Replacements
| Alias | Replacement |
|-------|-------------|
| `ls` | eza with icons and git |
| `ll` | eza long list with git status |
| `la` | eza all files with git |
| `lt` | eza tree (2 levels) |
| `cat` | bat with syntax highlighting |
| `find` | fd |
| `grep` | ripgrep |
| `du` | dust |
| `df` | duf |
| `top` | btop |
| `ps` | procs |
| `cd` | zoxide (smart directory jumping) |
| `cdi` | zoxide interactive |

### Quick Shortcuts
| Alias | Command |
|-------|---------|
| `v` | nvim |
| `g` | git |
| `gs` | git status |
| `gc` | git commit |
| `gp` | git push |
| `gpl` | git pull |
| `gd` | git diff |
| `ga` | git add |
| `gl` | git log --oneline -10 |
| `dps` | docker ps |
| `nfu` | nix flake update |
| `ncg` | sudo nix-collect-garbage -d |
| `nixconf` | cd ~/nix-config && nvim . |
| `weather` | wttr.in/Trondheim |
| `myip` | Show public IP |
| `ports` | Show listening ports |

## Power Menu (wlogout)

`Super+L` opens menu. Keys: `l` lock, `e` logout, `u` suspend, `h` hibernate, `r` reboot, `s` shutdown

## Idle Behavior (hypridle)

- **10 min**: Lock screen (hyprlock)
- **Never**: Screen off (DPMS disabled due to refresh rate issues)
- **Never**: Auto-suspend disabled

## Notifications (swaync)

SwayNotificationCenter provides desktop notifications with a control center.

- **Notification popups**: Bottom-right corner
- **Control center**: Top-center (below Waybar) - toggle with `Super+N` or click bell icon
- **Waybar integration**: Custom module with bell icon in bar center
- **Styling**: Full theme integration (changes with theme switcher)

Actions:
- **Left-click bell**: Toggle control center
- **Right-click bell**: Clear all notifications
- Config: `~/.config/swaync/config.json` and `style.css`

## Hyprland Visual Effects

Rich animations and effects configured in `modules/home.nix`:

- **Animations**: Smooth bezier curves for window open/close/move, fade, workspace switching
- **Borders**: Animated 3-color gradient (mauve -> pink -> blue, 45deg)
- **Shadows**: Soft drop shadows with 6px vertical offset
- **Blur**: Enabled on windows, popups, and layer surfaces (Fuzzel, wlogout, Waybar)
- **Rounding**: 12px corner radius
- **Opacity**: 98% active, 92% inactive windows

Gaming mode (`Super+G`) disables all effects for maximum performance.

## Installed Applications

### Work
- Teams for Linux
- Slack
- Zoom
- Discord
- Chromium (for Outlook PWA via `outlook` command)
- EduVPN client
- Curitz (`curitz-vpn` for split-tunnel access to Zino)

### Gaming
- Steam (with Gamescope integration)
- Lutris (wrapped to prevent glib conflicts)
- CurseForge (auto-updated from AUR)
- Protonup-ng (Proton-GE management)
- RetroArch (with mupen64plus and parallel-n64 cores)
- MPV
- Wine/Winetricks

### Development
- Claude Code
- VSCode
- Neovim (nixvim with LazyVim-like setup)
- Git, lazygit, gh (GitHub CLI)
- kubectl
- devenv

### 3D Printing
- Bambu Studio
- OrcaSlicer (wrapped with zink for NVIDIA Wayland)

### Distributed Computing & Crypto
- BOINC (client + TUI + Manager)
- Folding@home
- Gridcoin Research wallet
- Sparrow Bitcoin wallet
- Ledger Live Desktop

### Other
- 1Password (with CLI and Zen browser integration)
- EDMarketConnector (with SQLAlchemy patch for plugins)
- KDE Connect

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

### Theme System

12 hot-swappable themes available via `Ctrl+Super+Tab`:

| Theme | Description |
|-------|-------------|
| **catppuccin-mocha** | Default - Warm dark with mauve accent |
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

### What Gets Themed

Each theme auto-generates config for:
- Hyprland (borders, shadows, colors)
- Waybar (full CSS)
- Alacritty (colors + vi mode + search + hints)
- WezTerm (full Lua config)
- Fuzzel (launcher colors)
- Wlogout (button colors and hover states)
- Starship (prompt colors)

Theme files stored in `~/.local/share/themes/<themeName>/`
Current theme tracked in `~/.config/current-theme`

### Color Palette Structure

Each theme in `themes/` provides:
- Hex colors: `#cba6f7`
- RGB: `203,166,247`
- Hyprland format: `rgb(cba6f7)`
- RGBA with transparency: `rgba(cba6f7ff)`
- Font definitions (monospace, UI)

### Other Theming

| Component | Source |
|-----------|--------|
| Qt/KDE apps | `theming.nix` (kdeglobals) |
| GTK apps | Catppuccin GTK package |
| SDDM | catppuccin-sddm theme |
| Plymouth | Catppuccin Mocha boot splash |
| Neovim | Catppuccin via nixvim |
| VSCode | Catppuccin extension |
| btop | Full theme file |
| lazygit | Theme config |
| fzf | FZF_DEFAULT_OPTS colors |
| Cursor | Bibata-Modern-Ice (24px) |
| Icons | Papirus-Dark |

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

## Custom Scripts

Scripts defined via `writeShellScriptBin` in home.nix:

| Script | Purpose |
|--------|---------|
| `cliphist-paste` | Clipboard history picker with Fuzzel |
| `screenshot` | Region select with save/discard notification |
| `notification-sound-daemon` | Plays sound on D-Bus notifications |
| `volume-up/down/mute` | Volume control with sound feedback |
| `theme-switcher` | Fuzzel picker for 12 themes |
| `wallpaper-set/picker/random` | Wallpaper management |
| `system-info` | Beautiful dashboard with system stats |
| `keybinds` | Colorful keybinding reference |
| `waybar-toggle` | Toggle Waybar visibility |
| `gaming-mode-toggle` | Disable/enable all effects |
| `outlook` | Open Outlook PWA |
| `curitz-vpn` | Split-tunnel VPN for Zino |
| `boinc-manager` | BOINC Manager wrapper |
| `nixos-rebuild-flake` | The `nrs` command |

## Overlays

| Package | Fix |
|---------|-----|
| Dolphin | "Open with" menu + KDE theming outside KDE |
| EDMarketConnector | SQLAlchemy for Pioneer/ExploData/BioScan plugins |
| Lutris | Prevents glib module conflicts with Proton |
| OrcaSlicer | Zink rendering for NVIDIA Wayland |

## Automations

- **Proton-GE auto-update**: Systemd user timer runs `protonup` 5 minutes after login and weekly. Check status with `systemctl --user status protonup.timer`
- **CurseForge auto-update**: The `nrs` script checks AUR for new versions before each rebuild
- **Garbage collection**: `nh clean` runs weekly, keeps 5 generations and last 3 days
- **Low battery notification** (laptop only): Systemd user timer checks every 2 minutes, warns at 20%, critical at 10%

## Binary Caches

Configured in `common.nix` for faster rebuilds:
- `cache.nixos.org` - Official NixOS cache
- `nix-community.cachix.org` - Pre-built home-manager, nixvim, etc.
- `hyprland.cachix.org` - Pre-built Hyprland and dependencies

## Notes

- Hardware configs are in `hosts/<hostname>/hardware-configuration.nix` (tracked in git for flakes)
- Per-host config in `home.nix`: `primaryMonitor` (DP-1/eDP-1), NVIDIA env vars (desktop-only), VRR setting
- Zram swap: 15% of RAM (~5GB on 32GB system) for gaming overflow protection
- SSH askpass: Seahorse with `SSH_ASKPASS_REQUIRE=prefer`
- SSH signing: 1Password via `op-ssh-sign`
- 1Password browser integration requires `/etc/1password/custom_allowed_browsers`
- Home Manager version warning suppressed (expected with unstable + HM master)
- Bluetooth enabled via `hardware.bluetooth.enable` and blueman
- Flake inputs are pinned in `flake.lock` - run `nix flake update` to update dependencies
- nix-ld enabled for unpatched binaries (CUDA support for BOINC)
- Passwordless sudo for: nixos-rebuild, IP routing (curitz-vpn split-tunnel)
