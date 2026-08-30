# Offer Detection and Verdict Logic

Canonical implementation map for `1.0.12+100`, verified against the code on
2026-08-29.

## Maintenance contract

This document describes shipped behavior only. It is the required starting
point before changing offer capture, parser routing, parser rules, scoring,
overlay verdict delivery, deduplication, or outcome inference.

Any change to those behaviors must update this document in the same change.
Before a release, compare every affected section with the implementation and
tests. If this document and the code disagree, the code is the runtime truth and
the document must be corrected before release.

The implementation files that define this contract are:

- `android/app/src/main/res/xml/accessibilityservice.xml`
- `third_party/flutter_accessibility_service/android/src/main/java/slayer/accessibility/service/flutter_accessibility_service/AccessibilityListener.java`
- `lib/services/accessibility/accessibility_watcher.dart`
- `lib/services/accessibility/offer_watcher.dart`
- `lib/services/ocr/ocr_capture.dart`
- `lib/parser/offer_parser.dart` and every `lib/parser/*_parser.dart`
- `lib/parser/parser_registry.dart`
- `lib/domain/offer.dart`, `lib/domain/decision_engine.dart`, and
  `lib/domain/fox_settings.dart`
- `lib/ui/overlay/overlay_controller.dart`
- `lib/services/offer_log.dart`

## End-to-end flow

```text
Selected driver app emits an Android Accessibility event
  -> native service returns separate top-to-bottom windows
  -> AccessibilityWatcher flattens, throttles, and deduplicates the frame
  -> OfferWatcher checks Watching state and selected apps
  -> highest visible offer-like window is routed to strict parsers
     -> Uber may instead/additionally use screenshot OCR
  -> incomplete or ambiguous input returns null (no new verdict)
  -> complete Offer is normalized to dollars, kilometres, and minutes
  -> DecisionEngine applies the driver's rideshare or delivery rules
  -> OfferLog records the offer and scoring snapshot
  -> OverlayController refreshes access and displays an entitled or locked pill
  -> later Accessibility frames may infer taken/missed outcome
```

FoxyCo never presses Accept, Match, Reserve, or any other driver-app control.

## Capture and routing gates

### Android scope

The Accessibility service receives only window state/content/window-list events
from these packages:

| Platform | Android package | Parser status |
| --- | --- | --- |
| Uber / Uber Eats | `com.ubercab.driver` | Supported; device-tuned |
| Hopp | `ee.hopp.driver` | Supported; device-tuned |
| Lyft | `com.lyft.android.driver` | Supported; device-tuned |
| DoorDash | `com.doordash.driverapp` | Beta; public-card seeded |
| Instacart | `com.instacart.shopper` | Beta; public-card seeded |
| Skip | `com.delco.courier` | Beta; public/official-card seeded |

The package list is duplicated deliberately in `ParserRegistry`; tests must keep
the registry and Android XML in sync. Settings allow at most three selected
apps. An event from an unselected platform is dropped before parsing.

FoxyCo does not subscribe to Accessibility events from navigation, video, or
other unrelated apps. OCR is event-triggered rather than continuously polling
the screen, so an Uber card that appears while Google Maps, Android Auto, or a
video app is active may not be captured until a selected driver app emits an
event. This narrow scope is intentional: broad screen monitoring would increase
battery use and expose unrelated on-screen content.

### Accessibility frames

Android coalesces events with a 300 ms notification timeout. Dart uses a 100 ms
trailing throttle, always flushing the latest frame even if events never stop.
Only consecutive identical package/text frames are deduplicated; an unchanged
covered card can therefore be detected again after the top card disappears.

Each native window remains separate. Windows are ordered by layer, then focus,
then active state. FoxyCo examines the top offer-like window first so text from
a lower card, map, or dismissed window cannot be combined with the visible
card. A positive browse or accepted-trip frame is treated as the current top
screen instead of searching lower windows.

The parser matching the event package is tried first. Other selected platform
parsers may then inspect the same isolated window because Android can attribute
a stacked/merged window frame to the app underneath it. The platform on the
successfully parsed `Offer`, not the event package alone, owns the result.

### Shared strict parser contract

Parsers return `null` when required evidence is missing or contradictory. A
false negative is preferred to a confident wrong verdict.

Shared rideshare evidence includes:

- a takeable action (`Accept`, `Match`, or `Add to queue`), except for the
  explicit Lyft scheduled-ride and Uber OCR exceptions below;
- the first positive dollar amount that is not labelled toll, fee, tip, bonus,
  surge, promotion, quest, extra, or hourly rate;
- a complete supported route shape with positive distance; and
- rejection of browse/home markers such as Ride Finder, scheduled-ride lists,
  Go Online, Finding Trips, Trip Planner, and Go Offline where applicable.

`$0.00` is never a payout. Distances in miles are converted to kilometres.
Hours and minutes are converted to total minutes. Raw node/OCR text is used only
in memory during the parse and is not persisted.

## Platform parser rules

### Uber rides

Source: Accessibility when complete, plus the Uber OCR path described below.

A complete ride requires:

- a clean positive payout;
- a labelled trip row such as `37 mins (37.0 km) trip`; and
- either an Accept/Match action or a recognized Uber tier. The tier exception
  exists because OCR can miss the dark action button.

The optional `N mins (X km) away` row becomes pickup time/distance. If it is
absent, pickup values are zero rather than guessed. The required `trip` row
becomes drop-off time/distance. Optional hours are included. Pay is marked
gross. Recognized categories include UberX, XL, Comfort, Comfort Electric,
Share/Pool, Green, Pet, Premier, Black, and Connect. A Match-only card adds the
Radar label. Category never affects the verdict.

### Uber Eats

Uber Eats uses the Uber package and parser. A delivery card requires a positive
payout, a `Delivery` marker (optional bundle count), and a labelled
`N min (X km) total` row. Pickup is zero; the total row supplies delivery
distance and duration. `deliveryCount` defaults to one.

Although the stored platform is Uber, `Offer.rulesPlatform` switches any Uber
offer with `deliveryCount > 0` to Uber Eats so delivery thresholds, hourly
rules, and minimum payout are applied.

### Hopp

A complete Hopp offer requires Accept/Match, a clean payout, and two to six
ordered `N min · X km` legs. The first leg is pickup; every remaining leg is
summed as the trip, which supports up to five trip legs/stops. Fewer than two or
more than six legs returns `null`.

`NET` or `tax included` marks the payout as net. A demand/rate multiplier is
captured as display category. Net/gross metadata currently does not alter
scoring.

### Lyft

A live Lyft offer requires Accept/Add to queue, a clean total payout, and two
to six ordered `N min · X km` legs. The first is pickup and the rest are summed
as the trip. Bonus-labelled amounts are stored separately but are already part
of the displayed payout and are never added again. `Add to queue` marks the
offer queued and changes only history/category context.

Lyft's merged window can place the persistent earnings balance above the live
card. The parser therefore uses the last clean amount in visual order, while
still excluding bonus and estimated-hourly-rate amounts.

Lyft frames may legitimately contain background Ride Finder/Turbo/map text
because Android merges same-package windows. A live isolated card is therefore
not rejected for general browse chrome. A `scheduled ride` list is always
rejected because several listed fares can mimic one offer.

An opened scheduled ride is the exception: exactly one leg, a standalone
`Reserve` action, and a Today/Tomorrow clock time are required. Pickup remains
zero because Lyft does not expose current-to-pickup distance there; the one
explicit leg is scored as the trip and category is `Scheduled`.

### DoorDash (Beta)

A complete card requires Accept/Accepter, a Guaranteed/Garantie marker, route
language (pickup/drop-off/deliver-by/retail equivalents), one positive payout,
and one positive route distance. The whole displayed distance is stored as the
trip; pickup and duration are zero. Absolute deliver-by times are not treated
as duration. Item and pickup counts classify retail/shop-and-deliver and bundle
workload.

Because duration is zero, `$ / hr` mode falls back to `$ / km` and its distance
thresholds.

### Instacart (Beta)

A complete batch requires Accept, a positive payout and route distance, and an
explicit `Shop and deliver` or `Delivery only` type. Shop-and-deliver also
requires an item count; this prevents shopping work from being scored as pure
driving when workload is unknown. Delivery count is clamped to one through
three. Items and units are retained. Pickup and duration are zero, so hourly
mode falls back to distance scoring.

### Skip (Beta)

A complete card requires Accept, pickup/restaurant language, delivery/customer
language, a positive payout, and a positive route distance. The whole distance
is stored as the trip; pickup and duration are zero. Item count and Shop & Pay
category are retained. Arrival clock times are not treated as duration, so
hourly mode falls back to distance scoring.

## Uber screenshot OCR

OCR is on-device and is used only while Uber is selected. Accessibility remains
the source of package identity, triggering, card lifecycle, and outcome
evidence. OCR supplies only offer economics that Accessibility cannot expose.

The current path is:

1. A selected active app emits an empty, incomplete, or offer-shaped frame.
2. FoxyCo requests at most one screenshot per 1.5 seconds. Busy/cooldown misses
   can schedule one bounded retry, including a cross-app probe while another
   selected driver app is active.
3. The FoxyCo overlay rectangle is redacted from the bitmap.
4. Bundled ML Kit recognizes text in memory and sorts lines top-to-bottom,
   left-to-right.
5. Native code keeps one spatially coherent region from a recognized Uber tier
   to its Match/Accept button, or to its trip row when the button is missed.
6. Dart isolates the tier-to-action/trip lines again and requires Uber tier
   evidence before invoking `UberParser`.
7. The bitmap is erased and recycled; only recognized strings cross to Dart.

Late OCR is discarded if the Accessibility generation changed while capture
was running. It is also discarded when the captured active package is not a
recognized, currently selected driver app. This prevents screenshots viewed in
Gallery or another app from replaying an old offer.

Known OCR corruption guards:

- a three-or-more-digit amount without a decimal, such as OCR turning `$7.54`
  into `$754`, is never scored or stored;
- a three-or-more-digit parenthesized distance without a decimal, such as OCR
  turning `30.4 km` into `304 km`, is never scored or stored;
- changed Uber economics on a live/recent identical route must repeat once
  before replacing the current value; and
- history hydration collapses known dropped-decimal and distance-as-payout OCR
  correction pairs.

If OCR succeeds but contains no Uber card, native code emits an internal
no-card marker. That marker clears the active Uber pill and may restore a
covered non-Uber offer that was captured no more than 15 seconds earlier.

## Cross-app and stacked-offer behavior

When a Hopp, Lyft, or other selected card is active and Uber draws a card above
it without emitting an Uber Accessibility event:

1. every active lower-app event triggers a rate-limited Uber OCR probe, even
   when the lower app exposes only map text;
2. the lower offer may parse normally while that screenshot is in flight;
3. a confirmed Uber OCR offer replaces the lower pill and owns the visible
   lifecycle;
4. repeated lower-app frames are cached when complete and can neither overwrite
   nor clear the Uber pill;
5. OCR polling checks whether the Uber card is still visible; and
6. after the no-card marker, a still-fresh covered offer is parsed and shown
   again.

An active foreground switch can clear a pill owned by another platform.
Background events cannot keep alive or clear another app's pill. If the top
offer-like window ID changes, the old pill is cleared before using the new
window. These rules prevent stale lower windows and background apps from
driving the visible verdict.

## Verdict calculation

All offers are normalized before scoring:

```text
totalKm      = pickupKm + dropoffKm
totalMinutes = pickupMinutes + dropoffMinutes
pricePerKm   = payout / totalKm
pricePerHour = payout / totalMinutes * 60
```

Zero distance produces a zero distance rate and therefore BAD. If the optional
minimum payout rule is enabled and `payout < minimum`, the verdict is BAD before
rate scoring.

The selected ruleset is rideshare for Uber rides, Hopp, and Lyft; it is the
separate delivery ruleset for Uber Eats, DoorDash, Instacart, and Skip. The
driver can choose `$ / km` or `$ / hr` independently for those two rulesets.
When hourly mode is selected but parsed minutes are zero, the engine falls back
to `$ / km` and the distance thresholds.

For the active rate and thresholds:

```text
rate >= goodAtOrAbove  -> GOOD
rate <  badBelow       -> BAD
otherwise              -> OK
```

Defaults are GOOD at or above `$1.50/km`, BAD below `$1.00/km`; hourly defaults
are GOOD at or above `$30/hr`, BAD below `$20/hr`. Settings can change these.
Display currency is a label only: FoxyCo does not perform foreign-exchange
conversion.

The scoring snapshot stored with each history row preserves the rate mode,
thresholds, minimum payout rule, pickup-near threshold, distance unit, and
currency that explained that verdict at detection time.

## Entitlement and verdict display

Entitlement does not decide whether an offer is detected, parsed, scored, or
recorded. Immediately before showing a real offer, the overlay controller
refreshes access and adds the current entitlement state to the payload. The
overlay isolate hides protected verdict/economic content for a locked account.
An entitlement transition while a pill is visible clears that pill so the next
offer is rendered from fresh access state.

This separation is important when diagnosing “no verdict” reports: first check
whether History contains the offer. A history row with a locked pill indicates
an entitlement/display problem; no row indicates capture, selection, watching,
or parser confidence.

## Pill lifecycle, duplicates, and history

The live offer fingerprint is:

```text
platform | payout | pickupKm(1dp) | totalKm(1dp) | totalMinutes(1dp) |
deliveryCount
```

Repeated frames with the same fingerprint do not re-show the pill. A different
offer replaces it. The pill clears after five seconds, after 500 ms of confirmed
card absence, or after seven seconds without an active event from its owning
app. Ambiguous partial frames with payout/action/leg evidence keep it alive;
positive browse or accepted-trip evidence confirms the card left.

History uses a stricter full-card comparison and a two-minute dedupe window so
card flicker can re-show a useful pill without double-counting the offer. A
positively confirmed card departure permits a genuinely new identical offer.
History is capped at 2,000 rows and then applies the configured retention.

## Outcome inference

Outcome tracking is separate from the five-second pill lifecycle. The exact
history row most recently created for each platform remains the candidate.

- Uber ride screens such as Picking up, Waiting for rider, Start/Complete tier,
  or Dropping off imply taken.
- Lyft `Added to queue`, Arrive, Passenger notified, and slide-to-pickup/dropoff
  screens imply taken. Queued offers require the explicit queued confirmation.
- Hopp Arrived/Waiting/Start Trip/End Trip/Confirm Price/Rate passenger and
  related trip controls imply taken.
- a positive browse/home frame implies missed;
- ambiguous frames leave the outcome unknown; and
- delivery platforms currently have no accepted-trip phrase rules.

Automatic inference never overwrites a driver's manual outcome correction.
Manual final payout also remains separate from the originally offered payout
and verdict.

An accepted-trip marker that was already visible when a new offer appeared is
not evidence that the new offer was taken. This occurs when Uber or Lyft draws
a new request over the current trip screen. FoxyCo leaves that new offer's
outcome unknown unless the app emits an explicit queued-offer confirmation;
the driver can still correct it manually in History.

## Diagnostics and required verification

Parser health records successful parses, textless frames, and card-like misses.
Production diagnostic logs contain package, source, node count, parser shape,
timing, parsed economics, and verdict; they do not contain raw screen/OCR text,
addresses, rider names, or screenshots. Repeated identical miss signatures are
log-throttled to once per 10 seconds.

If app resume finds permissions intact but native overlay health inactive, the
shift remains Watching, the window is recreated, and the recovery reason is
written to diagnostics. Native logcat also records overlay generation, window
format/size, and surface create/change/destroy events without screen content.

For every capture/parser/scoring change:

1. update this document if any behavior above changed;
2. add or update the smallest parser or `offer_watcher_test.dart` regression;
3. run `flutter analyze` and the full Flutter test suite;
4. run the relevant real-device cases in `docs/MANUAL_TESTS.md`, including the
   stacked Uber-over-other-app case for OCR changes; and
5. verify signed release output with the release checklist before Play upload.

Host tests prove deterministic routing and scoring. Real-device testing is
still required for Android window ordering, protected Uber rendering,
screenshot permission, overlay visibility, and app-version selector changes.
