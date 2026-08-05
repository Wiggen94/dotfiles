# NixOS Hyprland Configuration

Gjermund's NixOS configuration with Hyprland as the window manager. Supports multiple machines via Nix flakes.

## System Overview

- **OS**: NixOS 25.11 (unstable)
- **WM**: Hyprland (Wayland compositor)
- **Shell**: Zsh with Oh-My-Zsh + Starship prompt
- **Terminal**: Alacritty
- **Bar**: Quickshell (QML-based)
- **App Launcher**: Vicinae
- **File Manager**: Dolphin (GUI), Yazi (terminal)
- **Browser**: Vivaldi
- **Editor**: Neovim (via nixvim) + VSCode
- **Dotfiles**: Managed by Home Manager

## Hosts

| Host | GPU | Monitor | Scale | Terminal | Notes |
|------|-----|---------|-------|----------|-------|
| `desktop` | RTX 5070 Ti (standalone) | 5120x1440@240Hz | 1.0 | Alacritty | VRR enabled, has WiFi |
| `laptop` | Intel + NVIDIA (Prime) | 2560x1440@60Hz | 1.33 | Alacritty | Power management, has WiFi |
| `sikt` | Intel (integrated) | External monitors | 1.0 | Alacritty | Work laptop (Sikt), has WiFi |

## Directory Structure

```
nix-config/
├── flake.nix                 # Defines hosts and inputs
├── flake.lock                # Pinned dependencies
├── colors.nix                # Backwards-compatible pointer to active theme
├── modules/
│   ├── common.nix            # Thin aggregator — imports system/*.nix
│   ├── home.nix              # Thin aggregator — imports home/*.nix
│   ├── system/               # System config split by domain
│   │   ├── nix.nix           # Nix settings, caches, overlays, nix-ld, comma
│   │   ├── boot.nix          # Bootloader, kernel, plymouth, zram, OOM, sysctl
│   │   ├── networking.nix    # NetworkManager, DNS, WireGuard, Tailscale, firewall, SSH
│   │   ├── hardware.nix      # Bluetooth, firmware, disk health, graphics, kvikk
│   │   ├── desktop.nix       # greetd, portal, keyring, file services, docker, 1Password
│   │   ├── shell.nix         # Zsh + aliases, locale/timezone
│   │   ├── gaming.nix        # Steam, gamescope, ananicy, Folding@home
│   │   ├── users.nix         # User account, sudo, polkit, ssh agent, env vars
│   │   ├── power.nix         # Laptop power mgmt + low-battery notifier (isLaptopHost)
│   │   ├── neovim.nix        # programs.nixvim (LazyVim-like)
│   │   ├── waydroid.nix      # Waydroid + NVIDIA acceleration (desktop only)
│   │   └── packages.nix      # environment.systemPackages + custom scripts (nrs, etc.)
│   └── home/                 # Home Manager config split by domain
│       ├── _common.nix       # Shared helpers: per-host config + theme generators (imported, not a module)
│       ├── base.nix          # Home identity, theme file generation, GTK, dconf
│       ├── hyprland.nix      # Hyprland config, quickshell, hypridle, pyprland
│       ├── desktop.nix       # Desktop entries, mimeapps, swaync
│       ├── programs.nix      # git, ssh, yazi, starship, btop, lazygit, vscode
│       └── services.nix      # Quickshell unit, protonup auto-update, TESS miner
├── hosts/
│   ├── desktop/
│   │   ├── default.nix       # Desktop-specific (games mount)
│   │   ├── nvidia.nix        # Standalone NVIDIA config
│   │   └── hardware-configuration.nix
│   ├── laptop/
│   │   ├── default.nix       # Laptop-specific (power, lid)
│   │   ├── nvidia-prime.nix  # Intel + NVIDIA Prime
│   │   └── hardware-configuration.nix
│   └── sikt/
│       ├── default.nix       # Work laptop-specific
│       ├── intel-graphics.nix # Intel-only graphics
│       └── hardware-configuration.nix
├── pkgs/                     # Local package definitions
│   └── waydroid-nvidia/      # Waydroid NVIDIA stack (host + guest + patched waydroid)
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
└── fresco.nix                # Modern BOINC manager GUI (Tauri)
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
5. **Configure host in `modules/home/_common.nix`** - add entry to `hostConfig`:
   ```nix
   hostConfig = {
     # ... existing hosts ...
     newhostname = {
       monitor = "monitor=,1920x1080@60,auto,1";  # resolution@refresh,position,scale
       primaryOutput = "eDP-1";                    # output name from hyprctl
       scale = 1.25;                               # 1.0 for large screens, 1.25-1.5 for laptops
       cursorSize = 30;                            # scale accordingly (24 for 1x, 30-36 for HiDPI)
       vrr = false;                                # variable refresh rate
       terminal = "alacritty";                     # alacritty works everywhere
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

- **IPv4 preferred over IPv6**: Via gai.conf - prevents slow DNS when IPv6 routes unavailable
- **DNS**: Static upstreams (192.168.0.185 AdGuard primary, 1.1.1.1 Cloudflare fallback) served via a local `systemd-resolved` cache on home hosts. The cache fixes slow Steam downloads (Steam's many parallel CDN lookups stalled without it). Work laptop (`sikt`) uses DHCP/`default` DNS, no resolved.
- **WireGuard**: Enabled with firewall port 51820
- **KDE Connect**: Firewall ports 1714-1764 TCP/UDP open
- **Reverse path**: Loose mode for WireGuard compatibility

## Key Bindings (Hyprland)

### Applications
| Keybind | Action |
|---------|--------|
| `Super+T` | Terminal (Alacritty) |
| `Super+B` | Browser (Vivaldi) |
| `Super+E` | File Manager (Dolphin) |
| `Super+A` | App Launcher (Vicinae) |
| `Super+C` | Calculator (qalculate-gtk) |
| `Super+Y` | Dropdown Terminal (pyprland scratchpad) |
| `Super+Shift+Y` | System Monitor scratchpad (btop) |
| `Super+O` | Obsidian |

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
| `Super+V` | Clipboard history (Vicinae) |
| `Super+P` | Screenshot (region select, copies to clipboard) |
| `Super+L` | Power menu (Quickshell) |
| `Super+N` | Toggle notification center (swaync) |
| `Ctrl+Super+Tab` | Theme switcher (12 themes) |
| `Super+Shift+W` | Wallpaper picker |
| `Super+G` | Gaming mode toggle (disables blur/animations/gaps) |
| `Super+Shift+B` | Toggle Quickshell bar visibility |

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
| `waydroid-nvidia-fetch-payload` | Download the Waydroid guest drivers from upstream CI (as your user) |
| `waydroid-nvidia-setup` | Provision Waydroid for the NVIDIA/Venus stack (root, after `waydroid init`) |
| `waydroid-nvidia-tweak` | Optional guest tweaks needing a live session (WebView GL, pointer, settings) |
| `waydroid-nvidia-probe` | Bounded Waydroid session + guest/host log capture for debugging |
| `sysinfo` | Beautiful system information dashboard |
| `keybinds` | Show all key bindings with colors |
| `fetch` | Quick system info (fastfetch) |
| `wallpaper-picker` | Interactive wallpaper selector |
| `wallpaper-set <path>` | Set wallpaper with transition |
| `wallpaper-random` | Random wallpaper with random transition |
| `y` | Launch Yazi file manager |
| `outlook` | Open Outlook PWA in Vivaldi |
| `curitz` | Access Zino (requires EduVPN connected) |

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
| `top` | htop |
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

## Power Menu (Quickshell)

`Super+L` opens the Quickshell power menu (`PowerMenu.qml`): lock, logout, suspend, hibernate, reboot, shutdown.

## Idle Behavior (hypridle)

- **10 min**: Lock screen (Quickshell lockscreen)
- **Never**: Screen off (DPMS disabled due to refresh rate issues)
- **Never**: Auto-suspend disabled

## Notifications (swaync)

SwayNotificationCenter provides desktop notifications with a control center.

- **Notification popups**: Bottom-right corner
- **Control center**: Top-center (below the Quickshell bar) - toggle with `Super+N` or click bell icon
- **Bar integration**: Bell icon in the Quickshell bar
- **Styling**: Full theme integration (changes with theme switcher)

Actions:
- **Left-click bell**: Toggle control center
- **Right-click bell**: Clear all notifications
- Config: `~/.config/swaync/config.json` and `style.css`

## Hyprland Visual Effects

Rich animations and effects configured in `modules/home/hyprland.nix`:

- **Animations**: Smooth bezier curves for window open/close/move, fade, workspace switching
- **Borders**: Animated 3-color gradient (mauve -> pink -> blue, 45deg)
- **Shadows**: Soft drop shadows with 3px vertical offset
- **Blur**: Enabled on windows, popups, and layer surfaces (Vicinae, Quickshell, notifications)
- **Rounding**: 12px corner radius
- **Opacity**: 98% active, 90% inactive windows

Gaming mode (`Super+G`) disables all effects for maximum performance.

## Installed Applications

### Work
- Teams for Linux
- Slack
- Zoom
- Discord
- Vivaldi (for Outlook PWA via `outlook` command)
- EduVPN client
- Curitz (access Zino via EduVPN)
- Obsidian
- OnlyOffice

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
- Node.js, Go, build tools (cmake, gcc, make)

### 3D Printing
- OrcaSlicer (wrapped with zink for NVIDIA Wayland)

### Distributed Computing & Crypto
- BOINC (client + TUI + Manager)
- Folding@home
- Gridcoin Research wallet
- Sparrow Bitcoin wallet
- Ledger Live Desktop

### Other
- 1Password (with CLI and Vivaldi browser integration)
- EDMarketConnector (with SQLAlchemy patch for plugins)
- KDE Connect

## Work: Curitz/Zino Access

For accessing Zino (hugin.uninett.no), connect EduVPN first, then run curitz:

```bash
curitz                  # Access Zino (requires EduVPN connected)
```

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
- Quickshell (bar, lockscreen, power menu — via `colors.json`)
- Alacritty (colors + vi mode + search + hints)
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
- **Cursor issues**: Add `cursor { no_hardware_cursors = true; }` to the Hyprland settings in `modules/home/hyprland.nix`
- **Browser crashes**: Comment out `GBM_BACKEND` in `hosts/desktop/nvidia.nix`
- **Discord/Zoom screenshare**: Comment out `__GLX_VENDOR_LIBRARY_NAME` in `hosts/desktop/nvidia.nix`

### Laptop (Prime hybrid)
- **Check which GPU is active**: `glxinfo | grep "OpenGL renderer"`
- **Force NVIDIA for an app**: `nvidia-offload <app>`
- **GPU monitoring**: `nvtop` or `intel_gpu_top`
- **Finegrained power issues**: Disable `powerManagement.finegrained` in `hosts/laptop/nvidia-prime.nix`

## Custom Scripts

Scripts defined via `writeShellScriptBin` in `modules/system/packages.nix`:

| Script | Purpose |
|--------|---------|
| `cliphist-paste` | Clipboard history picker with Vicinae |
| `screenshot` | Region select with save/discard notification |
| `notification-sound-daemon` | Plays sound on D-Bus notifications |
| `volume-up/down/mute` | Volume control with sound feedback |
| `theme-switcher` | Vicinae picker for 12 themes |
| `wallpaper-set/picker/random` | Wallpaper management |
| `system-info` | Beautiful dashboard with system stats |
| `keybinds` | Colorful keybinding reference |
| `gaming-mode-toggle` | Disable/enable all effects |
| `outlook` | Open Outlook PWA |
| `boinc-manager` | BOINC Manager wrapper |
| `nixos-rebuild-flake` | The `nrs` command |

## Overlays

| Package | Fix |
|---------|-----|
| Dolphin | "Open with" menu + KDE theming outside KDE |
| EDMarketConnector | SQLAlchemy for Pioneer/ExploData/BioScan plugins |
| Lutris | Prevents glib module conflicts with Proton |
| OrcaSlicer | Zink rendering for NVIDIA Wayland |
| FreeRDP | Audio parameter filtering to prevent SIGABRT crashes |

## Waydroid (Android apps, NVIDIA accelerated)

**Desktop only.** The stack requires the Wayland compositor to run on the NVIDIA
GPU, which rules out the hybrid laptop (upstream documents crashes) and the
Intel-only work laptop.

Android apps issue Vulkan into a guest Mesa **Venus** driver, which forwards over
a Unix socket (`/run/waydroid-venus/venus.sock`, seen inside the container as
`/dev/venus`) to a host **virglrenderer vtest** server that replays it on the
real GPU. ANGLE translates guest GLES to Vulkan on top of that.

Upstream: <https://github.com/Shiro836/waydroid-nvidia> (release `v0.1.2`).
**Not the `CinQwQeggs01` fork** — its releases omit the `guest-prebuilts`
tarball (ANGLE, hwcomposer, surfaceflinger) and its CI has shipped host binaries
with the vtest GPU allocator missing since 2026-07-31, which crash-loops the
session with `VTEST_CLIENT_ERROR_COMMAND_ID`.

Full design: `docs/superpowers/specs/2026-08-05-waydroid-nvidia-design.md`.

Config lives in `modules/system/waydroid.nix`; packages in `pkgs/waydroid-nvidia/`.

All binaries are hash-pinned `fetchurl`s from the upstream release — nothing is
vendored in git and there is no local payload directory.

**Uses the `waydroid-nftables` variant even though this config runs an iptables
firewall.** The kernel is built without `CONFIG_NETFILTER_XTABLES_LEGACY`, and
`waydroid-net.sh` prefers `iptables-legacy` whenever it is on `$PATH`, so the
iptables build fails container start with "Table does not exist". Don't "fix"
this back to `pkgs.waydroid`.

### One-time provisioning

```bash
sudo waydroid init -s GAPPS           # ~1 GB image download; -s VANILLA for no Play Store
sudo waydroid-nvidia-setup --refresh 240
waydroid session start                # or: waydroid show-full-ui
```

`waydroid-nvidia-setup` is idempotent — re-run it after any change to the guest
payload. It writes `/var/lib/waydroid/waydroid.cfg` (mutable state, deliberately
not declarative) and installs the guest drivers into `/var/lib/waydroid/nv/guest`,
where the patched container config generator bind-mounts them from.

**Host and guest must always come from the same release** — a mixed set
crash-loops with `VTEST_CLIENT_ERROR_COMMAND_DISPATCH` at 100% CPU. Bumping means
changing `version` and all three hashes in `pkgs/waydroid-nvidia/default.nix`
together.

The container and render server are managed declaratively:

```bash
systemctl status waydroid-container.service
systemctl --user status wd-venus.service    # must be up before a session starts
```

### ANGLE is mandatory, and must be upstream's build

This image's surfaceflinger has **no Vulkan RenderEngine** — it rejects
`debug.renderengine.backend=skiavk*` with "Unrecognized RenderEngineType" and
falls back to SkiaGL. GL is therefore the only compositor path, so ANGLE is what
decides whether compositing reaches the GPU. Without it, GL resolves to
**llvmpipe** (CPU compositing) and SurfaceFlinger then segfaults asking the vtest
gralloc for an `RGBA_FP16` buffer that upstream lists as unsupported.

The LineageOS `vendor.img` also ships its own ANGLE for both ABIs, and it *looks*
like it works — it loads and reports a correct renderer string. **Don't use it.**
It fails `eglCreateImageKHR` when the composer imports a gralloc buffer and then
null-derefs in `egl::Image::onDestroy`, killing the composer service and
SurfaceFlinger with it ~20-30 s in (window appears, then vanishes). Upstream's
ANGLE is bind-mounted over the image's copy.

### Optional guest tweaks

Ported from the fork's `waydroid-guest-customize.sh` (real upstream doesn't carry
it). Properties go through `waydroid-nvidia-setup`, so they survive
`waydroid upgrade`; guest state goes through `waydroid-nvidia-tweak`, which needs
a running session and drives it via `waydroid shell` (no adb, no open port).

```bash
# properties — re-run setup with the flags you want (omitting one clears it)
sudo waydroid-nvidia-setup --refresh 240 --density 200 --mouse-fix
sudo waydroid-nvidia-setup --refresh 240 --device-spoof     # + SPOOF_* overrides
sudo waydroid-nvidia-setup --refresh 240 --hwui-gl          # fallback, see below

# guest state — needs a running session
sudo waydroid-nvidia-tweak --webview-gl    # WebView off the Vulkan draw functor
sudo waydroid-nvidia-tweak --mouse         # pointer_speed = -4
sudo waydroid-nvidia-tweak --settings      # hide dev settings, allow sideloading
```

| Flag | Effect |
|------|--------|
| `--mouse-fix` | `cursor_on_subsurface=false` + `fake_touch=*` — makes click-and-drag register as touch (scroll/swipe) instead of mouse-drag (text selection, carousels ignoring drag). `fake_touch` is a wildcard-capable package list, not a boolean — `1` (as some scripts use) matches nothing |
| `--device-spoof` | ~47 props presenting a real phone (default HUAWEI P30 Pro) instead of `waydroid`/`unknown`, which apps like AnTuTu treat as an instant emulator tell. Override with `SPOOF_MODEL`/`SPOOF_BRAND`/`SPOOF_DEVICE`/`SPOOF_HARDWARE`/`SPOOF_PLATFORM`/`SPOOF_SOC`/`SPOOF_CHIPNAME`/`SPOOF_BOARD`/`SPOOF_API_LEVEL` — override them *together*, or setup warns that a mixed identity is itself a tell |
| `--hwui-gl` | Moves **all** app rendering from Vulkan (`skiavk`) to GL (`skiagl`). Still GPU-accelerated via ANGLE, but it gives up the direct Vulkan path — try `--webview-gl` first, which fixes WebView alone |
| `--multi-windows` | Android freeform mode. Note this gives windows *inside* the Waydroid surface, not separate host windows |

Magisk/Zygisk/Shamiko is **not** packaged — it needs the third-party
[WaydroidSU](https://github.com/mistrmochov/WaydroidSU) (`wsu`) plus a manually
downloaded Shamiko zip.

### ARM app support (libhoudini)

Not installed by default. Without it only x86/x86_64 apps run, which excludes a
large share of the Play Store. Enable with:

```bash
sudo waydroid-nvidia-setup --refresh 240 --arm-translation
```

That unpacks Intel's libhoudini into `/var/lib/waydroid/overlay/system` (which
the container overlays onto the guest's `/system`) and sets the abilist +
native-bridge properties. Omitting the flag on a later run removes both again.
Verify in the guest — `armeabi-v7a` and `arm64-v8a` should appear:

```bash
sudo waydroid shell getprop ro.product.cpu.abilist
```

Notes:
- **Proprietary Intel code**, hash-pinned (`fetchurl` + verified MD5) from the
  same archive `casualsnek/waydroid_script` uses, so no runtime downloader is
  involved. It is the Android 13 build; the Android 11 archive is a different
  commit and wrong for this image.
- Translated ARM32 apps land on the 32-bit Venus driver and 32-bit ANGLE this
  stack already installs, so they stay GPU-accelerated. If an ARM app reports
  `llvmpipe`/`Lavapipe`, the 32-bit payload is what to check.
- Needs `CONFIG_BINFMT_MISC` on the host (present) — houdini registers the four
  ARM ELF handlers via `/proc/sys/fs/binfmt_misc`.
- On AMD hosts `libndk_translation` is the equivalent; this is the Intel path.

### Debugging a session

A crash-looping guest saturates the CPU and can make the desktop unresponsive,
so don't debug with a bare `waydroid session start`. Use the bounded probe — it
takes the sudo prompt up front (`waydroid logcat` needs root), hard-stops via a
systemd `RuntimeMaxSec` backstop, and writes logs to `/tmp/waydroid-probe/`:

```bash
waydroid-nvidia-probe --seconds 60
```

`summary.txt` collects the lines that usually explain a failure, including
`sys.boot_completed` (the only reliable "Android finished booting" signal —
`waydroid status` showing RUNNING only means the *container* started).

Known failure signatures, both from binary mismatches:

| Symptom | Cause |
|---|---|
| `VTEST_CLIENT_ERROR_COMMAND_ID` | Host `virgl_test_server` lacks the vtest GPU allocator. Check with `strings virgl_test_server \| grep -c vtest_gpu_alloc` — must be non-zero. Upstream CI has shipped broken host builds. |
| `VTEST_CLIENT_ERROR_COMMAND_DISPATCH` | Host and guest binaries are from different upstream builds, or predate upstream's Venus fixes. |

## Automations

- **Proton-GE auto-update**: Systemd user timer runs `protonup` 5 minutes after login and weekly. Check status with `systemctl --user status protonup.timer`
- **CurseForge auto-update**: The `nrs` script checks AUR for new versions before each rebuild
- **Garbage collection**: `nh clean` runs weekly, keeps 5 generations and last 3 days
- **Low battery notification** (laptop only): Systemd user timer checks every 2 minutes, warns at 20%, critical at 10%

## Binary Caches

Configured in `modules/system/nix.nix` for faster rebuilds:
- `cache.nixos.org` - Official NixOS cache
- `nix-community.cachix.org` - Pre-built home-manager, nixvim, etc.
- `hyprland.cachix.org` - Pre-built Hyprland and dependencies

## Notes

- Hardware configs are in `hosts/<hostname>/hardware-configuration.nix` (tracked in git for flakes)
- Per-host config in `modules/home/_common.nix`: `primaryMonitor` (DP-1/eDP-1), NVIDIA env vars (desktop-only), VRR setting
- Zram swap: 15% of RAM (~5GB on 32GB system) for gaming overflow protection
- SSH askpass: Seahorse with `SSH_ASKPASS_REQUIRE=prefer`
- SSH signing: 1Password via `op-ssh-sign`
- 1Password browser integration requires `/etc/1password/custom_allowed_browsers`
- Home Manager version warning suppressed (expected with unstable + HM master)
- Bluetooth enabled via `hardware.bluetooth.enable` and blueman
- Flake inputs are pinned in `flake.lock` - run `nix flake update` to update dependencies
- nix-ld enabled for unpatched binaries (CUDA support for BOINC)
- Passwordless sudo for: nixos-rebuild
