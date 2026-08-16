# Comet competitive and technical analysis

**Analysis date:** 2026-08-14  
**Comet package:** `io.comet.app`  
**Inspected build:** `1.0.7` (`versionCode 33`, target SDK 36)  
**FoxyCo workspace:** current development tree on 2026-08-14  
**Purpose:** document what Comet contains and how it appears to work, compare it with FoxyCo, and provide a decision-ready expansion plan. This is research, not authorization to copy proprietary code or branding.

## 1. Executive conclusion

Comet is not using a secret Uber API. Its core Android path is a native accessibility service that reads visible text and content descriptions from supported driver apps. It supplements that path with active-window and multi-window scanning, short-interval polling, notification-triggered wake-ups, and optional on-device screenshot OCR. A native parser validates the text, computes economics, displays an overlay, speaks the grade, and stores an extracted trip record.

The installed APK contains support declarations for 13 platform labels:

1. Uber
2. Uber Eats, inside the Uber Driver package
3. Lyft
4. DoorDash
5. DiDi
6. Grubhub
7. Walmart Spark
8. Instacart
9. Hopp
10. Empower
11. Yandex Pro
12. Taxsee / Maxim
13. Pathao

That list does **not** prove equal quality across all 13 platforms. The APK has dedicated parsers for Pathao, Taxsee, and Yandex Pro and a broad generic card parser for the other apps. Only Uber was live-tested during this analysis. That test proved Comet's OCR fallback can be fast, but it also exposed a material parser error: the visible `4 min / 0.8 km` pickup leg was recorded as `0.0 km`, inflating the displayed hourly and per-distance values.

FoxyCo already has the cleaner core calculation: pickup plus trip distance and time, strict low-confidence rejection, isolated platform parsers, parser-health tracking, passive outcome inference, local history, and a simple lifetime entitlement model. Its main technical gap is capture resilience. It currently depends on accessibility events and has no screenshot OCR fallback or active post-signal polling comparable to Comet.

**Recommended direction:** do not attempt all 13 platforms at once and do not reproduce Comet feature-for-feature. First harden FoxyCo's shared capture layer, then add platforms one at a time from real captured fixtures. Prioritize DoorDash, Walmart Spark, and Instacart after Uber/Uber Eats/Lyft are reliable. Keep Hopp. Add region-specific platforms only when a tester can provide genuine offer screens and node/OCR captures.

## 2. Evidence and confidence rules

This report deliberately separates facts from inferences.

| Label | Meaning |
|---|---|
| **Confirmed — runtime** | Observed on the connected Samsung device during a real offer. |
| **Confirmed — APK** | Present in the installed APK, package dump, manifest/configuration, resources, DEX classes, or Hermes bundle. |
| **Confirmed — public** | Stated by Comet's developer in the linked public launch post. |
| **Strong inference** | Multiple static/runtime signals support the conclusion, but the exact source code or a live platform test was unavailable. |
| **Unverified** | Marketing declaration, dormant code, or feature that needs a controlled test. |

Evidence reviewed:

- Installed APK split set in `C:\Users\vamsi\comet-apks`.
- Android package and accessibility dumps: `package.txt` and `accessibility.txt`.
- Full device runtime log: `runtime.txt`.
- Four live screenshots in `C:\Users\vamsi\Downloads\comet`.
- APK assets, Android binary resources, DEX string/class metadata, native module names, and the Hermes JavaScript bundle.
- Comet developer's public launch post: <https://www.reddit.com/r/uberdrivers/comments/1vne322/new_free_app_called_comet_im_looking_for_feedback/>.
- FoxyCo source, tests, architecture, roadmap, monetization document, and full-app audit.

Limits:

- Release obfuscation and Hermes bytecode prevent reconstruction of every UI branch.
- Server-side RevenueCat, Firebase, exchange-rate, referral, and backup behavior cannot be fully proven from the APK.
- Google Play prices are localized and fetched at runtime. Static product names do not establish current prices.
- A parser class or package name proves implementation intent, not real-world accuracy.
- We did not bypass authentication, extract private app data, intercept encrypted traffic, or invoke actions inside driver apps.

## 3. Installed Comet application profile

| Item | Finding | Confidence |
|---|---|---|
| Framework | React Native / Expo 54, Hermes bytecode, new architecture enabled | Confirmed — APK |
| Native core | Kotlin package `expo.modules.cometengine` | Confirmed — APK |
| App version | `1.0.7`, code 33 | Confirmed — APK/device |
| Android support | min SDK 24, target SDK 36 | Confirmed — device package dump |
| Main local database | Expo SQLite is packaged | Confirmed — APK |
| OCR | Google ML Kit Latin text-recognition models packaged on-device | Confirmed — APK |
| Billing | RevenueCat plus Google Play Billing | Confirmed — APK |
| Ads | Google Mobile Ads rewarded-ad controller | Confirmed — APK |
| Cloud/messaging | Firebase components and Expo notifications are packaged | Confirmed — APK |
| Backup | Android `allowBackup=false`; app UI separately advertises account cloud backup | Confirmed — APK/bundle |
| iOS | Expo configuration contains an iOS bundle identifier, but public developer statement says the usable release is Android-only and iOS is in progress | Confirmed — APK/public |

Important requested Android permissions and capabilities:

- Accessibility service binding.
- Display over other apps.
- Notification listener service.
- Foreground service and special-use foreground service.
- Post notifications, vibration, wake lock, boot completed, and ignore battery optimizations.
- Internet/network state.
- Billing and license checks.
- Advertising ID/ad-services permissions.
- Camera is declared but was not granted on the inspected device; it is likely inherited from packaged Expo functionality and is not required for live offer OCR, which uses accessibility screenshots.
- Fine/coarse location and legacy external-storage permissions are explicitly blocked in the Expo configuration.

This permission surface is materially larger than FoxyCo's current surface because Comet includes ads, push/cloud functions, a notification listener, billing middleware, and screenshot OCR.

## 4. Comet's end-to-end offer pipeline

The following flow is supported by APK classes and the real Uber trace:

```text
Supported app emits window/content/click event
        or supported-app notification wakes the engine
        or short polling loop runs after a signal
                         |
                         v
Accessibility service reads active root + interactive windows
                         |
             text/contentDescription candidates
                         |
          optional accessibility screenshot -> ML Kit OCR
                         |
                         v
OfferTextSourceSelector chooses/merges the best fresh source
                         |
                         v
OfferPlatformDetector -> platform-specific/generic parser
                         |
                         v
OfferProcessingPipeline validates card and fields
                         |
                         v
TripEvaluationEngine computes grade and metrics
                         |
           +-------------+-------------+
           |                           |
           v                           v
Overlay HUD / bubble             voice grade/chime
           |
           v
Pending offer -> accepted/skipped/rejected history enrichment
```

### 4.1 Accessibility events and scope

Comet's accessibility service requests:

- `TYPE_VIEW_CLICKED`
- `TYPE_WINDOW_STATE_CHANGED`
- `TYPE_WINDOW_CONTENT_CHANGED`
- `TYPE_WINDOWS_CHANGED`
- interactive-window retrieval
- view ID reporting
- window-content retrieval
- screenshot capability
- 50 ms notification timeout

The configured package scope contains:

```text
com.ubercab.driver
com.lyft.android.driver
com.doordash.driverapp
com.didiglobal.driver.au
com.grubhub.driver
com.walmart.sparkdriver
com.instacart.shopper
ee.hopp.driver
com.yazam.empower.driver
ru.yandex.taximeter
com.taxsee.driver
com.pathao.driver
```

Uber Eats is not a second Android package in this design. Delivery offers are identified inside `com.ubercab.driver`.

### 4.2 Five capture/detection mechanisms

Comet's developer publicly describes “5 systems.” The APK does not expose a clean numbered marketing list, but the implementation supports the following five-part interpretation:

| Mechanism | What it does | Evidence | Status |
|---|---|---|---|
| Accessibility event trigger | Reacts to relevant changes immediately | Service config and runtime binder activity | Confirmed |
| Root/window node scan | Reads the active root and available interactive windows, including text and content descriptions | Service capabilities/classes | Confirmed |
| Burst polling/heartbeat | Re-scans after a signal so transient or non-eventing cards are not missed | `startPolling`, `stopPolling`, poll runnable, runtime cadence | Confirmed |
| Notification wake-up | A supported app notification starts or accelerates a scan | `OfferNotificationListener` | Confirmed |
| Pixel Capture OCR | Takes a transient accessibility screenshot and runs on-device ML Kit OCR | screenshot capability, ML Kit assets, OCR classes, runtime trace | Confirmed |

Notification handling appears to be a **wake signal**, not the principal offer parser. The listener recognizes the posting package and asks the accessibility engine to scan. No evidence showed it depending on private Uber notification payloads.

### 4.3 Timing observed in the inspected build

Static names, configuration strings, and the runtime trace indicate:

- Initial polling around every 600 ms for roughly the first five seconds after activity.
- Slower polling around every 1,500 ms afterward.
- Polling stops after several consecutive misses; the inspected behavior indicated four misses.
- OCR screenshots are rate-limited to about one every 1,200 ms.
- Scans are queued/drained rather than launching unlimited concurrent work.
- OCR has in-flight suppression, stale-result rejection, rerun requests, result-age checks, and a clear grace period.

These values describe build 1.0.7 and can change in later releases.

### 4.4 Real Uber timing

During the live offer at 10:32:

1. The Uber card appeared.
2. Android screenshot capture occurred at approximately `10:32:53.701`.
3. OCR started at `10:32:53.744`.
4. OCR succeeded at `10:32:53.890`.
5. Comet requested text-to-speech at `10:32:54.253`.
6. The overlay appeared at approximately `10:32:54.272`.

The overlay arrived about 570 ms after screenshot capture and less than 400 ms after OCR success. Repeated screenshot/OCR passes continued at roughly 1.2–1.4 second intervals.

This proves Pixel Capture was active and fast. Because Comet's release build did not emit a source-selection log, it remains a strong inference—not absolute proof—that OCR supplied the winning text candidate. The temporal ordering and repeated OCR activity make that inference highly likely.

## 5. Parser and validation logic

### 5.1 Native parser components

The APK contains these first-party native components:

- `OfferPlatformDetector`
- `OfferCardParser`
- `PathaoOfferParser`
- `TaxseeOfferParser`
- `YandexProOfferParser`
- `OfferTextSourceSelector`
- `OfferProcessingPipeline`
- `TripEvaluationEngine`
- `AcceptedTripScreenDetector`
- `CompletedEarningsParser`
- `EarningsTipParser`
- `PendingOffers`
- `PendingCompletedEarnings`
- `PendingEarningsTips`
- `OfferWindowCoordinator`
- `EngineDiagnostics`

This structure indicates a generic parser for similarly shaped North American/European cards plus specialized parsers for platforms whose layouts or locale conventions differ substantially.

### 5.2 Generic card gates

Recovered regexes and method names show the generic parser checks combinations of:

- A recognized action such as `Accept`, `Accept ride request`, or `Match`.
- A plausible fare amount rather than any number on screen.
- One or more duration/distance legs.
- Supported time forms including hours and minutes.
- Supported distance forms including `mi`, `mile(s)`, `km`, `kilometer(s)`, and localized spellings.
- Decimal comma and decimal point formats.
- Delivery/order count and stop markers.
- Platform/package identity.
- Pickup and trip plausibility bounds.

The parser explicitly recognizes or excludes labelled monetary components such as:

- fare / estimated fare
- tip / tip included
- surge / surge promotion
- toll / toll reimbursement
- bonus
- “Pro Perk”
- delayed ride guarantee

This matters because simply choosing the first currency amount would frequently confuse a bonus, toll, tip, or hourly-rate label with the offer payout.

### 5.3 Currency parsing

The native regexes explicitly include at least dollar-like symbols, Brazilian real (`R$`), and Costa Rican colón (`CRC`) representations. The UI bundle contains localized currency-code/symbol handling and RevenueCat-localized prices.

Comet's developer stated publicly on 2026-08-13 that the app had 10 supported currencies and monthly value synchronization, then stated on 2026-08-14 that an update adding 99 currencies was planned. The inspected APK alone does not establish whether all 99 were live in build 1.0.7.

### 5.4 Source selection

`OfferTextSourceSelector` ranks candidates and tracks source freshness. The service can receive different text from:

- the active root,
- another interactive window,
- a background/stale window,
- screenshot OCR,
- a scan triggered by a notification.

Selection is necessary because overlays, maps, and background gig apps may all retain accessible nodes. Comet tracks stale OCR results and clear authority, suggesting OCR is not blindly trusted forever after one successful scan.

### 5.5 Evaluation inputs

The native configuration and threshold models contain support for:

- minimum earnings per mile/distance unit,
- yellow/borderline earnings per mile,
- minimum earnings per hour,
- yellow/borderline earnings per hour,
- maximum pickup distance,
- yellow pickup-distance boundary,
- maximum trip distance/range,
- optional range enforcement,
- minimum surge multiplier,
- pool/shared-ride preference,
- expected tip,
- grading hourly value after costs,
- manual cost per mile,
- vehicle-derived cost per mile,
- fuel type and fuel cost,
- trip and day gross fare,
- trip and day net profit,
- profit margin,
- voice grade and profit chime.

The detail screen can explain each individual rule, rather than showing only the final grade.

### 5.6 Important verified calculation defect

The real Uber card showed:

- Fare: `$11.15`
- Pickup: `4 min`, `0.8 km`
- Trip: `23 min`, `14.8 km`

Comet's overlay/detail stored:

- Duration: `23 min`
- Distance: `14.8 km`
- Pickup distance: `0.0 km`
- `$0.75/km`
- `$29.09/hour`

Those displayed rates are internally consistent only when pickup is omitted:

```text
$11.15 / 14.8 km = $0.753/km
$11.15 / 23 min * 60 = $29.09/hour
```

Correct end-to-end economics for the visible card are:

```text
total distance = 0.8 + 14.8 = 15.6 km
total time     = 4 + 23 = 27 min
$ per km       = 11.15 / 15.6 = $0.7147/km
$ per hour     = 11.15 / 27 * 60 = $24.78/hour
```

The detail screen retained both addresses but claimed `0.0 km pickup`, so this is a parser/data-association failure, not an intentional “trip-only” display convention. The developer's launch post independently acknowledges and reports fixing a similar missed-pickup-time bug in launch imagery. The installed build still reproduced the defect on our card.

The detail screen also showed “Net $11.15 after fuel & wear.” Because that equals the fare, either the active vehicle cost was configured as zero or cost subtraction was not applied. We cannot classify that as a defect without the exact profile settings.

## 6. Platform-by-platform implementation matrix

No platform should be marked “working” until a real card has been captured and its displayed math checked against the source card.

| Platform | Android package / detection | Apparent parser path | APK support | Live proof in this study | Confidence and notes |
|---|---|---|---|---|---|
| Uber rides | `com.ubercab.driver` | Generic `OfferCardParser` | Yes | Yes | Capture works; tested card lost pickup leg. |
| Uber Eats | Same Uber package; delivery/card-content detection | Generic parser with delivery/order/stop rules | Yes | No separate Eats card | Code and public list confirm intent. Needs single, stacked, shop-and-pay, and add-on fixtures. |
| Lyft | `com.lyft.android.driver` | Generic parser | Yes | Not with Comet during this study | Publicly supported; FoxyCo has prior real-device evidence for its own Lyft path. |
| DoorDash | `com.doordash.driverapp` | Generic parser plus DoorDash-specific scan/parse hooks | Yes | No | DEX contains `parseDoorDash`, `doorDashScans`, and “DoorDash Offers.” Needs offer, stacked order, and total-pay fixtures. |
| DiDi | `com.didiglobal.driver.au` | Generic parser / platform detector | Yes | No | The package is specifically the Australian driver build; other country package IDs may differ. |
| Grubhub | `com.grubhub.driver` | Generic parser plus Grubhub scan counters | Yes | No | `grubhubScans` exists; parser quality unverified. |
| Walmart Spark | `com.walmart.sparkdriver` | Generic delivery/batch parser | Yes | No | Requires batch, multi-stop, shopping, curbside, and return-order fixtures. |
| Instacart | `com.instacart.shopper` | Generic delivery/batch parser | Yes | No | Package and label present; batch screen geometry and hidden mileage variants need testing. |
| Hopp | `ee.hopp.driver` | Generic parser with Hopp recognition | Yes | No Comet offer | Publicly supported. FoxyCo has a dedicated parser and accepted-trip evidence. |
| Empower | `com.yazam.empower.driver` | Generic parser / platform detector | Yes | No | Package confirmed in APK; regional availability limits testing. |
| Yandex Pro | `ru.yandex.taximeter` | Dedicated `YandexProOfferParser` | Yes | No | Dedicated parser is stronger implementation evidence, but localization/layout variants still require real fixtures. |
| Taxsee / Maxim | `com.taxsee.driver` | Dedicated `TaxseeOfferParser` | Yes | No | Dedicated parser present. Maxim branding/package can vary by region. |
| Pathao | `com.pathao.driver` | Dedicated `PathaoOfferParser` | Yes | No | Dedicated parser present. Currency, script, and regional variants require fixtures. |

Missing but potentially valuable platforms for FoxyCo include SkipTheDishes, Amazon Flex, Bolt, inDrive, 99/99 Food, and region-specific delivery apps. Comet's developer publicly said Bolt research was planned; it is not in the inspected 13-platform package scope.

## 7. Non-parser Comet features and logic

### 7.1 Live companion and overlay

- Persistent companion/bubble over driver apps.
- Compact HUD with grade, duration, distance, fare, per-minute, per-distance, and hourly values.
- Detailed verdict screen with per-rule pass/fail explanations.
- Voice grade.
- Profit chime.
- Mute/audio controls and voice selection support.
- Bubble gesture controller and overlay palette/theme selection.
- 18 themes and multiple alternate launcher/companion icons are publicly advertised; 18 alternate activity aliases/icons are visible in the package dump.

### 7.2 Offer lifecycle and history

- Pending offers are correlated with later screens.
- Offers can become accepted, skipped, or rejected.
- `AcceptedTripScreenDetector` searches for strong post-acceptance states.
- History records fare, distance, duration, grade, and outcome.
- Daily totals and weekly comparisons are advertised publicly and supported by native day/weekly fields.
- Detail screens explain why a threshold passed or failed.
- The user can manually correct status, as shown by “Skipped” and “Mark accepted.”

### 7.3 Earnings completion and tips

Comet has separate parsers for completed earnings and tips. The public workflow is:

1. Driver opens the earnings/history area of the selected platform.
2. Driver scrolls through completed transactions.
3. Accessibility/OCR reads completion values such as fare, tip, surge, toll, and guarantees.
4. Comet matches those values to a pending/history trip.
5. The stored trip is enriched with updated earnings.

Recovered logic recognizes tip, tip included, surge, toll reimbursement, delayed-ride guarantee, and delivery pay plus tip. Matching likely uses combinations of platform, time/date, fare, duration, distance, and pending-trip state. False matches remain possible when two trips have similar values; this needs correction UI and confidence handling.

### 7.4 Vehicle economics

- Vehicle profiles.
- Free tier includes one profile; Pro strings say unlimited profiles.
- Fuel type.
- Fuel cost estimate from algorithm settings.
- Manual cost-per-mile option.
- Maintenance, insurance, and other vehicle-cost concepts in localized UI strings.
- Net profit and profit margin.
- Estimated range and cost explanations.

We cannot confirm the exact depreciation/maintenance formula from static evidence. It should not be copied without independent product validation; different countries and vehicle types require explicit user inputs.

### 7.5 Account, backup, referral, and feedback

- Google identity configuration is present.
- Firebase messaging/components are present.
- UI strings advertise secure cloud backup of local account history and settings.
- Referral-code and free-month banking strings are present.
- The referral rule represented in strings is approximately one free month for each pair of referred friends that reaches a paid period, with additional pairs earning additional months. This is unverified server-side behavior.
- Feedback/diagnostics UI is present; diagnostic wording claims privacy-safe output.

### 7.6 Localization

The developer advertises 23 supported languages. The Hermes bundle contains extensive translations well beyond English, including European, Asian, and African languages. Locale-aware dates, units, billing strings, and currency formatting are present.

Localization is separate from parsing. A translated Comet UI does not automatically mean every driver app's localized offer grammar is equally supported.

## 8. Comet monetization model

### 8.1 Confirmed structure

- Free mode: 10 graded offers per day.
- One optional rewarded ad adds 5 more graded offers for that day.
- The public launch statement says the ad is limited to once per day.
- Each graded card consumes one credit whether the user accepts it or not.
- RevenueCat manages paid entitlement/product offerings.
- Google Play Billing is packaged.
- Monthly and annual subscription paths are present.
- One-week free-trial strings are present.
- Lifetime/one-payment access strings and a lifetime product path are also present.
- Paid/Pro mode removes the grading limit and unlocks additional profile/backup features.

### 8.2 Price status

The exact Comet prices are **not established by this analysis**. Product IDs and plan types are static, but Google Play/RevenueCat returns localized current prices and offers dynamically. Any number copied from another country, an old screenshot, or a storefront cache could be wrong.

To close this item, capture Comet's plan/paywall screen on the installed device showing:

- monthly price,
- annual price,
- lifetime price if offered,
- trial duration,
- renewal text,
- whether taxes are included,
- Canadian storefront currency.

No purchase is required.

### 8.3 FoxyCo monetization recommendation

FoxyCo's existing authoritative plan is simpler:

- free download,
- opt-in seven-day trial,
- one-time lifetime unlock,
- planned price `$12.99` using Google Play localized pricing,
- no subscription,
- no ads.

Keep that model for the initial release. It is easier to explain, test, support, and reconcile offline. A free daily-credit/ad system introduces ad consent, advertising identifiers, network dependence, additional Data Safety declarations, credit abuse logic, and another reason for drivers to distrust an accessibility app.

Revisit subscriptions only after real operating costs exist—for example, paid cloud backup or a maintained server feature. Parser updates and on-device OCR do not by themselves justify recurring billing.

## 9. Privacy, security, and Play policy observations

### 9.1 Positive design signals in Comet

- Accessibility package scope is limited to named driver apps.
- The service does not request gesture performance in the inspected configuration.
- Pixel Capture uses `AccessibilityService.takeScreenshot`, not continuous screen recording.
- ML Kit OCR models are packaged for on-device recognition.
- UI disclosure states screenshots are temporary, not stored, and not uploaded.
- Location permissions are blocked.
- External Android backup is disabled.

### 9.2 Remaining trust surface

- The app has Internet access.
- It has Firebase, RevenueCat, ads, push notifications, and cloud-backup features.
- It can read notifications from enabled gig apps.
- It can take screenshots while its accessibility service is active.
- Extracted trip/history data may be backed up when cloud backup is enabled even if raw screenshots are not.
- Advertising ID permissions and rewarded ads expand data disclosures.

Static analysis cannot prove that no raw text ever leaves the phone. That claim requires traffic testing, privacy-policy review, and server-side trust. FoxyCo can differentiate itself by keeping raw text/images ephemeral, offering OCR without ads, minimizing SDKs, and documenting exactly which extracted numeric fields are persisted.

### 9.3 FoxyCo policy boundary to preserve

FoxyCo's existing rule remains correct: **read and advise only**. Never auto-accept, auto-decline, tap, gesture, or control another app. Platform expansion must not broaden the accessibility service into automation.

Adding OCR would require updated onboarding, accessibility disclosure, privacy policy, Play accessibility declaration, Data Safety answers, and a review video that visibly explains temporary on-device screenshot processing.

## 10. FoxyCo current state versus Comet

| Capability | FoxyCo now | Comet 1.0.7 | Assessment |
|---|---|---|---|
| Core platform packages | Uber/Uber Eats, Lyft, Hopp | 13 platform labels / 12 packages | FoxyCo gap |
| Accessibility event reading | Yes | Yes | Comparable foundation |
| Active root/all-window reading | Yes through vendored plugin | Yes | Comparable intent; device behavior differs |
| Burst polling after signal | No dedicated native loop | Yes | FoxyCo gap |
| Notification listener wake-up | No | Yes | Optional gap; do not add until polling/OCR evidence shows value |
| Screenshot OCR fallback | No | Yes, ML Kit on-device | Highest-priority FoxyCo gap |
| Strict per-platform parser files | Yes | Mixed generic + specialized | FoxyCo is easier to test/maintain |
| Fail-safe low-confidence behavior | Strong: returns null | Gates exist, but real test emitted wrong pickup | FoxyCo design advantage |
| Pickup + trip total | Yes | Intended, failed on tested Uber card | FoxyCo correctness advantage |
| Multi-stop folding | Yes for shared timeline grammar | Stop/order support present | Both support conceptually |
| Rate modes | Per distance or per hour | Both plus after-cost grading | Comet broader |
| Offer history | Yes, local | Yes, richer detail | FoxyCo has foundation |
| Passive accepted/missed inference | Yes | Yes plus manual correction | Comparable; Comet has richer workflow |
| Earnings/tip enrichment | No | Yes | Later FoxyCo opportunity |
| Vehicle profiles | Yes | Yes | Comparable base |
| True profit engine | No; fuel/wear deferred | Present/configurable | FoxyCo gap, not needed before reliable capture |
| Currency | CAD and USD labels, no FX | Multiple currencies and conversion/sync claims | FoxyCo gap in labels/locales; avoiding FX is preferable |
| Units | km/mi | km/mi and localization | Comparable base |
| Voice grade/chime | No | Yes | Useful safety/glanceability feature |
| Themes/icons | Premium FoxyCo theme, limited variants | 18 themes/icons | Cosmetic, low priority |
| Cloud backup | No offer cloud | Optional account backup | Keep local-first for launch |
| Monetization | 7-day trial + lifetime planned | Free credits/ad + subscription/annual/lifetime paths | FoxyCo simpler |
| Ads | No | Rewarded ad | FoxyCo trust advantage |
| Diagnostics/parser health | Yes, privacy-shaped miss counters/logs | Engine diagnostics | Both useful |
| Automated tests | Extensive FoxyCo tests/fixtures | Unknown | FoxyCo engineering advantage |

Current FoxyCo release status remains: code and legal remediation are substantially complete, but final build/device/Play gates are still open. The latest audit reports strict analysis passing and earlier totals through 333 tests, with full final-suite and signed-device verification still required.

## 11. Multi-currency design for FoxyCo

### 11.1 Do not convert live fares

An Uber offer displaying `€12.50` is already denominated in the driver's operating currency. FoxyCo should parse `12.50`, attach `EUR`, and evaluate it against that driver's EUR thresholds. It should not convert it to CAD or USD before grading.

Automatic FX conversion of thresholds creates several problems:

- A driver-set rule can change without the driver touching it.
- Exchange rates do not reflect local fuel, insurance, tax, wage, or cost-of-living differences.
- A converted `$1.50/km` Canadian rule is not automatically a sensible rule in India, Brazil, or the UK.
- Offline behavior and stale FX data become correctness concerns.

### 11.2 Recommended currency model

Expand the existing enum/model into explicit currency metadata:

- stable ISO 4217 code,
- display symbol,
- symbol-before/symbol-after formatting,
- decimal digits,
- decimal/group separators from locale,
- driver-selected thresholds stored per currency/profile,
- no exchange-rate service at launch.

Start with currencies required by supported test markets, not 99 speculative entries. A sensible first group is CAD, USD, GBP, EUR, AUD, NZD, BRL, and INR. Add a currency only with parser fixtures demonstrating its actual offer-card formatting.

### 11.3 Locale parsing requirements

Parsers must distinguish:

- `1,234.56` from `1.234,56`,
- currency symbols shared by multiple countries,
- non-breaking spaces,
- symbol suffixes,
- whole-number currencies,
- localized distance/time words,
- km versus miles independently of currency.

Currency parsing belongs in a shared tested utility; platform layout recognition remains in each platform parser.

## 12. Recommended platform expansion order

### Tier 0 — reliability before breadth

1. Verify FoxyCo was actively “Watching” during the Comet Uber test.
2. Capture FoxyCo's real miss diagnostics for the exact Uber card.
3. Add targeted capture resilience: short polling and on-device OCR fallback.
4. Retest Uber rides and Uber Eats variants.
5. Retest Lyft and Hopp on current app versions.

Shipping more parsers on an unreliable capture layer multiplies silent failures.

### Tier 1 — North American delivery demand

1. **DoorDash** — large addressable delivery use case; clear package; stacked orders and changing UI make fixture coverage essential.
2. **Walmart Spark** — valuable batch economics; requires multi-stop, shopping, curbside, and return handling.
3. **Instacart** — batch pay, item counts, and mileage; useful but more layout/offer-type variation.
4. **Grubhub** — add when a tester can supply current real cards.

### Tier 2 — regional rideshare

- DiDi.
- Empower.
- Yandex Pro.
- Taxsee / Maxim.
- Pathao.

Each requires a regional tester because package IDs, language, currency, and card layouts vary. A parser written only from internet screenshots should remain experimental and disabled by default.

### Tier 3 — demand-led additions

- SkipTheDishes for Canada.
- Amazon Flex.
- Bolt.
- inDrive.
- 99 / 99 Food.
- Other regional services based on tester demand.

Do not publish a supported-platform badge until at least one current real offer fixture, one negative/home-screen fixture, and one live device result exist for that platform.

## 13. Recommended capture architecture improvements

### 13.1 Preserve the current parser boundary

FoxyCo's `OfferParser` and `ParserRegistry` are already the right extension point. Do not replace them with one giant generic parser. Share only primitive parsing helpers—money, duration, distance, and locale normalization—while keeping platform card gates isolated.

### 13.2 Add source-aware capture

A screen read should carry:

- package,
- active/background window state,
- capture source (`accessibilityTree` or `ocr`),
- timestamp,
- normalized text nodes,
- optional bounds,
- source confidence/quality indicators.

The parser should produce either no result or an offer with field-level provenance. If tree and OCR disagree, do not silently mix arbitrary legs. Prefer a complete internally consistent candidate or reject it.

### 13.3 Poll only after a relevant signal

Use a short, bounded native polling burst after:

- a supported-package window/content event,
- switching into a supported app,
- a card-like incomplete frame,
- optionally a supported-app notification.

Do not poll continuously for an entire shift. Stop after a complete stable parse, confirmed card exit, foreground-package change, or a small miss limit.

### 13.4 OCR should be fallback, not default continuous capture

Suggested order:

1. Accessibility tree parse succeeds: use it, no screenshot.
2. Tree is empty or card-like but incomplete: request one OCR capture.
3. OCR candidate is complete and passes the same platform gates: use it.
4. Tree and OCR remain incomplete or inconsistent: show nothing and record a privacy-safe miss signature.

Rate-limit OCR and suppress concurrent captures. Crop or exclude FoxyCo's own overlay region so its numbers are not recursively parsed as the next offer. Never save the bitmap. Dispose it immediately after recognition.

### 13.5 Field-level checks that would have caught Comet's bug

For a two-leg rideshare card:

- Require pickup and trip legs when both labels are visible.
- Never replace a missing pickup with zero and still call the offer complete.
- Distinguish `unknown` from numeric zero.
- If OCR sees two duration/distance rows but the model contains one leg, reject.
- Compute displayed values only from the stored component legs.
- Include pickup and trip components in the fixture assertion, not only final fare/rate.

## 14. Recommended feature roadmap

### Phase A — capture reliability and proof

- Source-aware tree reads.
- Bounded post-event polling.
- ML Kit Latin OCR fallback via accessibility screenshot.
- OCR overlay exclusion/cropping.
- Tree-versus-OCR diagnostics without raw text retention.
- Current Uber/Uber Eats/Lyft/Hopp real-device matrix.
- Battery, ANR, process-death, and Android 14–16 checks.

**Exit:** the same real card is captured correctly by both accessible-node and OCR-fallback scenarios, including pickup plus trip.

### Phase B — platform expansion

- DoorDash.
- Walmart Spark.
- Instacart.
- Grubhub when fixtures are available.
- Per-platform experimental/verified status.
- Per-platform parser-health counters and version metadata.

**Exit per platform:** current package confirmed, positive and negative fixtures pass, live card math verified, no overlay over home/history screens.

### Phase C — internationalization

- Locale-aware money parsing.
- Initial currency set driven by tested markets.
- Driver thresholds per currency/profile.
- Localized units/date/time.
- UI localization only after parser/localization scope is clear.

**Exit:** currencies display and persist correctly without FX conversion; decimal-comma fixtures pass.

### Phase D — high-value driver features

- Voice grade with concise, configurable phrases.
- Optional profit chime.
- Vehicle cost profile and transparent cost-per-distance formula.
- Net hourly/per-distance grade mode.
- Manual correction of inferred accepted/missed status.
- Earnings/tip enrichment only after reliable matching research.

**Exit:** every net figure has an inspectable formula and can be disabled; no guessed cost is presented as fact.

### Phase E — release/monetization

- Complete existing seven-day trial and lifetime purchase device matrix.
- Localized Play pricing.
- Keep ads and subscriptions out of v1.
- Consider cloud backup only after launch demand and privacy design.

## 15. Platform research and test protocol

For every new platform, collect the following before coding:

1. Package name and version.
2. Country, language, currency, and distance unit.
3. Screenshot of a complete offer.
4. Accessibility node dump with text, content description, bounds, window ID, and active-window flag.
5. OCR text with bounding boxes from the same screen.
6. Home/map screen negative fixture.
7. Earnings/history screen negative fixture.
8. Partial-render frames.
9. Single and multi-stop/batch variants.
10. Accepted-flow and declined/expired-flow screens.
11. Manual expected fields and calculations.
12. Live overlay latency and battery observations.

Minimum parser checks:

- exact fare source,
- pickup time/distance,
- trip time/distance,
- all intermediate stops,
- bonus/tip/toll separation,
- currency and unit,
- action/card signature,
- negative-screen rejection,
- missing-field rejection,
- decimal-format handling,
- duplicate and stale-window handling.

## 16. Decisions recommended now

| Decision | Recommendation | Why |
|---|---|---|
| Expand platform enum/registry immediately to all 13 | **No** | Empty badges without validated parsers create false confidence. |
| Add OCR | **Yes, next major technical milestone** | Real Comet trace proves it closes a practical capture gap. |
| Add continuous polling | **No** | Use bounded bursts only; continuous scans cost battery and increase stale reads. |
| Add notification listener | **Defer** | It adds permission/policy surface. Test whether event-triggered polling plus OCR is sufficient first. |
| Copy Comet's generic parser | **No** | The tested generic result was wrong. Keep FoxyCo's isolated strict parsers. |
| Add multi-currency | **Yes, without FX conversion** | Needed for expansion; driver economics are local and should not drift monthly. |
| Add 23 languages immediately | **No** | Translate after target markets and parser grammars are validated. |
| Add voice grade/chime | **Yes after capture hardening** | High glanceability/safety value and low conceptual complexity. |
| Add profit engine now | **After reliable capture** | Perfect cost math is useless if the card fields are missed. |
| Add automatic tips/earnings scan | **Research later** | Valuable but matching errors can corrupt financial history. |
| Change to free credits + ads | **No for v1** | More SDK, privacy, entitlement, and trust complexity. |
| Keep lifetime price plan | **Yes; reconfirm amount before Play setup** | Simple and already documented; exact willingness-to-pay needs beta data. |
| Add cloud backup | **Defer** | Local-first is a trust advantage and avoids new data obligations. |

## 17. Remaining Comet unknowns and safe next checks

The following can be closed with the installed app and no purchase:

1. Screenshot the Comet paywall/plan selector to record localized Canadian monthly, annual, and lifetime prices.
2. Screenshot its currency list and unit settings to establish what build 1.0.7 actually exposes.
3. Screenshot vehicle-cost inputs and default values.
4. Turn **Pixel Capture off** for one Uber offer and compare whether node/polling capture succeeds.
5. Turn Pixel Capture back on and compare latency/math.
6. Test one Uber Eats delivery card.
7. If installed and legitimately available, test Lyft with the same log/screenshot protocol.
8. Export Comet's privacy-safe diagnostics after a card to see which source it reports, if the UI includes source counters.

Testing other platforms requires those driver apps, legitimate accounts, and real offers. Installing an APK alone cannot generate trustworthy platform-specific evidence.

## 18. Final product position

FoxyCo should not win by displaying the longest platform list. It should win by being the offer analyzer whose math drivers can audit and trust:

- complete pickup plus trip economics,
- no action inside driver apps,
- strict rejection instead of confident guesses,
- on-device capture and OCR,
- transparent thresholds and cost formulas,
- no ads in the driving workflow,
- local-first history,
- verified platform badges rather than marketing-only support.

Comet demonstrates that broad platform coverage, OCR fallback, voice output, richer economics, and internationalization are feasible. Its real Uber error also demonstrates why FoxyCo's expansion must remain fixture-driven and fail-safe.

