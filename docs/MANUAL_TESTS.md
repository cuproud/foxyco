# Manual Test Log

Hand-verify checklist. I keep it current as features land; you spot-check any
row, any time. Mark `[x]` pass / `[!]` fail (add a note), leave `[ ]` untested.
No need to check in order or all at once.

- **PASS bar** = the exact thing you should see. Numbers are fixed, not "about".
- **How** = the shortest path to trigger it.
- Fail a row? Write one line under it. I fix root cause, not the symptom.

Legend: 🟢 GOOD  🟡 OK  🔴 BAD (pill shows icon + WORD + `km · $payout`).

---

## M2 — Overlay (pill + bubble)

> Verified live on a Galaxy S24 (Android 16). Overlay window is a COMPACT box
> (bubble-sized at rest, grows to fit the pill) — it only captures touch over
> itself, never the whole screen.
>
> ⚠️ Vertical sticking under the status/nav bar is addressed by a "drop-to-
> dismiss" patch in the VENDORED plugin fork (`third_party/flutter_overlay_window`):
> releasing the bubble in the bottom nav-bar zone closes the overlay. Rows 2.10 /
> 2.14 were CODED but NOT yet device-verified (session ended first) — check these
> first next session.

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| 2.1 | Grant overlay, tap **Simulate offer** | Verdict pill floats on the right edge | [ ] |
| 2.2 | 1st Simulate offer | Pill: 🟢 **GOOD** · `8.4 km · $12` | [ ] |
| 2.3 | 2nd Simulate offer | Pill: 🟡 **OK** · `6.2 km · $7.50` | [ ] |
| 2.4 | 3rd Simulate offer | Pill: 🔴 **BAD** · `11 km · $6` | [ ] |
| 2.5 | 4th Simulate offer | Cycles back to 🟢 **GOOD** · `8.4 km · $12` | [ ] |
| 2.6 | Wait after a **Simulate** pill (no real card on screen) | Pill persists (no card to end it); clears via the 45 s safety net | [ ] |
| 2.7 | Tap a live pill | Dismisses early, back to fox bubble | [ ] |
| 2.8 | Tap the fox bubble | FoxyCo app comes to front | [x] verified on S24 2026-07-13 |
| 2.9 | Long-press the fox bubble | Fox dims (paused); long-press again un-dims | [ ] |
| 2.10 | Drag the bubble left / right | Snaps to the nearest side edge | [ ] |
| 2.11 | Tap **Hide** on Home | Overlay disappears | [ ] |
| 2.12 | Tap Simulate | NO bottom popup / snackbar appears | [ ] |
| 2.13 | With bubble showing, use the rest of the screen / nav bar | Touch works everywhere except on the bubble itself | [ ] |
| 2.14 | Drag the bubble down onto the nav bar and release | Overlay closes (drop-to-dismiss) | [ ] |

## M3 — Real offer reading (accessibility parser)

> ⚠️ Device-only — the accessibility plugin has no effect off-device. All Dart +
> native wiring is done and `flutter test` is green (parser fixtures + pipeline);
> these rows are the on-device confirmation that remains.
>
> Setup: build (`./scripts/build.sh debug`), install, open FoxyCo, tap **Fix
> permissions** → enable "FoxyCo" under Settings ▸ Accessibility, return to app.

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| 3.1 | Grant accessibility, return to Home | Status flips from **blocked** to **Watching for offers**; the Access permission chip goes green | [ ] |
| 3.2 | Revoke accessibility in system settings, return | Status flips back to **blocked** | [ ] |
| 3.3 | Open Uber Driver, receive/observe a real offer | Pill draws with 🟢/🟡/🔴 + `$pay · $X.XX/km · $Y/hr`, no manual tap, within ~0.3 s | [ ] |
| 3.4 | Same on **Hopp** | Pill draws; NET pay parsed; km = pickup + dropoff summed | [ ] |
| 3.5 | Confirm the summed distance | Pill km = pickup km **+** dropoff km (neither app shows this sum) | [ ] |
| 3.6 | Long-press bubble to pause, trigger an offer | NO pill (reads gated while paused) | [ ] |
| 3.7 | An Uber acceptance-rate-gated offer (no upfront numbers) | NO pill / no wrong verdict (fail safe) | [ ] |
| 3.8 | Hopp package name (confirmed `ee.hopp.driver` 2026-07-12) | Foreground package while a Hopp offer is up == `ee.hopp.driver`; keep `ParserRegistry` + `res/xml` in sync | [ ] |

### M3-rework — parsing correctness + overlay lifecycle (2026-07-12)

> The strict offer-detection contract (Accept/Match + clean payout + exactly-2
> km legs + no browse markers) and the offer-present overlay lifecycle. These
> are the fixes for the 10/100 device session — verify each on device via
> `adb logcat | grep "FoxyCo\[watch\]"` before ticking.
>
> **First, capture ground-truth nodes** (do NOT re-tune from screenshots): with
> logcat running, trigger a real Uber / Hopp / Lyft offer AND each app's
> browse/home screen. The `read pkg=… :: <nodes>` lines are your fixtures —
> paste any that parse wrong into the matching `test/parser/*` file.

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| 3.9 | Lyft **Ride Finder / online map** (bug1 6, 8) | NO pill — the `$37.64` streak banner and `$N Lyft · M min away` bubbles are never parsed | [ ] |
| 3.10 | Lyft **scheduled-rides** home list | NO pill — multiple legs / browse markers reject it | [ ] |
| 3.11 | Real Lyft offer card (bug1 1) | Pill draws `$10.05 · $0.85/km · $30/hr`, gross pay | [ ] |
| 3.12 | Hopp **407 toll** offer (toll line above payout) | Payout = the real net `$`, NOT the toll amount | [ ] |
| 3.13 | Offer card dismissed / driver leaves offer screen | Pill clears within ~1 s of the Accept/Match affordance leaving (not on a fixed timer); bubble remains | [ ] |
| 3.14 | Turn watching **ON** in-app (no Simulate tap) | Bubble appears on its own; **Pause** dims it; **Resume** un-dims | [ ] |
| 3.15 | **Drag** bubble far left/right | Whole pill/bubble stays on-screen, never stuck off-edge (bug1 7) | [ ] |
| 3.16 | **Tap** bubble | FoxyCo comes to the foreground | [x] verified on S24 2026-07-13 |
| 3.17 | **Drag bubble to bottom** drop zone | Overlay closes AND Home flips out of "Watching" (no desync) | [ ] |

### M3-lifetime — pill stays while the card is up, clears on action (2026-07-13)

> Fixes the two device findings on 2026-07-13: the pill auto-closed after ~5 s
> while the offer was still on screen (a live map/countdown card fires mostly
> partial frames, so full parses dried up and the old 3 s grace timer aged the
> pill out), and it should close promptly on accept/decline/dismiss. The pill's
> life is now gated on the card's **Accept/Match affordance** (present the whole
> time the card is up), not on the full parse. Verify via
> `adb logcat | grep "FoxyCo\[watch\]"`.

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| 3.18 | Real offer up; let the countdown run / pan the map behind it for 15–20 s | Pill **stays** the entire time (does NOT auto-close after ~5 s); no re-show flicker | [ ] |
| 3.19 | Decline the offer (or let it expire) → app returns to the map | Pill clears within ~1 s; bubble remains; no lingering pill over the map | [ ] |
| 3.20 | Accept the offer → trip screen | Pill clears within ~1 s (Accept/Match affordance gone) | [ ] |
| 3.21 | Logcat while a live card is up | See `read … Match/Accept` frames but NO `clear armed` line until the card actually leaves | [ ] |

## M1 — Verdict engine ($/km → verdict)

Defaults: **GOOD ≥ 1.5 $/km**, **BAD < 1.0 $/km**, OK is the band between.
Boundaries: GOOD inclusive, BAD exclusive. So `1.5` = GOOD, `1.0` = OK, `0.9` = BAD.

| # | Offer (payout ÷ km = $/km) | PASS bar | Status |
|---|----------------------------|----------|--------|
| 1.1 | $15 ÷ 6 = **2.50** | 🟢 GOOD | [ ] |
| 1.2 | $9 ÷ 6 = **1.50** (boundary) | 🟢 GOOD | [ ] |
| 1.3 | $6 ÷ 5 = **1.20** | 🟡 OK | [ ] |
| 1.4 | $5 ÷ 5 = **1.00** (boundary) | 🟡 OK | [ ] |
| 1.5 | $4 ÷ 5 = **0.80** | 🔴 BAD | [ ] |

## M1 — Settings (thresholds live preview)

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| S.1 | Open Settings | GOOD slider = **1.50**, BAD slider = **1.00** | [ ] |
| S.2 | Drag GOOD below BAD | GOOD clamps, never drops under BAD | [ ] |
| S.3 | Move a slider | Live preview verdict updates immediately | [ ] |
| S.4 | Pickup guard slider | Default **2.0 km**, range 0.5–10 | [ ] |
| S.5 | Toggle off Uber + Hopp, try Lyft | Last app refuses to switch off | [ ] |
| S.6 | Pill size → Large, trigger pill | Pill draws large; survives app restart | [ ] |
| S.7 | Retention → 7 days | Offers older than 7 days vanish from History | [ ] |
| S.8 | Clear offer history | Confirm dialog → log empties, Home tally 0/0/0 | [ ] |
| S.9 | Kill + reopen app | All settings above persist | [ ] |

## Home dashboard + History (real offer log, 2026-07-16)

Demo data removed — tally/ticket/history are live from logged offers only.
"Show a demo pill" draws a pill but must NOT log anything.

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| H.1 | Fresh install, open Home | Tally **0 · 0 · 0**, ticket = "No offers yet" | [ ] |
| H.2 | Tap "Show a demo pill" | Pill draws; tally stays **0 · 0 · 0**, History count unchanged | [ ] |
| H.3 | Real offer appears (Uber/Hopp/Lyft) | Tally increments for its verdict; Last-offer ticket matches pill numbers | [ ] |
| H.4 | Open History | Same offer listed under **Today** with exact fare/km | [ ] |
| H.5 | History filters | Range/app/top-offers chips narrow the live list (no mock rows anywhere) | [ ] |
| H.6 | Kill + reopen app | Tally, ticket, and History survive restart | [ ] |
| H.7 | Tap **Pause** | Status flips watching ↔ paused | [ ] |

## M4 — Onboarding (first run, 2026-07-16)

3 swipeable pages: intro → overlay grant → accessibility grant (with the
plain-language, read-only disclosure). "Skip for now" always exits to Home.

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| O.1 | Fresh install (or clear app data), open app | Boots into onboarding "Meet FoxyCo", NOT Home — no Home flash first | [ ] |
| O.2 | Page 3 text | States plainly: reads ONLY pay+distance, sends nothing anywhere, **never taps buttons / accepts rides** | [ ] |
| O.3 | Page 2 "Grant Display over other apps" | System overlay settings opens; grant; return → button becomes **✅ Granted** | [ ] |
| O.4 | Page 3 "Grant Accessibility Access" | Accessibility settings opens; enable FoxyCo; return → **✅ Granted** | [ ] |
| O.5 | Both granted → "Start driving smarter" | Lands on Home, status **watching**, bubble up | [ ] |
| O.6 | Kill + reopen app | Boots straight to Home — onboarding never shows again | [ ] |
| O.7 | Fresh install, tap "Skip for now" | Lands on Home, status **blocked**, "Fix permissions" visible | [ ] |
| O.8 | After O.7, kill + reopen | Still boots to Home (skip also marks onboarding done) | [ ] |

## Resilience — live permission revoke (2026-07-16)

The OS pushes accessibility on/off changes; the dashboard must react without
waiting for an app resume.

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| R.1 | While watching, revoke FoxyCo in system Accessibility settings | Dashboard flips **blocked** + overlay tears down as soon as you return (no restart) | [ ] |
| R.2 | Re-enable the service in settings | Dashboard back to **watching**, bubble returns | [ ] |
| R.3 | While explicitly Paused, R.2's re-enable | Stays **Paused** (never un-pauses by itself) | [ ] |

## History — shift summary card (2026-07-16)

Rollup card above the offer list, computed over the FILTERED offers (so it
follows the range/app/top chips). Hidden when no offers match.

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| SS.1 | History with logged offers | Card shows OFFERS n (g·o·b), GOOD AVG $/km, BEST $/km + app, BUSIEST hour | [ ] |
| SS.2 | Narrow to one app chip | All four figures recompute for that app only | [ ] |
| SS.3 | Range with zero offers | Card gone, empty state shows | [ ] |
| SS.4 | Only BAD offers in range | GOOD AVG shows **—** (not $0.00) | [ ] |

## Settings — $/km vs $/hr rate mode (2026-07-16)

Segmented toggle above the threshold sliders. Each mode keeps its own cut
points ($/km: 1.50/1.00 · $/hr: 30/20). Offers with no parsed minutes fall
back to $/km scoring even in $/hr mode.

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| RM.1 | Settings → tap **$/hr** | Sliders re-range 10–60, defaults **30.00 / 20.00**, preview + band re-label /hr | [ ] |
| RM.2 | Change $/hr cuts, flip to $/km and back | $/km cuts untouched; $/hr cuts kept | [ ] |
| RM.3 | Real offer in $/hr mode (Hopp/Lyft carry minutes) | Verdict matches payout ÷ minutes × 60 vs the $/hr cuts | [ ] |
| RM.4 | Offer with no time data in $/hr mode | Still gets a verdict — scored by $/km (never blank, never all-BAD) | [ ] |
| RM.5 | Kill + reopen | Mode + both cut pairs persist | [ ] |

## Settings — parser health (2026-07-16)

Session-only per-app counters: successful parses vs card-like frames
(Accept/Match affordance present) that failed the full parse while nothing was
showing. Misses with zero successes ⇒ "Needs update".

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| PH.1 | Fresh session, Settings | Every watched app shows **No offers yet**; unwatched shows dimmed **Off** | [ ] |
| PH.2 | Real offer parses (pill drew) | That app flips to **OK · n read** | [ ] |
| PH.3 | Simulate breakage: 10+ offer cards arrive, none parse (only testable when a parser actually breaks) | App shows **Needs update** | [ ] |
| PH.4 | After PH.3, one successful parse | Flag clears back to **OK** | [ ] |
| PH.5 | Restart app | Counters reset (session-only by design) | [ ] |

---

_Last updated: 2026-07-16 (rate-mode RM-rows, shift-summary SS-rows, resilience R-rows, onboarding O-rows added; real offer log; settings expanded)._
