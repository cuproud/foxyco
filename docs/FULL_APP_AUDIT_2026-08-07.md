# FoxyCo full-app audit — 2026-08-07

Status: **code and legal remediation complete; release/device gates remain open**

This report audits the `1.0.9+26` workspace. Findings remain the original audit
record; completed fixes and their verification are tracked in the remediation
log below.

## Final local verification

- Strict `flutter analyze --no-pub`: **passed, no issues**.
- Flutter debug and release application-bundle (Dart/assets) compilation:
  **passed**.
- The vendored accessibility Java source compiles directly against Android 36,
  Flutter embedding, AndroidX annotations, and Gson. Only upstream Android API
  deprecation/annotation-classpath warnings remain; there are no Java errors.
- `MainActivity.kt`, including sensitive clipboard marking and delayed
  clear-if-unchanged, compiles directly against Android 36 and the Flutter
  embedding. This is a source/API check, not a replacement for the Gradle APK.
- Full Flutter suite: **not executed after the final batch** because this
  restricted workspace denies the localhost socket required by Flutter's test
  runner before any test body starts. Earlier per-fix totals through 333 tests
  remain recorded below; new regressions are present but must run in the normal
  developer environment.
- Android APK/AAB: **not built here** because Gradle cannot create its required
  local lock-contention socket in this workspace. Keep source at `1.0.9+26`;
  advance to `1.0.9+27` only after the full suite and signed release build pass.
- The release helper now runs analysis and the full Flutter suite before
  changing the build code, and also requires the Firestore emulator suite for
  every versioned or AAB build. The runbook bumps once for the AAB and builds
  any optional APK at that same version, avoiding the former accidental double
  bump.
- Firestore rules suite: source/config parsing passed; execution still requires
  npm dependencies and the Firebase emulator outside the restricted workspace.

## Remediation log

- **C3 fixed 2026-08-07:** every owned-products refresh and purchase-stream
  event now advances its relevant generation. Only the newest refresh may
  publish, and newer stream evidence invalidates every older query, including
  unavailable/error results. A regression test covers stale-result rejection.
  Verification:
  **327 tests passed** and `flutter analyze` reported **no issues**.
- **C2 fixed 2026-08-07:** entitlement derivations are serialized and coalesced.
  If Play/trial state changes during an async clock or preference operation, the
  superseded pass cannot publish and one fresh pass runs with current inputs. A
  controlled-clock regression test recreates the old-over-new completion race.
  Verification: **328 tests passed** and `flutter analyze` reported **no
  issues**.
- **C4 fixed 2026-08-07:** saving a trial snapshot now removes every absent
  field instead of retaining the prior account's values. The anonymous
  pre-trial path also persists a fully cleared snapshot. A preferences
  regression test starts with an old account and proves all three keys are
  removed. Verification: **329 tests passed** and `flutter analyze` reported
  **no issues**.
- **C1 fixed 2026-08-07:** `AccessStore` now owns the next trial, cached-purchase,
  offline-verification, and tester-build time boundary. It re-derives access
  without depending on Home or the banner, and every real offer forces a fresh
  time check before revealing paid details. It also remains unresolved until a
  slow purchase-cache read finishes, preventing a false “Trial ended” flash.
  Negative access remains unresolved while either Play or trial loading is
  incomplete; one finished-negative source can no longer expose stale paywall
  copy while the other is still resolving.
  The banner's duplicate timer was removed. Controlled regressions cover both
  cache hydration and expiry with no UI mounted.
  Verification: **330 tests passed** and `flutter analyze` reported **no
  issues**.
- **H1 / OfferLog fixed 2026-08-07:** offers received while preferences are
  loading are merged with disk history instead of being overwritten. Saves now
  wait for hydration, preventing the debounce timer from replacing the disk
  blob with a partial pre-load list. A delayed-preferences regression test
  proves both the live offer and stored history survive. Verification: **331
  tests passed** and `flutter analyze` reported **no issues**.
- **H2 fixed 2026-08-07:** each newly scored real offer now starts persistence
  immediately after hydration; only the near-immediate outcome stamp remains
  debounced. The hydration regression also waits for the merged two-offer blob
  to exist on disk. Verification: **331 tests passed** and `flutter analyze`
  reported **no issues**.
- **H1 / Settings fixed 2026-08-07:** edits made during preference hydration
  are queued as transformations, replayed over the saved snapshot, and only
  then persisted. This preserves both the startup edit and every unrelated
  saved setting. A delayed-preferences regression test verifies memory and disk.
  Verification: **332 tests passed** and `flutter analyze` reported **no
  issues**.
- **H1 / Garage fixed 2026-08-07:** vehicle save/delete/activate operations now
  await garage hydration before mutating. A delayed-preferences test saves a new
  vehicle during startup and proves both it and the existing disk vehicle remain
  in memory and on disk. Verification: **333 tests passed** and `flutter analyze`
  reported **no issues**.
- **H1 / Driver name fixed 2026-08-07:** name saves now await hydration before
  replacing and persisting the value. A delayed-preferences regression proves a
  startup save cannot be overwritten by the older disk name. The focused tests
  pass; full-suite verification follows.
- **H1 / Reminders fixed 2026-08-07:** startup add/update/remove transformations
  are replayed over the disk snapshot before persistence. A delayed-preferences
  regression proves a newly added reminder and the saved reminder both survive.
  Full-suite verification follows.
- **H1 / Session log fixed 2026-08-07:** a session completed while preferences
  are loading is merged with saved history, sorted newest-first, and persisted
  only after hydration. A delayed-preferences regression covers memory and disk.
  Full-suite verification follows.
- **H1 / Trial cache fixed 2026-08-07:** every authoritative trial state change
  advances a revision; a cache load may publish only if no newer server/account
  result landed while it was waiting. A delayed-cache regression covers the
  older-cache/newer-server race. Full-suite verification follows.
- **H1 / Purchase cache fixed 2026-08-07:** the cached Play verification anchor
  uses the same revision guard, so a slow old cache read cannot replace a newer
  Play-confirmed timestamp. A regression then removes live Play evidence and
  proves the fresh cached purchase remains usable. Full-suite verification
  follows.
- **H3 fixed in app/docs 2026-08-07:** onboarding now discloses that FoxyCo
  temporarily reads on-screen text in the three named driver apps, stores only
  extracted offer numbers locally, does not save or send raw text, and never
  acts inside those apps. Manual-test, design, and Play-declaration wording now
  match. The Play Console form and replacement review video remain release
  gates.
- **H4 fixed in app/docs 2026-08-07:** the privacy policy now discloses the
  anonymous Firebase identity created on first launch, Firebase Authentication's
  documented IP/user-agent processing, Google identity when trial start or
  account sign-in is chosen, trial timestamp, purposes, retention context, and
  processors. The release checklist now calls out the matching Data Safety
  declarations. Console verification remains a release gate.
- **H5 disclosure/workflow fixed 2026-08-07:** the web route now instructs a
  driver who wants both Firebase records removed to request deletion before
  using in-app deletion, while verified email can still locate the UID. The app
  dialog and privacy page plainly disclose the de-identified trial row retained
  after in-app deletion and no longer promise it can be found by former email.
  A real-account operator test and retention/legal approval remain release
  gates; client delete permission remains correctly denied.
- **H7 implemented 2026-08-07:** an official Firebase rules-unit-testing
  emulator suite now covers owner server-stamped create/read, cross-user and
  signed-out/true anonymous-auth denial, chosen timestamps/extra fields,
  immutable update/delete, and denial of every other collection. Rules now
  require a non-anonymous account identity before trial access. The Node file
  and configs parse; npm
  installation/emulator execution remain pending because registry access hung
  in the restricted workspace.
- **H8 fixed 2026-08-07:** the vendored accessibility fork no longer exposes
  node actions, global actions, or gesture dispatch in Dart or Java. Their
  method-channel handlers, broadcast command path, gesture builder, node cache,
  and tests were removed; R8 keep rules now retain only the plugin, service, and
  event receiver needed for read-only capture/overlay operation. Release
  bytecode and physical capture verification follow with the final build.
- **H9 fixed 2026-08-07:** real-offer, clear, hide, and demo overlay calls now
  contain native failures at the controller boundary, log them, and keep pill
  state false unless native show succeeds. A throwing fake regression covers
  the previously unhandled show path. Full-suite verification follows.
- **H10 fixed 2026-08-07:** a permission request arriving during an in-flight
  platform query marks the refresh dirty; the controller reruns until it has
  handled the final requested state. A delayed accessibility-query regression
  covers enable followed by disable. Full-suite verification follows.
- **H11 fixed 2026-08-07:** changing from watching/paused to permission-blocked
  now consumes `liveSince` through the existing session recorder before state
  changes. The revoke regression proves one bounded session is recorded and no
  stale boundary remains. Full-suite verification follows.
- **M1 fixed 2026-08-07:** stale-cache warnings are now derived from the access
  source actually granting entitlement, including cached purchases. Boundary
  tests cover the purchase warning window. Full-suite verification follows.
- **M2 fixed 2026-08-07:** cached purchase evidence dated after the trusted
  clock is rejected instead of receiving an extended grace window. A
  future-timestamp regression covers the lock. Full-suite verification follows.
- **M3 fixed 2026-08-07:** trial start and account restore now refresh an ID
  token and heal `FoxClock` from Google's issue time before resolving the
  server-stamped trial document. Successful trial reads and creation also stamp
  verification through that healed clock instead of the device wall clock. A
  clock regression starts with a one-year future poison and proves trusted sync
  restores present time. Full-suite verification follows.
- **M4 fixed 2026-08-07:** watcher identity now includes every stable parsed
  field. A positively observed browse/accepted transition marks the next card
  as a new lifecycle, allowing legitimate back-to-back identical-value offers
  through the log while ambiguous flicker still uses its two-minute guard. The
  existing lifecycle test now asserts two history rows. Full-suite verification
  follows.
- **M5 fixed 2026-08-07:** `OverlayController` now listens to entitlement while
  a real pill is visible and clears the snapshot whenever access changes, so a
  locked pill cannot linger after purchase (and an unlocked snapshot cannot
  linger after expiry/refund). A mutable-entitlement regression covers the
  locked-to-purchased transition. Full-suite verification follows.
- **M6 fixed 2026-08-07:** dashboard boot now starts blocked with both grants
  false and cannot begin monitoring until Android's first permission query
  resolves. Tests that exercise live monitoring now explicitly inject or
  refresh granted permissions; a boot regression asserts Start remains blocked.
  Full-suite verification follows.
- **M7 fixed 2026-08-07:** offer and session hydration now parse rows
  independently, retain valid history when one row is malformed, and write one
  local diagnostic. Persisted thresholds, pickup distance, and retention are
  clamped/fallbacked to the controls' supported ranges. Focused regressions cover
  both collections and settings. Full-suite verification follows.
- **M8 fixed 2026-08-07:** the vehicle editor now caps make/model at 30
  characters and plate at 12, accepts only digit years, and requires an optional
  year to fall from 1980 through next model year. A widget regression checks
  truncation and implausible-year rejection. Full-suite verification follows.
- **M9 fixed 2026-08-07:** Android log copies now mark the clip sensitive,
  suppressing clipboard previews on supported versions. The app warns the
  driver and the native channel clears the clip after one minute if it is still
  unchanged, even after leaving the Logs screen. The Dart fallback has the same
  lifetime. A method-channel regression verifies the sensitive path. Full-suite
  and Android build verification follow.
- **M10 implemented 2026-08-07:** strict casts, inference, and raw-type checks
  are enabled for first-party Dart. The complete strict baseline is part of the
  pending final analyzer gate; vendored third-party code remains excluded.
- **Recording follow-up fixed 2026-08-07:** accessibility reads now preserve
  Android's active-window signal. A confirmed foreground switch to another
  watched driver app immediately clears the previous app's pill, while
  background events cannot disturb the current pill. A regression covers the
  cross-app transition seen in the recording. Full-suite and device verification
  follow.

## Physical evidence reviewed

### 2026-08-06 Uber/Lyft screen recording

Reviewed `Screen_Recording_20260806_064846_Lyft Driver.mp4` frame by frame:
115 seconds, 1080×2340, recorded on a real Samsung device. The recording date
is visible, but the Android version and driver-app versions are not.

Confirmed by the recording:

- FoxyCo goes live, its bubble remains above the driver apps, and the dashboard
  later reports six observed offers.
- Real Uber and Lyft cards are received through the device flow; this is useful
  evidence that non-disability-tool accessibility nodes were readable on that
  device and those installed app builds on 2026-08-06.
- Multiple overlay calculations visibly match the source cards, including:
  Uber `$6.46 / 8.4 km / $24 h`, Uber `$7.77 / 10.6 km / $25 h`, Lyft
  `$20.04 / 19.4 km / $45 h`, Uber `$9.07 / 11.2 km / $26 h`, and Uber
  `$18.35 / 39.7 km / $33 h` (rounded display values).
- The pill returns to the bubble when an offer leaves, and an accepted Lyft
  flow reaches navigation without the offer pill remaining onscreen.

Not established by this recording:

- Android 14/15/16 coverage or current app-version compatibility—the OS and app
  version screens are not shown.
- Hopp parsing, accessibility permission grant/revoke, disclosure/consent,
  touch-through, drag/dismiss, process death, battery/ANR soak, or parser timing.
- Any purchase, promo-code redemption, restore, refund, acknowledgement,
  reinstall, account switch, offline grace, trial expiry, or build expiry flow.

Additional observation: rapid switching between simultaneous Uber and Lyft
offers can leave the previous platform's pill over the newly foregrounded card
for about one captured second, until that app's next accessibility event updates
it. The displayed numbers are correct for the preceding offer, but the transient
cross-app presentation is confusing and should receive a regression test/fix
under overlay lifecycle work.

Privacy warning: the uploaded recording visibly contains rider identity and
precise pickup/drop-off addresses. Do not use a public copy for review. Remove
or restrict the current upload and submit a redacted/unlisted replacement that
blurs personal data while preserving offer values and FoxyCo behavior.

## Executive result

- Automated baseline: **326 tests pass**, `flutter analyze` reports **no issues**.
- Dart line coverage: **79.5%** (5,044 / 6,341).
- The highest-risk code has the weakest coverage: billing store **10.6%**, trial
  store **18.7%**, purchase verifier **22.2%**, native accessibility watcher
  **12.8%**, and overlay service **7.5%**.
- Release/device evidence is incomplete: the manual checklist leaves every
  trial/purchase case and almost every real-offer accessibility case unchecked.
- Ranked findings: **6 critical, 11 high, 10 medium, 4 cleanup**.
- Recommendation: do not promote build 26 to production until the critical
  release blockers and the purchase/trial device matrix are closed.

## What was audited

- Trial, Google sign-in, purchase, restore, signature verification, offline
  grace, clock rollback protection, build expiry, and access-banner behavior.
- App lifecycle, concurrent refreshes, asynchronous provider hydration, local
  persistence, offer logging, session logging, permissions, overlay state, and
  parser de-duplication.
- Android manifests, accessibility configuration and vendored plugins, release
  permissions, backup behavior, Firebase rules, privacy/terms/deletion pages,
  and Play-policy-sensitive behavior.
- Navigation/UI tests, responsive/accessibility tests, static analysis, unit and
  widget tests, coverage, dependencies, stale documentation, and repo bloat.

Not locally provable: live Play purchase/restore/refund behavior, Firebase and
Play Console configuration, Android accessibility behavior inside current
Uber/Lyft/Hopp releases, battery/ANR behavior, and public legal-page deployment.
Those are explicit release gates below, not silent assumptions.

## Critical findings

### C1 — Entitlement can remain valid past its expiry in a long-running process

Evidence: `AccessStore._derive()` applies trial expiry, the seven-day cached
purchase grace, and tester build expiry only when invoked
(`lib/services/billing/entitlement.dart:225`). The only periodic entitlement
tick lives in `AccessBanner` and runs only while `access.onTrial`
(`lib/ui/paywall/access_banner.dart:36`). A cached purchase is not a trial, and a
purchased build subject to a tester kill date is not a trial. `showFromOffer()`
then reads the potentially stale provider (`lib/ui/overlay/overlay_controller.dart:130`).

Impact: an app left alive can show paid offer details after offline grace,
trial, or tester-build access should have ended. Access correctness currently
depends on a Home-screen banner widget being mounted.

Proposed solution: make `AccessStore` own one timer for the next relevant
boundary (trial end, cached-purchase grace end, or build expiry), cancel/re-arm
it whenever inputs change, and re-derive immediately before a real offer is
revealed. Use the existing clock abstraction; add fake-clock boundary tests.

Acceptance check: entitlement locks without Home or `AccessBanner` mounted,
for each of the three expiry sources, while the process stays alive.

### C2 — Older asynchronous entitlement work can overwrite newer truth

Evidence: each billing/trial listener starts an unsequenced async `_derive()`.
It snapshots both providers, then awaits `FoxClock.now()`, and finally writes
state (`lib/services/billing/entitlement.dart:225`). Multiple invocations can
finish out of order.

Impact: a late completion based on pre-purchase or pre-trial state can briefly
or persistently replace the newer unlocked state—the same defect class as the
reported “unlocked but trial ended” banner.

Proposed solution: add a monotonically increasing derivation generation (or
serialize derivations) and discard stale completions. Read current provider
values at the point used. Do not add a new state-management layer.

Acceptance check: controlled delayed-clock tests prove the oldest completion
cannot overwrite a newer purchase, trial start, refund, or expiry.

### C3 — A stale Play query can overwrite a just-completed purchase

Evidence: startup, resume, and restore can overlap `_refreshFromPlay()`
(`lib/services/billing/billing_store.dart:114`). A purchase-stream event can set
`purchased`, then an older successful `queryPastPurchases()` with an empty
snapshot can finish and set `notPurchased` at line 159. The helper preserves a
purchase on query failure, but not on a successful stale empty response.

Impact: a valid purchase or redeemed test license can unlock, then re-lock or
show stale trial UI depending on completion order.

Proposed solution: serialize Play refreshes and attach a generation to their
results. Purchase-stream evidence newer than a query's start must win. Preserve
the current fail-closed behavior for genuinely current empty queries.

Acceptance check: a delayed empty query begun before a valid purchase-stream
event cannot change `purchased`; a new explicit post-purchase empty query still
handles a real refund.

### C4 — Trial cache is not replaced when account/trial fields become null

Evidence: `_saveCache()` writes `startedAt`, `verifiedAt`, and email only when
non-null and never removes old keys (`lib/services/billing/trial_store.dart:221`).

Impact: after switching from an account with a used trial to an unused/anonymous
account, the next restart can load the old start timestamp with the new identity
and incorrectly report an active or ended trial.

Proposed solution: atomically replace the cached snapshot: set present fields
and remove absent fields. Scope it by stable account UID rather than email where
possible. Add account-switch and restart regression tests.

Acceptance check: used account → unused account → process restart remains
pre-trial with no inherited date or email.

### C5 — Production accessibility may stop receiving offer text on Android 14+

Evidence: FoxyCo correctly declares `android:isAccessibilityTool="false"`
(`android/app/src/main/res/xml/accessibilityservice.xml:25`). Android SDK 34+
allows apps to mark nodes as accessibility-data-sensitive, hiding them from
services that are not accessibility tools. Only apps whose primary purpose is
supporting people with disabilities may truthfully declare `true` under current
Google Play policy.

Impact: Uber, Lyft, or Hopp can hide offer nodes without a FoxyCo code change.
Changing the manifest to `true` is not an acceptable workaround and could block
Play approval.

Proposed solution: keep `false`; run a signed target-SDK-36 physical-device
matrix against current versions of all three driver apps. If nodes are hidden,
make a product decision among documented limited support, a separately reviewed
user-consented screen-capture/OCR design, or a distribution change.

Sources: [Google Play Accessibility API policy](https://support.google.com/googleplay/android-developer/answer/10964491),
[Permissions and APIs that access sensitive information](https://support.google.com/googleplay/android-developer/answer/16558241),
[Android `AccessibilityServiceInfo`](https://developer.android.com/reference/android/accessibilityservice/AccessibilityServiceInfo),
[Android `View#setAccessibilityDataSensitive`](https://developer.android.com/reference/android/view/View#setAccessibilityDataSensitive(int)).

Acceptance check: capture real accessibility node streams and correct pills for
current Uber, Lyft, and Hopp releases on Android 14, 15, and 16; record app and
OS versions in `docs/MANUAL_TESTS.md`.

### C6 — Public Terms still contain unresolved legal placeholders

Evidence: `docs/legal/terms.md:9` contains `[LEGAL NAME ...]` and line 135
contains `[YOUR PROVINCE/COUNTRY ...]`.

Impact: the public contract is unfinished and should not ship as production
terms.

Proposed solution: owner/legal counsel supplies the contracting legal name and
governing jurisdiction; update the page and its effective date, publish it, and
verify the in-app link. This is not a code inference to automate.

Acceptance check: no bracketed placeholders remain and the public URL returns
the approved text.

## High findings

### H1 — Async startup hydration can erase new user or offer state

Evidence: OfferLog, SessionLog, SettingsController, GarageController,
DriverNameController, ReminderController, TrialStore, and AccessStore return
defaults and launch unawaited loads. Their load completion replaces state. For
example, `OfferLog.build()` calls `_load()` and returns `[]`; `_load()` later
assigns the disk list (`lib/services/offer_log.dart:30-67`).

Impact: a real offer or user edit arriving before hydration finishes can be
lost or replaced by older disk state. Offer history is the highest-impact case.

Proposed solution: fix each store one at a time using the smallest shared rule:
await readiness before mutations, or use a dirty/generation guard and merge for
append-only logs. Do not introduce a database or a generic repository framework.

Acceptance check: delayed-preferences tests mutate each store before load
finishes and prove the mutation survives.

### H2 — Debounced offer persistence can lose the last real offer

Evidence: OfferLog defers writes for three seconds
(`lib/services/offer_log.dart:74-87`) and relies on an unawaited dispose write.
Android process death does not guarantee Dart disposal.

Impact: the offer the driver just acted on—and its outcome—can disappear after
an OS kill or crash.

Proposed solution: persist the first append immediately; coalesce only the
near-immediate outcome update, or flush on lifecycle pause in addition. Keep
SharedPreferences until measured volume proves it inadequate.

Acceptance check: kill immediately after record and after outcome update; both
survive restart.

### H3 — Accessibility disclosure over-promises what is read

Evidence: onboarding/manual expectations say FoxyCo reads “ONLY pay+distance.”
The service traverses all accessible text in the allow-listed driver apps, then
extracts and retains only offer fields. Names or addresses may exist transiently
in the tree even though raw text is not persisted or transmitted.

Impact: prominent disclosure may be considered inaccurate. Google Play requires
clear disclosure of accessed data and use before consent.

Proposed solution: say the service temporarily reads on-screen text in the
three named driver apps to identify pay, distance, and duration; only extracted
offer numbers are stored locally; no raw text is stored or sent; it never acts
on the app. Keep consent immediately before enabling the service.

Source: [Google Play prominent disclosure and consent requirements](https://support.google.com/googleplay/android-developer/answer/11150561).

Acceptance check: onboarding, Play declaration, store listing, privacy policy,
and actual behavior use the same precise wording.

### H4 — Privacy page contradicts first-launch Firebase behavior

Evidence: `TrialStore.refresh()` creates an anonymous Firebase Auth user and
forces an ID token before a trial is started (`lib/services/billing/trial_store.dart:251`).
`docs/legal/privacy.md:56` says only two things leave the device “only if you
choose to start a free trial,” then acknowledges an earlier anonymous identity.

Impact: the first-launch network/data disclosure is internally inconsistent and
can make the Play Data Safety declaration inaccurate.

Proposed solution: explicitly disclose anonymous Firebase authentication on
first launch, its identifiers/metadata, purpose, retention, and Google as
processor. Align the Data Safety form.

Acceptance check: a clean-install network trace matches the published privacy
description and Play Console declaration.

### H5 — “Email us to delete everything” cannot reliably locate retained data

Evidence: the app deletes Firebase Auth, but deliberately retains
`trials/{uid}` (`lib/services/billing/trial_store.dart:476`). The public pages
promise that an email from the former account can request deletion. After Auth
deletion, the retained row is only random UID plus timestamp; no documented
email-to-UID mapping remains.

Impact: FoxyCo may be unable to fulfill its published deletion method. Google
Play requires a working web deletion path and deletion of associated data,
subject to clearly disclosed legitimate retention exceptions.

Proposed solution: before deleting Auth, call a server-side deletion/retention
workflow that knows the UID. Decide with counsel whether a minimal one-way
trial-abuse record may be retained, and disclose it accurately. Do not weaken
Firestore rules to permit arbitrary client deletion.

Source: [Google Play account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111).

Acceptance check: a test account completes both in-app and web-request flows;
Firebase records match the approved retention statement.

### H6 — Money and native integration paths are mostly untested

Evidence: overall coverage is 79.5%, but billing/trial/verifier coverage is
10.6%/18.7%/22.2%. There is no `integration_test/` suite. Existing paywall tests
mostly override stores rather than drive BillingClient/Firebase behavior. The
vendored Java accessibility and overlay code has no app-level native test suite.

Impact: the green unit suite does not exercise the boundaries most likely to
cause purchases, restore, permission, or device-only regressions.

Proposed solution: first add deterministic Dart race/persistence tests for C1–C4
and H1–H2. Then add the smallest release-build device flow for permission,
real-offer, purchase, restore, reinstall, and expiry. Do not chase a vanity
coverage percentage.

Acceptance check: critical flows have regression tests and the M3/M18 device
matrix is completed against a recorded build hash.

### H7 — Firestore rules have no automated emulator test

Evidence: rules are restrictive (owner create only, server timestamp, no
update/delete, other paths denied), but no rules-test or emulator test file was
found.

Impact: a future rule edit can silently allow trial resets, cross-user reads, or
unexpected writes.

Proposed solution: add focused emulator tests for owner read/create, immutable
timestamp, denied overwrite/delete, and cross-user denial. No app abstraction
is needed.

Acceptance check: rules tests run in the release/CI checklist and fail when any
protected operation is loosened.

### H8 — Vendored accessibility plugin still ships automation APIs

Evidence: the manifest omits gesture capability and FoxyCo does not call it,
but the vendored plugin still exposes `performActionById` and `dispatchGesture`
in Dart and Java (`third_party/flutter_accessibility_service/...`). Broad keep
rules retain the plugin classes in release builds.

Impact: unused automation surface increases policy-review risk, maintenance
surface, and the damage of a future accidental call.

Proposed solution: remove those methods/channels from the vendored fork and
narrow keep rules to what parsing needs. Preserve the explicit omission of
`canPerformGestures`.

Acceptance check: release bytecode has no callable action/gesture channel and
real read-only offer capture still passes.

### H9 — Overlay plugin failures can become unhandled and desynchronize state

Evidence: OfferWatcher fire-and-forgets `showFromOffer()` and `clearOffer()`
(`lib/services/accessibility/offer_watcher.dart:348,466`). `_pillUp` is set
before native show succeeds (`lib/ui/overlay/overlay_controller.dart:134`).

Impact: a platform-channel error can become unhandled while internal state says
a pill is visible when it is not.

Proposed solution: catch failures at the controller boundary, log them, and
restore `_pillUp=false`; make fire-and-forget explicit only after the future is
error-contained.

Acceptance check: throwing fake overlay methods produce no unhandled async
error and controller/native state converges.

### H10 — Permission refresh coalescing can miss the final permission state

Evidence: when `_permissionRefresh` exists, every new status event returns the
same in-flight Future and does not queue a follow-up check
(`lib/ui/home/dashboard_controller.dart:153-166`).

Impact: a permission toggled during a slow platform query can leave the UI and
monitoring gate stale until another resume or event.

Proposed solution: add one dirty flag. If a request arrives in flight, rerun
once after completion. Avoid queues or streams beyond the existing observer.

Acceptance check: enable→disable and disable→enable during a delayed check end
in the final OS state.

### H11 — Permission revocation can discard an active session boundary

Evidence: a mid-shift permission refresh can set `blocked`, but the normal stop
path that consumes and clears `liveSince` is not run. `liveSince` is stored only
in memory (`lib/ui/home/dashboard_controller.dart:22`).

Impact: the active shift can be lost, linger, or be summarized against the wrong
boundary after access is restored.

Proposed solution: use the existing session-finalization path when a running
state becomes blocked, with an explicit “permission revoked” stop reason.

Acceptance check: revoke either permission mid-shift; one correctly bounded
session is recorded and no stale `liveSince` remains.

## Medium and low findings

### M1 — Cached-purchase staleness warning is never derived

`cacheGoingStale` is used for trial messaging, but a cached purchase receives no
advance “Play check needed” warning despite the UX copy. Derive it for the
purchase grace window and test the warning boundaries.

### M2 — Future-dated cached purchase timestamps extend access

`now.difference(purchasedAt) < grace` accepts negative durations. Validate or
clamp timestamps materially ahead of trusted time; add a future-cache test.

### M3 — A trial start can consult a poisoned local high-water clock

Ensure trusted token/server time heals `FoxClock` before resolving a newly
server-stamped trial. Test forward-clock poisoning followed by a legitimate
trial start.

### M4 — Distinct identical-value offers can be swallowed

Watcher identity is only platform, payout, and total distance rounded to one
decimal (`lib/services/accessibility/offer_watcher.dart:160`). OfferLog also
de-duplicates a stronger same-card signature for two minutes. Include all
available stable offer fields and use presence/clear lifecycle to distinguish
cards; add back-to-back identical-value fixtures without removing flicker
protection.

### M5 — A locked pill can remain after purchase until another offer event

The current overlay payload is a snapshot. Listen for entitlement transition
while a pill is visible and either redraw or clear it. Test purchase completion
with a locked pill onscreen.

### M6 — Initial permission state defaults to granted

Dashboard starts with both permissions `true` before querying Android
(`lib/ui/home/dashboard_controller.dart:56`). Represent startup as unknown or
blocked and disable monitoring until the first real check resolves. Update
widget tests to inject permissions instead of relying on an unsafe production
default.

### M7 — One malformed persisted row can discard an entire collection

Offer/session JSON loads deserialize the collection in one try block. Validate
and skip bad rows individually, retain good data, and record one diagnostic.
Also clamp persisted settings to supported ranges.

### M8 — Vehicle input validation is incomplete

Make/model/year/plate have no length limits; year validates four digits but not
a plausible range. Add modest field limits and a realistic year range at the
editor trust boundary.

### M9 — Clipboard log export has no clearing strategy

Production logs intentionally avoid raw screen text, which is good. Still warn
that copied diagnostics remain in the system clipboard, and use Android's
sensitive-clipboard flag where supported if the plugin path allows it.

### M10 — Static analysis is clean but not strict

`analysis_options.yaml` uses Flutter lints but does not enable strict casts,
strict inference, or strict raw types. Enable them only after a separate
baseline run shows a manageable diff; this is lower priority than runtime race
tests.

## Release and operational gates

1. Complete all `M18` trial/paywall rows in `docs/MANUAL_TESTS.md` using a
   Play-installed release build. Include purchase, redeem/license testing,
   restore, reinstall, missing key, offline grace, expiry, refund, and 72-hour
   acknowledgement follow-up.
2. Complete current-app/current-OS real-offer rows for Uber, Lyft, and Hopp,
   especially the Android 14+ sensitive-node gate in C5.
3. Verify Play Console product ID, price, license testers, public key, Data
   Safety, accessibility declaration, deletion URL, privacy URL, and terms URL.
4. Verify Firebase Auth providers, SHA fingerprints, Firestore rules deployment,
   quotas/budget alerts, and—after compatibility testing—App Check. App Check is
   defense in depth, not a substitute for rules.
5. Run a 30–60 minute live shift soak and inspect Play Vitals/ADB for crashes,
   ANRs, wake-lock behavior, battery use, overlay leaks, and parser miss health.
6. Re-run analyze, all tests, coverage, release build, signature verification,
   embedded Play-key verification, and artifact SHA after every approved fix.

The local dependency-freshness command could not complete because the installed
Flutter SDK attempted to update files outside the writable workspace. No
dependency upgrade should be guessed from that failure. Re-run `flutter pub
outdated` in the normal developer environment and review upgrades individually;
do not bulk-upgrade release dependencies immediately before submission.

## Complexity / maintenance audit

One-line deletion/simplification candidates (no fixes applied):

- `[delete] pubspec.yaml:45` — remove unused `cupertino_icons`; no
  `CupertinoIcons` usage exists.
- `[delete] pubspec.yaml:49` — remove unused `permission_handler`; app uses its
  platform plugins directly.
- `[delete] first.txt + project.txt` — 1,053 lines of stale specs describe a
  different Kotlin/free/no-cloud product and can mislead future work.
- `[shrink] docs/AUDIT.md:164` — historical text says
  `isAccessibilityTool=true`, contradicting the current manifest and current
  Play policy; label it historical or replace it with this report.

The parser interface has three implementations and is justified. The two
vendored plugin forks contain necessary device fixes, so replacing them merely
to reduce file count is not recommended. Their maintenance cost should instead
be reduced by deleting unused automation APIs (H8) and tracking upstream diffs.

Expected safe cleanup: **2 direct dependencies and 1,053 stale-spec lines**.
No speculative architecture rewrite is recommended.

Cleanup applied 2026-08-07: removed unused `cupertino_icons` and
`permission_handler`, and deleted tracked `first.txt` / `project.txt`. Git keeps
the deleted historical files recoverable. Dependency resolution and final build
verification follow.

## Approval-gated remediation order

Each item is intentionally small enough to approve, implement, test, and review
before starting the next:

1. **C3 — serialize BillingStore refresh and protect purchase-stream truth.**
2. **C2 — prevent stale AccessStore derivations.**
3. **C4 — replace TrialStore cache correctly across accounts.**
4. **C1 — move expiry enforcement into AccessStore.**
5. **H1 (OfferLog first) — prevent hydration overwrite.**
6. **H2 — make the newest offer durable against process death.**
7. **H9 — contain overlay platform errors.**
8. **H10/H11 — converge permissions and close revoked sessions.** These are
   separate implementation approvals even though they share one controller.
9. **M1–M7 — one correctness item at a time.**
10. **H7/H8 — rules tests, then remove native automation surface.**
11. **C5/H3/H4/H5/C6 — device/policy/legal closure with owner-supplied legal
    decisions; code/content changes remain separately approved.**
12. **Cleanup items — one dependency/doc deletion approval at a time.**

After those code fixes, run the release gates. A new production build number
should be created only after the selected fixes and their checks are complete;
rebuilding build 26 now would produce a new binary under an already-used version
code and would not improve confidence.
