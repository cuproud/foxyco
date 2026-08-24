# FoxyCo build 77 - analytics UI and release handoff

**Release:** `1.0.10+77`  
**Built:** 2026-08-23

## Shipped

- Removed locale-specific prefixes such as `CA$` from analytics amounts.
- Matched session recap earnings/rate presentation to Last Session.
- Reordered History Summary into verdicts, performance, accepted totals,
  offers, and compact supporting metrics.
- Added accepted trips and total distance driven from accepted offer history.
- Removed repeated good/ok/bad labels from the Offers card.
- Kept Uber Trip Radar `Match` parsing covered by the existing parser tests.

## Verification

- Flutter analyzer: passed.
- Flutter tests: 503 passed.
- Firestore rules tests: passed.
- Bundle: `dist/FoxyCo-v1.0.10+77-release-20260823-2033.aab`
- Size: 86,265,144 bytes.
- SHA-256:
  `e77a944bfba9eb21ebf7f7c1bf4a962e50dbfc3c7272b8f1987d0bc9cd2065fc`

## Device verification focus

1. Confirm selected currency remains visible in Settings while analytics uses `$`.
2. Verify History accepted-trip count and distance match accepted offer rows.
3. Check the compact summary layout with large counts and narrow screens.
4. Verify Uber Trip Radar cards with a `Match` action still score correctly.
