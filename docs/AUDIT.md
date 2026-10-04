# Release audit

Audit date: 2026-10-04

Candidate: `1.0.19+124`

Play upload remains conditional on the device and
Console checks in `MANUAL_TESTS.md` and `PLAY_RELEASE.md`.

## Build 124 — Garage visual refinements

- Reviewed `Screen_Recording_20261004_173310.mp4`: the prior shared reflection
  cycle left most highlights absent between pulses.
- Selected bars now have seven mixed reflections scattered at stable positions,
  randomized independent opacity/scale phases, a stronger warm rim and glow,
  a clipped inner glow, and a 2.5% lift. The shared clock persists through
  selections and parent rebuilds; only the effect repaints.
- Chart data, period grouping, value bubbles, gradient colors, unselected bars
  and surrounding card spacing are preserved.
- Widget checks cover 320/360 dp, both themes, normal/2× text and all four
  periods, rounded-mask pixels, selection fades, stable widget identities and
  reduced motion. The populated Garage card also has separate image/text bounds.
- Flutter analysis and 71 focused chart, Garage and navigation tests passed.
  Rendered compact-screen captures and a selection animation were reviewed.
- Vehicle cards now show brand/model first, body type and saved color second,
  and plate/year metadata below; the active-vehicle heading also omits the year.
  Metadata wraps to keep the layout usable with enlarged text.
- The active car is first; additional cars stay under a collapsed Other vehicles
  group, which closes when another car is selected. A 48 dp plus icon in the
  heading replaces the full-width Add vehicle button.
- Version code advances from 123 to 124; version name remains `1.0.19`.
- Guarded release preflight passed full Flutter analysis, the full Flutter suite
  and Firestore rules tests. The signed AAB includes the Play licensing key;
  `jarsigner` reports `jar verified`. The packaged manifest reports
  `com.foxyco.app`, version name `1.0.19` and version code `124`.
- Repo cleanup retains the installed design skill and graph exploration in
  version control, removes retired HTML references and their broken link, and
  removes the temporary preview harness. Generated previews and AABs stay in
  ignored `dist/`.
- Play Console upload and physical-device checks remain pending.

Verified artifact: `FoxyCo-v1.0.19+124-release-20261004-1820.aab`

SHA-256: `c95257092802eaf12a284c80c4dd6155f53678d9e725d0791e966debbeee17d9`

## Build 123 — Play upload rebuild

- Build code advances from 122 to 123 because build 122 has already been
  uploaded to Play Console. Version name remains `1.0.19`.
- Includes the build 122 changes and the History final-earnings editor fare
  prefill documented below.
- `pubspec.yaml` and About both report build 123.
- Release preflight passed Flutter analysis, Flutter tests, and Firestore rules
  tests. `jarsigner` reports `jar verified`.
- Play Console upload and device checks remain pending.

Verified artifact: `FoxyCo-v1.0.19+123-release-20261004-1722.aab`

SHA-256: `59ac57499e3cae9e15dbf9beafe6ef1ccf89a4668444c1f5a10b49d5581adc98`

## Build 122 — navigation recovery and visual polish

- Garage labels its report Income. The selected bar keeps five fixed-position
  reflections with staggered opacity and scale pulses, two larger four-point
  stars, clipped glow, and a fade between selected bars. Reduced motion shows
  four still reflections.
- The splash no longer paints the exhaust oval that appeared as a dark patch
  beside the car. The phone's own edge-panel handle is outside this scene.
- Google Maps and Waze window-state events can recreate the parent overlay
  window on handoff. A single follow-up refresh runs about 30 seconds later
  while the resting bubble is visible; a verdict pill defers it. The existing
  five-minute idle fallback remains. Navigation content is never copied or
  parsed as an offer. The disclosure and release wording now name both apps.
- Version code advances from 121 to 122; version name remains `1.0.19`.
  `pubspec.yaml` and About both report build 122.
- Same-version-code rebuild also includes the History final-earnings editor
  prefill: when no final payout exists, the upfront fare is shown as editable
  “Fare before tip” and the entered tip is added once.
- Guarded release preflight passed full Flutter analysis, the full Flutter
  suite, and Firestore rules tests. The signed AAB was built with the Play
  licensing key. `jarsigner` reports `jar verified` with the existing
  self-signed upload certificate and standard bundle warnings.
- The Samsung mask recovery remains a physical-device check. Play Console
  acceptance and other device checks remain pending.

Verified artifact: `FoxyCo-v1.0.19+122-release-20261004-1715.aab`

SHA-256: `194ce71e43c8145e820767610c995cded01c993df0f3ec9039f3dc52edfde5ff`

## Build 121 — Garage report polish

- Vehicle cards return to the top of Garage, ahead of the income report.
- The income chart shows an animated sparkle burst throughout the selected bar,
  with its amount in a small label directly above that bar.
- The percentage beside Total income compares the selected period with the
  previous equivalent period (week, month, quarter, or year). When previous
  income is zero, it shows a dash and explains the missing comparison. Tapping
  a bar changes its amount label but leaves the period comparison unchanged.
- Total income uses FoxyCo orange. Garage amounts use the currency symbol
  without the country code, and the Payouts, Expenses, and report-balance card
  follows the supplied reference layout.
- Home removes the long subtitle beneath Weekly goal.
- Build code advances from 120 to 121; version name remains `1.0.19`.
  `pubspec.yaml` and About both report build 121.
- Guarded release preflight passed full Flutter analysis, the full Flutter
  suite, and Firestore rules tests. The signed AAB was built with the Play
  licensing key. `jarsigner` reports `jar verified` with the existing
  self-signed upload certificate and standard bundle warnings.
- Play Console acceptance and physical-device checks remain pending.

Verified artifact: `FoxyCo-v1.0.19+121-release-20261004-1207.aab`

SHA-256: `50d79c1a77c209858ebe625ce27b946d03651bd6a843b25eefd79e5dedb8f0f1`

## Build 120 — Garage income report

- Garage opens with the reference-inspired income chart and a separate payout,
  recorded-expense, and report-balance card. The chart contains income only.
  Weekly, monthly, quarterly, and yearly periods use saved data; weekly
  boundaries and navigation use calendar dates across daylight saving changes.
- The report stays visible without opening an accordion. Vehicle cards,
  reminders, the expense ledger, and Add expense remain in Garage.
- Home colors the session earnings figure green and shortens the
  hourly and acceptance labels. History colors a recorded
  cancellation fee blue in rows and details.
- Build code advances from 119 to 120; version name remains `1.0.19`.
  `pubspec.yaml` and About both report build 120.
- Guarded release preflight passed full Flutter analysis, the full Flutter
  suite, and Firestore rules tests. The signed AAB was built with the Play
  licensing key. `jarsigner` reports `jar verified` with the existing
  self-signed upload certificate and standard bundle warnings.
- Play Console acceptance and physical-device checks remain pending.

Verified artifact: `FoxyCo-v1.0.19+120-release-20261004-0959.aab`

SHA-256: `fbf2fb547a936836bc3cba3ba71e15a1f32c154516af33144b84fb15adc57032`

## Build 119 — reminder, recap, overlay, and cancellation fee

- Play build code advances from 118 to 119; version name stays `1.0.19`.
- Home presents a due car reminder as a small dismissible bubble beside the
  header icon, and removes its duplicate lower banner. Session recap puts the
  time range and active time in compact top-row chips, gives Earnings and Jobs
  taken equal width, and separates the Recent sessions surface.
- History tightens filter spacing and offers fee entry when a trip is marked
  Cancelled. The detail sheet's Add fee Save path now returns double-valued
  zero tip and toll fields; a widget regression reproduces and guards the
  runtime type crash reported on device. Crossing the cancelled outcome
  boundary clears any prior final payout.
- The Android overlay recreates its parent window on Maps handoff and periodic
  recovery. A saved live session restores Watching after process restart when
  permissions still allow it. These changes respond to the 2026-10-03 video
  and diagnostics; R119.4–R119.5 remain device checks.
- Guarded release preflight passed Flutter analysis, the full Flutter suite,
  and Firestore rules tests. The signed AAB was built with the Play licensing
  key. `jarsigner` reports `jar verified` with the existing self-signed upload
  certificate, no-timestamp, POSIX-attribute, and streaming ZIP warnings.
- `pubspec.yaml` and About both report build 119. Play Console acceptance and
  the physical-device checks remain pending.

Device checks R119.1–R119.5 remain pending.

Verified artifact: `FoxyCo-v1.0.19+119-release-20261003-2329.aab`

SHA-256: `51019a51fbe9aa69e0e990190502915ff8c35d8eef4bd15eb1bba047f1d8d9db`

## Build 118 — session recap and manual-job math

- Version name remains `1.0.19`; only Play build code advances from 117 to 118.
- Home shows a shorter daily recap and keeps Recent sessions in a separate
  panel, collapsed by default.
- The recap's acceptance percentage now divides captured accepted offers by
  captured offers seen (`2 / 24` displays as `8%`). Manual jobs count toward
  recorded earnings and jobs taken on their entered date, but do not inflate
  offers seen or offer quality. Work outside a saved watch session adds its
  entered trip minutes to the recorded-hour denominator.
- History labels mixed captured and manual rows as Records. Its "Of seen"
  percentage uses captured offers only; Goal and report income continue to
  include manual payouts. Adding a manual job waits for saved History to load
  before refreshing a saved session.
- Guarded release preflight passed analysis, the full Flutter suite, and
  Firestore rules tests. Formatting and diff whitespace checks passed.
- JAR signature verification and bundletool validation passed. The packaged
  manifest reports `com.foxyco.app`, version name `1.0.19`, version code `118`.
  Jarsigner reports the existing self-signed upload-certificate, no-timestamp,
  POSIX-attribute, and streaming ZIP manifest-order warnings.
- Device checks R117.2–R117.4 and R118.1–R118.4 remain pending.

Verified artifact: `FoxyCo-v1.0.19+118-release-20261003-0114.aab`

SHA-256: `9cfeac9f19441ddb7739bc3bd430b263842c6d56b3250cd1b410469108b547e8`

## Build 117 — overlay surface recovery diagnostics

- Maps window-state events can refresh the bubble's child surface after an
  Uber/Lyft to Maps handoff. An idle five-minute check provides a fallback;
  neither path restarts Watching or the current session.
- Surface refresh logging now includes lifecycle callback counts. Maps event
  diagnostics are sampled at most once per 30 seconds, and repeated identical
  route-shadow summaries are collapsed to preserve the bounded email log tail.
- Accessibility disclosure, service description, privacy wording, and the
  Play release notes now describe the Maps window-state signal.
- Version metadata and About are synchronized to `1.0.19+117`.
- Guarded release preflight passed analysis, the full Flutter suite, and
  Firestore rules tests. Formatting and diff whitespace checks passed.
- JAR signature verification and bundletool validation passed. The packaged
  manifest reports `com.foxyco.app`, version name `1.0.19`, version code `117`.
  Jarsigner reports the existing self-signed upload-certificate, no-timestamp,
  POSIX-attribute, and streaming ZIP manifest-order warnings.
- Physical-device checks R117.1–R117.4 remain pending in `MANUAL_TESTS.md`.

Verified artifact: `FoxyCo-v1.0.19+117-release-20261003-0042.aab`

SHA-256: `55a3a4e0ce0997d68c645afebe1279a87d5a31f36363b4021bf85f21fee7f9fc`

## Build 116 — Home and Garage UI polish

- Includes build 115's theme-aware chart and recap improvements.
- Home recap shows the accepted-offer count for the whole day, uses equal metric
  columns and dividers, and labels the acceptance metric as accept rate.
- Quick tip replaces the carousel with a compact card, relevant navigation
  action, and a Next tip control. Tip copy fits 320–412 dp at up to 2× text.
- Home's reminder icon and due banner open Garage's expanded Maintenance
  reminders section. The nearest-reminder preview is hidden for a lone item.
- Garage explains final payouts, accepted-job estimates, and the balance formula;
  expense amounts adapt to narrow screens, tap feedback remains visible, and
  the expense editor uses the selected currency prefix.
- Splash moves the wordmark upward and pairs it with a styled Fraunces tagline.
- Version metadata and About are synchronized to `1.0.18+116`.
- Physical-device checks R116.1–R116.5 remain pending in `MANUAL_TESTS.md`.
- Guarded release preflight passed analysis, the full Flutter suite, and
  Firestore rules tests. Formatting and diff whitespace checks also passed.
- JAR signature verification and bundletool validation passed. The packaged
  manifest reports `com.foxyco.app`, version name `1.0.18`, version code `116`.
  Jarsigner reports the existing self-signed upload-certificate, no-timestamp,
  POSIX-attribute, and streaming ZIP manifest-order warnings.

Verified artifact: `FoxyCo-v1.0.18+116-release-20260928-2243.aab`

SHA-256: `1524d38133b6e13857e8f3a97f93ac09f41a0a7968b71c53c041253f2f900c70`

## Build 115 — graph and session recap polish

- Garage's report follows the light/dark palette, separates axis labels from
  the plot, uses rounded scale values and matching drawn legend swatches, and
  removes the redundant period subtitle below Income vs expenses.
- Home recap spaces and wraps metrics, flattens Offer quality, simplifies
  recent-session rows, and uses muted text for zero payouts. View details opens
  Session history.
- Version metadata and About are synchronized to `1.0.17+115`.
- Guarded release preflight passed analysis, the full Flutter suite, and
  Firestore rules tests. Narrow-layout tests cover both themes and 2× text.
- JAR signature verification and bundletool validation passed; the packaged
  manifest reports `com.foxyco.app`, version name `1.0.17`, version code `115`.
  Jarsigner reports the existing self-signed upload-certificate, no-timestamp,
  and streaming ZIP manifest-order warnings.
- Device UI checks R115.1–R115.2 remain pending in `MANUAL_TESTS.md`.

Verified artifact: `FoxyCo-v1.0.17+115-release-20260928-2146.aab`

SHA-256: `5310d366cc21d6adaf1ec5f22ff61cf2b0a534d7073649e6c14cbe4364164015`

## Build 114 — new Play upload version

Build 113 was already uploaded to Play Console. Build 114 increments both
version name and version code to `1.0.16+114`; app behavior is unchanged.
The guarded release helper passed Flutter analysis, the full Flutter test suite,
and Firestore rules tests. The generated AAB's JAR signature verified.

Verified artifact: `FoxyCo-v1.0.16+114-release-20260928-0121.aab`

SHA-256: `34c1fdefc0f6e4bee64cf99185a933616e00e13503e83b1bd121afeadf3d1607`

## Build 113 changes

- Home replaces the Review Inbox backlog card with a compact full-day Session
  recap. Multiple shifts on one date combine their active duration and earnings;
  the two most recent earlier workdays are available under Recent sessions.
- History session rows gain a floating return-to-top control, and payout amounts
  use the FoxyCo orange accent.
- Garage places a premium income-versus-expenses report below Vehicles. Monthly,
  quarterly, and yearly views navigate with arrows or graph swipes and show
  animated income/expense lines, payout breakdown, ledger expenses, balance,
  and category totals.
- Report income reuses History's recorded payout rollup, including final
  cancellation fees and toll reimbursements once. Expenses come from editable
  Garage ledger entries. Report balance is not a tax calculation.
- The vehicle-expense editor keeps Save visible above the keyboard.

## Build 113 verification

- Flutter analysis: passed
- Full Flutter test suite: passed
- Firestore rules tests: passed
- Signed AAB built with the guarded release helper and Play licensing key
- JAR signature verification: passed (self-signed upload certificate)
- Device checks R113.1–R113.9: pending; see `MANUAL_TESTS.md`

Verified artifact: `FoxyCo-v1.0.15+113-release-20260928-0114.aab`

SHA-256: `be32be3c140330668dbe08f4075b7e989810c245548b535a1e9e7d3666ed3e50`

The checks above establish a signed bundle and host-side behavior only. Play
acceptance, device behavior, and rollout remain external release gates.

## Build 111 changes

- Manual final-payout and cancellation-fee corrections now refresh History
  totals, saved session summaries, and Home goal progress from one shared
  rollup. Cancelled offers contribute no accepted count, route distance/time,
  or trip performance rate.
- History separates confirmed final money from accepted-offer estimates; the
  goal card links to its contributing calendar-period rows.
- First-run onboarding shows the real verdict pill before permissions, and
  lifetime-account sign-in copy no longer refers to protecting a trial.
- A Google Maps OCR capture context now recreates only Flutter's child surface,
  automating the part of stop/start Watching that cleared the S24 Ultra grey
  mask while preserving the service and shift. Other app switches remain
  diagnostic-only. Q.24 remains a physical-device gate before this recovery is
  claimed verified.

## Build 110 changes

- Week, Month, Quarter, and Year earnings targets are editable from the Home
  goal card and persist with the driver's existing settings.
- Large goal and progress amounts scale to narrow cards instead of clipping.
- Focused tests cover editing, serialization, and narrow-screen layout.

## Build 109 changes

- Lyft and Hopp duration parsing now includes an optional hour component, so
  `1 hr 28 mins` is 88 minutes rather than 28.
- History can add a missed completed Uber, Lyft, or Hopp ride with validated
  payout, distance, duration, and past timestamp; the current rideshare rules
  produce its stored verdict.
- Home now shows an animated goal card after Last session. Week, Month,
  Quarter, and Year progress uses taken/completed History earnings and excludes
  missed offers.
- Startup uses the supplied fox-car artwork and rotates Mountains → Snow →
  Autumn in one bounded native Flutter animation, with a reduced-motion path.
- Parser, persistence, narrow-layout, Home integration, seasonal rotation, and
  goal-period regression coverage were added.
- Vendored overlay/accessibility modules now declare the app's minSdk 26, and
  the API 30 OCR path carries its existing runtime gate into release lint.
- The S24 Ultra grey mask is not claimed fixed. Build 108 diagnostics and Q.24
  remain the evidence path; stop/start Watching remains the known workaround.

## Build 108 changes

- No layout, animation, parser, scoring, or outcome-rule changes from build 107.
- Expanded native window/surface and sampled OCR handoff diagnostics, including
  device/Android version and bounded alpha-only sampling of our own 2x2 corner.
- Native OCR failures/timeouts and card-shape counts are distinguishable;
  stale Dart OCR logs explain generation invalidation and synthetic no-card
  results without recording raw text.
- Regression checks cover stale-result reasons and no-card labeling.
- User confirmed the intermittent S24 Ultra mask appears immediately when
  selecting external Google Maps inside Lyft. Restarting Watching clears it.
  The supplied logs do not prove the root cause; build 108 is diagnostic,
  not a verified mask or stacked-Radar fix. Q.24 remains a device gate.

## Build 107 changes

- Total distance, total time, pickup, and ride icons now share the exact
  vertical centerline of their values.
- The distance-edit button is overlaid at the cell edge, preserving its full
  tap target without pushing the route value or label out of alignment.
- Widget coverage measures all four icon/value pairs and protects the compact
  sheet at normal, short, and large-text layouts.
- Version, About, testing, and release documentation are synchronized to build
  107.

## Build 106 changes

- Unmarked saved final payouts add their separately stored tip once while
  loading. New and rewritten rows persist an inclusion marker so restart,
  backup, and import cannot add it again.
- The reported Lyft example now resolves `CA$50.44 + CA$2.00 tip` to
  `CA$52.44` received and `CA$28.88` performance earnings after its
  `CA$23.56` toll reimbursement.
- Version, About, architecture, offer-detection, testing, and release
  documentation are synchronized to build 106.

## Build 105 changes

- Final payout editing adds a separately entered tip exactly once, keeps toll
  reimbursement separate from performance earnings, and exposes the net fare
  on compact History cards.
- Bonus and tip share one compact detail row, toll wording is shorter, long
  values fit without clipping, and distance editing uses an inline icon.
- Screenshot bitmap copying and clearing run outside the Android UI thread;
  routine no-card OCR diagnostics are sampled without changing capture cadence,
  parsing, retries, or offer delivery.
- Version, About, architecture, offer-detection, testing, and release
  documentation are synchronized to build 105.

## Build 104 changes

- Lower Lyft offers are cached even when Uber wins the overlay race, so the
  Lyft verdict returns after the covering Uber card closes.
- History counts and distance-editor guidance fit without clipping, and a
  successful feedback handoff clears the submitted form.
- Final earnings can record included tips and toll reimbursements; tolls stay
  visible in History but are excluded from performance rates.
- Session and trip hourly rates are labeled by their actual time basis.
- Version and release documentation are synchronized to build 104.

## Build 103 changes

- Active-trip evidence now survives offer and partial frames until the driver
  app positively returns to browse/home, preventing a covered offer from being
  falsely marked Accepted when the original trip screen returns.
- Diagnostic-only route matching compares pending offer locations with later
  accepted-trip screens in memory. Logs contain opaque session fingerprints,
  counts, scores, and uniqueness only; History and outcome inference are not
  changed by the shadow result.
- Version and release documentation are synchronized to build 103.

## Build 101 changes

- Cross-app Uber probing is explicitly verified over every supported selected
  non-Uber app: Hopp, Lyft, DoorDash, Instacart, and Skip.
- Any platform's saved History distance can be corrected without deleting the
  row; rates, session summaries, and the snapshot-based verdict refresh.
- Privacy-safe native mask diagnostics now reach copied in-app Diagnostics as
  well as ADB logcat.
- Version and release documentation are synchronized to build 101.

## Build 100 changes

- Every active selected Lyft/Hopp frame makes a rate-limited, bounded Uber OCR
  probe, so a stacked Uber card is found even over a plain lower-app map.
- Lower-app partial/map frames cannot clear or replace a confirmed Uber OCR
  card; OCR alone owns that top card until it disappears.
- Lyft selects the live card's lower payout instead of its persistent top
  earnings balance, preventing GOOD → OK voice/pill changes.
- Uber OCR rejects dropped distance decimals such as `30.4` → `304 km` before
  scoring or history persistence.
- Overlay health loss recovers the native window without ending the shift;
  native generation and surface lifecycle diagnostics were expanded.
- Overlay buffers explicitly require RGBA alpha, and detail-band icons align
  at the left edge of each half.
- Version and release documentation were synchronized to build 100.

## Verification

- Flutter analysis: passed
- Full Flutter suite: passed
- Focused parser/watcher/dashboard regression suites: passed
- Native Android overlay/OCR compilation: passed
- Android release lint: passed
- Signed release bundle and checksum verification: passed
- Packaged version and About label synchronized to build `111`: passed
- Firestore rules and guarded Play bundle preflight: passed

Verified Play artifact: `FoxyCo-v1.0.14+111-release-20260920-2241.aab`

SHA-256: `3b5e62cb5fd1b683521ce47c22b17467b868119ce95d73112f58df2a6534b1c0`

Jarsigner reports `jar verified` with self-signed upload-certificate,
no-timestamp, and streaming ZIP manifest-order warnings. Android bundle
validation is checked separately; Play acceptance and device testing remain
external gates, not claims made by host checks.

## Device gates

- Reproduce every selected non-Uber app → Uber → lower-offer restoration with real cards.
- Confirm `$28.41` never stores `304 km` and the corrected OCR stores `30.4 km`.
- Confirm Lyft's `$44.83` earnings balance never becomes an offer payout.
- Verify stale Uber cards clear promptly and never create duplicate History.
- Switch from Uber/Lyft to Google Maps and confirm the bubble stays transparent.
- Show a new request over an active trip and confirm its outcome stays unknown.
- Install from the Play test track and verify sign-in, purchase, restore,
  refund/revoke, update flow, crash/ANR, and battery behavior.

Do not retain rider names, addresses, screenshots, or raw Accessibility/OCR
text as release evidence.
