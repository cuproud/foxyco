# FoxyCo build 62 — delivery beta handoff

**Source/release:** `1.0.9+62`  
**Implementation date:** 20 August 2026  
**Status:** repository verification complete; delivery-app device verification pending

## What shipped

- Six parser-supported apps: Uber, Lyft, Hopp, DoorDash, Instacart and Skip.
- Fresh installs watch Uber/Lyft/Hopp. DoorDash, Instacart and Skip are labelled
  **Beta**, disabled by default and use separate strict parser files.
- Users can select and persist any one to three apps. A fourth app is blocked;
  the last selected app cannot be disabled.
- Home badges and History app filters derive from the current selection/history.
- Ride and delivery scoring profiles are independent. Delivery cards without a
  trustworthy duration fall back to delivery distance rules.
- Delivery order/item/unit fields flow through offer identity, History details
  and CSV export.
- Main-app Small/Medium/Large text sizing respects system scaling and does not
  change the separate overlay Pill size.
- Android Accessibility scope and user/legal/Play disclosures list all six
  packages. Events from a deselected package are dropped before parsing.
- Existing Uber/Lyft/Hopp parser logic and Accessibility-tool classification
  remain unchanged. Pixel Capture remains an opt-in, on-device fallback.
- Bubble drop-to-dismiss now uses the visible ✕ plus a 28dp margin as the
  actual target. Hover feedback and release share that geometry; canceled
  drags never stop watching.

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
- Flutter tests: **485 passed**.
- Firestore rules tests: passed.
- Signed release AAB: built successfully with `./scripts/build.sh aab --bump`.

```text
dist/FoxyCo-v1.0.9+62-release-20260820-2117.aab
86,116,187 bytes
SHA-256 5a6ce8427b9658c3b3f0acf13904bef490850932218b250cbfb408f59b601df7
```

## What remains Beta

Do not broaden parser matching or claim production-grade delivery support until
each app supplies current package/version evidence, positive and negative
Accessibility dumps, OCR text, partial frames, stacked/shop variants and
accepted/declined flows. Outcome inference intentionally remains disabled for
all three delivery platforms.

## Fast upload check

Run `MANUAL_TESTS.md` rows **Q.1–Q.11**. If time is very short, prioritize Q.1,
Q.2, Q.3, Q.4, Q.7, Q.8, Q.9 and Q.11. Skip live delivery rows until those apps or a
tester with them is available; their absence does not justify marking them
verified.
