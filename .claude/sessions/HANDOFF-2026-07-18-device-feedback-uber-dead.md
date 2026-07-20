# HANDOFF — Device-feedback fixes round + Uber still dead (2026-07-18)

**Prior context:** `.claude/sessions/HANDOFF-2026-07-13-m3-device-verified.md`
(OPEN BUG 1 there = the same Uber problem, with the a11y-tree investigation
plan) and `.claude/completions/2026-07-18-device-feedback-fixes.md` (full root
causes of everything fixed today). This doc is the state of the world for the
next session.

## TL;DR
Three rounds of on-device feedback fixed today (all shipped, 160/160 tests,
analyzer clean): stop-slider was physically impossible, cream-on-cream "Off"
chip, name save affordance, pill font + animated plasma verdict ring, demo
button under the nav bar, and TWO overlay-lifecycle bugs around the demo pill.
**Uber remains completely dead on device even on the latest build** — it is
now FoxyCo's only P1. Hopp + Lyft parse fine. Hero-card redesign is designed,
awaiting user's pick of 3 options.

## P1 — Uber: what we know across both sessions
- 07-13 session: real Uber offer card text is EXACTLY our regex format —
  `UberParser` would parse it. But full live sessions show ZERO reads
  containing `$`/`km`/`Accept`; only background-map text arrives
  (`Trip Planner`, `1-2 min`, `Finding trips`). The offer card appears to be
  a **separate window/surface that never reaches the a11y service**.
- Today: user re-verified on the latest build — "uber doesn't work at all".
- Diagnostic added today: `PlatformHealth.textlessFrames` — watched-app frames
  with zero readable text now count per platform; ≥10 with 0 parses renders
  "Unreadable · OCR needed" in Settings → Parser health.
  **CAVEAT for next session:** if Uber's map text keeps arriving (as 07-13
  logs show), frames are NOT textless — the counter may never trip and the row
  will show "No offers yet" or card misses instead. The user hasn't reported
  what the row actually says. **First step next session: ask, or pull logs.**

### Next-session decision tree (in order)
1. Get the user to read Settings → Parser health Uber row after a live Uber
   session with ≥1 real offer, or `adb logcat -d | grep FoxyCo` during one.
2. With a LIVE offer on screen: `adb shell uiautomator dump` (USER 0 — never
   `--user 95`, see memory) and check whether the dump contains the payout /
   `Accept` nodes.
   - Nodes present → our service/flatten drops that window. Fix in plugin
     window traversal (config already has `flagRetrieveInteractiveWindows`;
     the plugin may only walk the event's source window — likely needs
     `getWindows()` traversal in a plugin fork).
   - Nodes absent → a11y-hostile surface; only screen-capture path helps.
3. OCR fallback (user already endorsed this flow: a11y event → capture →
   detect card → OCR → extract → overlay). Requires TWO new dependencies,
   both need explicit user approval per CLAUDE.md:
   - screenshot: `AccessibilityService.takeScreenshot()` (API 30+) — NOT in
     flutter_accessibility_service 1.2.0; needs fork or custom channel.
   - OCR: `google_mlkit_text_recognition` (on-device, offline).
   - Constraint: strictly read-only observation (memory: never act in gig
     apps). OCR must only read — no taps, ever.

## Fixed today (9 items, all verified by tests; on-device confirmation via
## docs/MANUAL_TESTS.md §M6.1 rows M6F.1–M6F.13, mostly unchecked)
1. Slide-to-stop dead → thumb rested at LEFT end so a leftward drag had zero
   travel; now rests RIGHT, drags left (`slide_to_live.dart`).
2. Blank white pill top-right when offline → cream-on-cream "Off" chip; now
   dark chip + border (`home_screen.dart` `_LivePill`).
3. Name save → labeled orange Save button + keyboard-Done + snackbar
   (`settings_screen.dart` `_DriverNameCard`; FilledButton needed
   `minimumSize: Size(0,44)` — theme default explodes in a Row).
4. $/km font → Fraunces w700; all pill text has explicit families (overlay
   isolate has no theme → silent Roboto fallback) (`verdict_pill.dart`).
5. Plasma ring → `_PlasmaBorder`/`_PlasmaPainter` in `verdict_pill.dart`:
   verdict-colored orbiting arcs, 2.4 s loop; `animate: false` for settings
   preview/tests; reduced-motion freezes it.
6. Textless-frame diagnostic (see P1 above) — `accessibility_watcher.dart` no
   longer swallows empty reads; `parse_health.dart` + settings health row.
7. Demo button under floating nav → Home ListView bottom pad now adds
   `MediaQuery.padding.bottom` (`home_screen.dart`).
8. Offline demo left bubble lingering → demo timer status-checks: offline →
   `hide()` window; live → `clearPill()` (`overlay_controller.dart`).
9. Garbled "bubble" after offline demo → `closeOverlay` kills the WINDOW but
   the overlay ISOLATE + widget state survive; next bubble-sized window
   rendered the stale pill clipped into 72 dp. Fix: `startWatching` sends
   clearPill when it CREATES the window (skips when active so live pills
   survive); `hide()` clears pill before closing (`overlay_service.dart`).
   **Lesson for all future overlay work: the overlay isolate is immortal
   across window sessions — never assume fresh state on window creation.**

## Awaiting user decisions
- **Hero card redesign**: user hates the vector car. 3 animated options in
  `references/foxyco_hero_options.html` (A Showroom Spotlight / B HUD
  Platform / C Garage Portrait — details in the completion doc). After the
  pick: implement hero + onboarding vehicle picker (Garage data already
  exists: `garage_controller.dart`, `vehicle_editor_screen.dart`).
- **OCR dependencies** (P1 step 3) if the a11y route is confirmed dead.

## State
- Branch `m6-showroom`, all today's work UNCOMMITTED (user hasn't asked to
  commit). `git status`: 9 modified + completion doc + hero options html +
  3 stray reference PNGs (user's own, leave them).
- Tests 160/160, analyzer clean.
- Memory files updated: `uber-parses-nothing-suspect-canvas.md` (needs the
  07-13 nuance above folded in if Uber sends map text — check first),
  `hero-card-redesign-pending.md`.
