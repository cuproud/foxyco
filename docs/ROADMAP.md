# FoxyCo — Roadmap & Build Steps

Milestone-driven. Each milestone is shippable and testable on its own. Don't start the next
until the current one runs on a real phone. **We build the boring skeleton first, make it
actually detect a real Uber/Hopp offer, THEN make it pretty.**

Legend: 🎯 = MVP-critical · 🧱 = foundation for later · 💤 = deferred (not built now)

---

## M0 — Project skeleton (½ day)  🧱  ✅ DONE

Goal: empty Flutter app installs and opens on a phone.

- [x] `flutter create` → package `com.foxyco.app`, Android-only, min SDK 26 / target 35
      (`android/app/build.gradle.kts`)
- [x] `pubspec.yaml`: `flutter_riverpod`, `go_router`. `lib/` structured per ARCHITECTURE.md
- [x] `ProviderScope` + go_router wired
- [x] Runs, shows the FoxyCo dashboard. App icon + splash + "FoxyCo" label wired.

**Done when:** `flutter run` builds and opens the app on device. ✅

---

## M1 — Settings + verdict engine (1 day)  🎯🧱  ✅ DONE (persistence deferred)

Goal: the brain works, no overlay yet. Pure logic + a settings screen — fully unit-testable.

- [x] Defaults seeded: GOOD ≥ $1.50/km, OK $1.00–1.49, BAD < $1.00 (`Thresholds.defaults`)
- [x] `domain/`: `Verdict`, `Thresholds`, `DecisionEngine.evaluate` — pure Dart, no Flutter
- [x] Settings screen (thresholds sliders + **live verdict preview**), wired via Riverpod, clamps band
- [x] **Unit tests** for DecisionEngine: every branch + boundaries (at-threshold, zero km)
- [ ] 💤 SharedPreferences persistence — thresholds are in-memory for now; persist in M3 alongside offers

**Done when:** change a threshold in settings, unit test proves the verdict flips correctly. ✅

---

## M2 — Overlay rendering (1–2 days)  🎯  ✅ CODE-COMPLETE (device verify pending)

Goal: a fake offer draws the pill + bubble over another app. Still no real data.

- [x] Add `flutter_overlay_window` + `permission_handler`. Request "Display over other apps"
      (`OverlayService`, `AndroidManifest.xml` SYSTEM_ALERT_WINDOW + special-use FGS)
- [x] Overlay entrypoint (`@pragma('vm:entry-point') overlayMain()` in main.dart → `FoxOverlayApp`)
- [x] **Bubble**: fox dot pinned to edge, long-press = pause/resume, tap = open FoxyCo
      (drag/snap via plugin `positionGravity: auto`)
- [x] **Pill**: single-line, top-dropped, three sizes S/M/L, shape+color+word verdict
- [x] Cross-isolate: `shareData` map, `kind`-tagged (`offer`/`control`/`action`); fails safe on garbage
      — offer main→overlay, action (bubble gesture) overlay→main, control (paused/clear) main→overlay
- [x] Debug button "Simulate offer" on Home → rotates GOOD/OK/BAD over whatever's on screen
- [x] Auto-dismiss pill after 12s timeout (window stays alive, bubble persists)
- [ ] 💤 Persist last pill position (SharedPreferences) — deferred; plugin `positionGravity` handles snap for now
- [ ] ⏳ **Device verification** — plugin overlay only runs on real device/emulator, not `flutter test`.
      Build with `./scripts/build.sh --bump`, install, tap Simulate offer, confirm pill floats.

**Done when:** tap "simulate offer", pill appears over any app showing `GOOD · 8 km · $12`,
bubble drags around and sticks. *(All wiring + widgets + unit/widget tests done; needs a device run.)*

> ⚠️ Flutter gotcha: the overlay runs in a **separate isolate**. It can't read your Riverpod
> providers directly — pass data across with `FlutterOverlayWindow.shareData()` and listen with
> `overlayListener`. Keep the payload a tiny map. (See ARCHITECTURE "Isolate note".)

---

## M3 — Uber + Hopp parser (2–3 days)  🎯🧱  ← the hard part

Goal: real offers get read and analyzed automatically.

- [ ] Add `flutter_accessibility_service`. Configure the accessibility service (declare in
      `AndroidManifest.xml` + `accessibilityservice` config resource) for `com.ubercab.driver` and
      the Hopp package. `canRetrieveWindowContent=true`
- [ ] Request accessibility permission via the plugin; onboarding explains why
- [ ] Stream window events; grab the node list (text + bounds) per event
- [ ] `parser/`: `OfferParser` interface + `UberParser` + `HoppParser` (regex on node text, see
      REFERENCE_ANALYSIS.md for the exact anchors)
- [ ] Map parsed text → `Offer` (with `payIsNet` for Hopp), hand to `DecisionEngine`, push verdict to overlay
- [ ] Handle: no upfront data (Uber acceptance-rate gate), weird formats, offer disappears mid-parse
- [ ] Debounce content events + dedupe identical offers (battery — see AUDIT #4)
- [ ] **Fixture tests**: capture real node dumps, assert parsed `Offer`. One per format change

**Done when:** a real Uber or Hopp offer pops → pill shows correct verdict in <300 ms, no manual tap.

> ⚠️ Selectors WILL break when Uber/Hopp update their apps. Keep each parser isolated + version-tagged.
> See AUDIT.md "parser fragility."

---

## M4 — Home screen + polish pass (1–2 days)  🎯

Goal: a real app around the engine. Simple, clean.

- [ ] Home: status cards (service on/off, overlay permission, accessibility permission, "watching
      for offers"), today's tally (good/ok/bad counts — count only, no graphs)
- [ ] Onboarding: walk the driver through the 2 permissions (overlay + accessibility) clearly
- [ ] Drift DB: log each seen offer (platform, payout, km, verdict, timestamp) for the tally + future analytics 🧱
- [ ] First-run empty states, permission-denied states
- [ ] Wire everything through Riverpod providers

**Done when:** fresh install → onboarding → grant permissions → drive → home shows today's counts.

---

## M5 — Visual identity pass (1–2 days)  🎯

Goal: NOW make it premium. Lock the visual language from UI_DESIGN.md, apply design tokens.

- [ ] Lock visual direction (proposed in UI_DESIGN.md — Kinetic HUD / Aurora Glass / Neo-Tactile)
- [ ] App icon (fox), verdict color system, typography, motion (subtle: fade, count-up, elevation)
- [ ] Apply to overlay pill/bubble + home + settings + onboarding
- [ ] Dark mode first (drivers drive at night), OLED-friendly. Golden tests on the pill

**Done when:** it looks like something you'd pay for. Screenshot-worthy.

---

## M6 — Third platform / harden parser (2 days)  🧱

Goal: prove the parser abstraction scales. Add another platform (e.g. DoorDash or Lyft) without
touching DecisionEngine/overlay.

- [ ] New `OfferParser` impl for the next package, handles its quirks gracefully
- [ ] Platform auto-detect by foreground package
- [ ] Per-platform tally

**Done when:** three platforms analyzed, zero changes to business logic.

---

## Later (💤 — NOT now, architecture only)

Profit engine (fuel/wear/tax) · auto-accept/decline (⚠️ ToS risk, see AUDIT) · voice announce ·
mileage GPS tracking · expense manager + OCR · analytics/heatmaps · AI insights · goals ·
cloud backup · more platforms (Lyft, Skip, Instacart, Flex, Spark). Full list in the
original `project.txt`. Each is a new layer hanging off the same clean core.

---

## Sequencing rule

Logic (M1) before overlay (M2) before real data (M3) before looks (M5). If a milestone slips,
ship it as-is and move on — an ugly working verdict beats a beautiful fake one.
