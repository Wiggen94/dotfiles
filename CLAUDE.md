# NixOS Hyprland Configuration

Gjermund's NixOS configuration with Hyprland as the window manager. Supports multiple machines via Nix flakes. **niri** (scrollable-tiling) is installed as an alternative session on `desktop` and `laptop` (not on `sikt`, which stays Hyprland-only) — pick it at the SDDM greeter. See "niri Session" below.

## System Overview

- **OS**: NixOS 25.11 (unstable)
- **WM**: Hyprland (Wayland compositor, omarchy-managed) — or **niri** (alternative session, same omarchy shell on top)
- **Shell**: Zsh with zplug (omarchy) + Starship prompt
- **Terminal**: Alacritty
- **Bar**: Omarchy shell (Quickshell-based)
- **App Launcher**: Omarchy menu (Super+A / Super+Space)
- **File Manager**: Nautilus (GUI), Yazi (terminal)
- **Browser**: Zen
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
├── modules/
│   ├── common.nix            # Thin aggregator — imports system/*.nix
│   ├── home.nix              # Thin aggregator — imports home/*.nix
│   ├── omarchy.nix           # Omarchy system module (SDDM, zplug, portal, app trims)
│   ├── omarchy-hm.nix        # Omarchy HM overrides (hm.lua, shadows, SDDM sync)
│   ├── system/               # System config split by domain
│   │   ├── nix.nix           # Nix settings, caches, overlays, nix-ld, comma
│   │   ├── boot.nix          # Bootloader, kernel, plymouth, tmpfs, sysctl (memory mgmt owned by omarchy)
│   │   ├── networking.nix    # NetworkManager, DNS, WireGuard, Tailscale, firewall, SSH
│   │   ├── hardware.nix      # Bluetooth, firmware, disk health, graphics, kvikk
│   │   ├── desktop.nix       # Portal, keyring, file services, docker, 1Password
│   │   ├── shell.nix         # Zsh aliases (via /etc/zshrc), locale/timezone
│   │   ├── gaming.nix        # Steam, gamescope, ananicy, Folding@home
│   │   ├── users.nix         # User account, sudo, polkit, ssh agent, env vars
│   │   ├── power.nix         # Laptop power mgmt + low-battery notifier (isLaptopHost)
│   │   ├── neovim.nix        # programs.nixvim (LazyVim-like)
│   │   ├── waydroid.nix      # Waydroid + NVIDIA acceleration (desktop only)
│   │   └── packages.nix      # environment.systemPackages + custom scripts (nrs, etc.)
│   └── home/                 # Home Manager config split by domain
│       ├── _common.nix       # Shared helpers: per-host config + Hyprland Lua fragments (imported, not a module)
│       ├── base.nix          # Home identity, dconf
│       ├── desktop.nix       # Desktop entries, mimeapps
│       ├── programs.nix      # git, ssh, yazi, starship, lazygit, vscode
│       └── services.nix      # protonup auto-update, TESS miner
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
├── theming.nix               # Qt/KDE theming (static Catppuccin)
├── curseforge.nix            # CurseForge launcher (auto-updated)
├── curitz.nix                # Curitz CLI for Zino/Sikt
├── fresco.nix                # Modern BOINC manager GUI (Tauri)
├── herdr-world.nix           # Herdr World — browser/mobile workspace for herdr (prebuilt bundle; device-pixel-snap patch on the terminal renderer — cell backgrounds, glyph pen, canvas size)
└── herdr-world-shim.js       # Host-rewriting bun shim for the herdr-world bridge behind Tailscale Serve
```

## Rebuilding

**IMPORTANT**: Always use `nrs` to rebuild. This uses the flake-based configuration.

**Claude never runs `nrs`/`nixos-rebuild` itself.** `nh os switch --ask`
requires an interactive TTY for its confirm prompt, which a non-interactive
tool call doesn't have (`nh` fails with "The input device is not a TTY").
The user always runs the rebuild themselves in their own terminal — after
making config changes, tell them what to run (usually just `nrs`) instead of
invoking it directly.

```bash
nrs                    # Rebuild current host, show diff, confirm, commit & push
nrs --boot             # Same, but only sets the boot generation (reboot to activate)
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

`--boot` is for changes that shouldn't hit the live system (e.g. when you want
to test a config by rebooting into it): it builds, shows the same diff, and
runs `nh os boot` instead of switch — the running system is untouched until
the next reboot.

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
- **DNS**: Static upstream 192.168.0.185 (AdGuard Home, **only** nameserver on desktop) served via a local `systemd-resolved` cache. 1.1.1.1 was dropped as fallback: AdGuard Home's rewrite responses (git.gjermund.xyz) lack the EDNS OPT record, so resolved degrades .185 below any full-EDNS0 competitor and stops querying it (split-horizon + ad-blocking die). Single server = no selection to lose; resolved retries .185 with backoff if it's down. The cache fixes slow Steam downloads. Work laptop (`sikt`) uses DHCP/`default` DNS, no resolved.
- **WireGuard**: Enabled with firewall port 51820 (UDP)
- **KDE Connect**: Firewall ports 1714-1764 TCP/UDP open
- **Other open TCP ports**: 3100/3200 (Curari), 3773 (LAN), 5173 (Cerebro dev), 5357 (my-world-dashboard), 8000 (Cerebro API), 9876 (Curari API) — `sikt` clears all of these
- **Tailscale Services** (`tailscale-services` oneshot in `networking.nix`, desktop only): `desktop` is tagged `tag:server` and advertises each entry of the `services` attrset as `svc:<name>` — its own VIP + MagicDNS name, `https://<name>` tailnet-wide, tailscaled terminating TLS and proxying to a loopback backend. Add a line to publish another; distinct VIPs mean no port clash. Currently just **herdr-world** → `127.0.0.1:8788`, the always-on `herdr-world-shim` user service (`herdr-world-shim.js`, a Host-rewriting bun proxy — the bridge 403s any non-loopback Host on `/api`+`/ws` and Serve forwards it verbatim). The shim proxies to the bridge on `:8787`, which only listens while you run `herdr-world` / `herdr-world-tailnet`. Nothing binds a routable address. Needs tailnet policy (`tagOwners` + one `autoApprovers.services` line per service; a `grants` entry too — `*` does not cover `svc:` targets) and MagicDNS HTTPS certs. Non-fatal: never blocks activation. `systemctl restart tailscale-services` after a policy change.
- **Reverse path**: Loose mode for WireGuard compatibility

## Key Bindings (Hyprland)

### Applications
| Keybind | Action |
|---------|--------|
| `Super+T` | Terminal (Alacritty) |
| `Super+B` | Browser (Zen) |
| `Super+E` | File Manager (Nautilus) |
| `Super+A` | App Launcher (omarchy menu) |
| `Super+C` | Calculator (qalculate-gtk) |
| `Super+Y` | Dropdown Terminal (pyprland scratchpad) |
| `Super+Shift+Y` | System Monitor scratchpad (btop) |
| `Super+O` | Obsidian |
| `Super+M` | Toggle mirroring laptop screen onto a second monitor (meeting rooms/projectors) |
| `Super+K` | Keybindings reference (omarchy menu) |
| `Super+Escape` | System menu (omarchy) |

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
| `Super+1-9` | Switch workspace |
| `Super+Shift+1-9` | Move window to workspace |
| `Super+S` | Special workspace (scratchpad) |
| `Super+Shift+S` | Move window to special workspace |
| `Super+Mouse Wheel` | Scroll through workspaces |

### Utilities
| Keybind | Action |
|---------|--------|
| `Super+V` | Clipboard history (omarchy) |
| `Super+P` | Screenshot (region select, copies to clipboard) |
| `Super+L` | Power menu (omarchy) |
| `Super+N` | Notification history (omarchy shell) |
| `Ctrl+Super+Tab` | Theme switcher (omarchy themes) |
| `Super+Shift+W` | Wallpaper picker (omarchy) |
| `Super+G` | Gaming mode toggle (disables blur/animations/gaps/transparency) |
| `Super+Shift+B` | Toggle omarchy bar |
| `Super+Space` | Omarchy menu |
| `Super+Ctrl+V` | Omarchy clipboard history |
| `Super+Shift+Space` | Switch keyboard layout (no/kvikk) |

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

## niri Session (alternative to Hyprland)

niri is a **scrollable-tiling** Wayland compositor offered on `desktop` and
`laptop`. Select "Niri" at the SDDM greeter. It is **not** built for `sikt` —
`modules/common.nix` / `modules/home.nix` drop `system/niri.nix` and
`home/niri.nix` from that host's imports, which also keeps niri-flake out of
that host's evaluation entirely. It reuses the omarchy quickshell shell (bar,
launcher, menu, notifications, lock, theming) — only Xwayland is added on top.

- **Modules**: `modules/system/niri.nix` (makes it installable, nixpkgs' `niri`
  package not niri-flake's — see the comment there) and `modules/home/niri.nix`
  (typed `programs.niri.settings`: outputs, keybinds, layout, window rules).
- **niri-flake** (`inputs.niri`) is kept only for its NixOS + home-manager
  config modules, not its niri package.
- Output resolution/refresh/scale/VRR source of truth is still `hostConfig` in
  `modules/home/_common.nix`; `modules/home/niri.nix` maps it to niri's
  connector-keyed `outputs` (desktop `DP-1`, laptop `eDP-1`; `sikt` auto).

### Mental model

- Each workspace is an **infinite horizontal strip of columns**. New window =
  new column to the right; the screen is a viewport scrolling along the strip.
- A **column** holds one or more **vertically stacked** windows.
- **Workspaces are a dynamic vertical stack** per monitor (always one empty at
  the bottom). `Super+1..9` still work; there is no special/scratchpad
  workspace, so `Super+S` = overview.
- niri won't scroll a fully-visible neighbouring column out of view — so
  "game left + browser right, both always visible" is just two columns whose
  widths sum to ≤ the screen (and the game in borderless-windowed, not true
  `Super+F` fullscreen).

### Keybinds — how they differ from Hyprland

Ported as close to 1:1 as niri's model allows. Same as Hyprland unless noted.

| Keybind | niri action |
|---------|-------------|
| `Super+←` / `Super+→` | Focus column left / right |
| `Super+↑` / `Super+↓` | Focus window up / down **within the column** (also switches tabs in a tabbed column) |
| `Super+Ctrl+Arrows` | Move column / move window within column |
| `Super+Shift+Arrows` | Resize column width / window height (repeats) |
| `Super+Tab` / `Super+Shift+Tab` | Next / previous window (flows across columns) |
| `Super+R` / `Super+Shift+R` | Cycle preset column width (⅓→½→⅔) / window height |
| `Super+M` | Maximize column (not screen-mirror — that's dropped under niri) |
| `Super+J` | Toggle **tabbed** column display (Hyprland's was togglesplit) |
| `Super+Ctrl+C` | Center column |
| `Super+S` | Overview (Hyprland's was special workspace) |
| `Super+G` | **Gaming mode** — see below |
| `Super+Shift+E` | Quit niri (no Hyprland equivalent) |
| `Super+Y`, `Super+Shift+Y` | Dropped (no pyprland / scratchpad) |
| `Super+K` | niri's own hotkey overlay (omarchy's keybind menu reads `hyprctl` and is empty here) |

Applications, media keys, and the omarchy-shell bridges (`Super+A`/`Space`,
`Super+L`/`Escape`, `Super+V`, `Super+N`, `Super+P`, `Ctrl+Super+Tab`, …) are
bound identically to the Hyprland session.

### Gaming mode (`Super+G`)

niri has no live `hyprctl keyword` equivalent, but it hot-reloads **`include`d**
config files. So:

- `modules/home/niri.nix` appends `include optional=true "~/.config/niri/gaming.kdl"`
  to the end of the generated config (via an `xdg.configFile.niri-config`
  override that still runs `niri validate` at build time).
- The `gaming-mode` script (`modules/system/packages.nix`) toggles that file
  in/out of existence. Present = `gaps 0`, `struts` 0, `border { off; }`,
  `focus-ring { off; }`, plus a `window-rule` clipping to a zero corner radius
  to square off the base `geometry-corner-radius 18` — `clip-to-geometry` must
  stay `true` because niri can't unset a bool in a later rule (payload is the
  `niriGamingKdl` `writeText`). niri
  live-reloads on the change — no relogin, notification confirms each way.
- Lighter than the Hyprland gaming mode by choice: no animation disable, no bar
  hiding. Add those to `niriGamingKdl` / the script if wanted.

### Known quirk: desktop boot resolution

On `desktop` the Samsung LS49AG95 super-ultrawide sometimes cold-boots under
niri at **3840x1080@60** instead of native 5120x1440@240 — niri logs
`configured mode 5120x1440@240 could not be found, falling back to preferred`
because the panel hasn't exposed its full mode list yet (DP/DSC negotiation
race). Config is correct; fix live without a restart:

```bash
niri msg output DP-1 mode 5120x1440@239.761
```

### omarchy bridges that needed niri-specific handling

The omarchy shell/menu is Hyprland-shaped; a few actions call `hyprctl` or
quickshell IPC that misbehaves under niri.

- **Logout** — `modules/omarchy-hm.nix` shadows `omarchy-system-logout` with a
  branch that runs `niri msg action quit --skip-confirmation` when
  `NIRI_SOCKET` is set (the niri session is `systemctl --user niri.service` via
  `niri-session`, so quitting niri ends it). Upstream's path (`uwsm stop` + an
  `omarchy-osd` call that **segfaults the quickshell IPC client** under niri +
  `omarchy-hyprland-window-close-all`) is kept verbatim for the Hyprland branch.
- If lock / other power-menu actions start crashing quickshell the same way,
  they need the same treatment.

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
| `y` | Launch Yazi file manager |
| `shot` | Render a terminal command + output to PNG (copies to clipboard) |
| `wclaude` | Claude Code with your work Anthropic account (own config dir, own login) |
| `dclaude` | Claude Code backed by DeepSeek (own config dir, vision via glm-vision proxy) |
| `orclaude` | Claude Code via OpenRouter + local anthropic-proxy (fp8+ provider routing) |
| `orclaude-status` | Show provider/model/cache-hit/cost of the latest orclaude turn |
| `win-vm` | Start the Windows 11 VM and attach Looking Glass (desktop) |
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

## Power Menu (omarchy)

`Super+L` opens the omarchy power menu: lock, logout, suspend, hibernate, reboot, shutdown.

## Idle Behavior

Idle-timeout locking is owned by the **omarchy-shell** idle service
(`~/.config/omarchy/shell.json` → `idle.screensaver` / `idle.lock`, seconds;
defaults 150 / 300). It respects Wayland idle inhibitors.

- **2.5 min**: Screensaver
- **5 min**: Lock screen (`omarchy-system-lock`)
- **Never**: Screen off (DPMS disabled due to refresh rate issues)
- **Never**: Auto-suspend disabled

`hypridle` (`modules/omarchy-hm.nix`) no longer has an idle-timeout listener —
it stays only for the sleep hooks (lock before suspend, DPMS restore after).

**Idle inhibition while media plays**: `wayland-pipewire-idle-inhibit` runs as
a user service (`modules/home/services.nix`) and holds a Wayland idle inhibitor
whenever any app plays audio through PipeWire — Zen only raises one for
fullscreen video, so this covers windowed playback. Manual override:
`omarchy toggle idle stay-awake`.

## Notifications (omarchy shell)

The omarchy shell is the notification daemon — popups bottom-right, with a
history panel (last 10 notifications, persisted across restarts).

- **Popups**: Bottom-right corner
- **History panel**: `Super+N` (or the bar's bell indicator)
- **Dismiss one**: `Super+comma`
- **DND**: Bar's DND indicator
- **Theming**: Follows the active omarchy theme

## Hyprland Visual Effects

Rich animations and effects configured in `modules/omarchy-hm.nix` (the
`hm.lua` layer, built from the shared fragments in `modules/home/_common.nix`):

- **Animations**: Smooth bezier curves for window open/close/move, fade, workspace switching
- **Borders**: Animated 3-color gradient (mauve -> pink -> blue, 45deg)
- **Shadows**: Soft drop shadows with 3px vertical offset
- **Blur**: Enabled on windows, popups, and layer surfaces (omarchy menu/shell, notifications)
- **Rounding**: 18px corner radius
- **Opacity**: 98% active, 90% inactive windows

Gaming mode (`Super+G`) disables all effects (incl. transparency) for maximum performance.

### Per-host cost profile

Effects are **not** uniform across hosts. `desktopTuning` / `igpuTuning` in
`modules/home/_common.nix` set blur size+passes, shadow range, and whether the
`borderangle` gradient animation loops; each `hostConfig` entry picks one via
`tuning`. `desktop` (RTX 5070 Ti) gets the full set; `laptop` and `sikt` get
the iGPU profile.

| | desktop | laptop / sikt |
|---|---|---|
| Blur | size 10, passes 4 | size 6, passes 2 |
| Shadow range | 45 | 15 |
| `borderangle` loop | on | **off** |

`borderangle` with `style = "loop"` is the one that matters: it repaints every
window border every frame for the life of the session, so an iGPU never idles
and the battery drains for a spinning gradient. The gradient border is still
there on the laptops, it just doesn't rotate; the `border` leaf still animates
colour on focus change.

`gaming-mode-toggle` generates its restore values from the same `tuning`
entry, so a `Super+G` round-trip no longer re-enables effects (or
`dim_inactive`, which `sikt` sets to false) that the host turns down.

## Laptop / Docking Behavior

Display handling is **omarchy's**, not this config's. `modules/home/_common.nix`
used to autostart its own `monitor-handler` and bind the lid to its own
`lid-handler`; both duplicated omarchy's own machinery and lost to it. They are
gone:

- **Monitor hotplug** — omarchy's autostart runs
  `omarchy-hyprland-monitor-watch` on the same socket2 events. It recovers a
  monitor that came up modeless (the DP/DSC cold-boot race), reconciles
  clamshell state on a 2s poll while docked, and takes flocks so overlapping
  events don't stack. The old `monitor-handler` raced it (two watchers both
  running `hyprctl reload` on `monitoradded`) and on `monitorremoved` moved
  *every* workspace onto an arbitrary survivor, collapsing the whole desktop
  onto one screen when one of two externals was unplugged.
- **Lid** — both lid edges call `omarchy-hyprland-monitor-clamshell`, which
  reads the internal panel's *configured* position and scale back out of
  `monitors.lua`. The old `lid-handler` hardcoded `position = "auto", scale = 1`,
  which on `sikt` discarded the `auto-left` placement on every lid open and
  reshuffled the desktop until omarchy's poll corrected it. The script decides
  from the actual lid state (`omarchy-hw-clamshell`), so both edges can call
  the same thing.
- **Suspend on lid close** is still logind's (`modules/system/power.nix`), and
  `sikt` keeps `HandleLidSwitchDocked = "ignore"`.

### Workspace pinning and per-panel gaps

`hostConfig` carries two more per-host keys, both applied as
`hl.workspace_rule` calls:

- `workspacePins` — workspace → monitor. Without it, which workspace lands on
  which screen after a dock cycle is whatever order the outputs came up in.
  `sikt` pins 1–5 to the Philips ultrawide, 6–8 to the Lenovo, 9 to `eDP-1`,
  keyed by EDID description (connector names flip between boots on that dock).
  **This split is the one genuinely personal knob — adjust it.**
- `internalPanel` — tighter `gaps_in`/`gaps_out`/`border_size` on the laptop
  panel only, via the `m[eDP-1]` selector. A docked external keeps the roomier
  desktop spacing on the same host, so `sikt` isn't choosing between a cramped
  ultrawide and a wasteful 14" panel.

### monitors.lua is now self-updating

`~/.config/hypr/monitors.lua` is seeded from `hostConfig` and then
user-owned. It used to be written **once** (`if [ ! -e ]`) and never again, so
every later fix to the monitor rules — including `sikt`'s whole `desc:`-keyed
block — never reached a machine that had already been set up. The activation
script in `modules/omarchy-hm.nix` now records what it last seeded
(`~/.local/state/nix-config/monitors.lua.seed`) and refreshes the file while it
still matches; once you (or omarchy's scale slider) edit it, activation says so
and leaves it alone rather than clobbering the edit.

If activation prints that the file differs and isn't ours to rewrite, it
predates seed tracking. To re-seed from `hostConfig`:

```bash
rm ~/.config/hypr/monitors.lua
sudo systemctl restart home-manager-gjermund.service   # NOT nrs — see below
hyprctl reload
```

**Restart the unit, don't `nrs`.** Deleting the file doesn't change the Nix
closure, so `nh os switch` builds the identical system path,
`switch-to-configuration` finds no changed unit to restart, and
`home-manager-gjermund.service` never re-runs — the activation script that
would recreate the file simply doesn't execute. Rebuilding only re-seeds if
some *other* config change happens to land in the same run. (Writing the file
by hand works too, but then no seed is recorded and activation will refuse to
refresh it from then on.)

### Touchpad and gestures (laptop hosts only)

Omarchy's `input.lua` already sets `clickfinger_behavior = true` and
`scroll_factor = 0.4`, and `hl.config` merges per key rather than replacing the
`touchpad` table, so those survive `hm.lua`. Added on top, only on hosts with a
lid: `tap_and_drag`, `drag_lock`, `drag_3fg` (three-finger window drag), and
swipe tuning (`workspace_swipe_distance` 300 → 200, `forever`,
`direction_lock`).

| Gesture | Action |
|---------|--------|
| 3 fingers horizontal | Switch workspace |
| 3 fingers vertical | Magic scratchpad (`Super+S`) |
| 4 fingers horizontal | Move window to workspace (`Super+Shift+n`) |
| 4 fingers pinch in | Fullscreen toggle (`Super+F`) |

## Installed Applications

### Work
- Teams for Linux
- Slack
- Zoom
- Discord
- Thunderbird
- Zen (default browser)
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
- Claude Code (Anthropic), plus `orclaude`/`dclaude` variants — see "AI Claude Code Setups" below
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
- 1Password (with CLI and Zen/Vivaldi browser integration)
- EDMarketConnector (with SQLAlchemy patch for plugins)
- KDE Connect
- Flatpak (runtime-installed, not declarative): Toontown Rewritten (self-updates via its own remote)

## Work: Curitz/Zino Access

For accessing Zino (hugin.uninett.no), connect EduVPN first, then run curitz:

```bash
curitz                  # Access Zino (requires EduVPN connected)
```

## AI Claude Code Setups

Three Claude Code instances, each with its own config dir so history/settings never mix:

| Command | Backend | Notes |
|---------|---------|-------|
| `claude` | Anthropic API (personal account) | Standard setup |
| `wclaude` | Anthropic API (work account) | Own config dir (`~/.claude-work`); run once and `/login` with the work account — fully isolated credentials, no proxy/API key involved |
| `dclaude` | DeepSeek direct | Text-only model; images are described by the local glm-vision proxy using a vision model on OpenRouter |
| `orclaude` | OpenRouter (DeepSeek V4-Flash) | Through the local anthropic-proxy: hard-excludes <fp8 quantization, session-frozen provider routing from live-observed latency/throughput |

- **anthropic-proxy** (`pkgs/anthropic-proxy`): 5k-line Rust fork of anthropic-proxy-rs with OpenRouter provider routing; runs as the persistent `anthropic-proxy-openrouter.service` (user). Pinned model slugs are bumped by hand (`ANTHROPIC_MODEL` in `modules/system/packages.nix`, `PROVIDER_TRACKING_MODEL` in `modules/home/services.nix`).
- **glm-vision** (`pkgs/glm-vision`): patched upstream — separate vision gateway (OpenRouter) + recursive rewrite of image blocks nested in `tool_result.content`.
- API keys are read from 1Password at launch and cached in each instance's own dir (`~/.claude-deepseek/key`, `~/.claude-openrouter/key`); never stored in this repo.
- `wclaude` needs no API key — it's a plain Anthropic OAuth login (`/login` inside the `~/.claude-work` instance), same as `claude` but a different account.

## Secrets (sops-nix)

Desktop only (`modules/secrets.nix`): `secrets/secrets.yaml` is sops-encrypted (age key `~/.ssh/age-key.txt`), decrypted at activation. Edit with `sops secrets/secrets.yaml` from the repo root. Currently only carries `~/.ritz.tcl` (the curitz Zino config).

## Windows VM (desktop)

`modules/system/vm-passthrough.nix`: the Intel iGPU (UHD 770) is passed through to a Windows 11 VM via VFIO, viewed with Looking Glass. `win-vm` starts the VM and attaches the client. Design: `docs/superpowers/specs/2026-08-11-windows-vm-gpu-passthrough-design.md`.

## Theming

### Theme System

Omarchy's theme system (25 themes), switched with `Ctrl+Super+Tab`
(omarchy-theme-menu). Default: **catppuccin**. Light-theme detection is
disabled on all hosts.

| Theme | Description |
|-------|-------------|
| **catppuccin** | Default - warm dark with mauve accent |
| **tokyo-night** | Inspired by Tokyo nights |
| **nord** | Arctic blue palette |
| **gruvbox** | Retro warm colors |
| **rose-pine** | Elegant dark rose |
| **everforest** | Comfortable green tones |
| **kanagawa** | Inspired by Katsushika Hokusai |
| ... | (25 total — `omarchy theme list`) |

### What Gets Themed

`omarchy-theme-set` regenerates config for:
- Hyprland (borders, shadows, background colors)
- Alacritty (colors)
- Starship (prompt colors)
- GTK (Adwaita:dark base; color-scheme + Yaru icon theme via dconf)
- SDDM greeter (recolored copy via `omarchy-sddm-sync`)

Active theme state: `~/.local/state/omarchy/current/theme/`

### Other Theming

| Component | Source |
|-----------|--------|
| Qt/KDE apps | `theming.nix` (static Catppuccin kdeglobals) |
| GTK apps | Adwaita:dark + per-theme dconf (omarchy) |
| SDDM | Omarchy theme (recolored per theme) |
| Plymouth | Catppuccin Mocha boot splash |
| Neovim | Catppuccin via nixvim |
| VSCode | Catppuccin extension |
| btop | omarchy's btop config + theme |
| lazygit | Static Catppuccin theme config |
| fzf | FZF_DEFAULT_OPTS colors |
| Cursor | Bibata-Modern-Ice (24px) |
| Icons | Yaru (follows the active theme) |

## NVIDIA Troubleshooting

### Desktop (standalone NVIDIA)
- **Cursor issues**: Add `cursor { no_hardware_cursors = true; }` to the Hyprland settings in `modules/omarchy-hm.nix` (the hm.lua port)
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
| `screenshot` | Region select with save/discard notification |
| `shot` | Terminal command + output rendered to PNG via charm-freeze |
| `notification-sound-daemon` | Plays sound on D-Bus notifications |
| `volume-up/down/mute` | Volume control with sound feedback |
| `system-info` | Beautiful dashboard with system stats |
| `keybinds` | Colorful keybinding reference |
| `gaming-mode-toggle` | Hyprland: disable/enable all effects (`Super+G`); restores **this host's** tuning, not the desktop's |
| `gaming-mode` | niri: toggle `~/.config/niri/gaming.kdl` include — gaps/struts/border/focus-ring/rounding off (`Super+G`) |
| `monitor-mirror-toggle` | Toggle mirroring the laptop panel onto a second monitor (`Super+M`); picks the non-primary external when docked, or pass an output name |
| `runelite-mouse4-daemon` | Mouse4 → Enter while RuneLite is focused (evsieve) |
| `herdr-world-tailnet` | Start the Herdr World bridge (`:8787`) and print its tailnet URL. Reachability comes from the always-on `herdr-world-shim` + `svc:herdr-world` Service (`https://herdr-world.<tailnet>.ts.net`); plain `herdr-world` works the same tailnet-wide. Every admitted browser gets terminal-equivalent access to the herdr session |
| `dclaude` | Claude Code backed by DeepSeek (own config dir) |
| `orclaude` | Claude Code via OpenRouter + local proxy |
| `orclaude-status` | Latest orclaude turn's provider/cost info |
| `outlook` | Open Outlook PWA |
| `boinc-manager` | BOINC Manager wrapper |
| `nixos-rebuild-flake` | The `nrs` command |

## Overlays

| Package | Fix |
|---------|-----|
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
  ARM ELF handlers via `/proc/sys/fs/binfmt_misc`. These registrations leak
  from the container onto the *host's* binfmt_misc table (LXC/kernel
  namespace-isolation bug, not ours — see
  [waydroid/waydroid#2221](https://github.com/waydroid/waydroid/issues/2221)),
  which used to freeze host-wide `execve()` until cleared. `waydroid-binfmt-guard`
  (`modules/system/waydroid.nix`) now clears leaked entries continuously from
  boot, and a separate `virgl_test_server` crash bug that this same leak
  triggered indirectly is patched in `pkgs/waydroid-nvidia/patches/virglrenderer/0005-*`.
  Full root-cause writeup: `docs/superpowers/specs/2026-08-05-waydroid-nvidia-design.md`
  ("ARM translation stability"). As of that fix, `--arm-translation` boots
  clean and `waydroid show-full-ui` works.
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
- Memory management (zram 100%, systemd-oomd, swappiness) is owned by omarchy's tuning module — see `modules/omarchy.nix`
- SSH askpass: Seahorse with `SSH_ASKPASS_REQUIRE=prefer`
- SSH signing: 1Password via `op-ssh-sign`
- 1Password browser integration requires `/etc/1password/custom_allowed_browsers`
- Home Manager version warning suppressed (expected with unstable + HM master)
- Bluetooth enabled via `hardware.bluetooth.enable` and blueman
- Flake inputs are pinned in `flake.lock` - run `nix flake update` to update dependencies
- nix-ld enabled for unpatched binaries (CUDA support for BOINC)
- Passwordless sudo for: nixos-rebuild
