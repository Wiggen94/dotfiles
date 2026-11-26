<p align="center">
  <img src="https://raw.githubusercontent.com/NixOS/nixos-artwork/master/logo/nix-snowflake-colours.svg" width="100" alt="NixOS logo">
</p>

<h1 align="center">NixOS Hyprland Configuration</h1>

<p align="center">
  <b>A multi-host NixOS flake: Hyprland on Omarchy, managed with Home Manager</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/NixOS-unstable-5277C3?style=for-the-badge&logo=nixos&logoColor=white">
  <img src="https://img.shields.io/badge/Hyprland-Wayland-00ADD8?style=for-the-badge&logo=wayland&logoColor=white">
  <img src="https://img.shields.io/badge/Omarchy-4-f5c2e7?style=for-the-badge">
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge">
  <a href="https://github.com/Wiggen94/dotfiles/actions/workflows/nix-cache.yml"><img src="https://img.shields.io/github/actions/workflow/status/Wiggen94/dotfiles/nix-cache.yml?style=for-the-badge&label=build" alt="Build status"></a>
</p>

---

## Features

### Desktop
- **Hyprland on [Omarchy](https://github.com/mrosseel/omarchy-nix)** — Omarchy's Quickshell-based shell provides the bar, menus, notifications, lock screen, idle handling and polkit dialog
- **26 themes** — switched live with `Ctrl+Super+Tab`; Hyprland, Alacritty, Starship, GTK icons and the SDDM greeter all follow
- **Own keybindings** — this config's bindings replace Omarchy's (see below)
- **Per-host effects** — full blur/shadows and the animated gradient border on the desktop GPU, a lighter profile on the laptops' integrated graphics
- **Gaming mode** — `Super+G` turns off blur, animations, gaps and transparency, then restores *this host's* settings

### Productivity
- **Dropdown terminal** (`Super+Y`) and **btop** (`Super+Shift+Y`) scratchpads
- **Clipboard history** (`Super+V`), **screenshots** with annotate/OCR (`Super+P`)
- **Taskwarrior** synced across all hosts, with a 09:00 due-task reminder
- **Screen mirroring** for meeting rooms (`Super+M`)

### Development
- **Neovim** via nixvim — LazyVim-like, with LSP, Treesitter and Telescope
- **Claude Code** routed through a self-hosted 9Router, plus a separate work-account instance (`wclaude`)
- **MCP servers** declared in Nix for both Claude Code instances (codegraph, Chrome DevTools, mcp-nixos, GitHub, web search)
- **Modern CLI** — eza, bat, fd, ripgrep, zoxide, atuin, yazi
- **devenv** and **comma** (`, <package>` runs anything from nixpkgs without installing it)

### Gaming
- **Steam** with Gamescope, **Proton-GE** auto-updated weekly
- **Lutris**, **RetroArch** (N64 cores), **CurseForge** (auto-bumped from the AUR on every rebuild)
- **Waydroid** with NVIDIA acceleration (desktop only)

---

## Hosts

| Host | GPU | Monitor | Notes |
|------|-----|---------|-------|
| `desktop` | RTX 5070 Ti | 5120x1440@240Hz | VRR, Windows VM with iGPU passthrough, Waydroid |
| `laptop` | Intel + NVIDIA Prime | 2560x1440@60Hz | Power management, offload mode |
| `sikt` | Intel graphics | External monitors | Work laptop, docks to two externals |

---

## Installation

### Prerequisites
- NixOS with flakes enabled
- An age key at `~/.ssh/age-key.txt` whose public key is listed in `.sops.yaml`
  (secrets are decrypted at activation; see "Secrets" in [CLAUDE.md](CLAUDE.md))
- For `laptop`-style hosts: the GPU bus IDs in `hosts/<hostname>/nvidia-prime.nix`

### Existing host (`desktop`, `laptop` or `sikt`)

```bash
git clone https://github.com/Wiggen94/dotfiles.git ~/nix-config
cd ~/nix-config
sudo nixos-rebuild switch --flake .#desktop
```

### New host

1. Copy its hardware config into the repo:
   ```bash
   mkdir -p hosts/<hostname>
   cp /etc/nixos/hardware-configuration.nix hosts/<hostname>/
   ```
2. Add a `hostConfig` entry (monitor, scale, cursor size) in `modules/home/_common.nix`.
3. Add the host to `flake.nix`, using `hosts/laptop/default.nix` as a template.
4. Build it: `sudo nixos-rebuild switch --flake .#<hostname>`

The full checklist, scaling guidance and NVIDIA bus-ID steps are in [CLAUDE.md](CLAUDE.md).

---

## Usage

### Rebuilding

```bash
nrs          # Rebuild, show the diff, confirm, then commit and push
nrs --boot   # Same, but activate only on the next reboot
nfu          # Update all flake inputs (nix flake update)
```

`nrs` asks for confirmation, so it needs an interactive terminal: run it
yourself, not from a script or agent.

### Everyday commands

```bash
sysinfo          # System information dashboard
keybinds         # Show all key bindings
fetch            # Quick system info (fastfetch)
shot <cmd>       # Render a command and its output to PNG
, <package>      # Run any nixpkgs package without installing it
```

Aliases: `ls`/`ll`/`la`/`lt` (eza), `cat` (bat), `cd` (zoxide), `find` (fd),
`grep` (ripgrep), `y` (yazi), `v` (nvim), `g`/`gs`/`gc`/`gp` (git).

---

## Key Bindings

### Applications
| Key | Action |
|-----|--------|
| `Super+T` | Terminal (Alacritty) |
| `Super+B` | Browser (Helium) |
| `Super+E` | File manager (Nautilus) |
| `Super+A` / `Super+Space` | Omarchy menu / app launcher |
| `Super+C` | Calculator |
| `Super+O` | Obsidian |
| `Super+Y` | Dropdown terminal |
| `Super+Shift+Y` | System monitor (btop) |

### Windows
| Key | Action |
|-----|--------|
| `Super+Q` | Close window |
| `Super+F` | Fullscreen |
| `Super+W` | Toggle floating |
| `Super+J` | Toggle split direction |
| `Super+Tab` / `Super+Shift+Tab` | Cycle windows |
| `Super+Arrows` | Move focus |
| `Super+Shift+Arrows` | Resize window |
| `Super+Ctrl+Arrows` | Move window |

### Workspaces
| Key | Action |
|-----|--------|
| `Super+1-9` | Switch workspace |
| `Super+Shift+1-9` | Move window to workspace |
| `Super+S` | Scratchpad workspace |
| `Super+Shift+S` | Move window to scratchpad |

### Utilities
| Key | Action |
|-----|--------|
| `Super+V` | Clipboard history |
| `Super+P` | Screenshot |
| `Super+N` | Notification history |
| `Super+L` | Power menu |
| `Super+K` | Keybindings reference |
| `Ctrl+Super+Tab` | Theme switcher |
| `Super+Shift+W` | Wallpaper picker |
| `Super+G` | Gaming mode |
| `Super+Shift+B` | Toggle bar |
| `Super+M` | Mirror laptop screen |
| `Super+Shift+Space` | Switch keyboard layout (Norwegian / Kvikk) |

Laptops also get touchpad gestures: 3 fingers to switch workspace or open the
scratchpad, 4 fingers to carry a window or toggle fullscreen.

---

## Directory Structure

```
nix-config/
├── flake.nix                 # Hosts and inputs
├── modules/
│   ├── common.nix            # Thin aggregator -> system/*.nix
│   ├── home.nix              # Thin aggregator -> home/*.nix
│   ├── omarchy.nix           # Omarchy system side (SDDM, zsh, portals, app trims)
│   ├── omarchy-hm.nix        # Omarchy Home Manager overrides (hm.lua, shadows)
│   ├── system/               # nix, boot, networking, hardware, desktop, shell,
│   │                         #   gaming, users, power, neovim, waydroid, packages
│   └── home/                 # _common.nix (per-host config + Hyprland Lua),
│                             #   base, desktop, programs, services, Claude/MCP
├── hosts/
│   ├── desktop/              # RTX 5070 Ti, VM passthrough
│   ├── laptop/               # Intel + NVIDIA Prime
│   └── sikt/                 # Work laptop, Intel only
├── pkgs/                     # Local packages (chrome-devtools-mcp, waydroid-nvidia, ...)
├── secrets/                  # sops-nix encrypted secrets
└── theming.nix               # Qt/KDE theming
```

---

## Development

### Testing a change

There are no unit tests; a change is tested by evaluating every host. Run this
before `nrs`:

```bash
for h in desktop laptop sikt; do
  nix eval --raw .#nixosConfigurations.$h.config.system.build.toplevel.drvPath
done
```

To inspect a single option, for example whether a host's Home Manager enables a program:

```bash
nix eval --json .#nixosConfigurations.desktop.config.home-manager.users.gjermund.programs.neovim.enable
```

### Formatting

`nix fmt` runs nixfmt, but the repo is not nixfmt-clean: format only the files
you touch, or it reflows unrelated code.

### CI

[`nix-cache.yml`](.github/workflows/nix-cache.yml) runs `nix flake update`
weekly and on every `flake.lock` push, builds the `desktop` system, and commits
the new lock only if the build succeeds. Built paths go to the `wiggen` Cachix
cache, so local rebuilds mostly download instead of compiling. Inputs pinned to
a revision in `flake.nix` (currently `omarchy-nix`) are not moved by it.

---

## Troubleshooting

### NVIDIA cursor issues
Add `cursor = { no_hardware_cursors = true }` to the Hyprland settings in
`modules/omarchy-hm.nix`.

### Browser crashes (desktop)
Comment out `GBM_BACKEND` in `hosts/desktop/nvidia.nix`.

### Screen sharing issues (desktop)
Comment out `__GLX_VENDOR_LIBRARY_NAME` in `hosts/desktop/nvidia.nix`.

More (Waydroid, monitors, 9Router, MCP servers): [CLAUDE.md](CLAUDE.md).

---

## Acknowledgments

- [Omarchy](https://omarchy.org/) and [omarchy-nix](https://github.com/mrosseel/omarchy-nix) — desktop shell and themes
- [Hyprland](https://hyprland.org/) — Wayland compositor
- [NixOS](https://nixos.org/) — the reproducible operating system

---

## License

[MIT](LICENSE). Packages and upstream code this config pulls in (nixpkgs,
omarchy-nix, the proprietary pieces such as libhoudini and the NVIDIA driver)
keep their own licenses.

---

<p align="center">
  <sub>Made with Nix flakes</sub>
</p>
