# FoxyCo — Reference Screen Analysis (Uber + Hopp)

The two real offer screenshots in `references/` are the **base** for FoxyCo's design and parser.
DoorDash is dropped as the base. FoxyCo must look native sitting on top of these and parse them.

Images: `references/Uber.jpg`, `references/Hopp.jpg`.

---

## Uber offer card

- **Screen:** black turn-by-turn nav bar (top) → map → white bottom card (~40% height).
- **Card, top → bottom:**
  - `UberX` (black pill) + `Exclusive` (blue pill) — trip type chips
  - **`X` close button, top-right**
  - **`$10.55`** — huge bold, top-left + hex/boost icon
  - `★ 4.95` chip · `$3.00 Boost+ included` chip
  - divider
  - **`4 mins (0.8 km) away`** = pickup + address
  - dot-line timeline connector
  - **`15 mins (4.3 km) trip`** = dropoff + address
  - full-width **blue Accept** button; dark left segment = countdown timer
- **Pay = gross.** Pickup (0.8 km) and trip (4.3 km) shown **separately** → total ≈ 5.1 km.

## Hopp offer card

- **Screen:** status bar → **`✕ Decline` black pill floating top-right** → map w/ `46.3 km · 34 min`
  green route pill → white bottom card.
- **Card, top → bottom:**
  - `Hopp` chip + `Card` (red) chip
  - **`$15.65` `(NET, tax included)`** + **green underline bar** ← proto-verdict cue
  - `Tanya · 5.0 ★ (21)` chip
  - **`3 min · 1.1 km`** = pickup + address
  - **`34 min · 46.3 km`** = dropoff + address (same dot-line timeline)
  - full-width **green Accept** button
- **Pay = NET (tax included)** — already smarter than Uber.

---

## Shared design DNA (what FoxyCo inherits)

| Element | Uber | Hopp | → FoxyCo rule |
|---|---|---|---|
| Card | white rounded, bottom ~40% | white rounded, bottom ~40% | overlay stays OUT of bottom 45% |
| Payout | huge bold, top-left | huge bold, top-left | mirror this weight in expanded pill |
| Metadata | chips/pills | chips/pills | FoxyCo uses chip shapes too |
| Route | dot-line, pickup + trip **split** | dot-line, pickup + trip **split** | FoxyCo **sums** them (neither app does) |
| Action | full-width blue Accept | full-width green Accept | never cover it |
| Dismiss | `X` top-right (on card) | `✕ Decline` floating top-right | top-right is DEAD zone for FoxyCo |
| Verdict cue | none | green underline bar | FoxyCo = this idea, but threshold-driven |

---

## Consequences for FoxyCo

1. **Safe zone = the map band**: below the nav/status/Decline row, above the white card. Pill sits
   here, centered or left, dropped down from the top edge. Top-right is off-limits (X/Decline).
2. **Total km = pickup + trip.** Both apps split the two distances; FoxyCo summing them is real added
   value — neither app shows the sum or the $/km on it.
3. **Hopp's green bar proves the concept.** FoxyCo generalizes it: a real, driver-set threshold →
   GOOD/OK/BAD, on every platform, not just Hopp.
4. **Visual base = this idiom:** oversized bold number, chip-shaped verdict, dot-line timeline,
   dark-on-map + white card, brand-color action. FoxyCo's expanded pill and home screen echo it so it
   feels native beside Uber and Hopp.

## Parser consequences (`parser/`, Dart)

The accessibility plugin hands us the screen's text nodes. Each parser is a pure Dart class matching
`OfferParser`, tuned against these two layouts.

- **UberParser** — regex on the joined node text:
  - payout: `RegExp(r'\$([\d.]+)')` → **gross** pay
  - pickup: `RegExp(r'(\d+)\s*mins?\s*\(([\d.]+)\s*km\)\s*away')` → group 2 = `pickupKm`
  - dropoff: `RegExp(r'(\d+)\s*mins?\s*\(([\d.]+)\s*km\)\s*trip')` → group 2 = `dropoffKm`
  - `payIsNet = false`
- **HoppParser** —
  - payout: `RegExp(r'\$([\d.]+)')`; detect the `NET` / `tax included` flag → `payIsNet = true`
  - distances: `RegExp(r'([\d.]+)\s*km')` on the pickup row vs dropoff row, ordered by the dot-line
    timeline (pickup row appears first)
- Both put pay top-left and distances in two labeled rows → stable-ish text anchors. Tag each parser
  with the app version tuned against; keep node fixtures (see AUDIT #3):

```dart
abstract interface class OfferParser {
  Platform get platform;
  Offer? parse(List<String> nodeTexts); // null = low confidence → show nothing (fail safe)
}
```

- `Offer.payIsNet` (already in the domain model) lets the verdict treat Hopp (net) vs Uber (gross)
  correctly later when the profit engine lands.
</content>
