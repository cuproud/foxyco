# FoxyCo full app audit — 20 August 2026

**Product:** FoxyCo Android  
**Source version:** 1.0.9+55  
**Branch:** `main`  
**Baseline commit:** `723ac5a`  
**Scope:** current source, Android integration, entitlement, local data,
security/privacy, Play readiness, UX language, active documentation and
repository hygiene

## Executive result

**Code status:** conditionally ready for a new signed test build.  
**Play submission status:** not yet ready for production approval.  
**Reason:** static analysis is clean and the source issues found in this pass
were repaired, but the complete automated suites could not run in this sandbox,
the current driver-app matrix still requires physical-device testing, and the
`isAccessibilityTool=true` declaration requires an explicit Google Play review
decision.

This report replaces the *current status* in
`FULL_APP_AUDIT_2026-08-07.md`; the older file remains the historical record of
build 26 and its remediation.

## What changed since the previous audit

Build 55 now includes or materially expands:

- Uber, Lyft and Hopp parsing with optional on-device Pixel Capture OCR;
- configurable distance/hourly scoring, Minimum Offer and Pickup Guard;
- overlay bubble styles, verdict pill, Voice Verdict and Live Preview;
- editable offer outcomes and historical scoring snapshots;
- sessions, estimated/actual earnings, session hourly rate, By Hour and By App;
- CSV export, Garage/reminders and broader appearance settings;
- flexible Play updates and the in-progress Send feedback flow;
- reorganized Rules and Settings surfaces.

Future platforms and temporary fixed-date tester access were not counted as
current product value.

## Verification performed

| Check | Result |
|---|---|
| `flutter analyze --no-pub` | **Pass — no issues** |
| `dart fix --dry-run` | **Pass — nothing to fix** |
| Dart formatting | **Pass** for changed `lib/` and `test/` files |
| `git diff --check` | **Pass** |
| Secret-pattern scan | **Pass**; no tracked private key/password/API-secret match found |
| Manifest/permission source review | **Pass with Play policy gate** below |
| Firestore rules source review | **Pass**; own-account, write-once timestamp, default deny |
| Flutter test suite | **Blocked by sandbox**: localhost test server socket denied (`EPERM`) |
| Firestore rules tests | **Blocked by sandbox**: emulator ports 4400/4500/8080/9150 denied |
| Android lint/build | **Blocked by sandbox**: Gradle could not create its local lock/listener socket |
| `npm audit` | **Blocked by restricted network** (`registry.npmjs.org` unavailable) |

The blocked rows are not test failures. They remain mandatory in a normal local
or CI environment before producing an uploadable bundle.

## Findings repaired in this pass

### F1 — Android accessibility service declaration could prevent system binding

**Severity:** Critical  
**Status:** Fixed

The service used `android:exported="false"`. Android's current accessibility
service declaration uses an exported service protected by
`BIND_ACCESSIBILITY_SERVICE`, which limits binding to the system. The manifest
now uses `android:exported="true"` and retains the protected bind permission.

Reference: [Android accessibility-service declaration](https://developer.android.com/guide/topics/ui/accessibility/service).

**Device check:** revoke and re-enable Offer access on each supported Android
version, then verify events resume after process restart.

### F2 — Legacy build expiry could lock a paid lifetime owner

**Severity:** High  
**Status:** Fixed

`BUILD_EXPIRY` previously took precedence over a verified or cached purchase.
Purchase ownership now wins. The legacy define can cut off trial access for an
explicit expiry test, but it never grants tester access and never overrides a
lifetime purchase. Active release/tester docs were corrected.

### F3 — Editing an offer outcome left session earnings stale

**Severity:** High  
**Status:** Fixed with regression check

History updated the offer but not the saved `SessionSummary`. Completed count,
estimated earnings and session hourly rate could therefore disagree with the
edited offer. Saved sessions now rebuild from the offer log after a successful
manual correction, preserve manually entered actual earnings and exclude offers
outside the session end time.

### F4 — CSV export did not escape driver-app text

**Severity:** Medium  
**Status:** Fixed with regression check

Ride categories containing commas, quotes or line breaks corrupted the CSV.
Text beginning with spreadsheet formula characters could also execute as a
formula when opened. Every exported cell now receives standard quoting and a
formula prefix guard.

### F5 — Feedback screenshots contradicted the privacy policy

**Severity:** High documentation/privacy  
**Status:** Fixed

The new feedback flow uses Android's system photo picker and private cached
copies, but the published policy still said FoxyCo never reads photos and that
local earnings/history could never leave the phone. The policy now explains
the optional user-selected screenshots, external share/email app, runtime app
details, 24-hour cache cleanup and the fact that diagnostic logs are not added
automatically. Stale retention and account-deletion paths were corrected.

### F6 — Active pricing and tester documents were stale

**Severity:** High commercial/support  
**Status:** Fixed

Active docs still instructed CA/US publishers to use `$12.99`, described closed
tester/license access incorrectly and treated `BUILD_EXPIRY` as temporary
premium access. The authoritative model is now:

- Canada: **CA$24.99 lifetime**;
- United States: **US$17.99 lifetime**;
- trial: **7 days**;
- subscription: **none**;
- closed-track membership: no automatic entitlement;
- License testing: trusted billing QA only;
- lifetime promo code: permanent entitlement;
- temporary tester entitlement: planned, not present in build 55.

Google's current billing guidance says a non-consumable test purchase must be
refunded and revoked when it needs to be purchased again; removing a tester
from the license list is not documented as the reset mechanism.

Reference: [Google Play Billing testing](https://developer.android.com/google/play/billing/test).

### F7 — Product language was cute, vague or overstated

**Severity:** Medium UX/trust  
**Status:** Fixed

The following surfaces now use direct language:

- onboarding: plain rules, trial and lifetime explanation; no cookie emoji or
  “one bad offer pays for the app” claim;
- Home/session recap: plain empty and active states; decorative food emojis
  removed;
- paywall: no “earns its seat,” “monthly meter,” or payback promise;
- History: “Filter by minimum fare” replaces “Top offers only”;
- Settings: “App health,” “Current session,” plain correction wording and a
  consistent “Diagnostic logs” title;
- About: correct My Rules paths, pickup-distance explanation, Firebase timing,
  purchase language and Send feedback route;
- Fox Tips: thresholds now point to My Rules;
- feedback: Problem / Offer detection / App screen / Other and “App details.”

## Accessibility, OCR and Play policy

### Current product decision

`android:isAccessibilityTool="true"` remains in the build by explicit product
decision because changing it to `false` breaks proven Uber parsing of
accessibility-data-sensitive offer views. This audit did **not** change that
core behavior.

### Risk

Google Play states that `isAccessibilityTool=true` is intended for apps whose
main purpose is disability support. FoxyCo is a driver utility. This is a
material approval/suspension risk even though the implementation is read-only,
package-scoped and prominently disclosed.

Reference: [Google Play AccessibilityService policy](https://support.google.com/googleplay/android-developer/answer/16558241).

### Required next step

Before closed testing submission:

1. submit the accurate AccessibilityService declaration;
2. provide the disclosure/consent and real scoring video;
3. describe the read-only purpose, package scope and absence of gesture APIs;
4. wait for Google's decision before changing the core parser;
5. if Google rejects the flag, set it false and validate/improve the existing
   opt-in OCR fallback against current Uber, Lyft and Hopp cards.

Do not claim the OCR path is already a complete replacement until that signed
device matrix passes.

## Security and privacy review

### Passed in source

- accessibility events are restricted to the Uber, Lyft and Hopp packages in
  both Android XML and the Dart parser registry;
- `canPerformGestures` is absent and no first-party tap/gesture action path was
  found;
- OCR requests one frame only after opt-in and an incomplete active-card read;
- OCR bitmaps remain in memory, the Foxy overlay is redacted, buffers are
  cleared/recycled and recognized raw text is not persisted;
- app backups and device transfer are disabled for all private domains;
- feedback FileProvider exposes only `cache/feedback/`, validates canonical
  parents, caps selection at three images and grants read access only through
  the chosen intent;
- diagnostic clipboard content is marked sensitive natively where available
  and cleared after one minute by the fallback;
- Firestore rules allow only the signed-in owner to create/read a write-once,
  server-stamped trial document and deny every other path;
- release signing fails closed when key configuration is missing;
- purchase verification fails closed without the Play licensing public key;
- no ads, analytics or crash-reporting SDK is declared.

### Follow-up risks

- Feedback does not enforce an attachment byte-size limit. The three-image cap
  limits scope, but very large selected files can still fill cache or fail in an
  email client. Add a streaming size cap only if device testing reproduces it.
- Firebase App Check and budget alerts remain an abuse/cost-hardening option;
  they are not required for offer-data confidentiality because offer data is
  not sent to Firebase.
- Legal pages are served from `main`; publish the updated privacy text before
  sending the reviewed build to testers.

## Product/data correctness review

| Area | Result |
|---|---|
| Scoring rules | Clear GOOD/OK/BAD threshold boundaries; Minimum Offer remains an explicit BAD override |
| Pickup Guard | Informational only and described that way in Rules |
| Platform scope | Uber, Lyft and Hopp only; future enum values do not imply parser support |
| Historical scoring | Snapshots retained so old offers do not change when current rules change |
| Manual outcomes | Manual corrections win; session rollups now refresh |
| Session estimates | Completed-offer estimate and optional manual actual earnings are separated |
| History filters | Range/app/verdict/outcome/minimum-fare dimensions remain independent |
| CSV | Corrected quoting and formula protection |
| Local retention | User-controlled in Settings → History; clear-history confirmation retained |
| Updates | Flexible Play update flow is isolated from app operation on failure |

## UX/content audit

### Onboarding wizard

Five pages accurately cover the product, initial rules, optional 7-day trial,
overlay permission and Offer access. Permissions can be skipped. Remaining
device checks: large text, smallest supported screen, TalkBack announcements,
system-settings return, and consent-video sequence.

### Fox Tips

Current in-app tips are short, actionable and no longer point to the old
Settings threshold location. Tips should remain general guidance; do not add
unsupported city-demand, safety-percentage or earnings claims from the older
concept document without sources.

### Rules

The Rules screen correctly owns scoring, rate mode, Minimum Offer, Pickup Guard,
watched apps, Voice Verdict and Live Preview. Pickup Guard explicitly says it
does not change the verdict. No structural reorganization is required.

### Settings, Help and About

Settings is now grouped into You & your car, App health, Look & feel, Data and
Help & support. Help & support contains Send feedback, About FoxyCo and
Diagnostic logs. About now uses the real navigation paths and separates product,
trial/purchase, privacy and troubleshooting explanations.

### Trial and purchase

Onboarding and paywall clearly state 7 days, lifetime access and no
subscription. Restore and Redeem are under Settings → Profile → Access. The
localized storefront price is intentionally loaded from Play rather than
hardcoded. Real purchase, restore, pending, refund/revoke, promo redemption and
offline-grace flows remain device/Console gates.

## Pricing conclusion

The full analysis is in `PRICING_STRATEGY_2026-08-20.md`. Recommendation:

- **model:** lifetime;
- **Canada:** CA$24.99;
- **US:** US$17.99;
- **trial:** 7 days;
- **confidence:** Medium;
- **launch action:** keep pricing stable and measure trial conversion, refunds,
  support load and parser reliability before changing it.

## Repository and complexity audit

- Direct dependencies were checked against source usage; no safe unused package
  removal was found.
- No TODO/FIXME debt or tracked secret was found in current source.
- `references/` is large but intentionally tracked as the design source set;
  deleting it would discard documented project assets, so it remains.
- Ignored build, Gradle, Dart and Node caches account for most workspace disk
  use. They are not source dirt and were not destructively deleted.
- The existing Send feedback work was already uncommitted when this audit began;
  it was preserved, reviewed and completed in place.

Ponytail simplifications applied:

- **delete:** unused onboarding grant-button parameters and a redundant callback
  conditional;
- **delete:** decorative `snackFor` function and food-emoji copy;
- **reuse:** existing session and offer models for refresh; no new abstraction;
- **reuse:** one CSV cell helper; no dependency added.

Net complexity: approximately 12 implementation lines removed, one small
correctness helper and one focused session refresh added, **zero dependencies**.

## Remaining release gates

1. Run full Flutter tests, Firestore rules tests, Android lint and a signed
   release build outside this restricted sandbox.
2. Run the updated `MANUAL_TESTS.md` device matrix on supported Android versions
   with current Uber, Lyft and Hopp releases, including OCR off/on.
3. Submit the AccessibilityService declaration/video and obtain Google's policy
   decision on `isAccessibilityTool=true`.
4. Test Play prices in Canadian and US storefronts with Play Billing Lab or
   suitable accounts.
5. Test lifetime purchase, acknowledgement, restore, pending payment,
   refund/revoke and permanent promo-code redemption.
6. Test feedback with no attachment and three varied-size images across Gmail
   and at least one non-Gmail handler; confirm cache cleanup after 24 hours.
7. Profile a real multi-hour shift for battery, memory, ANRs and parser misses.
8. Publish updated legal docs from `main` before distributing build 55 or later.

## Go/no-go

**New internal/closed test build:** Go after the blocked automated suites pass
in a normal environment.  
**Google accessibility review:** Go with accurate disclosure and the documented
functional reason for the current flag.  
**Production launch:** No-go until Google policy disposition, current signed
device parsing/OCR evidence, Play billing tests and updated live legal pages are
complete.
