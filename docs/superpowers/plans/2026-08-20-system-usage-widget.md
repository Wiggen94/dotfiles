# System Usage Bar Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add CPU/RAM/GPU usage widgets to the omarchy bar, floating in the gap immediately left of the tray, theming with all 25 themes.

**Architecture:** Two home-manager-declared plugin directories under `~/.config/omarchy/plugins/` — `gjermund.bar` (a copy of the stock bar plugin with tray-pinning disabled) and `local.system-usage` (a new `bar-widget` plugin polling `/proc` and nvidia-smi) — plus runtime shell.json edits (`bar.id` + layout entry). All widget colors/fonts come from the `Color`/`Style` singletons, so theming is automatic.

**Tech Stack:** QML (Quickshell 0.3), Nix (home-manager `home.file`), nixfmt-rfc-style.

**Spec:** `docs/superpowers/specs/2026-08-20-system-usage-widget-design.md`

**No automated tests apply** (QML widget in a declarative config — no test harness). Verification is live-system: plugin validation, screenshots, theme switching, value comparison against `btop`/`nvidia-smi`.

**Verified facts the implementation relies on** (checked 2026-08-20 on `desktop`):
- The shell loads its source from `~/.local/share/omarchy/shell` (HM-linked from `${inputs.omarchy-nix}`); the flake input checkout contains `shell/plugins/bar/` (Bar.qml, BarModel.js, widgets/).
- `BarModel.js` `pinTrayToInner(entries, section)` unconditionally unshifts `omarchy.tray` to index 0 of the right section. The exact line to disable: `if (section === "right") result.unshift(trayEntry)` (line 38 of the stock BarModel.js).
- The bar renders its `right` section as a right-anchored `Row`: array index 0 is the innermost (leftmost) element; the tray is pinned there today, with the right cluster `[tray, agents, bluetooth, network, audio, power, monitor]` and a large empty gap between the center section and the cluster.
- Bar plugins replace the built-in via `config.bar.id` + manifest `omarchy.clonedFrom`; bar-widget plugins enable by presence in `bar.layout.*`. Plugin files are discovered from `~/.config/omarchy/plugins/*/manifest.json` at startup / `rescanPlugins`.
- Widget theming: `qs.Commons` `Color` (bar.text, urgent, accent, muted) + `Style` (font.caption, space, bar tokens) re-resolve on theme switch. `Ui/WidgetButton.qml` is the stock theming-ready text button (foreground color, `active`→urgent color, tooltip, `pressed` signal).
- The bar font resolves to **CaskaydiaMono Nerd Font 3.4.0** (`fc-match monospace`). Glyphs verified in its cmap: `` = fa-microchip (CPU), `` = fa-memory (RAM — NOT the stock FA codepoint f538!), `7` = md-video (GPU). No md-gpu glyph exists in this font.
- `nvidia-smi` works on desktop: `NVIDIA GeForce RTX 5070 Ti`.
- Quickshell `Process` has `started`/`exited(exitCode)`/`runningChanged` (no `failed` signal — a missing binary surfaces as a non-zero `exitCode`). `FileView` has `reload()` (used by `Color.qml`) and `onLoaded`.
- pyprland btop scratchpad exists on all hosts (`[scratchpads.btop]` in `modules/omarchy-hm.nix`); toggle command: `pypr toggle btop`.
- `modules/omarchy.nix` wires `./omarchy-hm.nix` into `home-manager.users.gjermund.imports` — new `home.file` entries go in `modules/omarchy-hm.nix`.
- The repo formatter is `nixfmt-rfc-style` (`nix fmt`).
- shell.json (`~/.config/omarchy/shell.json`) is user-owned runtime state — edited via `omarchy bar use` / `omarchy bar put`, not declared.

---

### Task 1: Add the widget plugin + bar clone to `modules/omarchy-hm.nix`

**Files:**
- Modify: `modules/omarchy-hm.nix` (append a new section near the end, before the closing `}` — after the mimeapps block)

- [ ] **Step 1: Add the system-usage widget files and bar-clone derivation to `modules/omarchy-hm.nix`**

Two edits to `modules/omarchy-hm.nix`:

**Edit A — the derivation goes in the `let` block** (a module body can only contain option definitions; derivations live in `let`, like `omarchySddmSync`). Insert after the `omarchyWebappLaunch` binding (just before the `in` at line ~277):

```nix
  # System usage bar widget + unpinned-tray bar clone (see
  # docs/superpowers/specs/2026-08-20-system-usage-widget-design.md). The
  # stock bar unconditionally pins the tray to the inner edge of the right
  # section (BarModel.js pinTrayToInner), so nothing can render left of it;
  # the clone keeps the tray where shell.json puts it, letting the usage
  # widget float in the gap immediately left of the tray. The clone is a
  # fork of the flake input's bar — when bumping omarchy-nix, this derivation
  # re-copies + re-patches automatically (only the sed line must keep
  # matching upstream's pinTrayToInner).
  omarchyBarClone = pkgs.runCommand "omarchy-bar-clone" { } ''
    cp -r ${inputs.omarchy-nix}/shell/plugins/bar/. $out/
    chmod -R u+w $out
    jq --arg id "gjermund.bar" --arg name "My Bar" --arg sourceId "omarchy.bar" '
      .id = $id |
      .name = $name |
      .omarchy = ((.omarchy // {}) + { clonedFrom: $sourceId }) |
      del(.omarchy.clonePaths)
    ' "$out/manifest.json" > "$out/manifest.json.tmp"
    mv "$out/manifest.json.tmp" "$out/manifest.json"
    sed -i 's|if (section === "right") result.unshift(trayEntry)|if (false) result.unshift(trayEntry)  // gjermund.bar: tray pinning disabled — shell.json order wins|' "$out/BarModel.js"
    grep -q "tray pinning disabled" "$out/BarModel.js" \
      || { echo "pinTrayToInner patch failed to apply" >&2; exit 1; }
  '';
```

**Edit B — the `home.file` entries go in the module body** (after the `xdg.mimeApps.defaultApplications = lib.mkMerge ...;` statement, before the final `}`), indented at the same level as the other `home.file` entries:

```nix
  home.file.".config/omarchy/plugins/gjermund.bar" = {
    source = omarchyBarClone;
    recursive = true;
  };

  home.file.".config/omarchy/plugins/local.system-usage/manifest.json".text = ''
    {
      "schemaVersion": 1,
      "id": "local.system-usage",
      "name": "System Usage",
      "version": "1.0.0",
      "author": "Gjermund",
      "description": "CPU, RAM and GPU utilization",
      "kinds": [ "bar-widget" ],
      "entryPoints": { "barWidget": "SystemUsage.qml" },
      "barWidget": {
        "displayName": "System Usage",
        "description": "CPU, RAM and GPU utilization",
        "category": "System",
        "defaultSection": "right",
        "allowMultiple": false
      }
    }
  '';

  home.file.".config/omarchy/plugins/local.system-usage/SystemUsage.qml".text = ''
    import QtQuick
    import Quickshell
    import Quickshell.Io
    import qs.Commons
    import qs.Ui

    BarWidget {
      id: root
      moduleName: "local.system-usage"

      readonly property int pollInterval: setting("interval", 2000)
      readonly property int urgentThreshold: setting("urgent", 90)

      property int cpuPercent: 0
      property var prevCpu: null
      property int ramPercent: 0
      property real ramUsedGb: 0
      property real ramTotalGb: 0
      property int gpuPercent: 0
      property string gpuModel: ""
      property string gpuVramText: ""
      property bool gpuUseSmi: true

      implicitWidth: layout.implicitWidth
      implicitHeight: layout.implicitHeight

      function refresh() {
        cpuFile.reload()
        memFile.reload()
        if (root.gpuUseSmi) {
          if (!gpuSmiProc.running) gpuSmiProc.running = true
        } else if (!gpuSysfsProc.running) {
          gpuSysfsProc.running = true
        }
      }

      // /proc/stat first line: cpu user nice system idle iowait irq softirq steal
      function onCpuRead(text) {
        var parts = String(text || "").split("\n")[0].trim().split(/\s+/)
        if (parts.length < 6 || parts[0] !== "cpu") return
        var busy = parseInt(parts[1], 10) + parseInt(parts[2], 10) + parseInt(parts[3], 10)
        var total = busy + parseInt(parts[4], 10) + parseInt(parts[5], 10)
        if (root.prevCpu && total > root.prevCpu.total) {
          var dTotal = total - root.prevCpu.total
          var dBusy = busy - root.prevCpu.busy
          root.cpuPercent = Math.max(0, Math.min(100, Math.round((dBusy * 100) / dTotal)))
        } else {
          root.cpuPercent = 0
        }
        root.prevCpu = { busy: busy, total: total }
      }

      // MemTotal/MemAvailable (zram-aware) — kB → GiB via 1048576
      function onMeminfoRead(text) {
        var total = 0
        var avail = 0
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
          var m = lines[i].match(/^(MemTotal|MemAvailable):\s+(\d+)/)
          if (!m) continue
          if (m[1] === "MemTotal") total = parseInt(m[2], 10)
          else avail = parseInt(m[2], 10)
        }
        if (!total) return
        var used = total - avail
        root.ramPercent = Math.round((used * 100) / total)
        root.ramUsedGb = used / 1048576
        root.ramTotalGb = total / 1048576
      }

      // nvidia-smi: "util%, memUsedMiB, memTotalMiB, name"
      function onSmiRead(text) {
        var line = String(text || "").split("\n")[0].trim()
        if (!line) return
        var parts = line.split(",")
        if (parts.length < 4) return
        var util = parseInt(parts[0].trim(), 10)
        var memUsed = parseFloat(parts[1].trim())
        var memTotal = parseFloat(parts[2].trim())
        root.gpuPercent = isFinite(util) ? Math.max(0, Math.min(100, util)) : 0
        root.gpuModel = parts[3].trim()
        if (isFinite(memUsed) && isFinite(memTotal) && memTotal > 0) {
          root.gpuVramText = Math.round(memUsed / 1024) + " / " + Math.round(memTotal / 1024) + " GiB"
        } else {
          root.gpuVramText = ""
        }
      }

      function onSmiFailed() {
        root.gpuUseSmi = false
        root.gpuModel = ""
        root.gpuVramText = ""
        refresh()
      }

      // Intel/AMD fallback (sikt): max gpu_busy_percent across cards
      function onSysfsRead(text) {
        var max = 0
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
          var n = parseInt(lines[i], 10)
          if (isFinite(n) && n > max) max = n
        }
        root.gpuPercent = Math.max(0, Math.min(100, max))
      }

      function openMonitor() {
        if (root.bar) root.bar.run("pypr toggle btop")
      }

      FileView {
        id: cpuFile
        path: "/proc/stat"
        printErrors: false
        onLoaded: root.onCpuRead(text())
      }

      FileView {
        id: memFile
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: root.onMeminfoRead(text())
      }

      Process {
        id: gpuSmiProc
        command: [ "nvidia-smi", "--query-gpu=utilization.gpu,memory.used,memory.total,name", "--format=csv,noheader,nounits" ]
        stdout: StdioCollector {
          waitForEnd: true
          onStreamFinished: root.onSmiRead(text)
        }
        onExited: function(exitCode) {
          if (exitCode !== 0) root.onSmiFailed()
        }
      }

      Process {
        id: gpuSysfsProc
        command: [ "sh", "-c", "cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null" ]
        stdout: StdioCollector {
          waitForEnd: true
          onStreamFinished: root.onSysfsRead(text)
        }
      }

      Timer {
        interval: root.pollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
      }

      Loader {
        id: layout
        sourceComponent: root.vertical ? verticalLayout : horizontalLayout
      }

      Component {
        id: horizontalLayout
        Row {
          spacing: Style.space(1)
          CpuButton { }
          RamButton { }
          GpuButton { }
        }
      }

      Component {
        id: verticalLayout
        Column {
          spacing: Style.space(1)
          CpuButton { }
          RamButton { }
          GpuButton { }
        }
      }

      component CpuButton: WidgetButton {
        bar: root.bar
        text: "\uf2db  " + root.cpuPercent + "%"
        fontSize: Style.font.caption
        horizontalMargin: 5
        tooltipText: "CPU " + root.cpuPercent + "%"
        active: root.cpuPercent >= root.urgentThreshold
        onPressed: root.openMonitor()
      }

      component RamButton: WidgetButton {
        bar: root.bar
        text: "\uefc5  " + root.ramPercent + "%"
        fontSize: Style.font.caption
        horizontalMargin: 5
        tooltipText: "RAM " + root.ramUsedGb.toFixed(1) + " / " + root.ramTotalGb.toFixed(0) + " GiB (" + root.ramPercent + "%)"
        active: root.ramPercent >= root.urgentThreshold
        onPressed: root.openMonitor()
      }

      component GpuButton: WidgetButton {
        bar: root.bar
        // md-video is U+F0567 — 5 hex digits, needs the ES6 \u{...} form
        // (Qt QJSEngine supports it). Fallback if it renders wrong: put the
        // literal PUA character in the string instead.
        text: "\u{f0567}  " + root.gpuPercent + "%"
        fontSize: Style.font.caption
        horizontalMargin: 5
        tooltipText: {
          var t = "GPU " + root.gpuPercent + "%"
          if (root.gpuModel) t += " · " + root.gpuModel
          if (root.gpuVramText) t += " · " + root.gpuVramText
          return t
        }
        active: root.gpuPercent >= root.urgentThreshold
        onPressed: root.openMonitor()
      }
    }
  '';
```

- [ ] **Step 2: Format and verify the nix syntax**

Run: `nix fmt modules/omarchy-hm.nix && nixos-rebuild build --flake .#desktop`
Expected: formatter changes nothing or only whitespace; the build succeeds (no nix evaluation errors). The build may take a few minutes on first run — if it errors, fix the reported line and re-run.

- [ ] **Step 3: Commit**

```bash
git add modules/omarchy-hm.nix
git commit -m "$(cat <<'EOF'
Add system usage bar widget + unpinned-tray bar clone

local.system-usage (CPU/RAM/GPU via /proc + nvidia-smi, sysfs fallback)
and gjermund.bar (tray pinning disabled) declared via home-manager so
all hosts get them.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Apply the running system (rebuild)

**Files:** none (build + activate)

- [ ] **Step 1: Switch to the new generation**

Run: `nrs` (rebuild, shows diff via nvd, asks for confirmation, commits any stragglers and pushes). The nrs commit message is auto-generated. If the user prefers, run `sudo nixos-rebuild switch --flake .#desktop` instead (no commit/push).

Expected: rebuild succeeds; home-manager links the two plugin directories under `~/.config/omarchy/plugins/`.

Verify with:
```bash
ls ~/.config/omarchy/plugins/gjermund.bar/         # Bar.qml, BarModel.js, widgets/, manifest.json
ls ~/.config/omarchy/plugins/local.system-usage/   # manifest.json, SystemUsage.qml
grep -c "tray pinning disabled" ~/.config/omarchy/plugins/gjermund.bar/BarModel.js   # → 1
jq -r .id ~/.config/omarchy/plugins/gjermund.bar/manifest.json                      # → gjermund.bar
jq -r .omarchy.clonedFrom ~/.config/omarchy/plugins/gjermund.bar/manifest.json      # → omarchy.bar
```

- [ ] **Step 2: Validate the widget manifest**

Run: `omarchy plugin validate ~/.config/omarchy/plugins/local.system-usage`
Expected: no schema errors (exit 0). If it reports errors, fix the manifest in `modules/omarchy-hm.nix`, `nix fmt`, re-run `nixos-rebuild build` + `nrs`.

---

### Task 3: Switch the bar to the clone and place the widget (runtime shell.json)

**Files:** `~/.config/omarchy/shell.json` (edited via omarchy CLI — user-owned runtime state, not committed)

- [ ] **Step 1: Discover the new plugins**

Run: `omarchy-shell shell rescanPlugins`
Expected: no output, exit 0. Verify both plugins are known:
```bash
omarchy plugin list | grep -E "gjermund.bar|local.system-usage"
```
Expected: two rows — `gjermund.bar` (bar kind) and `local.system-usage` (bar-widget kind).

- [ ] **Step 2: Switch the bar to the clone**

Run: `omarchy bar use gjermund.bar`
Expected: `Now using gjermund.bar as the bar`. (This sets `bar.id` in shell.json; the switch is fully active after the shell restart in Step 4.)

- [ ] **Step 3: Place the usage widget left of the tray**

Run: `omarchy bar put local.system-usage --section right --before omarchy.tray`
Expected: `Enabled and moved local.system-usage` (or similar success message). Verify shell.json:
```bash
jq '.bar.id, [.bar.layout.right[].id]' ~/.config/omarchy/shell.json
```
Expected:
```json
"gjermund.bar"
[ "local.system-usage", "omarchy.tray", "agents", "bluetooth", "network", "audio", "power", "monitor" ]
```

- [ ] **Step 4: Restart the shell to activate the new bar**

Run: `omarchy restart shell`
Expected: the bar disappears and reappears within ~2 seconds, now rendered by `gjermund.bar`. If the bar does not come back, run `omarchy-shell shell rescanPlugins` and restart again.

---

### Task 4: Live verification

**Files:** none

- [ ] **Step 1: Screenshot — placement check**

```bash
grim -o DP-1 -t png /tmp/usage-verify.png
magick /tmp/usage-verify.png -crop 1600x44+3520+0 /tmp/usage-bar.png
```
Expected: three text segments `[CPU %] [RAM %] [GPU %]` visible in the gap, immediately left of the tray chevron, with the rest of the right cluster unchanged (`agents, bluetooth, network, audio, power, monitor` at the far right edge).

- [ ] **Step 2: Value sanity check**

```bash
nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits
top -bn1 | head -2
free -g
```
Expected: GPU% on the bar matches nvidia-smi (within a few points); CPU% matches top's `%Cpu(s)` idle-derived busy; RAM% matches `free` (used = total − available). All within reasonable sampling deltas.

- [ ] **Step 3: Theming check**

```bash
omarchy theme set tokyo-night   # wait ~1s
omarchy theme set catppuccin
```
Expected: the usage widget's text/icons follow the theme colors live (foreground/urgent), same as every other bar widget. Screenshot again if uncertain.

- [ ] **Step 4: Interaction check**

- Hover the RAM segment: tooltip shows `RAM X.X / Y GiB (Z%)`.
- Click any segment: the btop scratchpad slides down.
- The segments show the pointy hand cursor on hover like other bar widgets.

- [ ] **Step 5: Vertical bar smoke test (optional)**

Run: `omarchy bar position right` then `omarchy bar position top` (or restore via the panel). Expected: the three segments stack vertically without overlap, then return to the horizontal layout. Skip if you don't want to risk the bar mid-session — the layout is code-reviewed.

- [ ] **Step 6: Document the other-host rollout**

The same Task 3 steps apply on `laptop` and `sikt` after their next rebuild (the plugin files come with the nix config): `rescanPlugins` → `omarchy bar use gjermund.bar` → `omarchy bar put local.system-usage --section right --before omarchy.tray` → `omarchy restart shell`. On `sikt` the GPU segment uses the sysfs fallback (no nvidia-smi) — verify it shows a live percentage, not a stuck 0.
