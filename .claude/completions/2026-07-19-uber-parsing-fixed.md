# Uber parsing FIXED — 2026-07-19 (P1 closed)

Uber was FoxyCo's only P1: offers never parsed on device across three sessions
(07-13, 07-18, 07-19 morning). Verified working live today: Match (Trip Radar)
AND Accept (Exclusive) cards parse, pill shows on both, clears ~0.5 s after the
card leaves. OCR fallback is DEAD — not needed, do not build it.

## The three stacked root causes (each masked the next)

1. **Frame-killing NPE in the a11y fork** —
   `AccessibilityListener.getSubNodes` null-checked `windowInfo` then called
   `node.getWindow()` THREE more times; on transient card windows the re-call
   returned null → NPE unwound the whole recursion into `processEvent`'s catch
   → the ENTIRE frame was discarded. Every card frame contains card nodes, so
   every card frame died; stable map-only frames sailed through (that's why
   logs showed only map text). Proof: `E EVENT ... isActive() on a null object
   reference` in logcat at card time + event-stream gaps exactly spanning each
   card's lifetime. Fix: reuse the single `getWindow()` result + per-node
   try-catch so a dying node skips only its own subtree.

2. **Uber marks card views `accessibilityDataSensitive` (anti-bot)** — after
   fix 1, card frames arrived but every node was TEXTLESS (walk of 183-224
   nodes, `withText=23`, all map chrome) while `uiautomator dump` (shell-
   privileged) saw full card text in the same second. Android 14+ strips
   sensitive views from services not declared as accessibility tools. Fix:
   `android:isAccessibilityTool="true"` in
   `android/app/src/main/res/xml/accessibilityservice.xml`. (Play-review
   caveat noted below.)

3. **Uber's fullscreen Accept/Exclusive activity sets
   `FLAG_HIDE_NON_SYSTEM_OVERLAY_WINDOWS`** — pipeline parsed `$3.86 →
   Verdict.ok` and "showed" the pill, but the bubble/pill window
   (TYPE_APPLICATION_OVERLAY) was hidden by the OS for exactly the card's
   lifetime. Match/Radar cards are dialogs without the flag — that's why only
   Match pills were ever seen. Fix: overlay window now attaches through the
   a11y service's WindowManager as **TYPE_ACCESSIBILITY_OVERLAY** (exempt by
   design). `OverlayService` borrows it via reflection
   (`AccessibilityListener.getA11yWindowManager()`), falls back to the old
   type when the service is off.

## Parser fixes that the window-merge exposed

- `_notPayout` now also filters `extra|quest|promotions?` — the map's Quest
  banner ("$20 extra for 30 trips") walks BEFORE the card and was winning the
  first-$ scan.
- `findPayout` skips amounts ≤ 0 — the map's earnings chip ("Home | $0.00")
  made `looksLikeOfferCard` true on every between-offers frame, so the pill
  clear timer was cancelled forever (pill sat until the next offer).
- `_browseMarker` gained Uber home-map hallmarks `finding trips|trip
  planner|go offline` → pill clears in ~clearGrace instead of riding the
  5 s minVisible floor.
- `UberParser` already accepted `Match` via `_acceptAction` — Radar cards
  needed no parser change. Stacked Radar frames observed so far carry ONE
  card's text at a time.

## Debugging landmines (cost hours — remember these)

- **`uiautomator dump` SUPPRESSES other a11y services while it runs.** A dump
  loop during live offers poisons the very logs you're comparing against.
  Dump for ground truth, but treat service logs from dump windows as invalid.
- **`adb install -r` multi-user Samsung**: installs to dual-app user 95 too.
  ALWAYS `adb install -r --user 0` (memory: install-user-0-only).
- After every reinstall the user must toggle the a11y service OFF→ON.
- Wireless debugging port changes on every reconnect; phone IP can too.

## Verified live (device logs)

- 12:05:58 `Uber $2.94 2.3km → Verdict.ok` (Match) — pill visible
- 12:07:27 `Uber $5.12 4.0km → Verdict.ok` (Accept — pill hidden pre-fix-3)
- 12:22:07 `Uber $3.86 2.9km → Verdict.ok` (Accept — pipeline OK, window
  hidden; THE screenshot that proved fix 3)
- Post-fix-3: user confirms 2 Accept offers pilled + cleared correctly.

## Loose ends

- `FOXYCO_WALK` diagnostic logging (AccessibilityListener) still in the debug
  build — 2 log lines per event. STRIP before any release build, keep while
  device debugging continues.
- `isAccessibilityTool="true"`: fine for sideload; revisit wording/policy if
  FoxyCo ever goes to Play review.
- Radar stacks with 2+ cards' text in ONE frame haven't been observed yet; if
  one appears, first `away`/`trip` rows win (top card) — acceptable.
- Tests 162/162, analyzer clean. All work UNCOMMITTED on `m6-showroom` along
  with 07-18 work (user hasn't asked to commit).
