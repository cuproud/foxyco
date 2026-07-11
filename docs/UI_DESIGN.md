# FoxyCo — UI Design

The complete visual + interaction design for FoxyCo (Flutter / Material 3). Covers the design
language, tokens, every screen, the overlay components, motion, and accessibility. Mockups are ASCII
— they fix *layout and hierarchy*, not final pixels. The final look is locked at M5 (see ROADMAP);
this doc is the proposal + the contract the tokens must satisfy.

Design north star: **a driver, mid-shift, glances for under half a second and knows: take it or
skip it.** Everything serves that glance. Everything else is secondary.

---

## 1. Design principles

1. **Glanceable over pretty.** Verdict readable in <0.5 s, at arm's length, in sunlight. Color +
   word + icon — never color alone.
2. **Dark-first.** Drivers work nights. True-dark / OLED default; light theme is secondary.
3. **Calm, not loud.** One accent per screen (the verdict). No gradients-on-gradients, no confetti.
4. **Big targets.** 48 dp minimum. Thumbs, moving vehicle, cold hands.
5. **Native beside Uber/Hopp.** Echo their idiom (oversized bold number, chip metadata, dot-line
   route) so the overlay doesn't feel like a foreign object.
6. **Honest.** If we're not sure (low parse confidence), we show a `?`, never a confident wrong call.

---

## 2. Visual direction (proposed — lock at M5)

Three candidates. Recommendation first.

### ⭐ A. Kinetic HUD (recommended)
Dashboard-instrument feel. Near-black background, one saturated verdict color, crisp mono-ish
numerics, thin rules. Reads like a car HUD — appropriate, glanceable, ages well.
- Bg `#0B0E11`, surface `#151A1F`, text `#F5F7FA`, verdict = the only saturated color on screen.
- Numbers in a tabular/semi-condensed face; labels small-caps, low emphasis.

### B. Aurora Glass
Frosted translucent cards, soft blurred verdict glow behind the pill. Premium, modern. Risk: blur
costs GPU (battery — AUDIT #4) and can wash out in sunlight. Reserve blur for the app, not the overlay.

### C. Neo-Tactile
Soft matte cards, chunky rounded shapes, playful — leans into the friendly "Foxy" mascot side.
Warmest/most approachable; risk of feeling less "serious money tool."

> **Recommendation: Kinetic HUD** for the overlay + core (glanceability + battery), with **one Neo-Tactile
> touch** — the fox mascot on onboarding/empty states — so the brand stays friendly. Best of both.

---

## 3. Design tokens

Single source of truth in `lib/ui/theme/`. M5 = swap these values, not the widgets.

### Color — verdict (semantic, fixed)
```
verdict.good   #2ED573   green   ● + "GOOD"
verdict.ok     #FFB020   amber   ◐ + "OK"
verdict.bad    #FF4757   red     ○ + "BAD"
verdict.unknown#8895A7   grey    ? + "—"    (low parse confidence)
```
Each verdict is **color + icon shape + word** so it survives colorblindness and glare.

### Color — surfaces (dark-first)
```
bg.base        #0B0E11
bg.surface     #151A1F
bg.surfaceHigh #1D242B
outline        #2A333C
text.primary   #F5F7FA
text.secondary #9AA7B4
text.disabled  #5A6673
brand.fox      #FF7A1A   (foxy orange — accents, logo, primary buttons only)
```

### Type scale (Material 3 roles → use)
```
displayLarge   57  → the payout number on the expanded pill
headlineMedium 28  → screen titles, big tally numbers
titleMedium    16  → card titles
bodyMedium     14  → body, list items
labelSmall     11  → chip text, metadata, small-caps labels
```
Numerals tabular where numbers align (tallies, thresholds, payout).

### Spacing (4 dp base)
```
xs 4 · sm 8 · md 16 · lg 24 · xl 32 · xxl 48
```
Screen padding 16. Card padding 16. Gap between cards 12.

### Shape & elevation
```
radius.pill  999   (pill, chips, bubble)
radius.card  20
radius.field 12
elevation: flat surfaces; use a 1 dp outline instead of heavy shadows (dark theme).
```

### Motion
```
fast   120 ms  (taps, chip toggles)
base   220 ms  (screen transitions, pill appear)
count  400 ms  (payout/tally number count-up)
curve  easeOutCubic
```
Rule: the verdict is **never** hidden behind an animation. Pill content is correct on frame 1; the
fade is decoration only.

---

## 4. App map & navigation

`go_router`, 4 routes. Bottom of the stack is Home.

```
/onboarding   (first run only — permission walkthrough)
/             Home
/settings     Thresholds, units, overlay prefs
/settings/pill  Pill size + position + timeout (sub-page)
```

No bottom nav bar in MVP — too few screens. Home has a gear → Settings. Simple.

---

## 5. Screens

### 5.1 Onboarding (first run)

Purpose: earn the two scary permissions honestly (Play policy — AUDIT #1). 3 short pages, swipeable,
skippable after permissions.

```
┌─────────────────────────────┐
│                             │
│           🦊                │   ← friendly fox mark (Neo-Tactile touch)
│                             │
│     Meet FoxyCo             │   headlineMedium
│                             │
│  Your co-driver that reads  │   bodyMedium, text.secondary
│  every offer and tells you  │
│  GOOD / OK / BAD in a       │
│  glance.                    │
│                             │
│   ● ○ ○                     │   page dots
│                             │
│   [   Next   ]              │   brand.fox button, full width, 56 dp
└─────────────────────────────┘

Page 2 — "Draw over other apps"
  Explains: FoxyCo floats a tiny pill over Uber/Hopp so you never switch apps.
  [ Grant "Display over other apps" ]  → opens system settings, returns

Page 3 — "Read the offer on screen"   ← the sensitive one
  Explains PLAINLY: FoxyCo uses Android's accessibility service ONLY to read the
  offer's pay + distance on screen, to score it. It does not read anything else,
  sends nothing anywhere, and never taps buttons for you.
  [ Grant Accessibility Access ]  → system settings, returns
  small link: "Why FoxyCo needs this" → full-screen plain-language explainer
```

States: each permission page shows ✅ once granted; "Next" disabled until granted (or "Skip for now"
in small text — the app works, just can't watch yet).

---

### 5.2 Home

The dashboard between shifts. Status at top (is FoxyCo actually watching?), today's tally below.
No graphs (MVP). Calm.

```
┌─────────────────────────────┐
│  FoxyCo            ⚙         │   title + settings gear
│                             │
│  ┌───────────────────────┐  │
│  │  ●  Watching for       │  │   STATUS CARD (hero)
│  │     offers             │  │   green dot = live & watching
│  │  Uber · Hopp           │  │   subtitle = active platforms
│  │            [ Pause ]   │  │   pause = stop the watch loop
│  └───────────────────────┘  │
│                             │
│  Permissions                │   labelSmall section header
│  ┌──────────┐ ┌──────────┐  │
│  │ Overlay ✅│ │ Access ✅ │  │   two permission chips; red ⚠ if missing → tap fixes
│  └──────────┘ └──────────┘  │
│                             │
│  Today                      │
│  ┌──────┐ ┌──────┐ ┌──────┐ │   TALLY — count only, count-up animated
│  │  12  │ │  7   │ │  4   │ │
│  │ GOOD │ │  OK  │ │ BAD  │ │   green / amber / red headers
│  └──────┘ └──────┘ └──────┘ │
│                             │
│  Last offer                 │
│  ┌───────────────────────┐  │
│  │ ● GOOD  Uber          │  │   most recent seen offer (from Drift log)
│  │ 8.4 km · $12 · $1.43/km│ │
│  │ 2 min ago             │  │
│  └───────────────────────┘  │
└─────────────────────────────┘
```

**Status card is the hero** — the driver's #1 question is "is it actually on?". Green pulsing dot =
watching; grey = paused; red = a permission is missing (with a one-tap fix). If a permission is
missing, the status card turns into a call-to-action ("Grant accessibility to start watching").

Empty state (fresh install, no offers yet): tally shows `—`, "Last offer" card replaced by the fox
mark + "No offers yet. Open Uber or Hopp and drive — I'll start scoring."

---

### 5.3 Settings

The core knob (thresholds) up top, everything else below. Every change persists instantly (no Save
button) and live-updates the verdict engine.

```
┌─────────────────────────────┐
│  ← Settings                 │
│                             │
│  Verdict thresholds ($/km)  │   the brain's only knob
│  ┌───────────────────────┐  │
│  │  GOOD at or above      │  │
│  │  $ [ 1.50 ]      ▲▼    │  │   stepper + text field, tabular numerals
│  │───────────────────────│  │
│  │  BAD below             │  │
│  │  $ [ 1.00 ]      ▲▼    │  │
│  │                       │  │
│  │  OK = the band between │  │   computed, shown for clarity
│  │  $1.00 and $1.49       │  │
│  └───────────────────────┘  │
│                             │
│  ┌───────────────────────┐  │
│  │ live preview          │  │   drag a sample $/km → watch verdict flip
│  │ $1.43/km  →  ◐ OK      │  │   makes the abstract concrete
│  └───────────────────────┘  │
│                             │
│  Units          [ km | mi ] │   segmented
│                             │
│  Platforms                  │
│  Uber                  [on] │   toggles (which packages to watch)
│  Hopp                  [on] │
│                             │
│  Overlay                  › │   → /settings/pill sub-page
│  About & privacy          › │
└─────────────────────────────┘
```

The **live preview** is the key UX bet: thresholds are abstract, so let the driver drag a sample
value and watch the pill flip GOOD↔OK↔BAD in real time. Removes all guesswork.

**Overlay sub-page** (`/settings/pill`): pill size (S/M/L segmented, with a live sample pill),
vertical drop offset (slider — how far below the top edge), auto-dismiss timeout (slider, 5–20 s),
"reset pill position". A live sample pill sits pinned at the current settings so changes are visible.

---

## 6. The overlay components (the product)

Rendered in the overlay isolate (`flutter_overlay_window`), but styled from the same tokens.

### 6.1 Pill — collapsed (default)

Single line. Dot (verdict color+shape) · total km · payout. Sits top-dropped, clear of the X.

```
   ╭──────────────────────────╮
   │  ●  GOOD · 8.4 km · $12   │      good   (green dot ●)
   ╰──────────────────────────╯

   ╭──────────────────────────╮
   │  ◐  OK · 5.1 km · $10.55  │      ok     (amber half ◐)
   ╰──────────────────────────╯

   ╭──────────────────────────╮
   │  ○  BAD · 12.0 km · $7    │      bad    (red ring ○)
   ╰──────────────────────────╯

   ╭──────────────────────────╮
   │  ?  reading offer…        │      unknown / low confidence (grey)
   ╰──────────────────────────╯
```

- Height by size: S 32 · M 40 · L 48 dp. Radius = pill (999). Bg `bg.surfaceHigh` at 96% opacity
  with a 1 dp verdict-colored outline — subtle, not a slab of color (sunlight + not covering the map).
- The **dot is the load-bearing element**: biggest, leftmost, verdict color + distinct shape.
- Appears: fade + 4 dp rise over `base` (220 ms). The text is correct on frame 1.
- Auto-dismiss after the timeout; or stays until the next offer replaces it.

### 6.2 Pill — expanded (on tap)

Echoes the Uber/Hopp card idiom: oversized bold payout, chip metadata, dot-line route, the $/km we
add. Still compact, still clear of the Accept button.

```
   ╭───────────────────────────╮
   │  ● GOOD                 ✕  │   verdict chip + close
   │                           │
   │  $12.00        $1.43/km   │   payout displayLarge; $/km = our value-add, brand.fox
   │                           │
   │  ┌ Uber ┐  gross          │   platform chip + net/gross flag
   │                           │
   │  ● 2.1 km  pickup         │   dot-line route (their idiom)
   │  │                        │
   │  ● 6.3 km  dropoff        │
   │  ─────────────────────    │
   │  8.4 km total             │   the SUM neither app shows
   ╰───────────────────────────╯
```

Tap again or timeout → collapses back to the pill.

### 6.3 Bubble

Always-on draggable dot; the persistent handle while driving.

```
        ╭────╮
        │ ●  │        ← verdict color of last offer (or grey idle)
        ╰────╯           snaps to nearest screen edge
```
- 48 dp. Tap = open FoxyCo. Long-press = pause/resume (dot dims when paused). Drag = reposition,
  snaps to edge, remembers position.
- It's ambient status: a green dot at the edge = "last one was good," without opening anything.

---

## 7. Iconography

- **Verdict icons** (shape-coded, colorblind-safe): ● filled = GOOD, ◐ half = OK, ○ ring = BAD,
  ? = unknown. Never rely on color alone.
- **App icon:** minimal geometric fox head, foxy-orange on near-black. Reads at 48 dp in a launcher.
- **Nav/action icons:** Material Symbols (rounded), 24 dp.

---

## 8. Accessibility (of FoxyCo itself)

- **Contrast:** verdict text/dot ≥ 4.5:1 on the pill surface; check the amber especially.
- **Never color-only:** every verdict pairs color + shape + word (§6).
- **Targets:** 48 dp min everywhere, including the bubble and pill.
- **Semantics:** the pill exposes a semantics label ("Good offer, 8.4 kilometres, 12 dollars") so
  TalkBack users get it too.
- **Text scale:** screens respect the system font scale; the pill caps scaling so it never grows
  large enough to cover the platform's controls (glance tool, not a reading surface).
- **Reduce motion:** honor the system setting — drop the count-up + rise, keep instant correct state.

---

## 9. What's deferred (design reserves room, M5+ / later)

- Full visual-language lock (which of §2 A/B/C) — M5.
- App icon + mascot final art — M5.
- Light theme polish — M5 (dark ships first).
- Analytics/heatmap screens, goals, expense/mileage UI — later milestones; Home's card grid is built
  to accept new cards without a redesign.
