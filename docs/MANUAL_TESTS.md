# Manual Test Log

Hand-verify checklist. I keep it current as features land; you spot-check any
row, any time. Mark `[x]` pass / `[!]` fail (add a note), leave `[ ]` untested.
No need to check in order or all at once.

- **PASS bar** = the exact thing you should see. Numbers are fixed, not "about".
- **How** = the shortest path to trigger it.
- Fail a row? Write one line under it. I fix root cause, not the symptom.

Legend: 🟢 GOOD  🟡 OK  🔴 BAD (pill shows icon + WORD + `km · $payout`).

## History backup smoke

| # | How | PASS bar | Status |
|---|---|---|---|
| B.1 | Create offers, manually change an outcome and final payout, then Settings → History → Export CSV backup | File contains the versioned FoxyCo header and opens safely in a spreadsheet | [ ] |
| B.2 | Import that file and choose Merge, including ordinary ride rows with no delivery counts | Rows return with manual outcome, final payout, detected outcome and original scoring details intact; no duplicate cards | [ ] |
| B.3 | Import the same file and choose Replace | History contains exactly the backup rows; canceling the picker/dialog changes nothing | [ ] |
| B.4 | Try an old report CSV, malformed CSV, and oversized file | Import rejects each before changing history and shows a generic error | [ ] |
| B.5 | Stop a session, then Settings → History → Clear all history | History is empty and Home no longer shows the saved Last session card, including after restart | [ ] |

---

## Current upload quick smoke (10–15 minutes)

Run these before promoting the AAB. They cover the highest-risk build changes
without requiring DoorDash, Instacart or Skip accounts.

**Current candidate:** Play bundle build 92. Real-device validation is
pending for accessibility-first Uber parsing, OCR fallback, cross-app capture,
and Accessibility-only non-Uber offers.

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| Q.1 | Install from the Play test track → Settings → About | About shows the new bumped build; startup and four-tab navigation work | [ ] |
| Q.2 | Rules → Watched apps | Existing selection survived upgrade; fresh install has no apps selected; Uber says **Includes Uber Eats** | [ ] |
| Q.3 | Try enabling a fourth app; then turn one off and enable Skip | Fourth is blocked; after freeing a slot Skip enables and Home shows exactly the selected apps | [ ] |
| Q.4 | Leave only Lyft selected, force-stop and reopen | Lyft remains the only watched app; disabled-app events cannot produce a pill | [ ] |
| Q.5 | Leave only Lyft/Hopp on, then enable Uber and open Delivery rules | Card is always visible but disabled for Lyft/Hopp-only; Uber enables it because it includes Eats; settings persist independently from ride thresholds | [ ] |
| Q.6 | History → App filters after enabling each delivery app | DoorDash, Instacart and Skip filters appear when selected or represented in History | [ ] |
| Q.7 | Settings → Text size → Small/Medium/Large; open every tab | No overflow, clipped headers or overlapping bottom navigation; Pill size/preview does not change | [ ] |
| Q.8 | Settings support rows at Large text | Send feedback, About and Diagnostic logs align and wrap without truncating their titles | [ ] |
| Q.9 | Select Uber, then trigger one real Uber/Lyft/Hopp offer | Uber OCR turns on automatically; all three show one correct pill/History row | [ ] |
| Q.10 | With an older Play build installed and the new test release available, foreground FoxyCo | Update prompt appears once per foreground session and opens the Play update flow | [ ] |
| Q.11 | Drag the bubble through the visible ✕ toward the bottom edge until the ✕ turns red, then release | Light haptic fires; overlay closes and Home leaves Watching. Releasing before red or canceling the drag does not stop the service | [ ] build 66 retest |
| Q.12 | Trigger update success, Google sign-in cancel/failure, and Name saved | Every message is a floating FoxyCo surface with 16dp corners and orange outline; no default solid-black bar | [ ] build 66 |

---

## Delivery beta + app text size (2026-08-20)

DoorDash, Instacart and Skip are off by default. Their parsers are seeded from public
offer cards; do not mark the live rows passed until matching real-device cards
have been captured and redacted.

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| D.1 | Fresh install → Rules → Watched apps | Uber says **Includes Uber Eats**; Uber, Lyft and Hopp are on; DoorDash, Instacart and Skip show **Beta** and are off | [ ] |
| D.2 | With three apps on, try enabling a fourth | Fourth switch is disabled and says **Turn off another app first** | [ ] |
| D.3 | Leave only Lyft on, kill and reopen FoxyCo | Only Lyft remains on; Home Ready card shows Lyft only | [ ] |
| D.4 | Leave only Lyft/Hopp on, then enable Uber or DoorDash | **Delivery rules** remains visible but disabled first, then enables; Uber Eats/delivery offers use it while ride rules remain unchanged | [ ] |
| D.5 | Enable each delivery beta and open History filters | DoorDash, Instacart and Skip app filters are available | [ ] |
| D.6 | Real DoorDash delivery card with guaranteed pay and route distance | One beta offer logs with exact payout/distance; absolute **Deliver by** time is not treated as duration | [ ] |
| D.7 | Real DoorDash retail/batched card | Items and order count match the card in offer details and CSV | [ ] |
| D.8 | Real Instacart shop-and-deliver batch | Payout, route distance, orders, items and units match the card | [ ] |
| D.9 | Instacart Shop Only/list screen or incomplete delivery card | No pill and no History row (fail safe) | [ ] |
| D.10 | Settings → Text size → Small, Medium, Large; inspect every tab at 320dp and system font 200% | No clipped text, overflow or overlap; floating pill size does not change | [ ] |
| D.11 | Real Skip detailed offer | Exact complete pay and total travel distance log once; arrival clock times are not treated as duration | [ ] |
| D.12 | Skip home/earnings, partial offer and Shop + Pay variants | Home/earnings/partial screens show no pill; explicit Shop + Pay items appear in details/CSV | [ ] |

---

## M2 — Overlay (pill + bubble)

> Verified live on a Galaxy S24 (Android 16). Overlay window is a COMPACT box
> (bubble-sized at rest, grows to fit the pill) — it only captures touch over
> itself, never the whole screen.
>
> ⚠️ Vertical sticking under the status/nav bar is addressed by a "drop-to-
> dismiss" patch in the VENDORED plugin fork (`third_party/flutter_overlay_window`):
> dragging through the visible ✕ to the bottom edge until it turns red, then
> releasing, closes the overlay. Rows 2.10 /
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
| 2.14 | Drag the bubble through the visible ✕ toward the bottom edge until it turns red, then release; repeat but release before red; interrupt/cancel a drag | Target gives one light haptic; only release after the red state closes the overlay | [ ] build 66 retest |

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
| 3.13 | Accept a Hopp offer and progress through **Arrived → Waiting/Start Trip → End Trip → Confirm Price → Rate passenger** | History marks the offer **Accepted** after the first strong trip state; no rider name/address is stored | [ ] |
| 3.14 | Decline or let a Hopp offer expire and return to its browse/home map | History marks the offer **Not taken**; an ambiguous blank/navigation frame stays **Unconfirmed** | [ ] |
| 3.15 | Offer card dismissed / driver leaves offer screen | Pill clears within ~1 s of the Accept/Match affordance leaving (not on a fixed timer); bubble remains | [ ] |
| 3.16 | Turn watching **ON** in-app (no Simulate tap) | Bubble appears on its own; **Pause** dims it; **Resume** un-dims | [ ] |
| 3.17 | **Drag** bubble far left/right | Whole pill/bubble stays on-screen, never stuck off-edge (bug1 7) | [ ] |
| 3.18 | **Tap** bubble | FoxyCo comes to the foreground | [x] verified on S24 2026-07-13 |
| 3.19 | **Drag bubble onto the visible ✕** and release | Overlay closes AND Home flips out of "Watching" (no desync) | [ ] |

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
| H.5 | History filters | Range/app/verdict/top-offers controls narrow the live list (no mock rows anywhere) | [ ] |
| H.6 | Kill + reopen app | Tally, ticket, and History survive restart | [ ] |
| H.7 | Tap **Pause** | Status flips watching ↔ paused | [ ] |
| H.8 | History → Trip status → **Accepted** | Only confirmed accepted offers remain; header, stats and charts share that count. **All** restores every outcome | [ ] |

## M4 — Onboarding (first run, 2026-07-16)

5 swipeable pages: intro → rules → trial/lifetime → overlay grant →
accessibility grant (with the plain-language, read-only disclosure). "Skip for
now" always exits to Home.

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| O.1 | Fresh install (or clear app data), open app | Boots into onboarding "Meet FoxyCo", NOT Home — no Home flash first | [ ] |
| O.2 | Accessibility page text | States plainly: temporarily reads offers from selected supported apps; stores only extracted offer numbers locally; raw text is not saved or sent; **never taps, accepts or declines** | [ ] |
| O.3 | Page 4 "Display over other apps" | System overlay settings opens; grant; return → button becomes **✅ Granted** | [ ] |
| O.4 | Page 5 "Offer access" | Accessibility settings opens; enable FoxyCo; return → **✅ Granted** | [ ] |
| O.5 | Both granted → "Finish setup" | Lands on Home, ready to go live | [ ] |
| O.6 | Kill + reopen app | Boots straight to Home — onboarding never shows again | [ ] |
| O.7 | Fresh install, tap "Skip for now" | Lands on Home, status **blocked**, "Fix permissions" visible | [ ] |
| O.8 | After O.7, kill + reopen | Still boots to Home (skip also marks onboarding done) | [ ] |
| O.9 | After O.7, tap **Fix permissions** with Accessibility off | FoxyCo shows the full read-only offer-access disclosure before Android Accessibility settings | [ ] |
| O.10 | Tap **Not now**, then **Fix permissions** again | Settings does not open after declining; the disclosure appears again on the next attempt | [ ] |

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

## Overlay responsiveness + read pipeline (2026-07-17 bug batch)

Fixes: a11y event processing moved off the main thread (unresponsive
bubble/pill root cause), duplicate-window node walk removed (doubled leg math),
opaque TextureView made translucent (dark gradient box), node LruCache bounded.

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| OV.1 | Long session (30+ min) in Hopp/Lyft with offers streaming | Bubble stays draggable/tappable the whole time — no freeze, no force-close needed | [ ] |
| OV.2 | Tap bubble mid-offer-storm | FoxyCo foregrounds within ~1 s | [ ] |
| OV.3 | Real offer, compare pill to card | Pill km/min/$ EXACTLY match the card's summed legs (e.g. 2-leg 4.5+15.1 km card ⇒ 19.6 km, never 39.2) | [ ] |
| OV.4 | Look behind bubble AND pill on a light map | No dark box/gradient/halo behind either — fully transparent around the widgets | [ ] |
| OV.5 | Decline/dismiss an offer | Pill drops to bubble within ~1–2 s (clearGrace + isolate wake), never sticks to the 45 s timer | [ ] |
| OV.6 | Offer appears | Pill within ~1 s of the card (parse no longer lags seconds behind) | [ ] |

---

## M5 — Polish & Control (2026-07-17)

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| M5.1 | Settings → Pill size Large, tap "Show a demo pill" | Pill renders LARGE (window ~348×100dp); Small/Medium likewise exact | [ ] |
| M5.2 | Change size while a pill is up | Live pill keeps its size; NEXT offer uses the new size | [ ] |
| M5.3 | Drag large pill to either edge | Still draggable — window under 360dp never pins mid-screen | [ ] |
| M5.4 | Drive a session, `adb install -r` a new build, open Settings → Diagnostic logs | Pre-update lines still present | [ ] |
| M5.5 | Logs → copy | Clipboard holds the tail; Clear (confirm) empties viewer | [ ] |
| M5.6 | Fill profile name+vehicle in Settings, back to Home | Hero card: greeting, vehicle line, tinted silhouette matches type+color | [ ] |
| M5.7 | Clear profile name | Card gone; dashboard exactly as before | [ ] |
| M5.8 | Fresh install, grant both permissions | Bubble does NOT appear until Start Monitoring tapped | [ ] |
| M5.9 | Start → kill app → relaunch | Boots STOPPED (never auto-watching) | [ ] |
| M5.10 | While watching: bubble long-press pause, resume | Pause/resume unchanged, layered under Start/Stop | [ ] |

---

## M6 — Showroom (dark UI, garage, slide-to-live, splash) (2026-07-18)

> Whole app went dark green-black ("showroom"). New: garage with multiple
> vehicles, slide-to-go-live control (replaces the Start button), animated
> splash. Overlay/pill/parse untouched — OV + M5 rows below still hold.

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| M6.1 | Cold-start the app | Dark splash: wordmark fades in + car drives in over ≈1.8 s, then crossfades to Home. Total never exceeds 3 s | [ ] |
| M6.2 | Enable "Remove animations" (OS a11y), cold start | Static logo ~0.5 s, NO car sweep, then Home | [ ] |
| M6.3 | Drag the bolt thumb ≥85% right | Medium haptic; control morphs to a Live bar with a pulsing dot; watching starts | [ ] |
| M6.4 | Drag thumb ~40% and release | Springs back with overshoot, light haptic, stays STOPPED (no watch) | [ ] |
| M6.5 | While live, drag thumb back left | Watching stops; bar morphs back to the slide track | [ ] |
| M6.6 | TalkBack on, focus the control | Announced as "Go live" / "Stop" button; double-tap activates it | [ ] |
| M6.7 | Install over an M5 build that had a saved profile | The saved vehicle appears in Garage as active; name preserved; 0 data lost | [ ] |
| M6.8 | Add a 2nd vehicle, set active, edit it, delete the active one | Active switches on tap; deleting active falls back to the remaining vehicle; hero card follows the active one | [ ] |
| M6.9 | Edit a vehicle, change its color, press Cancel | 0 changes persisted — hero card AND garage tile unchanged | [ ] |
| M6.10 | Set device clock to 23:30, open Home | Greeting reads "Late shift, &lt;name&gt;" (NOT "Good evening") | [ ] |
| M6.11 | With yesterday-only offers, open History on the Today filter | Header shows "0 today"; body shows "N offers outside these filters" with a Show-all reset | [ ] |
| M6.12 | View Home + History outdoors in bright light | Verdict colors + all text stay legible on the dark cards | [ ] |
| M6.13 | Re-run OV.1 and OV.6 (bubble + pill flows) | Behavior IDENTICAL to M3/M5 — overlay was untouched in M6 | [ ] |

---

## M6.1 — Device-feedback fixes (2026-07-18, post-install review)

> From on-device review: stop slider dead, blank white pill when off, no name
> save affordance, pill font, plasma ring, Uber never parsing.

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| M6F.1 | Go live, then drag the stop thumb LEFT from the RIGHT end of the bar | Thumb rests at the right end (Live label + "slide back to stop" fully readable, nothing covered); dragging ≥85% left stops watching — no force-close needed | [ ] |
| M6F.2 | While live, drag stop thumb ~40% left and release | Springs back to the right end, light haptic, stays LIVE | [ ] |
| M6F.3 | Home while NOT live | Top-right chip reads "Off" — grey text on a dark chip with a hairline border. NO blank white pill | [ ] |
| M6F.4 | Settings → type a new name | An orange "Save" button (labeled, not just an icon) appears next to the field; tapping it saves, keyboard closes, "Name saved" snackbar shows; keyboard Done key also saves | [ ] |
| M6F.5 | Settings → name unchanged | No Save button visible (field clean = nothing to save) | [ ] |
| M6F.6 | Trigger a demo/real pill | $/km figure renders in Fraunces serif (matches the big "37" on Home); "/km", "km", "$/hr" all in Inter — no Roboto mix | [ ] |
| M6F.7 | Watch the pill for ~3 s | Animated ring around the pill: two bright arcs orbiting a faint outline, GREEN on good / YELLOW on ok / RED on bad. Moving, not static | [ ] |
| M6F.8 | OS "Remove animations" on, trigger a pill | Ring present but STATIC (color signal kept, no orbit) | [ ] |
| M6F.9 | Go live, open Uber Driver, wait for ≥10 offer frames, then Settings → App health → Offer detection | Uber row reads "Unreadable · OCR needed" (red) if Uber sends textless frames — NOT "No offers yet" | [ ] |
| M6F.10 | Scroll Home to the bottom on a gesture-nav phone | "Show a demo pill" fully visible ABOVE the floating nav; tappable without fighting the bar | [ ] |
| M6F.11 | While OFFLINE (stopped), tap "Show a demo pill" | Pill shows ~5 s, then pill AND bubble disappear completely — no lingering bubble while the dashboard says stopped | [ ] |
| M6F.12 | While LIVE, tap "Show a demo pill" | Pill shows ~5 s, then retracts to the resting bubble (bubble stays — you're still watching) | [ ] |
| M6F.13 | While OFFLINE: demo pill → let it vanish → go LIVE | A clean fox BUBBLE appears — never clipped/garbled pill text in a bubble-sized box | [ ] |

---

## M7 — Uber parsing fixed (2026-07-19, verified live on device)

> Historical live-device fixes: fork NPE on transient card windows and the
> accessibility overlay needed over Uber's Accept card. Current releases set
> `isAccessibilityTool=false`; optional Uber OCR handles hidden card text.
> Rows M7.1–M7.4 were all PASSED live on 2026-07-19 (logs in completion doc).

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| M7.1 | Live + Uber online, wait for a Trip Radar "Match" card | Pill shows with the card's payout (e.g. $2.94 — never the Quest "$20 extra" or the $0.00 earnings chip) | [x] |
| M7.2 | Same for a fullscreen "Accept" (Exclusive) card | Bubble AND pill stay VISIBLE on top of the card (not hidden by Uber) and pill shows the card payout | [x] |
| M7.3 | Let a card expire / dismiss it | Pill retracts to bubble within ~1–2 s of the map returning — does NOT sit until the next offer | [x] |
| M7.4 | Between offers, watch the map ≥30 s | No pill appears from map chrome ($0.00 chip, Quest banner, ETA bubbles) | [x] |
| M7.5 | After any FoxyCo reinstall | `adb install -r --user 0` ONLY; then toggle the a11y service OFF→ON or nothing parses | [ ] |

_Last updated: 2026-07-19 (M7 rows: Uber Match/Accept parsing, pill visibility on Accept cards, pill clear; M7.1–M7.4 verified live)._

---

## M8 — Device feedback round 2 (2026-07-19)

> Logs section removed from Settings; pill centered on screen; full-fox bubble
> asset; verdict chips + top-offers fix in History; pill legend + Large-preview
> overflow fix; smooth pill→bubble retract; swipe-away kills the session
> honestly; FOXYCO_WALK diagnostics gated off (battery).

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| M8.1 | Open Settings, scroll | NO "Logs" section between Parser health and History | [ ] |
| M8.2 | Live + real/demo offer with the bubble parked on an edge | Pill appears HORIZONTALLY CENTERED on the screen — not pinned left/right | [ ] |
| M8.3 | Let the pill clear | Bubble returns to the SAME edge it was parked on before the offer | [ ] |
| M8.4 | Look at the bubble | Full fox head visible incl. both ears (no clipping) on the dark disc | [ ] |
| M8.5 | Demo pill → wait for retract | Pill cross-fades to bubble smoothly — no hard snap/clip mid-fade | [ ] |
| M8.6 | History → verdict chips | Good/OK/Bad chips filter the list; "All" resets; combines with app + range chips | [ ] |
| M8.7 | History → "Filter by minimum fare" ≥ $15 with OK/BAD offers over $15 logged | Those offers SHOW (fare floor only — verdict no longer forces GOOD) | [ ] |
| M8.8 | Settings → pill size Large on a narrow phone | Preview scales down to fit — no yellow/black overflow stripes | [ ] |
| M8.9 | Settings → below the preview | "How to read it" legend: verdict block, green km, red km, $/hr rows | [ ] |
| M8.10 | Go live, swipe FoxyCo out of Recents, reopen | Dashboard shows STOPPED (not a stale "online"); bubble gone | [ ] |
| M8.11 | Watch logcat during a live Uber session | No FOXYCO_WALK spam (gated behind DEBUG_WALK=false) | [ ] |

| M8.12 | Drag the bubble anywhere | A compact white ✕ target appears at screen bottom with **no full-width tint/mask**; gone the instant you release or within 2.5 s if Android cancels the gesture | [ ] |
| M8.13 | Drag the bubble INTO the bottom strip | ✕ turns solid red + swells while finger is in the zone; release closes the session (dashboard flips to stopped) | [ ] |
| M8.14 | Drag near-but-above the strip and release | ✕ stays neutral, bubble parks at the bottom edge, session KEEPS running | [ ] |
| M8.15 | With FoxyCo itself foregrounded, drop the bubble on the ✕ | Bubble closes AND dashboard flips to stopped (messenger no longer loops back to the overlay isolate) | [ ] |

---

## M9 — Car hero (photographic splash + home showroom) (2026-07-20)

> Splash and home hero now composite the layered car renders in assets/car/
> (stealth + reveal sets). Supersedes M6.1/M6.2 pass bars.

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| M9.1 | Cold-start the app | 3-act splash ≈2.2 s: dark car fades from black → headlights/grille FLICKER on → full-color reveal blooms + wordmark. Total never exceeds 3.5 s | [ ] |
| M9.2 | Enable "Remove animations" (OS a11y), cold start | Static full-reveal car + wordmark ~0.5 s, NO animation, then Home | [ ] |
| M9.3 | Home while STOPPED | Hero card shows the dark stealth car (lights off, fog) | [ ] |
| M9.4 | Slide to go live | Car cross-fades to the lit full-color reveal over ≈0.6 s; stopping fades it back to stealth | [ ] |
| M9.5 | Watch the home car ~10 s | Gentle float (±6 px) + glow pulse loops; no jank, no layer misalignment | [ ] |
| M9.6 | "Remove animations" on, open Home | Car is STATIC (no float/pulse); state crossfade is instant | [ ] |
| M9.7 | Home page at open (no scroll) | Slide-to-go-live fully visible above the fold; car has side margins | [ ] |
| M9.8 | Brand bar + onboarding + empty ticket | Full fox head (ears, no disc, no stray dots); floating bubble still round disc | [ ] |

_Last updated: 2026-07-20 (M9: layered car hero on splash + home)._

---

## M10 — Premium polish pass (2026-07-20)

> Batches 1–3: gesture-inset padding, Reset confirm, presets, hourly chart,
> offer detail sheet, shift recap, CSV export, 4-page onboarding.

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| M10.1 | Settings + History, scroll to very bottom on a gesture-nav phone | Last card/text fully visible above the floating nav (nothing clipped) | [ ] |
| M10.2 | Home last-offer ticket with a 2-digit distance (e.g. 11.0 km) | Number scales down to fit — never "11.0 …" ellipsis | [ ] |
| M10.3 | Settings → $/km-$/hr toggle | Selected segment text is CREAM on orange tint (readable), not dark red | [ ] |
| M10.4 | Settings → Reset (top right) | Confirm dialog appears; Cancel keeps settings; Reset restores defaults | [ ] |
| M10.5 | First day of use (no yesterday data) | Hero trend chip reads "first day", not "+N vs yesterday" | [ ] |
| M10.6 | Device set to 12-hour clock | Ticket + History times show "6:48 PM" style, not 18:48 | [ ] |
| M10.7 | History → tap any offer row (also Home ticket) | Bottom sheet: verdict, big fare, per-km/hr, pickup/trip/ride cells, plain-language verdict math line | [ ] |
| M10.8 | My Rules → Verdict thresholds ($/km mode) | Relaxed / Balanced / Picky chips; tap moves both sliders; band shows colored cut-point labels | [ ] |
| M10.9 | History with offers | "BY HOUR" 24-bar chart under stats; peak bar solid orange with count label; sparse 12A/6A/12P/6P axis | [ ] |
| M10.10 | Go live, let ≥1 offer arrive, slide to stop | Shift recap sheet: duration, offers scored, good/ok/bad pills, best $/km, busiest hour | [ ] |
| M10.11 | Slide to stop with 0 offers seen | NO recap sheet (silent stop) | [ ] |
| M10.12 | Settings → History → Export CSV | Android share sheet with foxyco_offers.csv; opens with correct header + rows | [ ] |
| M10.13 | Fresh install → onboarding | 5 pages: fox intro → Set your bar → trial/lifetime → overlay grant → accessibility grant; active dot stretches to a pill | [ ] |
| M10.14 | Onboarding last page WITHOUT accessibility granted | Main action reads "Enable offer access" and the separate exit reads "Finish setup without it" | [ ] |
| M10.15 | Home hero → tap the U/L/H platform badges | Jumps to Settings tab | [ ] |
| M10.16 | Tap filters/chips/nav across the app | Subtle haptic tick on each selection | [ ] |
| M10.17 | History stats card | OFFERS sub-line shows counts in verdict colors (green·amber·red), not plain "2·7·2" | [ ] |
| M10.18 | History → 7 Days filter at day boundary | Includes today + 6 prior days only (8th day excluded) | [ ] |

_Last updated: 2026-07-20 (M10: premium polish batches 1–3)._

### M10 addendum — outcome inference (2026-07-20)

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| M10.19 | Let an offer expire / decline it (app returns to map) | History row shows small ✕ by the time; detail sheet says "Likely passed" | [ ] |
| M10.20 | Accept an offer (app goes to pickup navigation) | History row shows green ✓; detail sheet says "Likely taken" | [ ] |
| M10.21 | While card is up, switch away to FoxyCo then back | No outcome stamped (stays unmarked) — heuristic must not guess | [ ] |
| M10.22 | Export CSV after M10.19/20 | outcome column present: taken / missed / unknown | [ ] |

### M10 addendum 2 — outcome toggle, reminders, emojis (2026-07-20)

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| M10.23 | Settings → Outcome tracking | "Guess taken / passed" switch ON by default + explainer note underneath | [ ] |
| M10.24 | Toggle outcome tracking OFF, run an offer past | Offer logs with NO ✓/✕ mark (unknown) | [ ] |
| M10.25 | Settings → Car reminders → Add reminder | Sheet: preset chips (inspection/insurance/oil/plates/tires/service), title field, date picker, lead chips (3d/1w/2w/1mo), note field; Save disabled until title+date | [ ] |
| M10.26 | Save "Safety inspection" dated ~2 weeks out, lead 1 month | Row shows icon + date + amber "in 14d" pill; Home shows amber banner "Safety inspection in 14 days"; banner tap jumps to Settings | [ ] |
| M10.27 | Edit reminder → Delete (trash) | Row gone; Home banner gone | [ ] |
| M10.28 | Set reminder date to yesterday | Red "1d overdue" pill + red Home banner | [ ] |
| M10.29 | Kill + reopen app | Reminders persist | [ ] |
| M10.30 | Home greeting across day parts | Plain greeting changes between Good morning / afternoon / evening / Late shift; no decorative food emoji | [ ] |

---

## M11 — Settings redesign (accordion, money font, garage silhouettes) (2026-07-21)

> Settings regrouped into 11 single-open accordion cards; new Appearance
> money-font picker (Space Grotesk asset) that re-skins every $ figure app-wide
> incl. the overlay pill; CustomPainter vehicle silhouettes per body type; car
> reminders capped to 3 with a "Show all" expander.

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| M11.1 | Open Settings | 11 collapsed group cards; **Driver** open by default; opening any other group collapses the previous; the chevron rotates on open/close | [ ] |
| M11.2 | Settings → Appearance → money font | 3 font cards each preview **"$24.50"** in their own face; tapping one instantly re-skins the Home hero + History amounts; survives kill + reopen | [ ] |
| M11.3 | Switch font, then trigger the next offer | The pill's $ figures render in the newly-picked font (font survives the overlay payload round-trip) | [ ] |
| M11.4 | Garage with vehicles of each body type | Silhouette matches type (sedan/SUV/hatch/pickup/van/bike) at row size; color tint + EV badge intact | [ ] |
| M11.5 | Car reminders with 5+ saved | List shows 3 rows + **"Show all (5)"**; expand/collapse toggles the rest; group summary count is correct | [ ] |

---

## M12 — polish pass + light theme (2026-07-25)

> Full-width glass go-live cue; card overflow audit; garage art sizing; About
> screen; bubble no longer lingers outside the gig apps; last-session recap
> card; and a light ("paper") theme selectable in Settings → Appearance.

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| M12.1 | Home → drag the go-live cue right, slowly | Full-width glass track; thumb follows the finger 1:1; releasing before the end springs back with no state change; past the end it goes live once (no double-fire) | [ ] |
| M12.2 | Settings → Garage → edit a vehicle, save | Editor reopens with the saved values (no blanked fields); silhouette + tint match the saved body type at both row and editor size | [ ] |
| M12.3 | Settings → About | Version, build, the credits/legal copy and every link render; back returns to Settings with the same group still open | [ ] |
| M12.4 | Go live, catch one offer, then leave the gig app (Home / recents / another app) | Pill clears within a second of leaving; it does NOT reappear on the launcher or in unrelated apps | [ ] |
| M12.5 | End a shift, then reopen the app the next calendar day | Last-session card still shows yesterday's totals (survives the day boundary) and is labelled as the previous session, not today | [ ] |
| M12.6 | Settings → Appearance → Theme = **Light**, then walk outside in daylight | Cream paper chrome, ink text legible in glare, every screen (Home / History / Settings / Logs / sheets) flips — no cream-on-cream or black-on-black text anywhere | [ ] |
| M12.7 | In Light, look at the Home car | Car sits in a **rounded dark showroom panel** with the cards' radius + shadow — a deliberate frame, not a gray halo with hard edges | [ ] |
| M12.8 | In Light, trigger an offer | Overlay pill stays **dark** (it lives in its own isolate and floats over other apps) — verdict colors and $ figures unchanged | [ ] |
| M12.12 | In Light, every card: Home receipt, Last session, History stats, **Top offers**, offer detail sheet, shift recap, vehicle editor preview | Card interiors are **white/near-white with ink text** — no dark receipt cards marooned on cream paper. Verdict hues go to their deeper tier so GOOD/OK/BAD still read as text | [ ] |
| M12.13 | In Light, Settings → Appearance | All three **$24.50** font samples are readable (they were cream-on-cream); the selected one on its orange tint too | [ ] |
| M12.14 | In Light, Home top-left | **"Good morning, Vamsi"** is visible (was invisible — cream on cream) | [ ] |
| M12.15 | Both themes, bottom nav | Active tab is an inverted chip: dark fill + light label in Light, cream fill + dark label in Dark. Never same-on-same | [ ] |
| M12.16 | Both themes, Settings → Pill size → "How to read it" | All four legend swatches visible, including the pale cream **$/hr** dot (it has a hairline so it survives a white card) | [ ] |
| M12.17 | My Rules → Verdict thresholds | Each slider has **−/+** buttons flanking it; one tap moves 5c ($ mode) or 0.1 (km); they dim out at each end of the range and land on exact values | [ ] |
| M12.18 | Settings → Garage → cycle Body through all 13 types | Every vehicle renders at a **similar visual size** — the Jeep/EV/Premium/bike no longer float small in the card (their art had 37-62% dead canvas). Two-wheelers still read smaller than a van | [ ] |
| M12.19 | Home, before dragging | Slide track is a recessed well in the card; label is high-contrast; the chevron train is clearly visible and marches right (was faint smudges). The gleam sweeping the track is a warm orange wash — **no gray/metallic smear** | [ ] |
| M12.20 | In Light, Home segment bar + History "BY APP" bars | Segments are clean **green / amber / red**, not olive-and-maroon — solid fills keep the bright tier in both themes | [ ] |
| M12.21 | In Light, Home "14 good / 47 ok / 56 bad" chips | Each word is legible on its tinted well — these carry text, so they take the deeper tier (the bright tier washed out once the card went white) | [ ] |
| M12.22 | Both themes, anywhere an Uber offer shows (Home dots, History rows, detail sheet, pill) | Uber roundel is **near-white with a dark U** in Dark and **near-black with a white U** in Light — never a pale disc with an invisible letter. Lyft pink / Hopp blue unchanged in both | [ ] |
| M12.23 | ~~In Light, the Home car panel~~ | ~~Dark `#111416` panel with a spotlight floor~~ — **superseded by M12.31**: the light-mode panel is now white | — |
| M12.24 | Both themes, any screen with cards | Cards have **two-stage depth** — a tight contact shadow at the edge plus a wide soft ambient one. No single gray halo ring | [ ] |
| M12.25 | Both themes, scroll any page slowly | Page background is a faint top-to-bottom wash (brighter at the top), not a flat fill. Should be almost subliminal — if you can clearly *see* a gradient it's too strong | [ ] |
| M12.26 | Home segment bar + History "BY APP" bars | Three separated rounded lozenges in a track, each top-lit — not one solid saturated stripe. Home bar is 11dp, History 10dp | [ ] |
| M12.27 | Home "47 ok" chip, both themes | Label is full-strength amber (was dimmed 10%), clearly readable against its tinted well | [ ] |
| M12.28 | Switch Light→Dark→Light from Settings, then go to Home **without scrolling** | Greeting, and every other label, is in the NEW palette immediately — no text left painted in the old theme's color. (Tab scroll positions reset on a switch; that's expected) | [ ] |
| M12.29 | Theme = Auto, flip system dark mode while sitting on Home | Same: the whole page repaints at once, no stale text | [ ] |
| M12.30 | Home → Last session card | Timer icon is vertically centred against the **4h 16m** digits, not riding above them | [ ] |
| M12.31 | In **Light**, Home car card | A **white** showroom card (same gradient/radius/shadow as the receipt card below), with a soft cream ellipse behind the car — NOT the old dark panel. The black body reads crisply; no grey fog haze, no red bloom, no floor reflection | [ ] |
| M12.32 | In Light, slide to go live and watch the car card | Card edge picks up the warm orange border + glow (matching the receipt card); car lights, grille and body accent come on; still no fog/backlight haze on the white | [ ] |
| M12.33 | In **Dark**, Home car | Unchanged — full-bleed on the page with every glow layer, no frame | [ ] |
| M12.34 | Both themes, the row directly above the car card | Left: a chip with a dot + **Live Status** over **Offline/Live/Paused/Access needed**. Right: sun (06–19) or moon glyph + **time** over **date**. Nothing sits on top of the car | [ ] |
| M12.35 | Sit on Home across a minute boundary (e.g. 8:44 → 8:45) | The clock flips **at the boundary**, matching the phone's own clock — not up to a minute late | [ ] |
| M12.36 | Phone set to 24-hour time, then to 12-hour | The above-car clock follows the phone's format (`20:45` vs `8:45 PM`) | [ ] |
| M12.37 | Home header, live and off | Fox head + **FoxyCo** only — no Live/Off pill on the right. State is readable from the above-car chip and the slide bar | [ ] |
| M12.38 | Bottom nav, both themes | Active tab sits on a **brand-orange** pill with a soft orange glow; its icon **and** label are deep green-black ink, both clearly legible. Inactive tabs unchanged | [ ] |
| M12.39 | Bottom nav, tap between tabs | The orange pill slides; no frame where the icon vanishes (orange-on-orange) mid-slide | [ ] |
| M12.40 | Home slide bar, off state | Chevrons march the track but **dissolve around "Slide to go live"** — no chevron crossing the words. Same when font scale is set to max | [ ] |
| M12.41 | Home slide bar, live state | Same: the left-marching train clears "Live · slide back to stop" and only runs in the open stretch toward the thumb | [ ] |
| M12.42 | **Dark**, Home car | Now a framed stage, not full-bleed: `#13171B→#1C2127` card, 1px white hairline, a wide ambient ellipse behind the car, a glowing amber **platform ring** on the wheel line with a warm pool inside it, and a dark contact shadow under the body | [ ] |
| M12.43 | ⚠️ **Ring alignment**, both themes | The ring sits ON the wheel-contact line — not cutting the tyres, not floating below them. If it's off, tune `HeroStageMetrics.groundY` (0.84) — it's the one value that can't be derived | [ ] |
| M12.44 | Watch the car for ~10 s, both themes | Body drifts **±2 px** over 4 s; the contact shadow tightens slightly as it rises; the ring glow breathes 0.15→0.35 on the same 4 s; the ambient ellipse breathes on a slower 6 s. Nothing bounces or shimmers | [ ] |
| M12.45 | Watch for ~20 s | Roughly every 8 s a soft highlight crosses the bodywork over ~1 s. It must stay **on the paint** — if any of it slides across empty card, the sweep mask is misaligned with the car | [ ] |
| M12.46 | In Light, the whole stage | Same composition at half strength: cool-white ambient, softer amber ring, lighter contact shadow. Card is still white and still matches the receipt card | [ ] |
| M12.47 | Settings → Accessibility → Remove animations ON, Home | Car is dead still: no float, no ring pulse, no ambient breath, **no sweep** | [ ] |
| M12.48 | Scroll Home hard up and down for ~30 s | No jank — the stage should hold 60 fps (car is behind a RepaintBoundary; only the glow layers repaint) | [ ] |
| M12.49 | Fresh install → wizard page 1 | A **"What should I call you?"** field under the intro copy. Keyboard does NOT pop by itself. Leaving it empty and continuing still works | [ ] |
| M12.50 | Type a name, swipe through to the end, finish | Home greets you by name immediately (`Late shift, <name>`) — no trip to Settings → Profile. Settings → Profile shows the same name | [ ] |
| M12.51 | Type a name, then **Skip for now** on page 1 | Same: the name is saved on the way out either exit | [ ] |
| M12.52 | Type `  spaces  ` around a name | Saved trimmed; capped at 24 characters | [ ] |
| M12.53 | Wizard last page | With access granted, only "Finish setup" appears. Without access, "Enable offer access" and "Finish setup without it" are clearly separate choices | [ ] |
| M12.54 | Finish the wizard, then force-stop the app immediately and relaunch | Boots to Home, **not** back into the wizard (the onboarded flag is now written before navigation) | [ ] |
| M12.55 | TalkBack on, walk the wizard | Page dots are silent (decorative). After granting a permission and returning, the **"✅ Granted"** state is announced instead of silently swapping in | [ ] |
| M12.9 | Theme = **Auto**, flip the phone's system dark mode | App follows immediately, no restart | [ ] |
| M12.10 | Pick Light, kill + reopen the app | Still Light. Launch stays on the dark stage the whole way in — native window, car splash, wordmark all one green-black surface with NO cream flash — and only Home arrives in paper | [ ] |
| M12.11 | Same in Dark | Identical launch: no cream flash at any point (the old launch window was still cream from before the app went dark) | [ ] |

_Last updated: 2026-07-25 (M12: polish pass + light theme; white car card + above-car status/clock)._

## M13 — Navigation flow

| # | Step | Expect | Pass |
|---|------|--------|------|
| M13.1 | On **History**, press system back (gesture or button) | Lands on **Home**, app still open. Press back again → app goes to background | [ ] |
| M13.2 | Same from **Settings** | Same: back = Home first, only then out | [ ] |
| M13.3 | On Home, press back straight away | Leaves the app immediately (no extra tap swallowed) | [ ] |
| M13.4 | Home hero, tap the **app badges** on the status row | My Rules opens with **Watched apps** expanded and scrolled into view | [ ] |
| M13.5 | With a reminder due, tap the **amber reminder banner** | Settings opens with **Garage** expanded and scrolled into view | [ ] |
| M13.6 | After M13.4, leave and tap My Rules by hand | The accordion is left exactly as you had it — the deep link fires once, not every visit | [ ] |
| M13.7 | Home → **Last session** card (needs one finished shift) | Tapping it switches to **History**. The empty "No sessions yet" card is NOT tappable | [ ] |
| M13.8 | Scroll any tab down, then tap **that same tab** in the nav | Scrolls back to the top with an animation. Tapping a different tab still just switches | [ ] |
| M13.9 | Scroll Home down, switch to History, come back | Home is still where you left it (re-tap only fires on the active tab) | [ ] |
| M13.10 | Settings, scroll to the bottom | **Help & support** groups **Send feedback**, **About FoxyCo**, and **Diagnostic logs** | [ ] |
| M13.11 | Tap **Diagnostic logs** | The existing log tail opens with email, copy, and clear actions | [ ] |
| M13.12 | Tap **Send feedback** | Four categories, description, optional screenshot picker, privacy note, and disabled Send action render | [ ] |
| M13.13 | Enter feedback and add three screenshots | A chooser opens with tester recipient, runtime version/device context, and three readable attachments; no logs are included | [ ] |
| M13.14 | Go live, let a real offer pill appear, then **tap the bubble** | App comes forward on **History** with that offer's detail sheet already open | [ ] |
| M13.15 | Let the pill clear (offer leaves the screen), then tap the bubble | App comes forward on whatever tab you left it on — no stale sheet | [ ] |
| M13.16 | Tap the bubble after **Show a demo pill** | Same: no sheet (demo pills are never logged, so there's nothing to open) | [ ] |

## M14 — Rules and Settings structure

| # | Step | Expect | Pass |
|---|------|--------|------|
| M14.1 | Inspect the bottom navigation | Four one-tap destinations appear in order: **Home · Rules · History · Settings** | [ ] |
| M14.2 | Open Rules | **Verdict thresholds** is open; Live preview, Pickup guard and Watched apps are on the same page and save immediately | [ ] |
| M14.3 | Tap a Rules group open, then another | Still single-open — the first collapses. Band headers don't move except by the height the accordion gives back | [ ] |
| M14.4 | Open Settings and scroll top to bottom | Scoring controls are absent; account/car, App health, look & feel, data and access controls remain | [ ] |
| M14.5 | Accessibility → Remove animations ON, open Settings | Every group is in place on the first frame; band rules render normally | [ ] |
| M14.6 | Home → tap the app badges (M13.4) | Lands on Rules with **Watched apps** expanded and scrolled into view | [ ] |
| M14.7 | Compare the band rules against Home's "LAST SESSION" and History's date headers | Identical treatment — same small-caps weight, same gap, same hairline (all three now come from one widget) | [ ] |

## M15 — 2026-07-26 device bugs

| # | Step | Expect | Pass |
|---|------|--------|------|
| M15.1 | Go live; let a real pill show and clear; repeat 5× | Bubble stays a clean circle throughout — **no grey square** behind it at any point. This resize cycle is what used to break it | [ ] |
| M15.2 | Between cycles, drag the bubble to the left edge, then the right | Still clean, both edges; pill still centres and the bubble returns to the edge you left it on | [ ] |
| M15.3 | Same check on the pill itself | No grey box behind the verdict pill either | [ ] |
| M15.4 | Mid-session, switch to History, scroll down, then tap the bubble | FoxyCo comes forward **on History, still scrolled** — not a fresh Home. Losing your place was the "it crashed" report | [ ] |
| M15.5 | Take ~10 real offers, open History | No two adjacent rows identical (same app, tier, fare, distance, minute). Was two `Uber Share $10.19 · 11.7 km · 2:49 PM` rows | [ ] |
| M15.6 | Compare Home's today tally against the History row count | Match. The duplicate rows were double-counting the tally, good-average $/km, busiest hour and the by-hour chart | [ ] |
| M15.7 | Two genuinely different offers seconds apart (e.g. $10.19 and $10.20) | Both logged — de-dupe compares platform, fare, distances and duration, not just timing or late labels | [ ] |
| M15.8 | On one active Lyft card, wait while bonus / queue labels finish rendering | One verdict pill and one History row only | [ ] |
| M15.9 | Let a Hopp card disappear within two seconds of its verdict | The verdict remains visible for at least five seconds total, then clears | [ ] |
| M15.10 | Capture an offer whose fields animate in after the first window event | A complete frame is picked up by the bounded follow-up reads; logcat does not continue scanning between events | [ ] |
| M15.11 | Keep FoxyCo, Uber and Lyft open; switch between them through 10+ pill→bubble cycles | Bubble and pill remain fully transparent outside their shapes — no grey window-sized mask | [ ] |
| M15.12 | Receive two Uber offers close together, accept only the newer one, then stay on its pickup/trip screen for several accessibility events | Only the newer History row becomes **Accepted**; the older row remains **Unconfirmed** | [ ] |
| M15.13 | History → tap an offer's status pill → choose Accepted, Not taken, then Unconfirmed | Card updates immediately, survives app restart, and later app events do not overwrite the manual choice | [ ] |
| M15.14 | Rules → Voice verdict → Preview voice | Android speaks one short sample using the phone's configured system voice | [ ] |
| M15.15 | Turn Voice verdict ON; receive GOOD, OK and BAD offers | Only each new GOOD offer is spoken; re-rendering one card does not repeat it | [ ] |
| M15.16 | With voice ON, trigger several GOOD offers quickly | The newest announcement replaces the previous speech; no delayed spoken backlog remains | [ ] |
| M15.17 | Fresh install from a Play testing track in each supported country, then open Settings → Appearance | Currency defaults from the Play storefront (USD/CAD/AUD/NZD/MXN/BRL); changing it only relabels fares and thresholds—no FX conversion | [ ] |

## M15A — automatic Uber OCR

| # | Step | Expect | Pass |
|---|---|---|---|
| OCR.1 | Fresh install → Rules → Watched apps | No apps are selected and Uber OCR is off | [ ] |
| OCR.2 | Select Uber, force-stop and reopen FoxyCo | Uber remains selected and OCR remains enabled | [ ] |
| OCR.3 | Unselect Uber | OCR turns off immediately; selecting Uber again restores it | [ ] |
| OCR.4 | Present accessibility-readable Uber, Lyft and Hopp offers while OCR is approved | All three parse immediately through Accessibility; no screenshot is requested for the readable Uber card | [ ] |
| OCR.5 | Present an Uber card known to expose an empty/incomplete Accessibility tree | One rate-limited OCR frame is recognized on-device and feeds the Uber parser; one verdict/history row | [ ] |
| OCR.5a | Present unreadable Lyft, Hopp or delivery-app text while Uber OCR is approved | No OCR-derived verdict; those platforms remain Accessibility-only | [ ] |
| OCR.5b | Stay in Lyft or Hopp and let an Uber request draw over it | The originating Uber event triggers OCR without switching apps; a later Lyft/Hopp offer still parses immediately through Accessibility | [ ] |
| OCR.6 | Keep the card active through repeated events, then animate/dismiss it so one OCR read changes a distance | No overlapping work, repeated audio/verdict, duplicate History row, or one-frame verdict flip; diagnostics show `conflict held` | [ ] |
| OCR.7 | Pause or stop FoxyCo, kill its overlay, swipe FoxyCo away, and revoke Accessibility in separate runs; also trigger OCR while the screen locks | Lifecycle cancellations discard pending OCR; a protected/unavailable screen produces no verdict; Accessibility works after re-enable | [ ] |
| OCR.8 | Inspect app-private storage and exported diagnostics after OCR offers | No PNG/JPEG/screenshot/cache file and no raw recognized text; logs contain only line counts, trigger/active package, elapsed milliseconds and sanitized conflict/stale-result events | [ ] |
| OCR.9 | Test Android 11, 14, 15 and 16, then Android 10 or an API-29 emulator | Android 11+ can OCR without a sharing prompt; when screenshot capture is unavailable, OCR turns off and Uber safely uses Accessibility text | [ ] |
| OCR.10 | Let an old verdict remain while a new unreadable card triggers OCR | The visible bubble/pill does not flicker; its rectangle is redacted only in memory, the new card is scored from its own text, and no duplicate verdict/history row is created | [ ] |
| OCR.11 | Debug APK only: enable Uber OCR and **Force OCR test mode**, restart monitoring, then show Uber over Lyft/Hopp | One Uber OCR verdict/audio/history row appears without a sharing prompt while Lyft/Hopp stay Accessibility-driven; disabling test mode restores event-triggered OCR; restarting FoxyCo resets test mode off | [ ] |
| OCR.12 | With Uber OCR enabled, accept one Uber offer and pass another | Accessibility lifecycle screens still mark the matching History rows Taken and Missed | [ ] |
| OCR.13 | Leave another app's verdict visible, then show an Uber request over it; also dismiss Uber while OCR is running | The old pill clears as Uber takes ownership, and a late screenshot cannot resurrect the dismissed offer | [ ] |
| OCR.14 | Show an Uber card whose dark Match/Accept text is missed but whose Uber tier, payout, away leg and trip leg are readable | One correct verdict/history row; the missing action line alone does not lose the card | [ ] |
| OCR.15 | Capture a `$7.54` / 7.4 km Uber offer through OCR, then inspect the pill, Home tally and History after restart | Exactly one `$7.54` OK row at about `$1.02/km`; never `$754`, GOOD, `$101.89/km`, or a duplicate | [ ] |
| OCR.16 | Let a real Uber card clear, then make the next OCR frame resemble its pickup distance as a payout (today's `$2.00` / 2.0 km regression) | The changed payout is held for confirmation and creates no false verdict/history row | [ ] |
| OCR.17 | Fresh install build 92, clear all history, then record 3–5 regular Uber offers plus Uber-over-Lyft/Hopp | Every physical card maps to exactly one correct row; readable Uber uses Accessibility and only incomplete Uber cards log OCR captures | [ ] |

## M16 — Foxy brand art

The 15-layer stock car is gone. One Foxy car (core + a per-theme glow/shadow
layer behind it), the gold `logo 3d` wordmark, and the sleeping fox.

| # | Step | Expect | Pass |
|---|------|--------|------|
| M16.1 | Cold-start the app and watch the splash | Car **and** gold wordmark fade up together over the first ~660 ms, then the glow flares on with two flickers. The wordmark is on screen for the rest of the splash — it never blinks in right before Home. No cream flash, no layer pop-in (M12.10/M12.11 still hold) | [ ] |
| M16.2 | Land on Home, **offline** | The same car sits on the stage. Glow behind it is low but present — the car has a shadow, it does not float | [ ] |
| M16.3 | Slide to go live | Over ~600 ms the glow behind the car blooms to full and the card edge warms. This is the whole offline→live tell now | [ ] |
| M16.4 | Look under the car on Home | **No ring, no line, no platform edge** — only a soft warm pool of light under the tyres. If any hard horizontal line shows across the card, the ring came back | [ ] |
| M16.5 | Check the car's framing in the card | Car sits low in the card, wheels near the bottom (~87%) with no dead gap under it. Nose and tail fully visible, nothing clipped at the sides | [ ] |
| M16.6 | Settings → Appearance → switch to the **light** theme, back to Home | Car reads as paint on paper, not a glowing object in a dark room: the back layer is a plain shadow. Going live warms the card edge — the car itself doesn't change (no lights-off art in this set) | [ ] |
| M16.7 | Watch the hero for ~10 s in both themes | Reflection sweep crosses **the car body only** — no highlight sliding across empty card. The sweep mask is the car core, so any drift shows here | [ ] |
| M16.8 | Home with no finished shifts (fresh install or cleared data) | The empty session card shows the **sleeping fox on grass**, ~132 dp wide, not squashed into a square | [ ] |
| M16.9 | Settings → About FoxyCo | Header is the **gold wordmark** with the version under it — not a fox head next to the word "FoxyCo" | [ ] |
| M16.10 | Check the fox head is still where it belongs | Home brand bar, shift recap sheet, onboarding, and the overlay bubble all still use the round head. Only the empty-session card and About changed | [ ] |
| M16.11 | Accessibility → Remove animations ON, cold start | Splash shows the car lit and the wordmark instantly, then moves on. Home's car is static | [ ] |
| M16.12 | Scroll Home up and down a few times on the oldest device you have | No jank on the hero. It's 2 images now instead of 15 — if this ever regresses, that's the place to look | [ ] |

## M17 — Offer detail sheet

| # | Step | Expect | Pass |
|---|------|--------|------|
| M17.1 | History → tap any row | Nothing cut off: verdict pill, fare, all six stat cells, the verdict-math line and the take/pass line all fully visible. The sheet grows past the old 9/16-screen cap | [ ] |
| M17.2 | Settings → Display → largest text size, reopen the same row | Sheet caps at 90% of the screen and the body **scrolls**; the grab handle stays put. No clipped text at the top | [ ] |
| M17.3 | Open an offer that has a ride tier (Uber Share, UberX, Comfort) | Tier shows right-aligned on the fare line, e.g. `$17.01 … UberX` — not truncated to `Ube…` in the header row | [ ] |
| M17.4 | Look at the big fare | Top of the `$` and digits not shaved off — display font has room above the caps | [ ] |

## M18 — Trial, paywall & locked pill (2026-07-28)

⚠️ **Every row here needs Firebase console setup done first** (`docs/FIREBASE_SETUP.md`
§1–5) — without `google-services.json` the Android build fails outright. Rows
marked 💳 additionally need the Play Console product live (§6).

⚠️ **Debug builds are unconditionally unlocked** (`kDebugUnlocked`). Testing
anything below in a `flutter run` build will show a false pass.
Use a **release** build: `flutter build apk --release --dart-define=PLAY_PUBLIC_KEY=<key>`.

| # | Step | Expect | Pass |
|---|------|--------|------|
| M18.1 | Fresh install (or clear app data), cold start, release build | App opens the onboarding wizard. NO sign-in prompt or Google sheet appears until the driver chooses to start the trial | [ ] |
| M18.2 | Complete or skip onboarding, then look at the top of Home | Banner reads **"Start your 7-day free trial"** with a chevron | [ ] |
| M18.3 | Go live, let a real offer land, WITHOUT starting the trial | Pill appears but shows **"Unlock FoxyCo / Tap to see this offer"** — no verdict word, no `$/km`, no `$/hr`, no km | [ ] |
| M18.4 | Tap that locked pill | FoxyCo comes to the foreground, lands on the **Home** tab, paywall sheet is already open | [ ] |
| M18.5 | Settings → Look & feel → the sample pill; and Home's demo pill | Both still show full numbers — the demo pill is free forever, only the LIVE pill locks | [ ] |
| M18.6 | Paywall → "Start 7-day free trial" | Google account sheet appears. Pick an account → paywall closes and the Home trial banner updates | [ ] |
| M18.7 | Home top, right after that | Banner calmly reads **"7 days left in your free trial"**; it does not say ended or ask you to unlock | [ ] |
| M18.8 | Go live again, real offer | Full verdict pill: verdict color, `$/km`, km, `$/hr` | [ ] |
| M18.9 | Settings → Profile → Access | Header summary reads **"Trial active · 7 days remaining"**; the signed-in Gmail is shown | [ ] |
| M18.10 | **The reinstall test.** Clear app data (or uninstall + reinstall), start trial again with the SAME Google account | Snackbar: **"This Google account already used its free trial."** Pill stays locked. A fresh trial is a release blocker. | [ ] |
| M18.11 | Airplane mode, cold start, mid-trial | App works, pill shows numbers. No error toast | [ ] |
| M18.12 | Settings → date & time → wind the clock back 3 days, reopen FoxyCo | Trial days-left does NOT go up. (`FoxClock` high-water mark) | [ ] |
| M18.13 | Wind the clock FORWARD past the trial end, reopen | Pill locks, banner reads "Trial ended — unlock FoxyCo" | [ ] |
| M18.14 | Wind the clock back to real time, go online, reopen | Correct days-left returns — the ID-token sync heals the poisoned clock, it does not stay expired | [ ] |
| M18.15 | 💳 Open paywall in Canadian and US Play storefront tests | Paywall and Google Play show **CA$24.99** in Canada or **US$19.99** in the US; wording says one-time / no subscription | [ ] |
| M18.16 | 💳 Complete a test purchase | Paywall closes by itself. Settings → Profile → Access reads **"Lifetime unlocked"** | [ ] |
| M18.17 | 💳 Kill the app immediately after paying, before it settles, then reopen | Still unlocked (queryPurchases re-acknowledges on launch). **Check 4 days later that Google did NOT auto-refund**; Play reverses unacknowledged purchases after 72 hours. | [ ] |
| M18.18 | 💳 Clear app data after purchasing, reopen, paywall → "Restore purchase" | "Purchase restored." Unlocked, and the trial state is irrelevant | [ ] |
| M18.19 | 💳 Release build WITHOUT `--dart-define=PLAY_PUBLIC_KEY` | Paywall shows "Purchases are unavailable in this build". Nothing unlocks. Fails CLOSED (§3.9) | [ ] |
| M18.20 | Deliberate expiry-only build with `--dart-define=BUILD_EXPIRY=<yesterday>` | Trial access locks, but a verified lifetime purchase stays unlocked. The define does not grant temporary tester access | [ ] |
| M18.21 | Settings → Profile → Access → Delete my account → confirm | "Account deleted." The Gmail row disappears; app still opens and works | [ ] |
| M18.22 | Airplane mode for 5+ days mid-trial (or fake it by clearing only the verify timestamp) | Banner: "Couldn't reach Google Play — unlock check needed in N days". Still usable | [ ] |

_Last updated: 2026-07-28 (M18: trial, paywall, locked pill — needs Firebase console setup before any row can run). 2026-07-27 (M17: offer detail sheet scroll + header). 2026-07-26 (M13: shell navigation — back-to-Home, deep-linked Settings sections, tab re-tap, Logs route, bubble → offer. M14: Settings banded into five sections; shared SectionLabel. M15: overlay surface transparency, bubble-tap resume, offer-log de-dupe. M16: Foxy brand art — 2-layer car, gold wordmark, sleeping fox)._

## Build 27 — audit-closure recording and device matrix (2026-08-07)

Use the Play-installed `1.0.9 (build 27)` release. Keep the upload unlisted and
blur rider names plus pickup/drop-off addresses before sharing it.

| # | Step | Evidence required | Pass |
|---|---|---|---|
| B27.1 | Start recording on Android Settings → About phone, then FoxyCo → About | Android version, device model and FoxyCo build 27 are visible | [ ] |
| B27.2 | Show Uber Driver, Lyft Driver and Hopp Driver app-info/version screens | Exact tested driver-app versions are visible | [ ] |
| B27.3 | With a redeemed license-test code or completed test purchase, cold-start FoxyCo and return after backgrounding it | Home has **no trial, trial-ended or unlock banner**; Settings says **Unlocked forever** | [x] verified 2026-08-08 |
| B27.4 | Start watching and capture one real Hopp offer | Correct payout, total distance, verdict and optional hourly rate appear; the pill clears when the card leaves | [x] verified 2026-08-08 |
| B27.5 | Capture one Uber and one Lyft offer | Values match each source card; raw rider/address text never appears in FoxyCo history or logs | [x] verified 2026-08-08 |
| B27.6 | While one app's pill is visible, foreground another watched driver app | Previous app's pill clears immediately; it never sits over the newly active app | [ ] |
| B27.7 | Revoke Accessibility while watching, then return to FoxyCo | Watching becomes blocked, bubble disappears, and exactly one bounded session is recorded | [ ] |
| B27.8 | Restore the permission, start again, pause/resume, drag and dismiss the bubble | State, bubble and dashboard remain synchronized; overlay is draggable and touch-through works | [ ] |
| B27.9 | Copy diagnostics, leave Logs immediately, wait one minute, then inspect/paste clipboard | Clip is marked sensitive and clears if it was not replaced | [ ] |
| B27.10 | Run M18.10 and M18.16–M18.20 on Play-installed builds/accounts | Reinstall, purchase/redeem, acknowledgment, restore, missing-key and build-expiry evidence is retained | [ ] |
| B27.11 | Run Uber/Lyft/Hopp for 30–60 minutes | No crash/ANR, ghost overlay, runaway battery use or stale cross-app pill; retain ADB/Play Vitals evidence | [ ] |
| B27.12 | Lock the screen while FoxyCo is active, then unlock it | FoxyCo/overlay is hidden on the lock screen and active again after unlock | [x] verified 2026-08-08 |

Repeat B27.3–B27.8 on Android 14, 15 and 16 where devices are available. The
existing 2026-08-06 recording supports Uber/Lyft behavior on one unidentified
Android version; it does not replace this versioned matrix.

_2026-08-08: No issues noticed in the three-app smoke test. Multi-day soak is
still in progress; leave B27.11 open until it finishes._

## Build 30 — multi-app outcome tracking (2026-08-10)

Use `1.0.9 (build 30)` and enable outcome tracking. Keep Uber Driver, Lyft
Driver and Hopp Driver open; obscure rider names and addresses in evidence.

| # | Step | Expect | Pass |
|---|---|---|---|
| B30.1 | While browsing Reels or YouTube, receive one offer from each driver app without accepting | All readable offers enter History; background home/browse frames do not assign taken or missed | [ ] |
| B30.2 | Accept an Uber offer, then open Uber and progress through Picking up, Waiting for rider, Start UberX, Dropping off and Complete UberX | The matching recent Uber History row becomes **Taken** on the first active trip state; newer Lyft/Hopp rows are untouched | [ ] |
| B30.3 | Accept a Lyft offer and reach Arrive, Passenger notified, Slide to pick up, then Slide to drop off | The matching recent Lyft row becomes **Taken**; Uber/Hopp rows are untouched | [ ] |
| B30.4 | Accept a Hopp offer and reach You have arrived, Waiting/Start Trip, End Trip, Confirm Price, then Rate passenger | The matching recent Hopp row becomes **Taken**; Uber/Lyft rows are untouched | [ ] |
| B30.5 | Let an offer disappear while its driver app remains in the background | Its outcome stays **Unknown**; FoxyCo does not guess from an inactive window | [ ] |
| B30.6 | After completing or ignoring other offers, leave or reopen Uber's LAST TRIP `$13.21` carousel card | No History row changes merely because the popup and fare are visible | [ ] |
| B30.7 | While already carrying a trip, receive a Lyft Add to queue card; first leave it untouched, then accept another and wait for **Added to queue** | The untouched card stays **Unknown**; only the card followed by active **Added to queue** becomes **Taken**. The existing trip screen alone proves neither | [ ] |
