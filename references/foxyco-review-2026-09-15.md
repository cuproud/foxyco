# FoxyCo review — 15 September 2026

Scope: current working tree (`1.0.14+107`), canonical offer-detection docs, historical mask handoff, supplied Maps screenshot, and sampled frames across the 115-second August 6 recording, with one-second inspection of its stacked-offer sequence. Existing uncommitted work was preserved. No production code or canonical behavior documentation was changed.

[Rendered preview](foxyco-review-2026-09-15.png)

## Recommendation

Keep the existing fox, car, warm paper and forest-dark identity. Prioritize reliable overlays, cancellation accounting, and a shorter path to the first useful verdict. The app already has substantial functionality: multiple parsers, custom scoring, voice, local history, corrections, backups, sessions, garage and reminders. More feature breadth is less valuable now than making this core dependable and easy to try.

## 1. Recurring grey rectangle — confirmed symptom, unconfirmed current cause

The supplied screenshot shows a sharp rectangular grey area around the circular bubble. That is more consistent with the overlay window/surface composition than the circular artwork. `FoxBubble` clips the asset to an oval and uses a tight circular shadow; `FoxOverlayApp` uses transparent MaterialApp/Scaffold backgrounds. A screenshot alone cannot prove which native layer fails.

The history is documented:

- `.claude/sessions/HANDOFF-2026-07-26-foxy-brand-assets.md`, §1.2: opacity reassertion on resize and flag updates; explicitly excluded drag paths and required device verification.
- Current `OverlayService.java`, `applyLayout`: comments explain that the next recurrence exposed unguarded drag/move/snap layout paths. Those now share the transparency guard.
- Current service construction uses a transparent Flutter SurfaceView, explicit RGBA buffers and surface callbacks. Recommending `setOpaque(false)` again would ignore that renderer change.
- `docs/MANUAL_TESTS.md` Q.15 already calls for accepting a ride, sending navigation to Maps and returning; OCR.19 asks for copied native diagnostics. These remain unchecked in the repository, and the current smoke section says device validation is pending.

Your external-navigation handoff narrows the reproduction: accepted ride → gig app's embedded navigation → launch external Maps → Android Auto involvement → bubble mask. Compare that with opening Maps directly. Also distinguish a simple window change from surface destruction/recreation, rotation and returning to the driver app.

Inspect `overlay-native` generation, window type, format, alpha, size and surface events immediately around the transition. The service being alive is not proof its pixels are transparent. Existing recovery for an inactive overlay does not establish recovery for a live but visually corrupted surface.

Do not label this fixed until repeated handoffs pass on the affected phone/build. No connected Android device was available during this review. A targeted surface lifecycle repair is the first choice once evidence identifies it. A native resting bubble is a fallback worth evaluating only if Flutter surface composition remains the reproducible cause. Keeping a permanently pill-sized window, suggested by an old handoff, also enlarges the touch-interception area and is not a free workaround.

## 2. Stacked Uber Radar — useful evidence and remaining gaps

Around 1:30 in the recording, Lyft's CA$20.04 offer has 0.4 + 19 km and 2 + 25 minutes. Its displayed CA$1.03/km and CA$45/hr agree with that offer. Around 1:35–1:36, an Uber CA$14.17 Radar card with 4.5 + 19.6 km and 8 + 22 minutes appears while the sampled frames still show the Lyft values. Uber's corresponding rates would be approximately CA$0.59/km and CA$28/hr. The clip therefore shows a replacement/lifecycle problem, not merely an incorrect formula. It predates the current August/September fixes; it is a regression scenario, not a current-build reproduction.

Current constraints and risks:

1. Maps/Android Auto are outside the intentionally narrow Accessibility event scope. Uber over a selected gig app and Uber over Maps are different cases. Native capture package validation can also discard a result outside selected driver apps. Expanding monitoring scope is a product/privacy/battery decision, not just a regex fix.
2. Before a top Uber card is confirmed, detection depends on events, a 1.5-second capture cooldown and bounded retries. Short-lived cards can disappear before a usable result.
3. Native isolation requires a recognized tier and a trip row, then keeps one candidate region; Dart isolates it again. Missing tier text, split OCR rows or unexpected Radar layouts can fail before normal parsing. `Match` is already supported; adding that keyword alone is not the answer.
4. Native `isolateUberCard` uses vertical bounds and chooses the qualifying region with fewer OCR lines. This is a review risk for multiple visible candidates, not proof of your failure. Host parser tests do not execute this ML Kit geometry code.

When logs arrive, classify each incident as no trigger, empty capture, wrong active package, stale-result rejection, no-card isolation, parser miss, duplicate suppression, or successful parse with failed/locked display. A History row versus no History row is an especially useful first split. Never combine the exposed lower app's fare with the top app's route to improve apparent detection rates.

## 3. Cancellation fees — confirmed end-to-end feature gap

`OfferOutcome.cancelled` exists, but `offer_detail_sheet.dart` only enables initial final-payout editing for taken/completed offers. A cancelled row with no prior final payout cannot add one. Both `OfferStats.from` and `SessionSummary.from` exclude cancelled rows from their earnings aggregates. Home's recent-accepted list excludes them too.

Proposed smallest correct behavior:

- Cancelled trip → record fee using the existing final-payout representation where possible; retain the original offer and cancelled outcome.
- Distinguish unrecorded fee, explicitly zero fee, and positive fee.
- Include recorded cancellation fees in earnings, with a separate cancellation count. Do not count these as completed rides or assume the original offered fare was received.
- Do not calculate realized cancellation $/km or $/hr from the original full trip. Start with unavailable trip rates; later allow actual partial distance/time as separate facts if needed.
- Include fees in shift hourly earnings using shift duration, and refresh saved session totals through the existing correction path.
- Verify zero/missing/paid cases, persistence/CSV round trips and session/history consistency. Keep toll and tip handling correct.

The preview illustrates this flow but implements no app accounting changes.

## 4. UI and motion

The car and fox are already recognizable. Give the car a smaller supporting role on Home and lead with Watching status, selected apps, this-shift earnings and records needing attention. Keep garage/reminders available without increasing the core dashboard's density. Label estimated versus recorded money explicitly.

The current verdict pill leads with $/km regardless of scoring mode and relies on color for its verdict. Give the active scoring rate priority and pair color with a verdict word/symbol. Fit and test the compact layout at real device widths; do not solve crowding by making critical text smaller. The preview shows a distance-mode example only.

Move an in-app sample verdict ahead of permission/account friction. Current onboarding has five pages, while the Home preview sits below session content and tips; selected apps are configured separately. A sample offer can explain the value before the user authorizes reading other apps. Keep disclosures and permission consent intact.

Suggested signature motions:

| Moment | Motion | Bound |
| --- | --- | --- |
| Watching starts | Orange fox-trail streak beneath existing car | Once, about 650 ms |
| New verdict | Small settle/fade; values readable from the start | About 180–220 ms |
| Fee saved | Confirmation appears and earnings refresh | Once, about 220 ms |
| Shift ends | Receipt-style recap reveal | Once, about 250–300 ms |

Existing performance foundations are good: separate overlay isolate, image decode sizing for the bubble, RepaintBoundary around car art, TickerMode on inactive tabs, reduced-motion support in several widgets, and OCR bitmap work off the Android UI thread. Preserve those. The hero still has a repeating controller and the pill has an animated plasma border; favor finite interactions before adding more perpetual effects. `overlay_entry.dart` has an unconditional AnimatedSwitcher duration, so reduced-motion handling should be checked there too.

No animation can be promised to have zero performance cost. Profile on the affected phone and a slower supported device while Maps, driver apps and OCR are active. Measure UI/raster frame times (16.7 ms budget at 60 Hz, 8.3 ms at 120 Hz), missed frames, capture latency, memory and sustained battery/thermal behavior against today's build. Browser preview smoothness proves none of these. Follow [Flutter's profiling guidance](https://docs.flutter.dev/perf/ui-performance) and [performance practices](https://docs.flutter.dev/perf/best-practices).

## 5. Getting the first real drivers

Zero signups alone does not identify whether reach, messaging, tester eligibility, installation or in-app activation failed. I have not seen your posts, Play Console funnel or group membership settings. The public group/opt-in endpoints could not be inspected successfully here; that is not evidence the links are broken.

The repository's `docs/index.md` is a short explanation, three testing steps and legal links. If that is the page you send people, it asks for several commitments before showing the product work. Closed-test apps are not searchable before open testing/production; group membership and Play opt-in are separate steps. See [Google Play's testing guidance](https://support.google.com/googleplay/android-developer/answer/9845334?hl=en-GB).

Suggested first experiment:

1. Recruit 5–10 Android Uber/Lyft drivers in the market you actually tested, such as GTA if that remains your target. Optimize for one successful session each, not broad impressions.
2. Use a short captioned demo: readable offer → FoxyCo verdict → driver-controlled decision → History. Hide rider names/addresses. Lead with value in the first two seconds, not a logo intro.
3. Provide one clear testing page with the demo, supported devices/apps, privacy explanation, honest limitations, trial/price terms and ordered group → opt-in → install instructions. Tell testers to use the same Google account at each step.
4. Validate this path with a fresh eligible account on an Android phone, including country/device availability. Group joining should not silently require an approval nobody handles.
5. Offer personal onboarding to the first willing drivers. With group-admin permission, request specific feedback rather than repeatedly posting generic promotion.
6. Track aggregate stages: post views/clicks where available, group joins, Play opt-ins/installs, successful setup, first real verdict and next-session use. Start with existing platform counts and voluntary feedback; new app analytics would require a deliberate change to the current privacy promise.

Suggested post copy:

> GTA Uber/Lyft drivers on Android: I built FoxyCo to show an offer's $/km and $/hr against your own limits, without leaving the driver app. It never accepts or declines rides for you. I'm looking for five drivers to try a session and tell me where it gets confusing or misses an offer. It's in closed testing, with a 7-day trial and a one-time unlock afterward. Here's a short demo and the exact steps to join. I'll help with setup.

Use GTA and the trial wording only if those remain your intended market and actual testing offer. Do not claim proven earnings improvement or Android Auto integration. Check whether the seven-day trial gives your testers enough time to evaluate the core feature across the requested test period.

## Verification and next order

135 focused tests passed: Uber parser, offer watcher, offer stats, session-history model and offer-detail sheet. Preview JavaScript syntax and local assets were checked, and the desktop preview was rendered and visually inspected in headless Chrome. No full release checks or physical-device performance tests were run.

Recommended order: collect the Maps/Radar incident logs and reproduce → repair and verify overlay/capture behavior → cancellation accounting and its previewed UI → first-use demonstration and small tester cohort → measured visual polish. Do not broaden supported apps or add heavy animation packages before those steps.
