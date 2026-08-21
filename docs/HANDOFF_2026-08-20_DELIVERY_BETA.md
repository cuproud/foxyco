# FoxyCo build 66 — delivery beta and device-fix handoff

**Source/release:** `1.0.9+66`  
**Implementation date:** 20 August 2026  
**Status:** repository verification complete; build-66 and delivery-app device verification pending

## What shipped

- Six parser-supported apps: Uber, Lyft, Hopp, DoorDash, Instacart and Skip.
- Fresh installs watch Uber/Lyft/Hopp. DoorDash, Instacart and Skip are labelled
  **Beta**, disabled by default and use separate strict parser files.
- Users can select and persist any one to three apps. A fourth app is blocked;
  the last selected app cannot be disabled.
- Home badges and History app filters derive from the current selection/history.
- Ride and delivery scoring profiles are independent. Delivery cards without a
  trustworthy duration fall back to delivery distance rules.
- Uber is one selectable app covering rides and Uber Eats because both share
  the Uber Driver package. Eats offers use delivery rules; Uber rides keep ride
  rules. The Delivery rules card remains visible but disables for Lyft/Hopp-only.
- Delivery order/item/unit fields flow through offer identity, History details
  and CSV export.
- Main-app Small/Medium/Large text sizing respects system scaling and does not
  change the separate overlay Pill size.
- Android Accessibility scope and user/legal/Play disclosures list all six
  packages. Events from a deselected package are dropped before parsing.
- Existing Uber/Lyft/Hopp parser logic and Accessibility-tool classification
  remain unchanged. Pixel Capture remains an opt-in, on-device fallback.
- Bubble drop-to-dismiss uses the last device-verified raw screen-Y boundary:
  drag through the visible ✕ toward the bottom edge until it turns red, then
  release. Hover and release share that predicate; canceled drags never stop watching.
- All app snackbars now inherit one FoxyCo theme: floating palette surface,
  16dp corners, orange outline and matching text. This covers update success,
  Google sign-in, profile, garage, feedback, logs and purchase messages without
  per-caller styling.

## Build 66 regression fixes

- Build 64 replaced the working bottom-edge dismiss predicate with a rectangle
  read from a separate Accessibility overlay window. The coordinate spaces did
  not agree on the Galaxy S24, so the target never turned red and release never
  closed the overlay. A build-65 `getLocationOnScreen` attempt compiled but did
  not restore device behavior. Build 66 removes cross-window rectangle reads
  and restores the previously verified raw screen-Y predicate.
- The post-update confirmation and other `SnackBar` callers previously fell
  back to Material's black bar. `AppTheme` now owns their shared FoxyCo styling.

## Delivery parser contracts

- **DoorDash:** guaranteed pay + route distance + Accept + route marker.
  Supports public single, batched and Canadian French retail examples.
- **Instacart:** pay + distance + Accept + Shop and Deliver/Delivery Only.
  Shop and Deliver additionally requires item count; Shop Only fails closed.
- **Skip:** complete pay + total distance + Accept + pickup and delivery
  endpoints. Arrival clock times are never interpreted as duration.

The evidence and field mappings live in
[`DELIVERY_PLATFORM_RESEARCH_2026-08-20.md`](DELIVERY_PLATFORM_RESEARCH_2026-08-20.md).
Public cards are test seeds, not proof of current Accessibility node behavior.

## Verification completed

- Static analysis: passed.
- Flutter tests: **488 passed**.
- Firestore rules tests: passed.
- Signed release AAB: built successfully with `./scripts/build.sh aab`.

```text
dist/FoxyCo-v1.0.9+66-release-20260820-2222.aab
86,121,362 bytes
SHA-256 3c8159aa690c65e0b3e5eb488259fea7cd274f0eea70b1bf14b43fe98522918a
```

## What remains Beta

Do not broaden parser matching or claim production-grade delivery support until
each app supplies current package/version evidence, positive and negative
Accessibility dumps, OCR text, partial frames, stacked/shop variants and
accepted/declined flows. Outcome inference intentionally remains disabled for
all three delivery platforms.

## Fast upload check

Run `MANUAL_TESTS.md` rows **Q.1–Q.12**. For build 66, prioritize Q.1, Q.10,
Q.11 and Q.12. Skip live delivery rows until those apps or a tester with them is
available; their absence does not justify marking them verified.
