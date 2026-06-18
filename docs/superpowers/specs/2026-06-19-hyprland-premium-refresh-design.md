# Hyprland Premium macOS-smooth Refresh — Design

**Date:** 2026-06-19
**Scope:** `modules/home.nix` (shared Hyprland Lua config). Applies uniformly to all three hosts (`desktop`, `laptop`, `sikt`).

## Goal

Make the non-gaming Hyprland experience feel more fluid and premium, with a
macOS-like motion character: front-loaded motion (fast start), long gentle
settle, *mild* spring overshoot on open. This is primarily a bezier-curve and
decoration job — not simply slowing animations down.

## Constraints & Decisions

- **Feel:** macOS-like / smooth (calm, eased, deliberate).
- **Visual scope:** Full refresh — motion *and* decoration (rounding, shadows,
  opacity, gaps, blur).
- **Surfaces:** Hyprland compositor layer + layer-surface (Quickshell bar,
  swaync notifications, Vicinae launcher) open/close animations. Theme-generated
  CSS colors are NOT touched.
- **Actual stack (CLAUDE.md is out of date):** launcher is **Vicinae** (not
  Fuzzel), bar / power menu / lockscreen are **Quickshell** (not Waybar /
  wlogout), notifications are still **swaync**.
- **Per-host:** Identical effects on all hosts (user choice). Blur is tuned
  lighter than current so the heavier shadows don't cost net performance.
- **Gaming mode:** Untouched — `gaming-mode-toggle` still disables effects.
- **Rotating gradient border:** Kept (signature of the setup) but slowed for a
  calmer feel.
- **API:** Native Hyprland Lua API (`hl.config`, `hl.curve`, `hl.animation`,
  `hl.layer_rule`). `hl.window_rule` already uses `animation = "slide"`, so
  `hl.layer_rule` accepts the same `animation = "<style>"` key.
- **Speed semantics:** Hyprland animation `speed` is duration in deciseconds
  (higher = longer). Perceived snappiness comes mostly from the bezier shape.

## Changes

All edits are in the `hl.config(...)`, curve, animation, and layer-rule blocks
of `modules/home.nix` (around lines 953–1041 and 1223–1229).

### 1. Animation curves

Replace the current curve set with macOS-tuned curves. Format is Hyprland
bezier: `points = { {x1,y1}, {x2,y2} }`.

| Curve | Points | Purpose | Character |
|-------|--------|---------|-----------|
| `macEase` | `{{0.22,1},{0.36,1}}` | window move, workspace slide | Quint ease-out — glides to a stop |
| `macSpring` | `{{0.34,1.56},{0.64,1}}` | window open, special workspace | Gentle overshoot, settles (not bouncy) |
| `macFade` | `{{0.4,0},{0.2,1}}` | all fades | Smooth ease in-out |
| `macSnap` | `{{0.16,1},{0.3,1}}` | layers / popups | Expo-out — crisp but soft |
| `borderRot` | `{{0.5,0},{0.5,1}}` | animated gradient border loop | Even rotation (calm) |

### 2. Animation timings

| Leaf | bezier | speed (ds) | style |
|------|--------|-----------|-------|
| `windowsIn` | `macSpring` | 5 | `popin 90%` |
| `windowsOut` | `macEase` | 4 | `popin 92%` |
| `windowsMove` | `macEase` | 5 | `slide` |
| `fadeIn` | `macFade` | 4 | — |
| `fadeOut` | `macFade` | 4 | — |
| `fadeSwitch` | `macFade` | 4 | — |
| `fadeDim` | `macFade` | 4 | — |
| `fadeLayers` | `macSnap` | 4 | — |
| `border` | `default` | 10 | — |
| `borderangle` | `borderRot` | 70 | `loop` (slowed from 50) |
| `workspaces` | `macEase` | 6 | `slide` |
| `specialWorkspace` | `macSpring` | 5 | `slidevert` |
| `layers` | `macSnap` | 4 | `popin 90%` |

### 3. Decoration refresh

In `hl.config({ ... })`:

| Setting | Current | New | Rationale |
|---------|---------|-----|-----------|
| `general.gaps_out` | 12 | 14 | More breathing room |
| `decoration.rounding` | 12 | 14 | Softer macOS-like corners |
| `decoration.active_opacity` | 0.98 | 1.0 | Crisp opaque active window |
| `shadow.range` | 12 | 28 | Large diffuse macOS shadow |
| `shadow.render_power` | 4 | 3 | Softer falloff |
| `shadow.offset` | `0 3` | `0 7` | Window "floats" higher |
| `shadow.color` (active) | (unset) | `rgba(0000004d)` | Soft depth without harshness |
| `shadow.color_inactive` | `rgba(11111b50)` | unchanged | — |
| `blur.size` | 10 | 8 | Same glassy look, cheaper |
| `blur.passes` | 4 | 3 | Same glassy look, cheaper |
| `blur.vibrancy` | 0.4 | 0.5 | Richer frosted-glass saturation |

Unchanged: `gaps_in`, `border_size`, `inactive_opacity`/`dim_inactive`/
`dim_strength`/`dim_special` (depth cues kept), all other blur fields.

### 4. Layer-surface animations

Namespaces confirmed via `hyprctl layers`. Add an `animation` key to the
relevant `hl.layer_rule` entries (keeping their existing `blur`/`ignore_alpha`),
and clean up the stale rules:

| namespace | animation | surface |
|-----------|-----------|---------|
| `notifications` | `slide` | swaync popups |
| `vicinae` | `popin` | Vicinae launcher (centered) |
| `quickshell` | `fade` | bar + power menu + lockscreen (shared namespace) |
| `gtk-layer-shell` | (keep blur only) | generic GTK layer apps |

**`quickshell` is a shared namespace** for the bar, the Quickshell power menu,
and the lockscreen. A single rule applies to all three, so `fade` is chosen as
the universally flattering option (a slide would look odd on the lockscreen).

**Stale rules to remove:** `launcher` (old Fuzzel namespace) and `logout_dialog`
(old wlogout namespace) — neither matches any live surface. Replace the
`launcher` entry with a `vicinae` entry; delete the `logout_dialog` entry.

## Out of Scope

- Theme CSS / QML styling (Quickshell, Vicinae, swaync colors and internal spacing).
- Per-host effect tiers.
- Gaming-mode behavior.
- Any new keybinds or scripts.

## Verification

- `nrs` builds cleanly (Lua config parses; no Hyprland config errors in
  `hyprctl` / journal).
- Visually confirm after rebuild: window open spring, workspace glide, larger
  soft shadow, opaque active window, launcher/notification entrance motion.
- Gaming mode still strips effects.

## Risks

- Spring overshoot (`macSpring`) can look "wobbly" if too strong; `1.56`
  overshoot is mild. Tune down toward `1.3` if it feels excessive.
- Larger shadows (`range 28`) increase fill cost; offset by reduced blur passes.
  If the Intel `sikt` host stutters, revisit the "same everywhere" decision.
