# DoorDash, Instacart and Skip offer-card research

**Research date:** 2026-08-20  
**Purpose:** define a conservative first parser contract from public evidence.
This is not a substitute for current Android accessibility dumps and live
device verification.

## Evidence reviewed

### DoorDash

- [Official redesigned offer screen](https://help.doordash.com/en-au/dashers/article/redesigned-accept-modal)
  and its [comparison image](https://images.ctfassets.net/ubxkqizxnrpo/4HHStCqo5ghqH9leDPLJNN/bffb7f6c61707a01a68a25fb2c7cd019/rtaImage__39_.png?fm=png&q=80&w=1200).
- [Official batched-offer guide](https://dasher.doordash.com/en-ca/blog/batched-offers-explained)
  and its [batch screenshot](https://images.ctfassets.net/trvmqu12jq2l/66BIzB4lndsKJM4VRZnHHR/c0587c9ab2068a4702476b6d5c16d329/Batched_1_New.png?fm=png&q=60&w=1200).
- [Recent driver-posted Canadian retail offer](https://www.reddit.com/r/doordash_drivers/comments/1tciwr1/accept_or_decline/)
  showing a localized French card, kilometres, item count and a retail pickup.

Observed card variants include a single restaurant delivery, multiple pickups,
and retail/shop-and-deliver. The stable visible fields are:

| Card text | FoxyCo field | Initial handling |
|---|---|---|
| `$7.50 Guaranteed (incl. tips)` | `payout` | Required; total guaranteed offer, never add tips again |
| `1.6 mi` / `4.9 km` | `totalKm` | Required; stored canonically in kilometres |
| `Deliver by 10:45 AM` | none yet | Context only; an absolute deadline is not job duration |
| `Restaurant pickup`, `Pickup`, `Customer dropoff` | offer signature | Required structural evidence |
| Multiple pickup rows | `deliveryCount` | Count pickup/order rows when reliable |
| `3 items` / `16 articles` | `itemCount` | Optional delivery workload metadata |
| `Accept` / `Accepter` | offer signature | Required action affordance |
| Countdown number | none | Never parse as payout, distance or duration |

The public images do not expose a dependable pickup-versus-delivery distance
split or total duration. The beta parser must therefore store the displayed
route distance as total distance, leave pickup distance and minutes unknown,
and fall back to distance-rate scoring.

### Instacart

- [Official earnings explanation](https://company.instacart.com/shoppers/shopper-earnings)
  states that batch pay accounts for travel to the store and customer, item
  quantity/weight and expected shopping time.
- [Official upfront-information announcement](https://company.instacart.com/shopper-community/creating-new-ways-to-earn)
  confirms total Instacart pay, customer tips, items, store and distance are
  shown before acceptance.
- [Recent driver-posted batch-list card](https://www.reddit.com/r/InstacartShoppers/comments/1tlkcvt/missing_something_like_this_will_ruin_your_whole/)
  shows `3 shop and deliver`, item/unit counts, mileage, store and total pay.
- [Driver-posted detailed batch example](https://www.reddit.com/r/InstacartShoppers/comments/1bkbooj/would_you_have_accepted_this_batch/)
  provides a second real-world layout reference.

| Card text | FoxyCo field | Initial handling |
|---|---|---|
| `$267.22` | `payout` | Required total offer |
| `3 shop and deliver` | `deliveryCount`, `category` | Required order type; count defaults to one when omitted |
| `29 items (36 units)` | `itemCount`, `unitCount` | Required for shop-and-deliver confidence |
| `9.6 mi` | `totalKm` | Required for delivery scoring |
| Store name/logo | none yet | Structural context only; do not persist addresses |
| Batch pay and customer tip breakdown | optional future metadata | Never sum when the displayed total was already parsed |
| Heavy pay / boost tags | `category` only | Do not add to payout again |
| Accept action | offer signature | Required on a detailed card; list-only cards remain diagnostics until verified |

Instacart also exposes Shop Only and Delivery Only work. Shop Only has no useful
driving-distance rate, so the initial parser must reject it rather than produce
a misleading verdict. Multi-store and multi-customer batches require live
fixtures before their route distance semantics can be considered verified.

### Skip Courier

- [Current Google Play listing](https://play.google.com/store/apps/details?id=com.delco.courier)
  confirms the Android package `com.delco.courier` and current product name
  **Skip - Courier**.
- [Official courier application page](https://couriers.skipthedishes.com/application)
  publishes a detailed offer screenshot showing complete earnings, total travel
  distance, pickup, delivery, arrival times, countdown and Accept/Decline.
- [Official Courier Pay basics](https://insidetrack.skipthedishes.com/faq/courier-pay-basics/)
  says complete earnings, pickup/delivery locations and estimated distance are
  shown before acceptance.
- [Official Offer basics](https://insidetrack.skipthedishes.com/faq/offer-basics/)
  confirms partner, customer, pay and distance plus a 60-second long-press
  Accept action.
- [Official Ontario Bill 88 FAQ](https://insidetrack.skipthedishes.com/faq/bill-88/)
  confirms total pay is upfront and may include Transit Pay, tips, bonuses and
  incentives; displayed estimated distance compensation can differ from the
  final weekly adjustment.

| Card text | FoxyCo field | Initial handling |
|---|---|---|
| `$14.40 includes tip and bonus` | `payout` | Required complete offer; never add tip/bonus again |
| `5 km total travel distance` | `totalKm` | Required; store canonically in kilometres |
| Pickup/partner row | offer signature | Required route endpoint; address is never persisted |
| Delivery/customer row | offer signature | Required route endpoint; customer/address is never persisted |
| Arrival clock times | none yet | Context only; absolute clock times are not job duration |
| `Accept offer` + countdown | offer signature | Accept required; countdown ignored |
| Shop + Pay and explicit item count | `category`, `itemCount` | Optional workload metadata when visible |

The initial parser requires pay, distance, Accept and both route endpoints. It
does not try to reconcile jurisdiction-specific post-delivery distance-payment
adjustments or infer duration from arrival times.

## Implementation boundary

- One parser file per platform; shared accessibility/OCR capture remains
  unchanged.
- All three delivery platforms are labelled **Beta** and disabled by default.
- Accessibility and OCR text feed the same strict parser.
- Missing or ambiguous required fields return `null`; zero is never substituted
  for an unknown economic field.
- Automatic accepted/declined outcome inference stays disabled until genuine
  post-accept and post-decline screens are captured.
- Public screenshots seed tests, but a platform is not promoted from Beta until
  package/version, positive and negative accessibility dumps, OCR output and
  live card math are verified on Android.

## Still needed from real devices

For each platform: package/version confirmation, complete accessibility node
dump, OCR text with bounds, home/map negative frame, earnings/history negative
frame, partial render, single and stacked/batch cards, accepted flow,
declined/expired flow, locale/unit variants, and measured overlay latency.
