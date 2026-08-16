# FoxyCo real-world test implementation plan — 2026-08-16

## Confirmed test baseline

- Phone build: **1.0.9 (build 32)**, installed from Google Play Console.
- Evidence folder: `C:\Users\vamsi\Downloads\fox\Aug 15`.
- Build-32 defects confirmed by the supplied evidence:
  - a verdict can remain after its offer card has gone;
  - the overlay window can expose a grey/black rectangular surface around the
    bubble or pill;
  - accepting one Uber offer can mark several earlier Uber offers Accepted.
- Repository work must remain incremental. Complete and verify one item before
  starting the next; do not apply speculative overlay hot patches.

## Authoritative platform references

- Android `AccessibilityService.getWindows()` returns interactive windows in
  descending layer order (top first) and warns that node content can become
  outdated while a window changes:
  https://developer.android.com/reference/android/accessibilityservice/AccessibilityService#getWindows()
- Retrieving those windows requires
  `FLAG_RETRIEVE_INTERACTIVE_WINDOWS` and `canRetrieveWindowContent`:
  https://developer.android.com/reference/android/accessibilityservice/AccessibilityServiceInfo#FLAG_RETRIEVE_INTERACTIVE_WINDOWS
- Android window format defaults to opaque unless a `PixelFormat` is supplied,
  and accessibility overlays have their own trusted window type:
  https://developer.android.com/reference/android/view/WindowManager.LayoutParams
- Flutter documents that `TransparencyMode.transparent` enables background
  transparency for a SurfaceView-backed `FlutterView`:
  https://api.flutter.dev/javadoc/io/flutter/embedding/android/TransparencyMode.html
- Google Play requires an Accessibility API declaration; apps that are not
  accessibility tools also require prominent in-app disclosure and consent:
  https://support.google.com/googleplay/android-developer/answer/10964491

## Implementation order

### 1. Bubble artwork

Status: **implemented locally; device verification pending**.

- Source:
  `references/logo/ChatGPT Image Aug 16, 2026, 01_27_03 AM.png`
- Runtime asset: `assets/branding/foxyco_bubble.png`
- Preserve the source artwork and alpha channel.
- Keep the existing 512×512 runtime contract so no Flutter layout, overlay
  dimensions, or `pubspec.yaml` changes are required.
- Verify the resting bubble, paused opacity, locked pill icon, light maps and
  dark maps on device.

### 2. Accessibility-window ownership and pill lifecycle

Status: **implemented locally; device verification pending**.

Root-cause direction:

- Native capture currently flattens all same-package accessibility windows.
- Window layer, ID, active/focused state and ownership are lost before parsing.
- A stale/lower offer window can therefore defeat visible browse/accepted
  evidence and keep the old pill alive.

Implementation requirements:

1. Preserve window boundaries and top-to-bottom layer order through capture.
2. Select one owning offer window/card instead of combining unrelated windows.
3. Keep partial frames from that owner, but do not let a stale lower window
   override a visible browse, accepted or newer-offer window.
4. Clear after the short grace when departure is positively confirmed.
5. Reserve the five-second minimum for ambiguous disappearance only.
6. Keep the 45-second overlay-isolate timer as emergency recovery only.
7. Add alternating-window tests, not only consecutive-frame tests.

Acceptance checks:

- Card remains visible: pill remains visible.
- Accept/decline/timeout to browse: pill clears promptly.
- Leaving all watched apps: bubble returns after the silence timeout.
- A stale hidden window cannot keep or resurrect a pill.
- A newer top offer replaces the prior pill without an intermediate bubble.

### 3. Exact accepted-offer ownership

Status: **implemented locally with item 2; device verification pending**.

The existing build-32 exact-candidate guard handles repeated accepted frames
only when nothing changes the candidate between them. It does not cover this
sequence:

1. accepted-trip frame;
2. stale earlier-card frame;
3. accepted-trip frame;
4. another stale earlier-card frame.

Implementation requirements:

- Bind the outcome to the last top-owned live card, not merely the last parsed
  same-platform frame.
- Freeze that candidate through the accepted transition.
- Repeated accepted frames must be idempotent.
- Manual History corrections remain authoritative.
- Background and lower-layer offers cannot receive the active trip outcome.

Required regression fixture:

- Log three Uber offers, accept only the newest, alternate accepted frames with
  stale parses for the older cards, and assert that only the newest is Accepted.
- Repeat for overlapping Uber/Lyft offers and Lyft queued offers.

Implemented check: three Uber offers ending in `$30.70`, followed by repeated
accepted-trip frames carrying `$8.72` and `$5.36` as stale lower windows. Only
the `$30.70` row may become Accepted. Existing cross-app and queued-offer tests
continue to cover the sibling ownership paths.

### 4. Overlay lifecycle serialization and rectangular mask

Status: **command serialization and privacy-safe native diagnostics implemented
locally; renderer decision and device verification pending**.

Do not add another delayed transparency call. Both the patched TextureView and
the transparent SurfaceView have already failed on the Samsung device.

First add privacy-safe diagnostics for:

- overlay/window generation;
- start, replace, resize, surface-create, surface-change and surface-destroy;
- window type, format, flags and alpha;
- command generation and payload/clear ordering;
- Accessibility Service reconnects.

Then serialize status, first-offer startup, payload updates and clears through
one ordered command path. Stale generations must be ignored.

Implemented locally:

- `OverlayService` now serializes start, show, update, pause, clear and hide in
  invocation order, including first-start initialization.
- Native `FOXYCO_OVERLAY` logcat entries identify each service generation and
  record create/add/replace/resize/remove/attach/detach/destroy with type,
  format, flags, alpha and dimensions. They record no offer, rider or address
  data.
- No renderer or delayed-transparency patch was added.

Renderer/ownership decision is device-evidence-driven:

1. serialized transparent SurfaceView;
2. Accessibility Service directly owning `TYPE_ACCESSIBILITY_OVERLAY`;
3. image-backed or native Android overlay if the Flutter surface still exposes
   its rectangular bounds.

Release acceptance:

- 100 pill-to-bubble cycles;
- repeated dragging and edge snapping;
- lock/unlock and service reconnect;
- Uber, Lyft and Hopp open together for 30–60 minutes;
- no rectangle, ghost window, stolen taps or stale command.

### 5. Minimum offer amount verdict rule

Status: **implemented locally; device verification pending**.

Recommended rule:

- Optional custom minimum payout.
- Below minimum becomes BAD by default; optionally allow OK or Ignore.
- Otherwise keep the existing $/km or $/hr verdict.
- Apply the final result consistently to overlay, History, dashboard and voice.
- Add payout to Live preview so the override is understandable.
- Existing installs default to disabled to avoid silently changing saved rules.

Implemented behavior: the rule defaults off, accepts a custom payout, and lets
the driver choose BAD, OK or GOOD. Payout exactly at the boundary continues to
the normal rate rule.

### 6. Voice verdict controls

Status: **implemented locally; device verification pending**.

- GOOD toggle: on by default for new installs; preserve existing saved choices.
- OK toggle: off by default.
- Shared cooldown: 5–120 seconds; proposed default 15 seconds.
- Spoken phrases only: “Good offer” and “Okay offer”.
- Remove payout and currency from preview and live speech.
- Keep `QUEUE_FLUSH` so a new allowed utterance replaces current speech.
- Show the active GOOD/OK scoring conditions in the section.

Implemented behavior: GOOD defaults on for new/default settings, OK defaults
off, the shared cooldown is configurable from 5–120 seconds (15-second
default), and preview/live speech say only “Good offer” or “Okay offer”. Saved
explicit choices remain authoritative.

### 7. Orange selected controls

Status: **implemented locally; visual/device verification pending**.

- Reuse `brandFoxSoft` selected fill and `brandFox` border/accent.
- Apply to Settings Pill size, Appearance and History retention choices.
- Apply to History range/app/verdict filter selection.
- Preserve semantic green/amber/red verdict icons while the selection surface
  uses the orange brand accent.

### 8. Production gates

- Resolve the Accessibility API declaration and `isAccessibilityTool` policy
  classification before release.
- Run analyzer, full tests, signed release build and native compilation.
- Repeat the Android 14/15/16 device matrix where devices are available.
- Retain sanitized logs and screenshots for every release-blocking check.

Local validation completed on 2026-08-16:

- whole-repository Dart analysis: zero issues;
- Dart formatting and `git diff --check`: clean;
- targeted regression checks added for stale-window pill ownership, exact
  accepted-offer ownership, serialized overlay commands, minimum payout,
  verdict-only voice/cooldown, and orange selected controls;
- Flutter test execution is blocked in this workspace because the sandbox
  forbids the localhost socket used by `flutter_tester`;
- Android/Gradle execution is blocked here because Gradle cannot create its
  wildcard-IP file-lock listener. Native compilation remains a required
  outside-sandbox/release-machine check.
