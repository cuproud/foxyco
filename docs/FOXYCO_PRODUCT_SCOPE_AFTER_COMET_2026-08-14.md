# FoxyCo product scope after Comet analysis

**Decision draft:** 2026-08-14  
**Purpose:** define the FoxyCo feature set, navigation, build order, and explicit exclusions after inspecting Comet 1.0.7 and testing real Uber, Hopp, and Lyft offers.

## 1. Product promise

FoxyCo reads a visible gig offer, verifies the important fields, includes pickup/deadhead in the economics, and gives the driver a fast, explainable verdict without touching the driver app.

The product should optimize for:

1. Correct capture.
2. Correct end-to-end math.
3. One offer recorded once.
4. A verdict readable without leaving the driver app.
5. Rules the driver can understand and change quickly.
6. Minimal permissions and local-first data.

Breadth, themes, ads, cloud features, and marketing platform counts come after those six.

## 2. Recommended main navigation

```text
Home        Rules        History        Settings
shift       core         decisions      app/device
status      scoring      and results    configuration
```

Four destinations are appropriate: each is frequent, distinct, and important enough to deserve one tap.

### 2.1 Home

Home answers: **Is FoxyCo ready, and how is my shift going?**

- Start, pause, and resume watching.
- Permission/readiness summary.
- Current shift totals.
- Today's GOOD / OK / BAD counts.
- Most recent offer.
- Active watched-platform badges; tapping them opens Rules → Platforms.
- Trial/unlock status when relevant.
- Due vehicle-reminder banner.
- Shift recap when watching stops.

Do not turn Home into another settings page.

### 2.2 Rules

Use the navigation label **Rules**, the screen title **My Rules**, and the subtitle **How FoxyCo judges every offer**.

“Verdict” sounds like a result that already happened. “Algorithm” sounds technical and makes ordinary driver preferences feel dangerous to edit. “Rules” accurately describes what the driver controls.

Move these existing Settings sections into Rules:

1. Verdict thresholds.
2. Rate mode: per distance or per hour.
3. Relaxed / Balanced / Picky presets.
4. Pickup guard.
5. Live verdict preview.
6. Watched apps.

Recommended page order:

```text
MY RULES
How FoxyCo judges every offer

[ Grade by:  $/km | $/hour ]

[ Presets: Relaxed | Balanced | Picky ]

[ Verdict band ]
BAD below ... / GOOD at or above ...

[ Pickup guard ]
Near at or under ...

[ Live preview ]
Change a sample rate and see the resulting pill

[ Platforms ]
Uber · Uber Eats · Lyft · Hopp · future verified apps
```

Rules should save immediately, as the existing controls do. No separate Save button is needed.

### 2.3 History

History answers: **What did FoxyCo see, and why did it grade that way?**

- One row per unique offer.
- Filters by date, platform, verdict, and likely outcome.
- Fare, pickup, trip, total distance/time, rate, and verdict.
- Plain-language explanation using the rules active when captured.
- Likely accepted/passed status, visibly labelled as an estimate.
- Manual correction: Accepted, Passed, or Unknown.
- Daily/weekly summaries.
- CSV export.
- Local retention controls remain in Settings.

History insertion must be idempotent: repeated accessibility, polling, and OCR observations may refresh one record but cannot create a second record.

### 2.4 Settings

Settings answers: **How should the app, account, device integration, and data behave?**

Keep:

- Driver/account and lifetime unlock.
- Garage, vehicle profiles, and reminders.
- Overlay size and appearance.
- Theme and money typeface.
- Currency and distance units.
- Outcome tracking toggle.
- History retention and clear/export controls.
- Permissions.
- Parser health and diagnostics.
- Accessibility disclosure.
- Privacy, terms, account deletion, About, and Help.

Removing scoring and watched-app controls will make Settings shorter and easier to understand.

## 3. Required release features

These define the product and must work before adding broad platform coverage.

### 3.1 Reliable source capture

- Read accessibility node text and content descriptions.
- Inspect the active root and relevant interactive windows.
- Preserve active/background-window identity.
- Run a short bounded polling burst after relevant events.
- Use on-device screenshot OCR only when the accessibility tree is missing or incomplete.
- Rate-limit OCR and prevent overlapping captures.
- Exclude FoxyCo's own overlay from OCR input.
- Never save screenshots.
- Never upload raw screenshots or raw screen text.
- Stop scanning after success, confirmed card exit, package change, or a small miss limit.

Do not add notification access until device tests show that accessibility events, bounded polling, and OCR are insufficient.

### 3.2 Stable offer lifecycle

- Generate one stable identity from platform, fare, pickup, trip, category, stop count, and a bounded time window.
- Accessibility and OCR candidates for the same card converge into that identity.
- A partial or empty scan does not mean the card disappeared.
- Keep a verdict visible for at least five seconds.
- Keep it visible longer while the same card is positively present.
- Clear on positive home/map, accepted-trip, foreground-package change, or sustained absence evidence.
- Retain a recently-seen identity after HUD clearance so the same active card cannot be logged again.
- Record and consume entitlement/usage once per identity.

This directly prevents Comet's observed Hopp false-clear and duplicated Lyft record/credit charge.

### 3.3 Strict parsing

- Parse fare separately from tips, tolls, bonuses, surge, guarantees, and hourly-rate labels.
- Preserve pickup and trip as separate components.
- Sum pickup plus every trip/stop leg for the final economics.
- Represent a missing field as unknown, never numeric zero.
- Reject an incomplete candidate rather than issue a confident wrong verdict.
- Validate units, time, distance, fare, stop count, and plausible bounds.
- Retain field-level capture source for diagnostics.
- Keep a versioned positive fixture and negative/home-screen fixture for every platform.

### 3.4 Explainable scoring

Required v1 scoring remains intentionally small:

- Driver chooses one primary mode: money per distance or money per hour.
- Driver sets BAD and GOOD cut points; the middle band is OK.
- Driver can apply a preset and then fine-tune it.
- Pickup guard is displayed separately and clearly.
- Offer detail shows the actual formula.

Do not call a value a “floor” if failing it does not force a bad result. Every rule label must match its real effect.

### 3.5 Overlay and audio

- Compact, glanceable verdict pill.
- GOOD / OK / BAD uses color, icon/shape, and text.
- Fare, total distance, and optionally hourly value.
- Pickup warning when the deadhead exceeds the driver's guard.
- Bubble remains draggable and read-only.
- Optional voice verdict.
- Optional short positive chime.
- Independent mute switch.
- Audio must not repeat when the same card is re-read.

Voice is the first feature to add after capture/OCR reliability. It provides real driving value without adding another sensitive permission.

### 3.6 Local history and correction

- Persist only extracted offer fields, not raw screen content.
- Deduplicate before persistence.
- Record the rules used for the historical verdict, or preserve the verdict and its relevant cut points.
- Infer Accepted/Passed only from strong read-only screen signals.
- Label inference as likely/estimated.
- Let the driver correct it manually.
- Export CSV.

## 4. Platform plan

### 4.1 Verified core

- Uber rides.
- Uber Eats inside Uber Driver.
- Lyft.
- Hopp.

These stay first because FoxyCo already has parser code and device evidence. Current-version capture must be rerun after OCR/polling changes.

### 4.2 Next platforms

Add one at a time:

1. DoorDash.
2. Walmart Spark.
3. Instacart.
4. Grubhub when a current tester/fixture is available.

### 4.3 Regional/testing platforms

- DiDi.
- Empower.
- Yandex Pro.
- Taxsee / Maxim.
- Pathao.
- SkipTheDishes.
- Amazon Flex.
- Bolt.
- inDrive.
- 99 / 99 Food.

A platform appears in production only after:

- package confirmed,
- current positive card fixture,
- current negative/home fixture,
- partial-render fixture,
- expected math checked manually,
- live device capture,
- no duplicate history record,
- no overlay on non-offer screens.

Until then it can be labelled Experimental/Beta in internal tester builds, not marketed as supported.

## 5. Currency and international support

Required:

- Parse and retain the offer's actual currency.
- Display one ISO code/symbol consistently throughout Rules, overlay, history, detail, and export.
- Use locale-aware decimal/group separators.
- Keep km/miles independent from currency.
- Store thresholds per selected currency/profile where necessary.
- Never convert a live fare to another currency before grading.
- Do not automatically change driver thresholds using monthly FX rates.

Initial target set, expanded only with real fixtures:

- CAD
- USD
- GBP
- EUR
- AUD
- NZD
- BRL
- INR

One formatter must drive every unit label. Comet's inspected build selected kilometres while still displaying “earnings per mile” and `$ / mile` in parts of its algorithm UI; FoxyCo must not repeat that inconsistency.

Full UI translation is later. Parser localization and currency correctness come first.

## 6. Vehicle cost and profit features

### 6.1 Keep now

- Vehicle profiles.
- Fuel/powertrain identity.
- Maintenance/insurance reminders.

### 6.2 Add after capture reliability

- Fuel economy or EV efficiency.
- Local fuel/electricity price.
- Maintenance cost per month or distance.
- Insurance and other operating costs.
- Effective cost per distance with visible formula.
- Gross and estimated net values.
- Optional grade-by-net-hour mode.

Rules:

- Every cost defaults to visibly “not configured,” not silently zero.
- Gross remains visible beside net.
- Net is labelled **estimated**.
- Missing pickup/time prevents a “true profit” claim.
- The driver can disable cost-based grading.

## 7. History enrichment features

Useful later, after core history is reliable:

- Match completed earnings back to an accepted offer.
- Add confirmed tips, toll reimbursements, bonuses, and guarantees.
- Update gross/net totals.
- Show confidence and allow manual correction.

Do not build automatic earnings matching before stable offer identity exists. A false match corrupts financial history and is worse than leaving the tip unknown.

## 8. Monetization

Keep the existing v1 plan:

- Free download.
- User-started seven-day trial.
- One localized Google Play lifetime purchase.
- No subscription.
- No ads.
- No daily offer-credit counter.

Reconfirm the exact lifetime price before Play configuration. Comet's inspected paywall displayed `$2.79` weekly, `$8.49` monthly, `$69.99` yearly, and `$209.99` lifetime, likely in the Canadian storefront. Its displayed `$0.96/week` for `$69.99/year` was mathematically inconsistent. FoxyCo pricing must always come directly from Google Play and any derived comparison must have a test.

Do not add a subscription until FoxyCo has a recurring paid service cost or a proven paid cloud feature.

## 9. Explicitly not required for v1

- Auto-accept or auto-decline: never.
- Any gesture/tap inside another app: never.
- Notification listener permission.
- Continuous all-shift polling.
- Ads or rewarded credits.
- Subscription plans.
- Referral system.
- Cloud offer-history backup.
- 18 themes or many alternate icons.
- 23 UI languages.
- 13 unverified platform badges.
- Automatic FX conversion.
- Automatic earnings/tip matching.
- iOS companion/overlay claims.

These exclusions keep v1 trustworthy and testable.

## 10. Build sequence

### Stage 1 — navigation cleanup

- Add Rules as the second tab.
- Move threshold, rate mode, presets, pickup guard, preview, and watched apps from Settings.
- Update Home deep links and back-navigation behavior.
- Preserve the existing controls and state; this is a move, not a redesign of scoring logic.

### Stage 2 — capture hardening

- Source-aware screen reads.
- Bounded polling.
- On-device OCR fallback.
- Cross-source offer identity.
- Stable clear/hold behaviour.
- Duplicate-proof history and audio.

### Stage 3 — current-platform verification

- Uber rides.
- Uber Eats variants.
- Lyft.
- Hopp.
- Battery/ANR/process/Android-version matrix.

### Stage 4 — platform expansion

- DoorDash.
- Spark.
- Instacart.
- Grubhub.

### Stage 5 — international and driver value

- Currency/locale foundation.
- Voice and chime.
- Transparent vehicle economics.
- Manual outcome correction.

### Stage 6 — release

- Complete billing/trial device tests.
- Complete Play accessibility and OCR disclosure.
- Signed release build and closed test.

## 11. Recommended decision

Approve the navigation direction:

```text
Home · Rules · History · Settings
```

Then implement only Stage 1 as a focused UI move. Capture/OCR and platform expansion remain separate changes with separate verification.

