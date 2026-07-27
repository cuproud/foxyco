# HANDOFF 2026-07-26 — Foxy brand assets (car / logo / mascot)

Bugs from the 2026-07-26 device session are **fixed in code** (below). The brand-asset
swap is **not started** — that's the work for the next session, spec'd out here.

Branch: `m6-showroom`. Nothing committed. `flutter analyze` clean (one pre-existing
`car_hero.dart` unused-import warning), `flutter test` 210 passing, `flutter build apk
--debug` succeeds.

---

## Part 1 — Bugs fixed this session

### 1.1 Duplicate History rows ✅ fixed + tested

Two identical `Uber · Share · $10.19 · 11.7 km · 2:49 PM` rows.

**Root cause.** `OfferWatcher` drops `_shownKey` (`offer_watcher.dart:_clearNow`) whenever
a frame stops looking like the card — a partial read, a half-rendered tree. A card that
flickers and comes back then parses as brand new and is logged a second time. Every stat
downstream (today's tally, good-average $/km, busiest hour, the by-hour chart) counted one
offer as two.

**Fix.** `OfferLog.record` (`services/offer_log.dart`) drops an entry matching the newest
one within `OfferLog.dedupeWindow` (2 min), compared via the new
`OfferSummary.sameCardAs` — platform, payout, both distances, duration, tier. Excludes
`seenAt`/`verdict`/`outcome` (the first is what differs between reads; the last two are
ours, not the card's).

Guarded at the log sink, not in the watcher, on purpose: re-showing the **pill** for a card
that came back is correct behaviour. This is the one sink every caller routes through.

Tests: `test/offer_log_dedupe_test.dart` (5 cases — collapse, window expiry, a one-cent
difference still recording, only-newest-compared, and `sameCardAs` field selection).

### 1.2 Grey square mask behind bubble/pill ⚠️ fixed, NEEDS DEVICE VERIFICATION

**Root cause (high confidence).** The fork already fixed this once — `OverlayService.java`
carries a `setOpaque(false)` patch dated 2026-07-17 with the same symptom described. That
call runs **once**, in `onStartCommand`. `updateViewLayout` re-creates the TextureView's
SurfaceTexture at the new size, and the surface goes back to compositing opaque. Matches
the report exactly: appears after a while (i.e. after a pill→bubble resize cycle), clears
on a service restart (fresh view).

**Fix.** `keepSurfaceTransparent(params)` in
`third_party/flutter_overlay_window/.../OverlayService.java` re-asserts all three flags
(`params.format = TRANSLUCENT`, `textureView.setOpaque(false)`,
`flutterView.setBackgroundColor(TRANSPARENT)`). Called from `resizeOverlay` and
`updateOverlayFlag` — the two paths that change size or rebuild `params.flags`. Idempotent
(`TextureView.setOpaque` no-ops when unchanged), so it just runs every time rather than
trying to detect the bad state. Deliberately NOT wired into the drag handlers
(`updateViewLayout` at the three drag sites): those only move x/y, which does not resize
the surface.

**If it comes back anyway**, the next suspect is `FlutterTextureView` re-attaching on
resize and resetting opacity internally — in that case stop resizing the window entirely
and keep one pill-sized window with a transparent Flutter-side layout.

### 1.3 Bubble tap → "crash", app reopens fresh ⚠️ fixed, NEEDS DEVICE VERIFICATION

Probably not a crash. `bringHostAppToFront()` fired the launcher intent with
`FLAG_ACTIVITY_NEW_TASK | REORDER_TO_FRONT | SINGLE_TOP`. Against an
`ACTION_MAIN`/`CATEGORY_LAUNCHER` intent, `REORDER_TO_FRONT` turns "resume this task" into
a relaunch — the driver loses tab, scroll and any open sheet, which reads exactly like a
crash-and-restart from the outside.

**Fix.** `NEW_TASK` only (still required when starting an activity from a Service; on its
own it is precisely what the launcher icon does — resume, state intact).

**If it really is a crash**, this fix won't cover it. Capture it:
```bash
adb logcat -c && adb logcat -v time | tee /tmp/foxy-crash.log
# reproduce: go live → wait for the mask → tap the bubble
grep -iE "FATAL|AndroidRuntime|FoxyCoNative|libflutter" /tmp/foxy-crash.log
```

> ⚠️ 1.2 and 1.3 are **native** changes. `flutter test` cannot reach them and there was no
> device on this machine (`flutter devices` → Linux desktop only). Both are reasoned from
> the code, not observed working. Verify before trusting.

### Verification steps (device)
1. Go live, let a real pill show and clear, repeat ~5×. Bubble must stay a clean circle —
   no grey box at any point. (This is the cycle that used to break it.)
2. Drag the bubble to both edges between cycles; still clean.
3. Tap the bubble mid-session → FoxyCo comes forward **on the tab you left it on**, scroll
   position intact.
4. Take ~10 real offers and check History has no adjacent identical rows.

---

## Part 2 — Brand assets (NEXT SESSION, not started)

Goal in the user's words: *"give the app a unique foxy look overall instead of some random
car."* `logo 3d` is the main logo from now on.

### 2.1 Asset inventory — measured, not assumed

All under `references/car/`. Every file is RGBA with a **clean cutout** (alpha 0 in the
corners, near-binary edges — verified with PIL, not eyeballed).

| File | Px | MB | Notes |
|---|---|---|---|
| `foxy_car_assets_v1/dark_theme/01_foxy_car_core_4k.png` | 4096×2731 | 4.4 | car+fox, no glow |
| `foxy_car_assets_v1/dark_theme/02_dark_glow_shadow_4k.png` | 4096×2731 | 0.7 | glow/shadow only, alpha max 149 |
| `foxy_car_assets_v1/dark_theme/03_foxy_car_dark_4k.png` | 4096×2731 | 5.6 | **composite** (01 over 02) |
| `foxy_car_assets_v1/light_theme/01_foxy_car_core_4k.png` | 4096×2731 | 4.4 | byte-identical core to dark |
| `foxy_car_assets_v1/light_theme/02_light_shadow_4k.png` | 4096×2731 | 0.5 | softer, no glow |
| `foxy_car_assets_v1/light_theme/03_foxy_car_light_4k.png` | 4096×2731 | 5.4 | **composite** |
| `foxy_car_core_4k.png` | 4096×2731 | 4.4 | same core, loose copy |
| `logo 3d.png` | 1024×1536 | 2.0 | gold "FoxyCo" wordmark; art occupies y 571–936 only |
| `logo black.png` | 1536×1024 | 1.4 | monochrome, legal/print use |
| `sleeping fox.png` | 1024×1536 | 2.4 | fox asleep on a grass disc; art in y 665–1321 |

**Two things to get right before importing:**

1. **Do not ship 4K.** `foxy_car_assets_v1/QA_REPORT.txt` says outright: *"The approved
   1536×1024 render was alpha-safe upscaled to 4096×2731 … it is an upscale, not a native-4K
   rerender."* There is no real detail above 1536. Downscale to **1536×1024** (which also
   matches the existing `assets/car/` canvas exactly) — ~10 MB of APK for nothing otherwise.
2. **Crop the logo/mascot canvases.** Both are ~1024×1536 with the art in a band; ~75% of
   `logo 3d.png` and `sleeping fox.png` is empty alpha. Crop to the bounding box before
   importing or every layout has to compensate with negative padding.

```bash
# from references/car/ — downscale + crop in one pass
python3 - <<'EOF'
from PIL import Image
import os
os.makedirs('/tmp/foxy_out', exist_ok=True)
def car(src, dst):
    Image.open(src).resize((1536,1024), Image.LANCZOS).save(f'/tmp/foxy_out/{dst}', optimize=True)
def crop(src, dst):
    im = Image.open(src).convert('RGBA')
    im.crop(im.getchannel('A').getbbox()).save(f'/tmp/foxy_out/{dst}', optimize=True)
car('foxy_car_assets_v1/dark_theme/01_foxy_car_core_4k.png', 'foxy_car_core.png')
car('foxy_car_assets_v1/dark_theme/02_dark_glow_shadow_4k.png', 'foxy_car_glow_dark.png')
car('foxy_car_assets_v1/light_theme/02_light_shadow_4k.png',    'foxy_car_shadow_light.png')
crop('logo 3d.png', 'foxyco_logo.png')
crop('logo black.png', 'foxyco_logo_mono.png')
crop('sleeping fox.png', 'foxy_sleeping.png')
EOF
```
Ship the **core + per-theme glow** (2 files + 1 shared core), not the composites — the core
is byte-identical across themes, so that's one 1536×1024 car instead of two.

> Watch out: transparent pixels carry non-black RGB (dark green under the sleeping fox,
> grey under the logos). Anything that ignores or premultiplies alpha wrongly — a JPEG
> conversion, a careless resize — turns them into a visible green/grey box. Keep everything
> RGBA PNG and always resize with alpha intact.

### 2.2 Home hero — replace the 15-layer car

**This is the big one, and it is a simplification, not a port.**

Today `lib/ui/theme/car_hero.dart` composites **15** pre-aligned PNGs on a 1536×1024
canvas, with one opacity per layer held in `CarHeroState` and two presets:
`CarHeroState.stealth` (parked, lights off) and `CarHeroState.reveal` (lights on, glows
blooming). `home_screen.dart:813` lerps stealth→reveal on the offline→live transition;
`splash_screen.dart:97` drives its own `_stateAt(t)` timeline including a headlight
flicker.

The Foxy set has **two** layers and no lights-off/lights-on variant. So the 15-opacity
machinery and both presets go away, and the offline↔live tell needs re-deciding.

Recommendation: keep the car core at full opacity always and **animate the glow layer's
opacity as the live tell** — `02_*_glow_shadow` at ~0.25 offline, 1.0 live, lerped on the
same curve the stealth→reveal crossfade uses now. That preserves the existing "the car
wakes up when you go live" beat with the new art and one animated value.

Files to touch:
- `lib/ui/theme/car_hero.dart` — collapse `CarHeroState` to (roughly) a single `glow`
  double; delete the 15 layer entries and both presets. `CarHero.layerNames` is the splash's
  precache list — keep the name, shrink the list.
- `lib/ui/theme/hero_stage.dart` — the ring/ambient/sweep treatment (M12.42–48) was tuned
  against the old car's geometry. The Foxy car sits differently in frame; `HeroStageMetrics.groundY`
  (0.84, the wheel-contact line) **will** need re-tuning — MANUAL_TESTS M12.43 already flags
  it as the one value that can't be derived.
- `lib/ui/home/home_screen.dart` — `_CarStage` (~line 813), `_onPaper` (~line 770, the
  light-theme opacity haircut).
- `lib/ui/splash/splash_screen.dart` — `_stateAt` and the `_flicker` curve (no separate
  headlight layer to flicker any more; either drop it or flicker the glow).
- Delete the 15 old PNGs from `assets/car/` once nothing references them (~4 MB back).

### 2.3 Splash / loading screen

Use `foxy_car_core_4k` (downscaled) as the splash car — same swap as 2.2, driven from
`splash_screen.dart`. Then put `logo 3d` under it in place of the current wordmark
treatment. Check `splash_mark.png` / `splash_mark_a12.png` in `assets/branding/` and the
generated `android/app/src/main/res/drawable*/splash.png` — the **native** launch window is
generated by `flutter_native_splash`, so regenerate rather than hand-editing those.
`docs/MANUAL_TESTS.md` M12.10/M12.11 guard the "no cream flash on launch" behaviour — keep
them passing.

### 2.4 Sleeping fox — empty session card

`home_screen.dart:1273`, inside `_EmptySession`: swap
`Image.asset('assets/branding/foxyco_head.png', width: 64, height: 64)` for the cropped
sleeping fox. It's a wide-ish landscape crop (~994×656 of art), so 64×64 square is wrong —
give it a width and let height follow, ~120–140 wide next to "No sessions yet 🍪".

This is the **only** head-fox usage that should change. Leave the other four
(`home_screen.dart:247` brand bar, `shift_recap_sheet.dart:75`, `onboarding_screen.dart:207`,
`fox_bubble.dart:55` the overlay bubble) alone unless asked.

### 2.5 Logo everywhere else

- `about_screen.dart:25` — swap the 40×40 head for `logo 3d`. It's a **wordmark**, not a
  square mark: the row already renders "FoxyCo" as text beside it (`about_screen.dart:34`),
  so use the logo *instead of* the icon+text pair, not next to a duplicate name.
- `logo black.png` → keep as the monochrome/print mark for legal docs. Not referenced from
  code; it does **not** belong in `pubspec.yaml assets:` (would ship 1.4 MB for nothing).

### 2.6 pubspec

`assets/car/` is included as a whole directory (`pubspec.yaml:104`), so new files there need
no pubspec edit — but **deleting** the old ones is what actually reclaims the APK size.
Branding files are listed individually with an explicit warning that the rest of
`assets/branding/` are generator inputs that must not ship (~6 MB) — respect that when
adding the logo.

### Suggested order
1. Downscale/crop into `assets/` (script above). Confirm APK size before/after.
2. 2.4 + 2.5 first — small, self-contained, visible wins, no animation work.
3. 2.2 the hero. Expect `HeroStageMetrics.groundY` re-tuning on device.
4. 2.3 splash last (it precaches from `CarHero.layerNames`, so it wants 2.2 settled).
5. Add M15 rows to `docs/MANUAL_TESTS.md` as you go.

---

## Uncommitted state on this branch

Mine, this session and the previous one:
`lib/router.dart`, `lib/ui/shell/root_shell.dart`, `lib/ui/home/home_screen.dart`,
`lib/ui/history/history_screen.dart`, `lib/ui/settings/settings_screen.dart`,
`lib/ui/settings/settings_controls.dart` (new), `lib/ui/settings/garage_section.dart` (new),
`lib/ui/theme/section_label.dart` (new), `lib/ui/overlay/overlay_controller.dart`,
`lib/services/offer_log.dart`, `lib/domain/offer_summary.dart`,
`third_party/flutter_overlay_window/.../OverlayService.java`, `docs/MANUAL_TESTS.md`,
`test/navigation_test.dart` (new), `test/offer_log_dedupe_test.dart` (new),
`test/settings_screen_test.dart`.

Pre-existing dirty from an earlier session — **not mine, don't fold into a commit blindly**:
`lib/ui/home/slide_to_live.dart`, `lib/ui/onboarding/onboarding_screen.dart`,
`lib/ui/theme/hero_stage.dart` (new), `test/hero_stage_test.dart` (new),
`test/onboarding_test.dart`, `test/widget_test.dart`, and the `references/` asset shuffle.

Earlier work in these two sessions (shell navigation M13, Settings restructure M14) is
described in `docs/MANUAL_TESTS.md` under those headings.
