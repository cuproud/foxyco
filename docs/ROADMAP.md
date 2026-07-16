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

## M3 — Uber + Hopp parser (2–3 days)  🎯🧱  ← the hard part  ✅ CODE-COMPLETE (device verify pending)

Goal: real offers get read and analyzed automatically.

- [x] Add `flutter_accessibility_service` (^1.2.0, pinned per AUDIT #9). Service declared in
      `AndroidManifest.xml` + `res/xml/accessibilityservice.xml`, scoped to `com.ubercab.driver` +
      the Hopp package, `canRetrieveWindowContent=true`, read-only (no `canPerformGestures` — AUDIT #2)
- [x] Request accessibility permission via the plugin (`AccessibilityWatcher.requestPermission`);
      Home "Fix permissions" wires it, lifecycle-resume re-checks. (Standalone onboarding = M4)
- [x] Stream window events → flattened node-text list per event (`AccessibilityWatcher.reads()`)
- [x] `parser/`: `OfferParser` interface + `UberParser` + `HoppParser` (regex anchors from
      REFERENCE_ANALYSIS.md) + `ParserRegistry` (dispatch by foreground package)
- [x] Map parsed text → `Offer` (with `payIsNet` for Hopp, +pickup/dropoff **minutes** for $/hr),
      hand to `DecisionEngine.evaluateOffer`, push verdict to overlay (`OfferWatcher` pipeline)
- [x] Handle: no upfront data (Uber gate) / one-leg / missing pay / garbage → `null` (fail safe)
- [x] Debounce content events (250 ms) + dedupe identical reads (battery — AUDIT #4)
- [x] **Fixture tests**: node dumps from the reference layouts → assert parsed `Offer` (both parsers,
      incl. boundaries + null cases) + an `OfferWatcher` pipeline test (parse→score→pill, pause gating)
- [ ] ⏳ **Device verification** — plugin only runs on a real device. Build, grant accessibility,
      open Uber/Hopp, confirm a live offer draws the pill. See MANUAL_TESTS M3 rows.
- [ ] ⏳ **Confirm the Hopp package name** — `com.hopp.driver` is a PLACEHOLDER in `ParserRegistry`
      + `res/xml`. Dump the foreground package on device and correct BOTH if wrong.

**Done when:** a real Uber or Hopp offer pops → pill shows correct verdict in <300 ms, no manual tap.
*(All Dart + native wiring + tests done; `flutter test` green, debug APK builds. Needs a device run.)*

> ⚠️ Selectors WILL break when Uber/Hopp update their apps. Keep each parser isolated + version-tagged
> (`OfferParser.tunedAgainst`). See AUDIT.md "parser fragility."

---

## M4 — Home screen + polish pass (1–2 days)  🎯

Goal: a real app around the engine. Simple, clean.

- [x] Home: status cards (service on/off, overlay permission, accessibility permission, "watching
      for offers"), today's tally (good/ok/bad counts — count only, no graphs)
- [x] Onboarding: walk the driver through the 2 permissions (overlay + accessibility) clearly
      (`ui/onboarding/` — 3 pages, plain-language read-only disclosure, skip allowed, first-run gate)
- [x] Offer log: log each seen offer (platform, payout, km, verdict, timestamp) for the tally +
      future analytics — SharedPreferences JSON (`services/offer_log.dart`), not Drift; capped +
      retention-purged, plenty for MVP 🧱
- [x] First-run empty states, permission-denied states
- [x] Wire everything through Riverpod providers

**Done when:** fresh install → onboarding → grant permissions → drive → home shows today's counts.
*(Code-complete 2026-07-16; needs device run — MANUAL_TESTS O-rows.)*

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

Profit engine (fuel/wear/tax) · ~~auto-accept/decline~~ (**NEVER — product rule 2026-07-16:
FoxyCo is strictly manual/read-only; it never acts inside another app. ToS risk, see AUDIT**) ·
voice announce ·
mileage GPS tracking · expense manager + OCR · analytics/heatmaps · AI insights · goals ·
cloud backup · more platforms (Lyft, Skip, Instacart, Flex, Spark). Full list in the
original `project.txt`. Each is a new layer hanging off the same clean core.

---

## Sequencing rule

Logic (M1) before overlay (M2) before real data (M3) before looks (M5). If a milestone slips,
ship it as-is and move on — an ugly working verdict beats a beautiful fake one.
