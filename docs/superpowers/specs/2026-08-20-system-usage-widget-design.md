# CPU/RAM/GPU usage widgets on the omarchy bar — design

**Date:** 2026-08-20
**Hosts:** all (`desktop`, `laptop`, `sikt`) — one user-level widget, per-host GPU sources

## Goal

Show live CPU, RAM, and GPU utilization on the omarchy Quickshell bar as three
compact `[icon %]` segments — CPU, RAM, GPU — on the right side of the bar,
immediately left of the system tray, theming automatically with all 25 omarchy
themes (colors, fonts, spacing follow the active theme).

## Decisions (user-confirmed)

1. **Placement:** in the empty gap between the center section and the right
   cluster, immediately left of the tray.
2. **Format:** icons + percent text (three `WidgetButton` segments).
3. **GPU source:** `nvidia-smi` when available (desktop RTX 5070 Ti, laptop
   dGPU in Prime offload mode); fall back to `/sys/class/drm/*/device/
   gpu_busy_percent` when nvidia-smi is absent (sikt, Intel-only).

## Background: how the omarchy bar places widgets

Verified in the running shell source (`~/.local/share/omarchy/shell/plugins/bar/`):

- The bar's `right` section is a right-anchored `Row` — array index 0 renders
  at the section's **inner** edge (leftmost of the cluster), later indexes
  extend toward the screen edge.
- `BarModel.js` `pinTrayToInner()` **unconditionally unshifts** `omarchy.tray`
  to index 0 of the right section (Bar.qml applies it in `normalizeLayout`).
  The tray drawer reveals inward, and pinning keeps its reserved space next
  to the bar center. Consequence: nothing can render left of the tray within
  the right section — the tray always wins index 0.
- Plugins: `bar-widget` plugins are enabled by presence in `bar.layout.*`
  entries; a `bar`-kind plugin replaces the built-in bar via `config.bar.id`
  plus a `clonedFrom` manifest marker (shell routes built-in IPC targets to
  the clone). `~/.config/omarchy/plugins/<id>/` is scanned at startup and on
  `rescanPlugins`; plugin files and shell.json both hot-reload.
- Theming: widgets import `qs.Commons` (`Color`, `Style`) — `Color.bar.text`,
  `Color.urgent`, `Style.font.*`, `Style.space()` are all derived from the
  active theme (`~/.local/state/omarchy/current/theme/colors.toml` +
  `shell.toml`) and re-resolve on theme switch. `Ui/WidgetButton.qml` is the
  stock theming-ready text button (foreground color, urgent `active` state,
  tooltip, click handling) — same base the keyboard-layout widget uses.
- shell.json (`~/.config/omarchy/shell.json`) is **user-owned runtime state**:
  the repo never declares it; omarchy commands and the bar's drag-drop edit it.

## Architecture

Two pieces, both declared in the nix config (so all hosts get them), plus a
per-host runtime edit in shell.json.

### 1. Bar clone with tray pinning removed (`gjermund.bar`)

`omarchy plugin clone` is the documented way to customize built-in behavior;
we reproduce it declaratively so it stays version-locked to the `omarchy-nix`
flake input instead of a frozen imperative copy:

- Build in `modules/omarchy-hm.nix` (or a new module it imports):
  - `pkgs.runCommand`: copy `${inputs.omarchy-nix}/shell/plugins/bar/` (the
    whole dir: Bar.qml, BarModel.js, widgets/, README.md),
  - rewrite `manifest.json` id → `gjermund.bar`, name → `My Bar`, add
    `omarchy.clonedFrom: "omarchy.bar"` (mirror `omarchy-plugin-clone`'s
    `update_manifest`),
  - patch `BarModel.js`: `pinTrayToInner(entries, section)` becomes a
    pass-through (`return entries`). Only change in the entire bar.
- Ship as `home.file.".config/omarchy/plugins/gjermund.bar"` (recursive
  source). The shell discovers it on next scan/startup.

### 2. Usage widget (`local.system-usage`)

New user plugin, declared as `home.file` under
`.config/omarchy/plugins/local.system-usage/`:

- **manifest.json** — schemaVersion 1, id `local.system-usage`, kinds
  `["bar-widget"]`, `entryPoints.barWidget: "SystemUsage.qml"`,
  `barWidget.defaultSection: "right"`.
- **SystemUsage.qml** — `BarWidget` root (`moduleName:
  "local.system-usage"`), containing a `Row` (or `Column` when
  `bar.vertical`) of three `WidgetButton` segments, one per stat:

  | Segment | Icon (FontAwesome solid) | Text | Tooltip |
  |---------|--------------------------|------|---------|
  | CPU | microchip `` | busy % | CPU % |
  | RAM | memory `` | used % | used / total GB |
  | GPU | nf-md-gpu (verify codepoint in JetBrainsMono Nerd Font; fallback ``) | util % | util % + VRAM used/total + model (nvidia-smi) |

  - Icons/text in the theme's bar text color (`WidgetButton` default);
    segment flips to `active` (urgent color) above the `urgent` threshold
    setting (default 90%).
  - Click on a segment runs `pypr toggle btop` (btop scratchpad exists on all
    hosts via `modules/omarchy-hm.nix` pyprland config).
  - Data, all polled on a `Timer` at `settings.interval` ms (default 2000),
    `triggeredOnStart`:
    - **CPU:** `FileView` on `/proc/stat` — delta of busy
      (`total − idle − iowait`) over total between samples; first sample
      displays 0.
    - **RAM:** `FileView` on `/proc/meminfo` — `MemAvailable` vs `MemTotal`
      (zram-aware).
    - **GPU:** `Process nvidia-smi --query-gpu=utilization.gpu,memory.used,
      memory.total --format=csv,noheader,nounits`. Probe at startup; if the
      binary is missing/fails, switch to the sysfs fallback: read
      `/sys/class/drm/card*/device/gpu_busy_percent`, take the max.
  - Widget settings (all optional, read via `BarWidget.setting()`):
    `interval` (ms), `urgent` (percent threshold).

### 3. Runtime state (per host, imperative)

Edit `~/.config/omarchy/shell.json` on each host (hot-reloads on save):

- `bar.id: "gjermund.bar"` (switches the bar to the clone; missing/omarchy.bar
  stays built-in).
- Right section becomes (usage first, then the tray, then the cluster):
  `[local.system-usage, omarchy.tray, agents, bluetooth, network, audio,
  power, monitor]` — with pinning gone, the usage widget renders in the gap,
  immediately left of the tray. Tray drawer still opens inward (left), into
  the gap, pushing the usage widgets rather than overlapping them.

## Non-goals

- Temperatures, per-core breakdowns, network/disk usage — utilization
  percentages only (tooltips may show a bit of extra context).
- A full system-monitor panel/popup.
- Intel GPU display on the laptop (Prime offload) — dGPU via nvidia-smi only,
  per user choice; sikt's Intel GPU is covered by the sysfs fallback.
- Changing shell.json management to declarative.

## Verification

1. `omarchy plugin validate ~/.config/omarchy/plugins/local.system-usage`
   (manifest schema).
2. Rebuild via `nrs` (asks before running — it commits and pushes).
3. Shell picks up the clone + widget (plugin dir rescan; hot reload). If the
   bar doesn't switch: `omarchy-shell shell rescanPlugins`.
4. Screenshot: usage visible in the gap left of the tray, right of center.
5. `omarchy theme set tokyo-night` then back to catppuccin — colors/layout
   follow live (theme IPC pushes new colors to the shell).
6. Sanity: CPU/RAM percentages vs `btop`; GPU util vs `nvidia-smi` on the
   desktop.
7. The sysfs GPU fallback (sikt) cannot be exercised on the desktop — code
   review only; it's a single-file read.

## Maintenance

- The bar clone is a fork: upstream bar fixes require re-syncing (re-copy the
  new `Bar.qml`/`BarModel.js` from the bumped flake input and re-apply the
  2-line pinning patch). The declarative build makes this a version bump, not
  a manual re-clone.
- Plugin files live in the repo; editing the widget means editing the nix
  config (home-manager symlinks are store-backed).
