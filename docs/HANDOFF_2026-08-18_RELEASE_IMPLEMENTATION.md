# FoxyCo handoff — release implementation and verification

**Date:** 2026-08-18  
**Workspace:** `/home/vamsi/github/foxyco`  
**Branch:** `main`  
**Release build:** `1.0.9+46`

This handoff records the completed implementation represented by the current
release worktree. It includes the Comet-informed architecture work, the UI
walkthrough fixes, bubble appearance customization, and the final voice/pill
synchronization fix.

## Architecture and platform support

- Platform metadata is extensible and is not the parser capability boundary.
- ParserRegistry exposes verified parser candidates separately from metadata-only
  future platforms.
- OfferWatcher can evaluate watched candidates from accessibility windows rather
  than assuming the foreground app is the provider. A provider is taken from the
  parser that owns the offer card.
- Shared identity/dedupe and suppression prevent repeated accessibility, OCR,
  polling, or provider-switch observations from creating duplicate history or
  verdicts.
- Existing parser/OCR infrastructure was preserved; no speculative OCR engine or
  broad parser rewrite was added.

## Offer lifecycle and voice consistency

- A valid offer receives a finalized verdict before it is sent to the overlay.
- The pill has a hard five-second maximum lifetime and cleared-offer paths use the
  existing short grace window.
- Expired, dismissed, and cleared identities cannot resurrect the same pill.
- Voice is scheduled only after the same `showFromOffer` operation that renders
  the pill succeeds, followed by a short stabilization delay.
- Pending speech is invalidated when an offer is replaced, cleared, or the watcher
  is disposed. At speak time, identity, platform, watch state, and current voice
  settings are revalidated.
- Voice does not rescore independently. GOOD/OK/BAD eligibility and Offer Guard
  behavior remain unchanged; BAD remains silent.

## History, outcomes, and historical correctness

- History preserves captured offer economics and offer-time scoring snapshots.
- Historical explanations use the stored snapshot instead of current Rules.
- Final outcomes support Accepted, Not taken, Cancelled, Completed, and Unknown.
- Automatic detection remains separate from user correction, with edited metadata
  retained for later diagnostics.
- History filters are dynamic and include platform, verdict, outcome, date, fare,
  and Top offers only behavior without fixed Uber/Lyft/Hopp assumptions.
- Offer detail keeps verdict and outcome independent and explains passed, failed,
  or unavailable rules using the historical snapshot.

## Sessions and earnings

- Home Last Session and Shift Recap use the shared session rollup.
- Active-platform badges, session counts, verdict distribution, outcome counts,
  and insight tiles are responsive and data-driven.
- Estimated earnings count only qualifying completed/realized offers. No eligible
  completed offers is shown as unavailable (`—`), not monetary zero.
- Captured offer-card amounts remain intact. Estimated session earnings and the
  editable user-confirmed actual total are separate values.
- Session $/hr uses session elapsed duration, preferring actual earnings when
  available and clearly identifying estimates otherwise.

## UI and permissions

- Rules keeps Verdict Thresholds, Offer Guard, Live Preview, Watched apps, and
  Voice Verdict in the established order. Existing scoring behavior is unchanged.
- Live Preview uses realistic offer economics and stable GOOD/OK/BAD geometry.
- Offer access terminology and onboarding actions distinguish permission setup
  from going Live, and settings are rechecked after returning from Android.
- Vehicle Profile restores the original canonical vehicle taxonomy and assets;
  Color and Vehicle type use bounded, safe modal selectors.
- Settings uses user-facing Offer detection terminology and consistent collapsed
  card spacing.
- Loading/splash backgrounds follow the system light/dark theme.
- The floating bubble has one shared overlay implementation with a persisted
  `BubbleStyle`: Cool Fox (default), FoxyCo F, and Fox Paw. All styles preserve
  bubble position, footprint, pill anchoring, and lifecycle.

## Validation

- Flutter analysis: passed through `scripts/build.sh`.
- Full Flutter tests: passed (`434` tests).
- Firestore rules tests: passed.
- `git diff --check`: passed.
- Release AAB: built successfully at
  `build/app/outputs/bundle/release/app-release.aab` (95.5 MB).
- The build emitted only the existing MaterialIcons tree-shaking notice.

## Known limitations

- Uber Eats, DoorDash, Instacart, and other metadata entries must not be called
  production-supported until real parser fixtures and device validation exist.
- Automatic final earnings reconciliation remains future work; manual session
  earnings correction is the safe current path.
- Device validation is still required for real accessibility/OCR timing,
  cross-app overlays, voice timing, and all three bubble assets at overlay size.
