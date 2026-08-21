# FoxyCo Functionality Tour Analysis

Source: `Screen_Recording_20260821_082847_Lyft Driver.mp4` (6:38, recorded August 21, 2026)

Scope: visible offer detection, parsing, verdict presentation, cross-app switching, overlay lifecycle, and scheduled/Ride Finder behavior. This is a video-evidence review, not a device-log audit; exact accessibility node contents and History rows cannot be proven from the recording alone.

## Implementation status — build 67

The immediate findings were implemented in `1.0.10+67`: the highest visible
card window now owns the pill, a newly topmost incomplete card clears the prior
verdict, opened Lyft Reserve details use a narrow scheduled-card parser, and
Reserve misses feed parser health. Automated stacked-window and scheduled-card
regressions pass. Physical-device verification remains required for real Uber
Radar rotations, Lyft overlays behind Uber, and Lyft layout variants.

## Executive result

FoxyCo handles ordinary Lyft, Lyft Ride Finder, Hopp, and a standalone UberX card reliably in this tour. The displayed rate calculations match the visible fares, distances, and times after normal rounding.

Three visible offer-detail cards receive no new verdict:

1. Lyft scheduled ride — **$6.53**, 7 min / 2.9 km.
2. Lyft scheduled ride — **$22.08**, 36 min / 45 km.
3. UberX card — **$13.45**, displayed on top of an existing Lyft card.

The two scheduled misses are confirmed and systematic. The current Lyft parser explicitly rejects anything containing “scheduled ride” and only accepts `Accept`, `Match`, or `Add to queue`; scheduled details use **Reserve**. The cross-app miss is also visible: FoxyCo keeps showing the prior Lyft pill (`$1.12/km · 9.9 km · $30/hr`) while the UberX $13.45 card is in front.

## Detection scorecard

The tour contains 13 distinct offer-card presentations, including two scheduled details and one repriced/re-presented Lyft card.

| Approx. time | Platform/type | Visible offer | Expected FoxyCo calculation | Observed | Result |
|---|---|---:|---|---|---|
| 0:07 | Hopp live card | $7.42; 3.5 + 9 km; 7 + 16 min | $0.59/km; 12.5 km; ~$19/hr | Matching pill | Pass |
| 0:16 | Lyft live | $18.15; 1.4 + 23.6 km; 4 + 25 min | $0.73/km; 25 km; ~$38/hr | Matching pill | Pass |
| 0:46 | Lyft Ride Finder | $7.01; 1 + 2.3 km; 4 + 10 min | $2.12/km; 3.3 km; ~$30/hr | Matching pill | Pass |
| 1:13 | Lyft scheduled detail | $6.53; 7 min / 2.9 km | Scheduled-trip rate; pickup unknown | No pill/verdict | **Miss** |
| 1:30 | Lyft scheduled detail | $22.08; 36 min / 45 km | Scheduled-trip rate; pickup unknown | No pill/verdict | **Miss** |
| 1:46 | Lyft live | $8.01; 0.6 + 5.5 km; 3 + 14 min | $1.31/km; 6.1 km; ~$28/hr | Matching pill | Pass |
| 2:12 | Lyft live | $13.12; 1.6 + 10.4 km; 5 + 19 min | $1.09/km; 12 km; ~$33/hr | Matching pill | Pass |
| 3:04 | Lyft Ride Finder | $11.06; 0.8 + 9.1 km; 4 + 18 min | $1.12/km; 9.9 km; ~$30/hr | Matching pill | Pass |
| 3:22 | Lyft repriced/re-presented | $11.04; same 9.9 km / 22 min route | $1.12/km; 9.9 km; ~$30/hr | Matching rounded values | Indeterminate re-parse; arithmetic correct |
| 3:26 | UberX over Lyft | $13.45; 0.1 + 16.1 km; 2 + 31 min | $0.83/km; 16.2 km; ~$24/hr | Prior Lyft pill remains: $1.12/km; 9.9 km; $30/hr | **Miss / stale verdict** |
| 4:37 | Lyft live | $4.05; 0.4 + 2.1 km; 3 + 6 min | $1.62/km; 2.5 km; $27/hr | Matching pill | Pass |
| 4:56 | Lyft Comfort | $11.01; 1.7 + 5.3 km; 6 + 13 min | $1.57/km; 7 km; ~$35/hr | Matching pill | Pass |
| 5:47 | UberX standalone | $5.40; 1 + 4.3 km; 4 + 11 min | $1.02/km; 5.3 km; ~$22/hr | Matching pill | Pass |

Confirmed visible outcome: **10 card presentations show arithmetically correct pills, 3 miss, and 1 of the 10 is visually impossible to distinguish from a retained pill because the rounded metrics are identical.** The unopened cards in Lyft’s scheduled-rides list are browse results, not counted as misses. Only the two cards opened into full detail are counted.

## Chronological behavior analysis

### 1. Normal offer detection works

The first Hopp card and subsequent Lyft live cards are detected quickly. FoxyCo correctly:

- adds pickup and trip distance;
- adds pickup and trip time;
- computes payout per total kilometre;
- computes payout per total displayed minutes;
- rounds the pill values consistently;
- replaces the pill when ordinary offers change;
- handles Lyft’s `Accept` and Ride Finder’s `Request match` surfaces;
- handles Lyft Comfort as a normal Lyft product;
- parses a later standalone UberX `Match` card.

These successes show that the basic arithmetic, overlay rendering, Lyft live parser, Ride Finder parser, and Uber parser are functional.

### 2. Lyft scheduled cards are deliberately excluded

At roughly 1:13 and 1:30, full scheduled-ride detail cards are opened. Each has a fare, route information, duration/distance, rider information, and a **Reserve** action. FoxyCo shows no verdict.

The current code explains this behavior:

- `LyftParser.parse()` requires `hasAcceptAction()`.
- `hasAcceptAction()` recognizes Accept, Match, and Add to queue, but not Reserve.
- `LyftParser.parse()` rejects the entire frame when it sees `scheduled ride`.
- The rejection was added to prevent multiple cards in the scheduled-rides browse list from being stitched into one false offer.

That protection is correct for the list, but it also blocks a single opened scheduled detail. The parser needs to distinguish **scheduled list** from **scheduled detail**, not treat all scheduled content as browse noise.

### 3. Uber overlay on top of Lyft keeps the wrong pill

Around 3:26, an UberX $13.45 card appears over a still-visible Lyft $11.04 card. FoxyCo continues showing:

```text
$1.12/km · 9.9 km · $30/hr
```

Those are the Lyft route values. The Uber card should produce approximately:

```text
$0.83/km · 16.2 km · $24/hr
```

This is more serious than a silent miss because the retained pill appears confident while describing the obscured card underneath. It violates the intended fail-safe behavior: a stale verdict can be mistaken for a verdict on the front card.

The repository already has a test for an Uber card attributed to the Lyft package, so the missing case is probably not “Uber text under Lyft package” by itself. The recording is closer to this structure:

```text
active/merged accessibility read
  window A: old Lyft card — still complete and parseable
  window B: new UberX card — visually on top
```

The watcher iterates windows and accepts the first successful parse. If the older Lyft window arrives first, it matches the already-shown key and returns before the visible Uber card can replace it. Window order/z-order and replacement arbitration therefore need a regression fixture matching this exact recording.

### 4. Standalone Uber later works

At roughly 5:47, an UberX $5.40 card is shown without a Lyft card underneath. FoxyCo correctly displays `$1.02/km · 5.3 km · $22/hr`.

This narrows the earlier failure:

- Uber parsing itself is not generally broken.
- Cross-app coexistence/merged windows is the differentiator.
- The likely failure is candidate selection or stale-card precedence, not the Uber regex.

### 5. Overlay lifecycle observations

- Pills generally appear shortly after a complete card renders.
- Pills remain readable while the offer is on screen.
- The mascot bubble remains available throughout app switches.
- The stale Lyft pill survives when the Uber card replaces/overlays it; the overlay lacks a visible platform badge, making the mismatch hard for a driver to notice.
- On ordinary card dismissal/return to map, the pill clears or collapses as expected in the sampled sequence.

## Bugs and required changes

### P0 — wrong or missing verdicts

#### F-01: Stale Lyft verdict shown over Uber card

**Severity:** Critical

**Evidence:** Around 3:26, UberX $13.45 is foregrounded while the pill still reports the previous Lyft $11.04 route.

**Expected:** The Uber offer replaces the Lyft pill, or FoxyCo clears the old pill immediately until the Uber parse is complete.

**Likely cause:** First-success selection across merged accessibility windows favors a still-parseable older Lyft window. Existing cross-package tests use one flat text list and do not reproduce two simultaneously complete windows.

**Minimum fix:**

1. Preserve accessibility window z-order/active-window metadata.
2. Parse the topmost active card window before background/underlay windows.
3. If a newly topmost card-like window is incomplete, clear or mark the prior pill as pending rather than displaying it as current.
4. Add a regression test containing both complete Lyft and Uber windows, Lyft first in the raw collection and Uber topmost.

Do not simply prefer Uber globally; the correct rule is **topmost active offer wins**.

#### F-02: Opened Lyft scheduled detail never scores

**Severity:** High

**Evidence:** Both opened scheduled details remain without a verdict for several seconds.

**Expected:** FoxyCo recognizes a single reserveable scheduled detail and provides an appropriately qualified verdict.

**Root cause:** `scheduled ride` is an unconditional Lyft rejection and `Reserve` is not an accepted offer action.

**Minimum fix:**

1. Keep rejecting the multi-card Scheduled Rides list.
2. Recognize **Reserve** only for a single opened scheduled-detail layout.
3. Require one clean payout, one route leg, a scheduled pickup time, and a Reserve action.
4. Tag the parsed offer as `Scheduled`.
5. Never merge values across multiple scheduled list cards.

#### F-03: Scheduled ride has no pickup/deadhead distance

**Severity:** High for scoring correctness

**Evidence:** Opened scheduled details show the scheduled pickup time and trip duration/distance, but no current-to-pickup distance.

**Expected:** FoxyCo must not pretend the shown trip distance is the full driver distance.

**Minimum behavior:**

- Display a scheduled pill with **trip-only** metrics.
- Label it clearly: **Scheduled · pickup distance unavailable**.
- Do not apply Pickup Guard when pickup distance is unknown.
- In $/km mode, either return a qualified verdict based on trip-only distance or show **Needs pickup distance** instead of GOOD/OK/BAD, according to the product’s safety preference.
- In $/hr mode, use only the displayed trip duration and state that wait/deadhead time is excluded.

The safest initial release is an informational pill rather than a full verdict until the app can obtain a reliable deadhead estimate.

### P1 — reliability and diagnosability

#### F-04: Pill has no source-platform identity

When several gig apps overlap, a stale pill looks valid. Add a small Lyft/Uber/Hopp source mark or platform-colored dot to the expanded pill. This does not fix detection, but it makes attribution auditable at a glance.

#### F-05: Repriced card cannot be visually distinguished from stale rounded values

The Lyft route changes from $11.06 to $11.04 while distance/time remain the same. Both round to the same `$1.12/km` and `$30/hr` pill. The video cannot prove whether FoxyCo re-parsed it.

Include the payout in the expanded/details view or diagnostic overlay, and ensure the offer fingerprint includes raw payout plus route values. History should not create duplicates for a platform repaint, but a material fare change should update or replace the active offer.

#### F-06: Miss telemetry excludes Reserve cards

The current miss counter is driven by `hasAcceptAction()`. Because Reserve is not recognized, scheduled misses may never appear in Parser Health.

Add a scheduled-detail-specific card action to miss telemetry. Keep the general action matcher strict so browse pages do not inflate misses.

#### F-07: No visible “reading” or “unsupported card” state

Silence is ambiguous: the driver cannot tell whether FoxyCo is processing, intentionally ignoring a browse card, or failed to parse.

For a strong card candidate that remains unparsed beyond a short threshold, show a temporary neutral state such as **Reading offer…** followed by **Couldn’t read this card**. Do not show this for ordinary maps or scheduled lists.

### P2 — behavior polish

#### F-08: Cross-app switch menu adds interaction overhead

Tapping a platform bubble opens a modal with **Open app** and **Go Offline**. This is understandable, but frequent switching becomes two taps. A normal tap could open the app directly; long-press could expose status/actions. Keep the current modal if accidental switching has been a real issue.

#### F-09: Multiple floating platform bubbles obscure offer content

Hopp, Uber, Lyft, and the FoxyCo mascot occupy both sides of the offer cards and sometimes cover fare or route content. Collapse watched-platform shortcuts into one stack/launcher, or auto-dim non-active platform bubbles while an offer is visible. Do not move the FoxyCo verdict pill over the native Accept/Match/Reserve action.

#### F-10: Offline/online state can become ambiguous across apps

The recording switches between Lyft and Uber while each has its own online state. FoxyCo should show per-platform state in its switcher, for example **Lyft online · Uber online**, rather than implying one global live state.

## Recommended parser design

### Lyft live/Ride Finder

Keep the existing strict path:

```text
Accept / Request match
+ payout
+ at least pickup and trip legs
-> normal verdict
```

### Lyft scheduled detail

Add a separate, narrow path:

```text
Reserve
+ exactly one visible scheduled ride
+ scheduled pickup time
+ one trip duration/distance
+ one clean payout
-> ScheduledOffer(trip metrics, pickup unknown)
```

Reject when any of these list indicators exist:

- `Available rides` with multiple fare cards;
- several payout candidates;
- several scheduled pickup times;
- no Reserve action;
- map price bubbles without an opened detail surface.

This preserves the original false-positive protection without blocking a full detail card.

### Cross-window arbitration

Use card selection before parser selection:

```text
collect visible accessibility windows
  -> rank by active/focused state and z-order
  -> identify complete card candidates per window
  -> parse the highest-ranked complete card
  -> if top card is card-like but incomplete, suppress stale lower-card verdict
```

Do not concatenate two card windows before parsing. Concatenation can combine the fare from one app with the route from another.

## Required regression checks

Add the smallest tests that reproduce the observed failures:

1. **Lyft scheduled list remains rejected.** Multiple scheduled rows must never form one offer.
2. **Lyft scheduled detail is recognized.** Reserve + one payout + pickup time + one trip leg creates a scheduled offer with unknown pickup distance.
3. **Scheduled detail without Reserve is rejected.** Prevents list/map false positives.
4. **Top Uber over complete Lyft wins.** Two windows, both parseable; Uber is topmost and must replace the Lyft pill.
5. **Incomplete top Uber clears/suspends stale Lyft.** Never show the lower card’s verdict as if it belongs to the top card.
6. **Standalone Uber still parses.** Preserve the working $5.40 case.
7. **Lyft Ride Finder still parses.** Preserve Request match behavior.
8. **Repriced same-route offer updates once.** $11.06 to $11.04 should update the active candidate without duplicate speech or duplicate History rows.
9. **Platform badge follows replacement.** Visual source must switch Lyft -> Uber with the parsed offer.
10. **Scheduled miss is counted.** Parser Health should surface repeated Reserve-detail failures.

## Suggested logging additions

For debug/diagnostic logs, record one compact line per card transition:

```text
CARD windows=2 top=uber parsed=uber payout=13.45 replaced=lyft
MISS top=lyft subtype=scheduled_detail payout=true legCount=1 reserve=true
SUPPRESS stale=lyft reason=top_card_incomplete top=uber
```

Do not log rider names, full addresses, screenshots, or raw accessibility text. The existing boolean/signature approach can be extended with card subtype, window rank, chosen parser, and replacement reason.

## Product wording for new states

| Situation | Recommended pill/status copy |
|---|---|
| Parsing a strong candidate | **Reading offer…** |
| Failed complete live card | **Couldn’t read this offer** |
| Scheduled detail, pickup unknown | **Scheduled · pickup distance unavailable** |
| Trip-only scheduled rate | **Trip only · deadhead not included** |
| Cross-app replacement pending | Hide old verdict; keep neutral FoxyCo bubble |
| Unsupported card type | **This offer type isn’t supported yet** |

## Release priority

### Before the next field test

1. Fix cross-window arbitration so a top Uber card cannot inherit a Lyft verdict.
2. Add the exact two-window Uber-over-Lyft regression fixture.
3. Add scheduled-detail recognition or explicitly show that scheduled offers are unsupported.
4. Add platform identity to the expanded pill.

### After correctness is stable

1. Add qualified scheduled-trip scoring.
2. Add neutral reading/failure states for strong candidates.
3. Improve Parser Health telemetry for Reserve cards and window-selection failures.
4. Reduce floating-bubble obstruction.

## Bottom line

The core live-offer parser performs well: every ordinary card with a clearly visible new pill has correct arithmetic in this tour. The bugs are concentrated in two boundaries—**a new Lyft card subtype (scheduled Reserve)** and **two gig-app cards visible at once**. Fixing those boundaries is higher value than broad parser changes. Most importantly, when a new foreground card cannot yet be parsed, FoxyCo must clear or neutralize the old verdict; silence is safer than confidently showing another app’s numbers.
