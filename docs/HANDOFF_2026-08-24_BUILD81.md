# FoxyCo build 81 - History detail and empty-state handoff

**Release:** `1.0.10+81`  
**Built:** 2026-08-24

## Shipped

- Reuses the existing History hunt artwork whenever the active filters return
  no offers, while preserving the hidden-offer count and one-tap reset.
- Compacts Home's recent accepted timeline with 24 dp platform marks, shorter
  currency labels and 60 dp rows so time and distance remain visible.
- Reworks offer details into two prominent rate cards plus grouped
  distance/time and pickup/ride bands.
- Removes the verdict-threshold explanation repeated below the existing
  GOOD/OK/BAD badge.
- Makes the accepted outcome banner denser, adds an outlined final-payout
  action and keeps the sheet scrollable at large Android text sizes.
- Strengthens the light/dark History city artwork and gives estimated earnings
  an accessible orange accent.

## Verification

- Flutter analyzer: passed.
- Full Flutter test suite: passed.
- Firestore rules tests: passed.
- Short-viewport and 200% text-scale offer-detail tests: passed.
- Recent accepted-trip edit/navigation test: passed.
- Light/dark History layout tests: passed.
- Bundle: `dist/FoxyCo-v1.0.10+81-release-20260824-1916.aab`
- Size: 86,547,466 bytes.
- SHA-256:
  `be1c2f5ddc19c0f97a86a2450fdd49ba942de79f6cf495f0787a91ef19bdc756`

The release build emitted the existing CupertinoIcons lookup warning; Material
Icons were bundled and tree-shaken successfully.

## Device verification focus

1. Check three mixed-platform recent trips at normal and large Android text
   sizes; confirm payout, time and distance remain readable.
2. Open an accepted trip and verify rate cards, grouped trip facts and the
   accepted banner in both themes.
3. Add or edit a final payout and confirm Home and History refresh.
4. Compare the expanded History city artwork and orange earnings value in
   light and dark mode.
5. Select filters with zero matches and confirm the hunt artwork and Show all
   action are both visible.
