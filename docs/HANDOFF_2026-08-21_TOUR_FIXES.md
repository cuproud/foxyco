# FoxyCo build 67 — tour fixes handoff

**Release:** `1.0.10+67`  
**Built:** 2026-08-21

## Shipped

- The highest-layer offer card owns the pill across stacked Uber Radar and
  overlapping Uber/Lyft windows. A different incomplete top card clears the
  stale lower-card verdict.
- A single opened Lyft scheduled detail with `Reserve`, time, payout and one
  route leg parses as `Scheduled`; multi-card scheduled browse lists remain
  rejected.
- Reserve cards participate in parser-miss health reporting.
- History filters open in a bottom sheet and always include Uber, Hopp, Lyft,
  DoorDash, Instacart and Skip.
- Rules, Settings, Help/FAQ, App Health and account wording were clarified.
- Vehicle editing rejects duplicate make/model values and improves labels and
  delete confirmation.

## Verification

- Flutter tests: 494 passed.
- Flutter analyzer: no issues.
- Firestore rules tests: passed through `scripts/build.sh aab`.
- Release bundle:
  `dist/FoxyCo-v1.0.10+67-release-20260821-1339.aab`
- Size: 86,152,711 bytes.
- SHA-256:
  `f714b94172cd61108852b7ddf3741af929c34999bc290a7ff5eb55cb68147a71`

## Device verification focus

1. Cycle through three to five stacked Uber Radar cards and verify each newly
   topmost card replaces the pill.
2. Put a Lyft offer behind an Uber card; verify Uber wins until dismissed, then
   Lyft becomes current without retaining stale values.
3. Open Lyft scheduled details from the list; verify only the opened Reserve
   card is read and its trip-only metrics are not merged with neighboring cards.
4. Confirm History filters show all six apps even before each app has history.
5. Recheck vehicle save/delete, Rules summaries, Help & About, and App Health
   wording on the target phone size.

The two source reviews are `app-tour-ui-analysis-2026-08-21.md` and
`app-functionality-tour-analysis-2026-08-21.md`.
