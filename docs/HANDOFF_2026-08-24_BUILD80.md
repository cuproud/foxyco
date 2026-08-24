# FoxyCo build 80 - Home, History and pricing handoff

**Release:** `1.0.10+80`  
**Built:** 2026-08-24

## Shipped

- Removed the growing Home "trips need review" banner; review remains optional
  through History.
- Replaced bulky recent-accepted cards with a compact timeline whose row tint
  and badge follow each platform's color. Trips still open the payout editor.
- Removed the redundant Last Session total-earnings editor and centered its
  collapsed performance row.
- Aligned the History performance metrics and vertically centered its collapsed
  summary.
- Added matching Toronto city artwork for light and dark History cards. Runtime
  assets are compressed 960 px WebP files; the old sunset asset was removed.
- Shows the CA$24.99 Canada or US$19.99 launch-price fallback while Play product
  details load. Checkout remains disabled until Play returns its authoritative
  localized product and price.

## Verification

- Flutter analyzer: passed.
- Full Flutter test suite: passed.
- Firestore rules tests: passed.
- Narrow scaled light/dark History tests: passed.
- Recent accepted-trip edit/navigation test: passed.
- Bundle: `dist/FoxyCo-v1.0.10+80-release-20260824-1740.aab`
- Size: 86,550,764 bytes.
- SHA-256:
  `468fe7bb954c0386a7a5c4ecf6ad29860568fc4d2e4ec56113c0881c92a90bd2`

## Device verification focus

1. Compare expanded and collapsed History performance cards in both themes.
2. Check mixed-platform recent trips at normal and large Android text sizes.
3. Tap each recent trip and confirm final-payout editing still updates Home.
4. Confirm Canada shows CA$24.99 during Play loading and the storefront price
   replaces it before checkout becomes available.
