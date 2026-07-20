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
| M5.4 | Drive a session, `adb install -r` a new build, open Settings → Logs | Pre-update lines still present | [ ] |
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
| M6F.9 | Go live, open Uber Driver, wait for ≥10 offer frames, then Settings → Parser health | Uber row reads "Unreadable · OCR needed" (red) if Uber sends textless frames — NOT "No offers yet" | [ ] |
| M6F.10 | Scroll Home to the bottom on a gesture-nav phone | "Show a demo pill" fully visible ABOVE the floating nav; tappable without fighting the bar | [ ] |
| M6F.11 | While OFFLINE (stopped), tap "Show a demo pill" | Pill shows ~5 s, then pill AND bubble disappear completely — no lingering bubble while the dashboard says stopped | [ ] |
| M6F.12 | While LIVE, tap "Show a demo pill" | Pill shows ~5 s, then retracts to the resting bubble (bubble stays — you're still watching) | [ ] |
| M6F.13 | While OFFLINE: demo pill → let it vanish → go LIVE | A clean fox BUBBLE appears — never clipped/garbled pill text in a bubble-sized box | [ ] |

---

## M7 — Uber parsing fixed (2026-07-19, verified live on device)

> Three stacked root causes fixed: fork NPE on transient card windows,
> `isAccessibilityTool` for Uber's accessibilityDataSensitive card views, and
> TYPE_ACCESSIBILITY_OVERLAY pill (Uber's Accept card hides normal overlays).
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
| M8.7 | History → "Top offers only" ≥ $15 with OK/BAD offers over $15 logged | Those offers SHOW (fare floor only — verdict no longer forces GOOD) | [ ] |
| M8.8 | Settings → pill size Large on a narrow phone | Preview scales down to fit — no yellow/black overflow stripes | [ ] |
| M8.9 | Settings → below the preview | "How to read it" legend: verdict block, green km, red km, $/hr rows | [ ] |
| M8.10 | Go live, swipe FoxyCo out of Recents, reopen | Dashboard shows STOPPED (not a stale "online"); bubble gone | [ ] |
| M8.11 | Watch logcat during a live Uber session | No FOXYCO_WALK spam (gated behind DEBUG_WALK=false) | [ ] |

| M8.12 | Drag the bubble anywhere | Red gradient strip + white ✕ circle fade in at screen bottom while dragging; gone the instant you release | [ ] |
| M8.13 | Drag the bubble INTO the bottom strip | ✕ turns solid red + swells while finger is in the zone; release closes the session (dashboard flips to stopped) | [ ] |
| M8.14 | Drag near-but-above the strip and release | ✕ stays neutral, bubble parks at the bottom edge, session KEEPS running | [ ] |

_Last updated: 2026-07-19 (M8 rows: settings/history/pill UX round 2 + lifecycle honesty + dismiss-zone discoverability)._
