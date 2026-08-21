# FoxyCo build 67 — UI, wording and flow analysis

Source: `Screen_Recording_20260821_140445.mp4` (2:44, recorded August 21,
2026)

Scope: the update experience, Home, Rules, History, offer details, Settings,
feedback, wording, visual hierarchy and navigation. This review is based on
visible behavior in the recording; it does not verify live offer parsing.

Implementation update: the confirmed issues in this review were addressed in
`1.0.10+68`, including bottom clearance, account copy, filter contrast, Rules
summaries, total-time wording, watched-app-limit feedback and vehicle-model
suggestions. The apparent blank scoring card was an animation frame, not a bug.

## Overall verdict

Build 67 looks coherent, distinctive and close to release quality. The fox/car
art, warm surface palette, compact verdict language and colored platform marks
make FoxyCo recognizable. History is the strongest part of this tour: its
summary, charts, offer rows and detail sheet turn raw offers into useful driver
feedback without looking like a generic analytics app.

The remaining weakness is density management. Rules and Settings still use many
nearly identical accordion cards, and the floating bottom navigation sometimes
covers the final control or text.
The next pass should prioritize correctness and obstruction issues rather than
another visual restyle.

## What improved successfully

- `Offer scoring`, `Minimum payout & pickup`, `More offers` and `Higher value`
  are clearer than the previous terminology.
- History filters now open in a focused bottom sheet and include Uber, Hopp,
  Lyft, DoorDash, Instacart and Skip.
- `Lifetime plan · Active`, `Sign out`, `Help & About` and
  `Screen-reading fallback` read naturally.
- `Comfort SUV` and `Plate number (optional)` use clearer vehicle language.
- The offer detail sheet has excellent hierarchy: verdict and payout first,
  compact rate/time/distance metrics second, then a plain-language scoring
  explanation and outcome.
- Light and dark themes appear visually related rather than like two separate
  products.

## Immediate fixes

### P0 — floating bottom navigation obscures content

The navigation capsule overlaps content on Home, expanded Rules and Settings.
Examples include the Home action/last-session boundary, the watched-app limit
helper, and lower Appearance controls. A user can sometimes scroll around it,
but persistent navigation should not cover the last actionable row.

Give every tab's scroll view bottom padding equal to the navigation height plus
the device safe area. Snackbars should anchor above the navigation instead of
covering both the primary action and page content.

### P1 — account status repeats itself and feels contradictory

The expanded Profile section presents all of these together:

- `Lifetime plan · Active`
- `Lifetime unlocked`
- Google account for lifetime access
- Google account used for the trial
- Restore purchase

The state is valid, but the repetition makes users wonder whether trial access
still matters after purchase. Use one status block:

```text
Lifetime access
Active through Google Play
foxyco.dev@gmail.com
```

Keep `Restore purchase` as a secondary action. Move the trial-account and
deletion explanation into a separate `Account & privacy` row, or shorten it to
one sentence when lifetime access is active.

### P1 — watched-app selection feedback is too subtle

DoorDash, Instacart and Skip become very pale when unavailable because three
apps are already selected. The small explanation sits low enough to compete
with the floating navigation.

Keep disabled rows readable and show a direct inline message near the first
blocked tap: `You can watch up to 3 apps. Turn one off to add DoorDash.` This is
more useful than relying on reduced opacity and a general footer.

## Screen-by-screen analysis

### Update flow

The initial `FoxyCo update available` banner is clear, and `Later` versus
`Update now` is an appropriate choice. The experience then passes through the
Play update dialog, a mostly white Google installation screen, an in-app
`Updating FoxyCo… 51%` banner and finally a success snackbar. That is a lot of
status presentation for one action, though most of it belongs to Google Play.

Improvements:

- Use `Update available` rather than repeating the product name inside FoxyCo.
- While Play owns installation, use a neutral `Installing update…` status and
  avoid presenting a second percentage unless it comes from the same source.
- `Updated to 1.0.10` is more informative than `FoxyCo updated successfully`.
- Place the success message above the floating navigation and dismiss it
  quickly; it currently covers the shift action area.

### Home

The primary hierarchy is strong: greeting, live status, hero artwork, daily
offer summary and start control. The U/H/L platform dots efficiently show the
active watched set.

Improvements:

- `first day` remains ambiguous. Use `Day 1`, `First shift`, or remove it until
  the underlying achievement is clear.
- Standardize count wording. The screen says `offers seen today`; History uses
  `offers`. `Offers reviewed` best describes FoxyCo's role.
- The hero remains visually dominant over the actual start action. Reducing its
  height modestly would keep `Slide to go live` fully visible above navigation.
- The update snackbar and floating navigation should never obscure the slider.

### Rules

The renamed cards are easier to understand, and the collapsed summaries let a
driver audit the current configuration quickly. Only-one-open behavior keeps
the page manageable.

Improvements:

- Fix the blank expanded scoring card before visual refinements.
- `GOOD CA$1.00–1.50/km` is ambiguous because GOOD normally starts at the upper
  threshold. Prefer `BAD < CA$1.00 · GOOD ≥ CA$1.50/km` in the summary.
- `Minimum payout & pickup` is clear but visually long. `Payout & pickup limits`
  scans faster while preserving meaning.
- The delivery mode control and threshold values sit near the bottom navigation
  when expanded. Ensure all controls can scroll completely above it.
- The tiny vehicle illustration on the slider is memorable, but the actual
  adjustable value should remain unmistakable and keyboard/tap editable for
  precise amounts.

### History overview and filters

This is the best flow in the recording. The summary exposes volume, average
quality, best rate and busiest hour; the by-hour and by-app charts provide a
useful second level; rows remain compact. The filter sheet is much better than
the previous in-page expansion.

Improvements:

- Unselected app and verdict chips are too pale, especially green Instacart and
  Hopp. Increase text/icon contrast while keeping the selected red treatment.
- `Filter by minimum fare` uses a switch but no amount until enabled. Show the
  inactive value in the helper (`Any fare`) and reveal a simple amount stepper
  when enabled.
- The header summary `All platforms · Any fare · All time` is useful; keep the
  same order after filters change so it remains scannable.
- The red `Done` button is appropriately prominent, but preserve 8–12 px above
  the system gesture/navigation area on every device.
- If filter changes apply immediately behind the sheet, label the button
  `Show 10 offers`; this confirms both the action and result count. If they are
  staged, `Apply filters` is clearer than `Done`.

### Offer list and detail sheet

The list is information-dense without becoming noisy. Platform color, verdict,
outcome, payout, time and rate are all discoverable. The detail sheet correctly
places the decision explanation below the numbers.

Improvements:

- Make explicit whether the large payout includes the bonus. The current
  `Includes CA$2.85 bonus` wording suggests it does, which is good; preserve
  that contract everywhere.
- `Not taken` plus `The app returned to its offer map` is excellent explanatory
  copy. The small pencil/edit affordance on list outcomes is easy to miss;
  provide an `Edit outcome` tooltip/semantic label and a 44 px target.
- `Trip time` excludes pickup while `Total` distance includes pickup and ride.
  Rename it `Ride time` or show `Total time` if the parser has both values.
- The outcome picker is clear, but `Accepted`, `Cancelled` and `Completed` can
  represent stages of the same trip. If only one value is stored, title it
  `Latest known outcome` and explain that later states replace earlier ones.

### Settings and Profile

The section order is sensible and the new labels are stronger. App Health is
visible without being buried in diagnostics. However, Settings remains long and
card-heavy.

Improvements:

- Consolidate the account state as described above.
- `Reset preferences` is still visually prominent in red at the top. Move it
  inside `Your data` or the bottom of Settings, where destructive maintenance
  actions are expected.
- Use expansion for quick controls (`Pill size`, `Text size`, `Appearance`) and
  navigation rows for complex areas (`Profile`, `Garage`, `Offer detection`).
  This reduces the feeling that every setting is the same kind of object.
- `Offer detection — Current session` beside historical offers is technically
  correct but can read as a mismatch. Use `This session` and explain
  `No offers read since watching started` in the expanded state.
- The `Small` text setting is genuinely small in labels and helper copy. Ensure
  it never drops below the accessible minimum; it should be compact, not faint.

### Feedback

The feedback form is focused and appropriately disables submission before a
description is entered. Category chips and optional screenshots are useful.

Improvements:

- The heading `What happened?` is repeated inside its placeholder. Use
  `Describe what you expected and what happened` as the field hint.
- When `Offer detection` is selected, automatically attach safe diagnostic
  metadata only after clearly stating what will be included; never attach offer
  text or screenshots without explicit consent.
- Change `Add screenshots` to `Add screenshot` if only one can be selected.

## Visual-system assessment

### Strong and unique

- The fox driving imagery is memorable and directly tied to the product.
- Coral red functions as a strong action/navigation accent without taking over
  the whole interface.
- Platform dots and verdict colors make dense data quick to scan.
- Rounded cards, warm off-white backgrounds and restrained shadows are
  consistent across the app.
- Offer details balance personality with the seriousness of earnings data.

### Needs refinement

- Too many cards share the same white rounded shape, padding and shadow. Use
  flatter navigation rows for secondary Settings destinations and reserve
  elevated cards for summaries or active controls.
- Secondary gray and pastel text is occasionally too faint. Raise contrast on
  unselected chips, helper text and disabled watched-app rows.
- Bottom navigation is visually polished but behaves like an overlay without
  sufficient content insets.
- Some screens use large unused vertical areas inside expanded cards while
  nearby controls are crowded against the bottom navigation.

## Recommended order

1. Add consistent bottom insets and snackbar positioning above navigation.
2. Consolidate lifetime/trial/account wording.
3. Improve disabled-chip and watched-app contrast/feedback.
4. Clarify Rules threshold summaries and History time labels.
5. Simplify Settings card hierarchy in a later structural pass.

Build 67 does not need a new aesthetic direction. Its strongest path is to keep
the current identity, remove obstruction and ambiguity, and make dense screens
feel lighter through hierarchy rather than through more decoration.
