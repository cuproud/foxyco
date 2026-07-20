# Car Hero — Splash + Home (2026-07-20)

## Goal
Replace painted splash car and add layered photographic car hero to home, using pre-aligned PNG layer sets in `references/car/foxyco_reveal_assets(2)` and `foxyco_stealth_assets(2)` (both 1536×1024 RGBA, same canvas, composite by z-order).

## Assets
Copy unique PNGs to `assets/car/` (dedupe `car_shadow`, `headlights_sharp`, `interior_glow` — identical across sets). Register `assets/car/` in pubspec. ~3.4MB total.

Layers (z-order bottom→top):
- Shared: `car_shadow`
- Stealth set: `stealth_backlight`, `stealth_fog_rear`, `car_stealth`, `stealth_fog_front`, `outline_rim_light`, `headlight_beams`
- Reveal set: `reveal_backlight`, `ground_color_glow`, `car_reveal`, `body_accent_glow`, `grille_lights`, `car_reflection`
- Shared top: `headlights_sharp`, `interior_glow`

## Shared widget — `lib/ui/theme/car_hero.dart`
`CarHero`: `Stack` of `Image.asset` layers, each wrapped in `Opacity`. All layers same canvas → plain `Stack` with `fit: BoxFit.contain`, aspect 3:2. `cacheWidth` set from layout width × devicePixelRatio to cap decode memory.

API: takes per-layer opacities via a small state object (`CarHeroState`) with named factories/lerp so splash and home drive it differently. Reflection rendered separately (flipped, masked) by home only.

## Splash — `lib/ui/splash/splash_screen.dart`
Rewrite scene; keep controller/ceiling/reduced-motion skeleton. Duration 2200ms, ceiling 3500ms.

Timeline (controller intervals):
- 0–0.27 — fade in from black: `car_shadow`, `car_stealth`, both fogs, faint `stealth_backlight`
- 0.27–0.55 — ignition: `headlights_sharp`, `headlight_beams`, `grille_lights`, `outline_rim_light`, `interior_glow` flare in with flicker curve (two dips then full)
- 0.55–1.0 — reveal: crossfade `car_stealth`→`car_reveal`, bloom `reveal_backlight` + `ground_color_glow` + `body_accent_glow`, fogs dissolve, wordmark fades up
- Reduced motion: static full-reveal composite + wordmark, 500ms timer (existing pattern)
- `_SplashScenePainter` + `vehicle_art` usage deleted from splash

## Home hero — `lib/ui/home/home_screen.dart`
`_Hero` gains car stage between status row and tally count:
- `CarHero` + reflection below (flipped, `ShaderMask` fade, low opacity)
- Loops (skipped when `disableAnimations`): 6s float (±6px translateY), 3.2s glow pulse on backlight/ground glow
- State tie-in: `WatchStatus.watching` → full reveal (lights on); else stealth (lights dim). 600ms crossfade on status change.
- Receipt content below unchanged.

## Testing
`flutter analyze` clean; existing widget tests pass; manual device check per docs/MANUAL_TESTS.md (add splash + hero rows).

## Skipped
Smoke drift, parallax, precacheImage warm-up — add if device shows jank or pop-in.
