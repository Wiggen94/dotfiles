# Hyprland Premium macOS-smooth Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the non-gaming Hyprland experience a calmer, more premium macOS-like feel through retuned animation curves/timings, a decoration refresh, and layer-surface entrance animations.

**Architecture:** All changes are edits to a single `extraConfig` Lua string in `modules/home.nix` (Hyprland native Lua API via `wayland.windowManager.hyprland`, `configType = "lua"`). No new files. Validation is a non-switching build (catches Nix/eval errors), then `nrs` to switch, then `hyprctl configerrors` + visual check.

**Tech Stack:** Nix / home-manager, Hyprland Lua config API (`hl.config`, `hl.curve`, `hl.animation`, `hl.layer_rule`).

**Spec:** `docs/superpowers/specs/2026-06-19-hyprland-premium-refresh-design.md`

---

## File Structure

Only one file changes:

- **Modify:** `modules/home.nix`
  - Curves block (~lines 1018–1024)
  - Animations block (~lines 1029–1041)
  - `hl.config` general/decoration block (~lines 954–992)
  - Layer rules block (~lines 1225–1229)

Line numbers are approximate — match on the literal strings shown in each task.

## Commit / verification model

This repo rebuilds and commits via the `nrs` script (`nixos-rebuild-flake`), which builds, shows the diff, asks for confirmation, then commits **and pushes** all staged changes in one go. So this plan does **not** commit per task. All edits are made first, validated with a non-switching build, then applied + committed once via `nrs` in the final task.

---

### Task 1: Replace animation curves

**Files:**
- Modify: `modules/home.nix` (curves block)

- [ ] **Step 1: Replace the curve definitions**

Find this exact block:

```lua
      hl.curve("smoothOut",    { type = "bezier", points = { {0.36, 0},    {0.66, -0.56} } })
      hl.curve("smoothIn",     { type = "bezier", points = { {0.25, 1},    {0.5,  1}     } })
      hl.curve("overshot",     { type = "bezier", points = { {0.05, 0.9},  {0.1,  1.1}   } })
      hl.curve("smoothSpring", { type = "bezier", points = { {0.55, -0.15},{0.20, 1.3}   } })
      hl.curve("fluent",       { type = "bezier", points = { {0.0,  0.0},  {0.2,  1.0}   } })
      hl.curve("snappy",       { type = "bezier", points = { {0.4,  0.0},  {0.2,  1.0}   } })
      hl.curve("easeOutExpo",  { type = "bezier", points = { {0.16, 1},    {0.3,  1}     } })
```

Replace with:

```lua
      -- macOS-smooth curve set: front-loaded motion, gentle settle
      hl.curve("macEase",   { type = "bezier", points = { {0.22, 1},    {0.36, 1} } })  -- quint ease-out
      hl.curve("macSpring", { type = "bezier", points = { {0.34, 1.56}, {0.64, 1} } })  -- mild overshoot, settles
      hl.curve("macFade",   { type = "bezier", points = { {0.4,  0},    {0.2,  1} } })  -- smooth ease in-out
      hl.curve("macSnap",   { type = "bezier", points = { {0.16, 1},    {0.3,  1} } })  -- expo-out, crisp but soft
      hl.curve("borderRot", { type = "bezier", points = { {0.5,  0},    {0.5,  1} } })  -- even border rotation
```

- [ ] **Step 2: Confirm no other references to the old curve names remain**

Run: `grep -n 'smoothOut\|smoothIn\|"overshot"\|smoothSpring\|"fluent"\|"snappy"\|easeOutExpo' modules/home.nix`
Expected: **No output.** (Every old curve name is replaced in Task 2. If any line prints, it is an animation still pointing at a deleted curve — Task 2 fixes all of them; re-run after Task 2 and expect no output.)

---

### Task 2: Retune animation timings

**Files:**
- Modify: `modules/home.nix` (animations block)

- [ ] **Step 1: Replace the animation definitions**

Find this exact block:

```lua
      hl.animation({ leaf = "windowsIn",        enabled = true, speed = 4,  bezier = "overshot",    style = "popin 80%" })
      hl.animation({ leaf = "windowsOut",       enabled = true, speed = 3,  bezier = "smoothOut",   style = "popin 80%" })
      hl.animation({ leaf = "windowsMove",      enabled = true, speed = 4,  bezier = "fluent",      style = "slide" })
      hl.animation({ leaf = "fadeIn",           enabled = true, speed = 3,  bezier = "smoothIn" })
      hl.animation({ leaf = "fadeOut",          enabled = true, speed = 3,  bezier = "smoothOut" })
      hl.animation({ leaf = "fadeSwitch",       enabled = true, speed = 4,  bezier = "smoothIn" })
      hl.animation({ leaf = "fadeDim",          enabled = true, speed = 4,  bezier = "smoothIn" })
      hl.animation({ leaf = "fadeLayers",       enabled = true, speed = 3,  bezier = "easeOutExpo" })
      hl.animation({ leaf = "border",           enabled = true, speed = 8,  bezier = "default" })
      hl.animation({ leaf = "borderangle",      enabled = true, speed = 50, bezier = "smoothIn",    style = "loop" })
      hl.animation({ leaf = "workspaces",       enabled = true, speed = 5,  bezier = "easeOutExpo", style = "slide" })
      hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4,  bezier = "smoothSpring",style = "slidevert" })
      hl.animation({ leaf = "layers",           enabled = true, speed = 3,  bezier = "snappy",      style = "popin 90%" })
```

Replace with:

```lua
      hl.animation({ leaf = "windowsIn",        enabled = true, speed = 5,  bezier = "macSpring",  style = "popin 90%" })
      hl.animation({ leaf = "windowsOut",       enabled = true, speed = 4,  bezier = "macEase",    style = "popin 92%" })
      hl.animation({ leaf = "windowsMove",      enabled = true, speed = 5,  bezier = "macEase",    style = "slide" })
      hl.animation({ leaf = "fadeIn",           enabled = true, speed = 4,  bezier = "macFade" })
      hl.animation({ leaf = "fadeOut",          enabled = true, speed = 4,  bezier = "macFade" })
      hl.animation({ leaf = "fadeSwitch",       enabled = true, speed = 4,  bezier = "macFade" })
      hl.animation({ leaf = "fadeDim",          enabled = true, speed = 4,  bezier = "macFade" })
      hl.animation({ leaf = "fadeLayers",       enabled = true, speed = 4,  bezier = "macSnap" })
      hl.animation({ leaf = "border",           enabled = true, speed = 10, bezier = "default" })
      hl.animation({ leaf = "borderangle",      enabled = true, speed = 70, bezier = "borderRot",  style = "loop" })
      hl.animation({ leaf = "workspaces",       enabled = true, speed = 6,  bezier = "macEase",    style = "slide" })
      hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5,  bezier = "macSpring",  style = "slidevert" })
      hl.animation({ leaf = "layers",           enabled = true, speed = 4,  bezier = "macSnap",    style = "popin 90%" })
```

- [ ] **Step 2: Re-run the orphan-curve check from Task 1**

Run: `grep -n 'smoothOut\|smoothIn\|"overshot"\|smoothSpring\|"fluent"\|"snappy"\|easeOutExpo' modules/home.nix`
Expected: **No output.** Every animation now references one of `macEase`/`macSpring`/`macFade`/`macSnap`/`borderRot`/`default`.

---

### Task 3: Decoration refresh

**Files:**
- Modify: `modules/home.nix` (`hl.config` general + decoration blocks)

- [ ] **Step 1: Bump `gaps_out` in the `general` block**

Find:

```lua
              gaps_in          = 6,
              gaps_out         = 12,
              border_size      = 3,
```

Replace with:

```lua
              gaps_in          = 6,
              gaps_out         = 14,
              border_size      = 3,
```

- [ ] **Step 2: Update rounding and active opacity**

Find:

```lua
              rounding         = 12,
              active_opacity   = 0.98,
              inactive_opacity = ${inactiveOpacity},
```

Replace with:

```lua
              rounding         = 14,
              active_opacity   = 1.0,
              inactive_opacity = ${inactiveOpacity},
```

- [ ] **Step 3: Refresh the shadow block**

Find:

```lua
              shadow = {
                  enabled        = true,
                  range          = 12,
                  render_power   = 4,
                  color_inactive = "rgba(11111b50)",
                  offset         = "0 3",
                  scale          = 1.0,
              },
```

Replace with:

```lua
              shadow = {
                  enabled        = true,
                  range          = 28,
                  render_power   = 3,
                  color          = "rgba(0000004d)",
                  color_inactive = "rgba(11111b50)",
                  offset         = "0 7",
                  scale          = 1.0,
              },
```

- [ ] **Step 4: Lighten blur and enrich vibrancy**

Find:

```lua
              blur = {
                  enabled            = true,
                  size               = 10,
                  passes             = 4,
                  new_optimizations  = true,
                  ignore_opacity     = true,
                  xray               = false,
                  noise              = 0.015,
                  contrast           = 1.0,
                  brightness         = 1.0,
                  vibrancy           = 0.4,
                  vibrancy_darkness  = 0.3,
                  popups             = true,
                  popups_ignorealpha = 0.2,
                  special            = true,
              },
```

Replace with:

```lua
              blur = {
                  enabled            = true,
                  size               = 8,
                  passes             = 3,
                  new_optimizations  = true,
                  ignore_opacity     = true,
                  xray               = false,
                  noise              = 0.015,
                  contrast           = 1.0,
                  brightness         = 1.0,
                  vibrancy           = 0.5,
                  vibrancy_darkness  = 0.3,
                  popups             = true,
                  popups_ignorealpha = 0.2,
                  special            = true,
              },
```

---

### Task 4: Layer-surface animations + stale rule cleanup

**Files:**
- Modify: `modules/home.nix` (layer rules block)

- [ ] **Step 1: Replace the layer rules block**

Find this exact block:

```lua
      hl.layer_rule({ match = { namespace = "launcher"        }, blur = true, ignore_alpha = 0.3 })
      hl.layer_rule({ match = { namespace = "logout_dialog"   }, blur = true, ignore_alpha = 0.3 })
      hl.layer_rule({ match = { namespace = "notifications"   }, blur = true, ignore_alpha = 0.3 })
      hl.layer_rule({ match = { namespace = "quickshell"      }, blur = true, ignore_alpha = 0.3 })
      hl.layer_rule({ match = { namespace = "gtk-layer-shell" }, blur = true, ignore_alpha = 0.3 })
```

Replace with:

```lua
      hl.layer_rule({ match = { namespace = "vicinae"         }, blur = true, ignore_alpha = 0.3, animation = "popin" })
      hl.layer_rule({ match = { namespace = "notifications"   }, blur = true, ignore_alpha = 0.3, animation = "slide" })
      hl.layer_rule({ match = { namespace = "quickshell"      }, blur = true, ignore_alpha = 0.3, animation = "fade" })
      hl.layer_rule({ match = { namespace = "gtk-layer-shell" }, blur = true, ignore_alpha = 0.3 })
```

Notes:
- `launcher` (old Fuzzel) is replaced by `vicinae` (the live launcher namespace, confirmed via `hyprctl layers`).
- `logout_dialog` (old wlogout) is deleted — the power menu is now a `quickshell` surface.
- `quickshell` is the shared namespace for bar + power menu + lockscreen, so `fade` is used (a slide would look wrong on the lockscreen).

---

### Task 5: Validate, rebuild, and verify

**Files:** none (verification only)

- [ ] **Step 1: Confirm the host name for the build**

Run: `hostname`
Expected: one of `desktop`, `laptop`, `sikt`. Use this value as `<host>` below.

- [ ] **Step 2: Non-switching build to catch Nix/eval errors before touching the running system**

Run: `cd ~/nix-config && sudo nixos-rebuild build --flake .#<host>`
Expected: builds to completion with no Nix evaluation or syntax errors (creates a `./result` symlink, does NOT activate). If it errors, fix the reported file/line and re-run before proceeding.

- [ ] **Step 3: Apply with the project workflow**

Run: `nrs`
Expected: `nh os switch` builds, shows the `nvd` diff, prompts for confirmation; on success it auto-commits and pushes. Confirm the diff only touches `modules/home.nix` (plus the generated Hyprland config) and the new docs.

- [ ] **Step 4: Verify Hyprland accepted the config with zero errors**

Run: `hyprctl configerrors`
Expected: `no errors` (or empty). If errors are listed, they name the offending option — fix in `modules/home.nix` and re-run `nrs`.

- [ ] **Step 5: Visual verification checklist**

Confirm by interacting with the desktop:
- Open a window (e.g. `Super+T`): scales in with a gentle spring, settles without obvious wobble.
- Switch workspaces (`Super+1`..`6`): smooth horizontal glide.
- Special workspace (`Super+S`): slides vertically with mild spring.
- Active window is fully opaque; inactive windows are dimmed; shadows are large and soft, window appears to float.
- Open the launcher (`Super+A`, Vicinae): pops in (scale-up).
- Trigger a notification: slides in.
- `Super+Shift+B` (bar toggle): bar fades.
- Gradient border rotation is present but calmer/slower than before.

- [ ] **Step 6: Confirm gaming mode still strips effects**

Run: toggle gaming mode (`Super+G`), observe blur/shadows/animations disable; toggle back, effects return.
Expected: gaming mode behavior unchanged.

---

## Tuning notes (if the feel is off)

- Spring too wobbly on window open: lower `macSpring`'s first y from `1.56` toward `1.3` (Task 1).
- Motion feels sluggish: drop the `speed` values in Task 2 by 1 (e.g. `windowsIn` 5→4, `workspaces` 6→5).
- Shadows too heavy / Intel `sikt` stutters: lower shadow `range` 28→20 (Task 3, Step 3), or revisit the "same everywhere" decision and gate effects per host.
