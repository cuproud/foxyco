# FoxyCo build 68 — UI and tour fixes handoff

**Release:** `1.0.10+68`  
**Built:** 2026-08-21

## Shipped

- Topmost cross-app and stacked Uber Radar card arbitration from build 67.
- Narrow Lyft scheduled Reserve-detail parsing without list-card merging.
- History filtering for Uber, Hopp, Lyft, DoorDash, Instacart and Skip.
- Common car-model suggestions for 11 makes with free-text fallback.
- Clearer Rules summaries, watched-app cap feedback and History filter contrast.
- Improved bottom-navigation clearance, account copy, update confirmation,
  total-time wording and Reset-preferences placement.

## Pricing behavior

- Canada launch price: CA$24.99 lifetime.
- United States launch price: US$19.99 lifetime.
- Future countries: use USD as the Play Console base and review generated local
  prices before publishing.
- FoxyCo does not hardcode prices; the paywall displays Google Play's localized
  product price.

## Tester access

Closed-track membership does not grant premium access. Build 68 has no
November 30 fixed-date unlock, so there is no local date to extend to December
30. Ordinary testers receive the seven-day trial. A future temporary tester
entitlement needs a server-controlled allowlist and expiry; a global build date
would also unlock production users and is intentionally not used.

## Verification

- Flutter tests: 495 passed.
- Flutter analyzer: no issues.
- Firestore rules tests: passed through `scripts/build.sh aab --bump`.
- Bundle: `dist/FoxyCo-v1.0.10+68-release-20260821-1427.aab`
- Size: 86,186,405 bytes.
- SHA-256:
  `ef96c65cd035312e0b44c2a059f8f3c02017eb117bb3e62dd4414f3a56c42286`

## Device verification focus

1. Rotate stacked Uber Radar cards and overlap Uber/Lyft cards.
2. Open Lyft scheduled Reserve details and verify trip-only scoring.
3. Verify all six History app filters and the three-app watched limit.
4. Test car-model suggestions and arbitrary free-text models.
5. Verify CA and US localized prices using Play Billing Lab/storefront tests.
