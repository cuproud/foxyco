# FoxyCo — Fox Tips Card

**Status:** Design spec, not yet built  
**Location on Home:** Below the Last Session card  
**Independence:** Self-contained widget, zero coupling to offer parsing or billing

---

## 1. What it is

A rotating card on Home that shows one short tip at a time — gig driving
advice, app feature hints, maintenance reminders, safety notes. The fox
mascot appears as a small illustration inside the card, matched to the tip
category.

Drivers glance at it between offers. It is not a notification, not a
banner, not a paywall surface. It is ambient value — something useful every
time they open the app.

---

## 2. Card anatomy

```
┌─────────────────────────────────────────────────────┐
│  [fox illustration — right side, ~80×80 dp]         │
│                                                     │
│  CATEGORY CHIP   ·   tip #3 of 12                   │
│                                                     │
│  Tip headline (1 line, bold)                        │
│  Body text (2–3 lines, secondary colour)            │
│                                                     │
│  ← prev    [dot indicators]    next →               │
└─────────────────────────────────────────────────────┘
```

- Card background: same surface token as the Session card (`FoxColors.surface`)
- Category chip: small coloured pill (colour per category, see §4)
- Fox illustration: right-aligned PNG, transparent background, ~80 dp tall
- Swipe left/right to navigate; arrows optional (match existing slide arrows)
- Auto-advance: off by default (drivers are mid-shift, don't want motion)

---

## 3. Architecture (independent, wire-ready)

```
lib/ui/home/fox_tips_card.dart     ← the widget, reads from the provider
lib/domain/fox_tip.dart            ← FoxTip model (category, headline, body, asset)
lib/services/tips_provider.dart    ← Riverpod provider, returns List<FoxTip>
assets/tips/                       ← fox PNG illustrations (one per category)
```

The widget takes `List<FoxTip>` from the provider and renders. The provider
today returns a hardcoded list. Future upgrade: swap the provider to fetch
from a remote JSON (no widget change needed). The widget is added to Home
with one line — it is never entangled with offer parsing, billing, or
overlay logic.

**FoxTip model:**
```dart
class FoxTip {
  final TipCategory category;
  final String headline;
  final String body;
  // asset name without path/extension, e.g. 'fox_tip_earnings'
  // null = no illustration for this tip
  final String? asset;
}
```

---

## 4. Categories and tip content (v1 — 12 tips)

| # | Category | Chip colour | Headline | Body |
|---|---|---|---|---|
| 1 | Earnings | Amber | Peak hours pay more | 4–6 PM and 7–9 PM weekdays are the highest-demand windows in most cities. Check the by-hour chart in History to find YOUR peak. |
| 2 | Earnings | Amber | Short trips kill your $/km | Offers under 5 km rarely clear your threshold once you factor in pickup. FoxyCo flags these automatically. |
| 3 | Earnings | Amber | Surge ≠ good offer | A 1.8× surge on a $4 base is still $7.20. Check the $/km, not the multiplier. |
| 4 | Safety | Blue | Take a break every 2 hours | Fatigue is the #1 cause of gig driver incidents. Set a phone reminder — your reaction time drops 20% after 2 hours of continuous driving. |
| 5 | Safety | Blue | Keep your rating above 4.85 | Below 4.85 on Uber you lose access to premium tiers. One bad rating takes ~20 five-stars to recover. |
| 6 | Maintenance | Green | Check tyre pressure monthly | Under-inflated tyres cut fuel economy by up to 3% and wear unevenly. Takes 5 minutes at any servo. |
| 7 | Maintenance | Green | Oil change every 5,000 km | Gig drivers average 3–4× the km of a regular driver. Stick to 5,000 km intervals, not the 10,000 km on the sticker. |
| 8 | Maintenance | Green | Clean your cabin weekly | A 4.9 rating is worth more than a surge. Passengers notice smell and mess before anything else. |
| 9 | App tip | Fox orange | Set your thresholds first | FoxyCo's verdict is only as good as your numbers. Go to Settings → Verdict thresholds and enter your real cost-per-km. |
| 10 | App tip | Fox orange | History shows your real peak | The by-hour chart in History is built from YOUR offers, not city averages. Check it after your first 50 offers. |
| 11 | App tip | Fox orange | Pickup distance matters | A $20 offer with a 12 km pickup is often worse than a $14 offer with a 1 km pickup. FoxyCo scores both. |
| 12 | Gig life | Purple | You are running a business | Track fuel, maintenance, and depreciation. At $0.20/km all-in costs, a $15 offer over 20 km nets ~$11, not $15. |

---

## 5. Fox illustration list — images needed

One PNG per category (5 images). Transparent background. Roughly square
canvas, ~512×512 px minimum (displayed at ~80–100 dp). The fox is the
FoxyCo mascot — same character as the splash/home car fox.

| Filename | Scene / pose | Used for |
|---|---|---|
| `fox_tip_earnings.png` | Fox holding a stack of cash or a coin, looking pleased, maybe sunglasses | Tips #1, #2, #3 (Earnings) |
| `fox_tip_safety.png` | Fox wearing a seatbelt or a hi-vis vest, calm confident pose | Tips #4, #5 (Safety) |
| `fox_tip_maintenance.png` | Fox holding a spanner/wrench or crouching next to a tyre, sleeves rolled up | Tips #6, #7, #8 (Maintenance) |
| `fox_tip_app.png` | Fox pointing at a phone screen or tapping a chart, curious/helpful expression | Tips #9, #10, #11 (App tips) |
| `fox_tip_giglife.png` | Fox at a small desk with a calculator and notepad, business-like but relaxed | Tip #12 (Gig life) |

**Style notes for generation:**
- Transparent PNG, no background colour or shadow behind the fox
- Same 3D render style as the splash car fox (sunglasses character)
- Facing slightly left (card text is on the left, fox on the right)
- Cropped tight — minimal empty canvas around the character
- No text baked into the image

---

## 6. Wiring into Home (one change)

In `lib/ui/home/home_screen.dart`, after the Session card block:

```dart
const SizedBox(height: Gap.md),
const _Padded(child: SectionLabel('Fox tips')),
const SizedBox(height: Gap.sm + Gap.xs),
const _Padded(child: FoxTipsCard()),
```

`FoxTipsCard` is a `ConsumerWidget` that reads `tipsProvider`. No other
file changes needed.

---

## 7. Future upgrades (no rework required)

| Upgrade | What changes |
|---|---|
| Remote tips (A/B, seasonal) | Swap `tipsProvider` implementation only |
| Per-platform tips (Uber vs Lyft) | Add `platform` filter to `FoxTip`, provider filters by `settingsProvider.watchedApps` |
| Tip dismissal / "don't show again" | Add `dismissed: Set<int>` to provider, persist in SharedPreferences |
| Tip of the day (single random) | Provider returns `[tips[dayOfYear % tips.length]]` |
| Paywall tip slot | Add a `TipCategory.unlock` entry; widget renders the paywall card variant |

---

_Last updated: 2026-07-27_
