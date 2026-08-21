# FoxyCo App Tour — UI and Flow Analysis

Source: `Screen_Recording_20260821_082033.mp4` (2:14, recorded August 21, 2026)

Scope: visual design, information architecture, wording, content, and perceived navigation flow. This review does not validate behavior, calculations, persistence, accessibility-service reliability, or other functionality; those belong in the follow-up functionality review.

## Implementation status — build 67

The immediate pass is implemented in `1.0.10+67`: clearer scoring presets and
section names, History filters in a bottom sheet, all six supported apps in the
History app filter, improved Help/FAQ/account and App Health wording, and safer
vehicle validation/deletion copy. Rules and Settings retain their existing
accordion architecture; splitting every group into separate routes remains a
larger optional redesign, not a build-67 release requirement.

## Overall verdict

FoxyCo already feels like a real product, not a generic dashboard. The fox-and-car identity, verdict vocabulary, illustrated empty states, compact bottom navigation, and driver-specific rules give it a memorable point of view. The warm background and restrained red/green accents are coherent across the tour.

The largest opportunity is hierarchy. Rules and Settings are both long accordion collections built from nearly identical white cards. That consistency is useful at the component level, but overuse makes unrelated concepts feel equal and turns each tab into one large settings sheet. The next design pass should preserve the visual system while separating daily actions, configuration, education, and troubleshooting more clearly.

## Observed app flow

```text
Launch
  -> Branded splash
  -> Home dashboard
       -> Live status / go-live control
       -> Today's verdict summary
       -> Last session
       -> Fox Tips carousel
  -> My Rules
       -> Scoring
       -> Platforms
       -> Alerts
  -> History
       -> Filters
       -> Empty/results state
  -> Settings
       -> You & your car
       -> App health
       -> Look & feel
       -> Your data
       -> Help & support
       -> About / FAQ
       -> Diagnostic logs
```

This four-tab model is natural: **Home = now, Rules = decisions, History = past, Settings = configuration**. Keep it. The problem is not the top-level navigation; it is the amount and similarity of content inside Rules and Settings.

## Screen-by-screen review

### 1. Launch and splash (about 0:00–0:04)

**Strong**

- The fox in the sports car communicates the product idea immediately.
- The warm background carries cleanly into the app.
- The logo is distinctive and memorable.

**Improve**

- The first frame appears faint before resolving. If this is an intentional fade, shorten it; if it is asset loading, show the final artwork immediately to avoid a washed-out flash.
- The car artwork and FoxyCo wordmark use different visual languages (modern 3D render versus retro flame lettering). This can be a deliberate “driver culture” identity, but use the pairing consistently so it feels authored rather than assembled.

### 2. Home (about 0:04–0:22)

**Strong**

- “Good morning, Krishna” gives the screen a friendly start.
- Live status, time, hero artwork, offer count, verdict counts, and “Slide to go live” form a clear operational dashboard.
- The sliding go-live control is appropriate for a consequential action and harder to trigger accidentally than a button.
- The last-session card gives continuity between shifts.
- Fox Tips add personality and useful driver education without blocking the main action.

**Improve**

- The hero car illustration is visually dominant even when the driver is offline and has no offers. Reduce it slightly or let the go-live control claim more of the first viewport.
- “Ready when you are” and “Slide to go live” repeat the same idea. Keep the warmer status line, but make the action label simply **Slide to start** or **Start shift**.
- Use one term consistently: the screen mixes “offers seen,” “offers scored,” and “offers appeared.” Prefer **offers reviewed** for the count and **No offers appeared during this session** for the empty explanation.
- “first day” is ambiguous. If it is a streak or account-age badge, label it **Day 1** and provide context on tap; otherwise remove it.
- The Tips carousel exposes narrow fragments of neighboring cards. A small peek is a useful swipe cue, but the current fragments look clipped and compete with the active card. Show one full card plus a controlled 12–16 px preview.
- “Show a demo pill” sounds internal. Prefer **Preview an offer**. If it exists only for testing/onboarding, visually demote it or move it into Help.
- Tips should not use dense paragraph copy in a carousel. Limit each to a short title plus two lines, with **Learn more** when necessary.

**Content/image recommendation**

Keep the fox characters: they are one of the strongest unique assets. Standardize crop, lighting, outline/shadow, and scale so every tip looks like the same illustrated world. Avoid mixing realistic scenic art, 3D cars, and mascot illustrations without a shared treatment.

### 3. My Rules (about 0:22–1:15)

**Strong**

- “How FoxyCo judges every offer” is concise and explains the tab.
- Scoring, Platforms, and Alerts are sensible groups.
- Live Preview is excellent: it lets users understand a rule using a concrete GOOD/BAD result before going live.
- The GOOD/OK/BAD language maps cleanly to green/amber/red.
- Watched Apps makes platform scope visible, and the “up to 3 apps” rule is stated close to the controls.
- Voice preview controls reduce uncertainty before enabling announcements.

**Primary issue: one mega-page made of similar cards**

Every rule is presented as the same white rounded accordion card. Expanded cards become very tall, push neighboring sections far away, and make configuration feel heavier than it is. The user must remember which accordion contains which concept.

**Recommended structure**

1. Keep a compact Rules overview with three summary cards: **Offer scoring**, **Apps**, and **Voice alerts**.
2. Open each summary as its own focused screen or bottom sheet.
3. Keep **Live Preview** inside Offer scoring rather than as a peer rule; it is a validation tool for those thresholds.
4. Merge **Verdict thresholds**, **Offer guard**, and **Delivery rules** into one focused **Offer scoring** flow with a mode switch for rides versus deliveries.
5. Keep **Watched apps** separate because it controls data sources, not scoring.
6. Keep **Voice announcements** separate because it controls output behavior.

That produces three mental models instead of six similar accordions:

```text
Offer scoring: verdict thresholds + minimum offer + pickup distance + delivery rate + preview
Apps: watched platforms and selection limit
Voice alerts: enabled verdicts + interval + audio previews
```

**Specific UI improvements**

- Show only one expanded accordion at a time if the single-page model is retained.
- Move unit selection (`$/km`, `$/hr`) beside the section title and clarify whether it switches the scoring basis or only the displayed unit.
- Avoid relying on green/red alone; retain the GOOD/BAD text and add distinct icons or shapes.
- Sliders with minus/plus buttons are understandable but imprecise. Show a tappable value field so users can enter an exact threshold.
- The vehicle icon sitting on the slider track is delightful but can be mistaken for the draggable handle. Make the actual interaction affordance unmistakable.
- “Relaxed / Balanced / Picky” is approachable, but explain that choosing one changes the numbers. Consider **More offers / Balanced / Higher value**, which describes the consequence instead of judging the driver.
- “Minimum offer” and “Offer guard” are overlapping names. Use **Minimum payout** for the value and **Pickup limit** for distance; call the combined feature **Offer guard** only at the parent level.
- “Delivery rules” should state whether delivery earnings are judged by distance or time. The summary currently changes between `CA$1.00/km` and `CA$30.00/hr`, which could look like a state bug unless the selected mode is explicit.
- “Beta · best effort” is honest but repeated on several rows. Put one short beta notice under the app list, then mark affected apps with a small **Beta** badge.

**Possible visual bug/state ambiguity**

- Watched Apps appears with different enabled combinations while the summary sometimes still lists `Uber · Hopp · Lyft`. Verify that the collapsed summary refreshes immediately and always reflects the current selection.
- The selection limit says “up to 3 apps”; ensure attempting a fourth provides immediate explanation rather than silently toggling another app off.

### 4. History (about 1:15–1:25)

**Strong**

- The empty state is visually warm and relevant to driving.
- “No offers yet” plus the go-live instruction explains why the page is empty.
- Filters include the right dimensions: date, app, verdict, accepted status, and minimum fare.
- Reset is available without dominating the page.

**Improve**

- The expanded filter becomes a large form inside the page and pushes the empty state down. Use a filter bottom sheet or dedicated filter screen, then show active filters as removable chips below the header.
- “Any fare” does not match “Filter by minimum fare.” Prefer **No minimum**.
- “Accepted” should be a proper filter with **Any / Accepted / Not accepted**, not a lone option among verdict chips.
- The scenic empty-state image is attractive but belongs to a different visual style from the 3D mascot/car art. Re-render or art-direct it in the same FoxyCo world.
- When no history exists, disable or hide **Export CSV** and **Clear offer history** instead of presenting actions that cannot do useful work.
- Once offers exist, add a compact summary above the list: reviewed, GOOD, accepted, and estimated hourly rate. This turns History into a learning tool rather than a log.

### 5. Settings overview and Profile (about 1:25–1:34)

**Strong**

- Categories are comprehensive and logically named.
- The account/access state is visible.
- Destructive actions use red and are separated from ordinary controls.

**Improve**

- Settings repeats the same accordion-card pattern as Rules, making it another long mega-page. Use standard list rows for navigation and reserve expansion for quick toggles only.
- The top-level order should follow frequency and urgency: **App health**, **Car**, **Appearance**, **Data**, **Account**, **Help**. Profile/account details do not need the first and largest position for a driver returning daily.
- “Lifetime unlocked” is unnatural. Use **Lifetime access** or **Lifetime plan — Active**.
- “Sign out of Google account” should be **Sign out**; the provider is already visible.
- “Google account used for your trial” appears alongside lifetime access. If both states can coexist, explain why; otherwise this looks contradictory.
- “Reset” at the top of Settings is too broad and risky. Rename it to the exact scope, such as **Reset preferences**, and confirm before applying.

### 6. Garage and Edit vehicle (about 1:34–1:47)

**Strong**

- The vehicle image makes configuration personal and easy to recognize.
- Fuel type uses quick segmented choices.
- Add vehicle and reminder are discoverable without crowding the overview.

**Bug/content issues to verify**

- The card displays **2026 Honda Honda**, and Edit vehicle shows both Make and Model as **Honda**. The model should be a model name (for example, CR-V), not the manufacturer.
- “SUV Comfort” appears to mix body style and ride-service category. Use a standard type such as **SUV**, unless “Comfort” materially changes calculations and is explained.
- The car artwork changes between two orange SUV renders during editing. Keep the selected vehicle image stable unless the field change intentionally changes it.
- “Plate · optional” is shown as a value-like tile. Use an input label (**Plate number (optional)**) and an empty placeholder instead.
- Delete is a small icon near the top edge. Give it a clear accessible label and require confirmation naming the vehicle.

**Improve**

- Make and Model should be searchable dependent fields: selecting Honda narrows valid models.
- Color and vehicle-type menus should not cover the Save action or make the current value hard to compare.
- Keep Save fixed above the safe area; enable it only after a change.

### 7. App health (about 1:47–1:57)

**Strong**

- Offer detection and outcome tracking expose important system state rather than hiding it.
- Pixel Capture is correctly framed as a fallback.
- “How detection works” and “How it works” provide nearby education.

**Improve**

- This is operationally important and should be easier to scan than ordinary preferences. Add a single status banner: **Ready**, **Action needed**, or **Limited**, followed by the one action required.
- Rows showing “No offers yet,” “Off,” and “Needs update” mix activity, configuration, and errors. Use explicit status badges and plain explanations.
- Replace the quoted technical phrase `“Needs update” means...` with direct copy: **If offer cards appear but FoxyCo cannot read them, update the app or enable Pixel Capture.**
- “Pixel Capture (OCR)” is technical. Lead with the outcome: **Screen reading fallback**, with **Uses OCR** as secondary text.

### 8. Look & Feel (about 1:57–2:06)

**Strong**

- Pill-size preview is excellent because users see the consequence immediately.
- Dark/Light/Auto, distance, currency, and number style are useful, concrete preferences.
- The three floating-bubble icon options reinforce brand personality.

**Improve**

- Rename **Money numbers** to **Number style**.
- Font samples such as Inter, Fraunces, and Space Grotesk change more than number formatting and may weaken product consistency. If only large monetary values change, label it **Amount font** and preview a full offer pill.
- “Daylight, windscreen glare” is helpful rationale for Light mode but visually reads like a stray note. Use concise helper copy below the entire theme control.
- Currency and units can default from locale but should remain independently editable, as shown.
- The expanded Appearance card is long enough to deserve its own screen.

### 9. Data, Help, About, FAQ, and diagnostics (about 2:06–2:14)

**Strong**

- Retention choices are plain and easy to scan.
- Export and deletion controls are visible.
- FAQ topics address trust-critical questions: tapping, permissions, storage, lock screen, trials, and troubleshooting.
- Diagnostic logs are available without occupying the normal user journey.

**FAQ structure improvement**

The About screen groups product description, how it works, trial/account questions, privacy, permissions, technical behavior, and troubleshooting into one very long accordion page. Break it into four sections or separate pages:

```text
Using FoxyCo
  What FoxyCo does, verdicts, pickup distance, History, lock screen

Access & billing
  Trial, lifetime access, sign-in, sign-out

Privacy & permissions
  Accessibility, Pixel Capture, stored data, data leaving the phone

Troubleshooting
  Missing/stuck pill, stopped mid-shift, unsupported apps, contact support
```

Add search only if the help content grows beyond this set; the current amount does not require it.

**Wording changes**

- **What does FoxyCo do?** → keep.
- **Does it ever tap for me?** → **Can FoxyCo tap or accept offers for me?**
- **Where do good / ok / bad come from?** → **How are GOOD, OK, and BAD decided?**
- **Is FoxyCo made by a gig platform?** → **Is FoxyCo affiliated with Uber, Lyft, or another platform?**
- **Does the bubble show on my lock screen?** → keep, if this is a frequent concern.
- **How does History know I took an offer?** → **How does FoxyCo detect accepted offers?**
- **What is the pickup distance for?** → **How does pickup distance affect a verdict?**
- **What does signing in do?** → **Why sign in with Google?**
- **What happens if I sign out?** → keep.
- **Does offer data leave my phone?** → keep; this is strong trust language.
- **The pill never appears** → **The offer pill does not appear**.
- **It worked, then stopped mid-shift** → keep.
- **One app scores but another never does** → **FoxyCo works in one app but not another**.
- **The pill stays up after I leave the gig app** → **The offer pill stays visible after I leave the app**.
- **How do I get rid of the bubble?** → **Hide or turn off the floating bubble**.
- **Something else is wrong** → **Contact support**.

**Improve**

- Move About/version/legal information below Help; it should not be the container for the entire knowledge base.
- Rename **About FoxyCo** to **Help & About** if it continues to contain FAQs.
- Keep Diagnostics one level deeper under Help and add **Copy**, **Share**, and **Clear** labels/tooltips to the icon actions. Raw logs are not suitable for most users without a “Send with feedback” path.
- Before **Clear offer history**, state that the action cannot be undone and whether exported files remain.

## Cross-app visual assessment

### What feels strong and unique

- The mascot/car pairing is recognizable and owns a clear “driver copilot” space.
- GOOD/OK/BAD is faster to understand than a generic numeric score.
- The offer pill preview connects abstract rules to an on-road outcome.
- Warm cream surfaces make the product feel calmer than typical gig-driver tools.
- Red is used as an active brand color while green remains meaningful for positive verdicts.
- The UI consistently keeps core navigation in the thumb zone.

### What currently feels too similar

- Nearly every object is a white rounded card with a pastel square icon, title, subtitle, and chevron.
- Rules, Settings, FAQ, and filters all use expansion as the primary interaction.
- Large corner radii, shadows, and card nesting reduce the visual distinction between navigation, controls, summaries, and explanations.

Use fewer card types:

1. **Navigation row** — flat row with chevron; opens a focused screen.
2. **Status card** — colored or bordered summary for live/app-health state.
3. **Control group** — one surface containing related toggles or segmented controls.
4. **Content card** — tips, empty states, and education only.

Do not put every row in its own floating card. Section dividers and whitespace will make Settings lighter and easier to scan.

## Card merge/break recommendations

| Current area | Change | Reason |
|---|---|---|
| Verdict thresholds + Offer guard + Delivery rules + Live preview | Merge under **Offer scoring**, then use focused sub-sections | These all answer “How is an offer judged?” |
| Watched apps | Keep separate | It controls sources, not scoring |
| Voice announcements | Keep separate | It controls output and has its own previews |
| Profile + access/trial copy | Merge into **Account** | Avoid duplicate account state and contradictory labels |
| Garage + reminders | Keep together | Reminders belong to a vehicle |
| Offer detection + Pixel Capture | Merge under **Offer detection** | Pixel Capture is a fallback mode of detection |
| Outcome tracking | Keep separate | It is a different capability and permission story |
| Pill size + text size + appearance | Merge into a dedicated **Appearance** screen | They share a live visual preview |
| History retention + export + clear | Keep together under **History & data** | Same data lifecycle |
| About + FAQ + troubleshooting | Break into Help categories | Current page combines unrelated intents |

## Priority changes

### P0 — fix before polish

1. Correct the duplicated vehicle make/model (`Honda Honda`) and verify the underlying field mapping.
2. Verify Watched Apps summaries update immediately and the three-app limit behaves transparently.
3. Resolve the apparent **Lifetime access** versus **trial** account-state contradiction.
4. Ensure the selected vehicle artwork does not unexpectedly change during editing.
5. Confirm all destructive actions have explicit scope and confirmation.

### P1 — highest UX return

1. Replace long Rules and Settings accordion mega-pages with overview rows leading to focused screens.
2. Consolidate scoring controls into one Offer Scoring flow with Live Preview inside it.
3. Turn App Health into a status-first screen with one clear next action.
4. Move History filters into a bottom sheet and surface active filters as chips.
5. Reorganize FAQ into Using FoxyCo, Access & billing, Privacy & permissions, and Troubleshooting.
6. Normalize terminology: offer reviewed, minimum payout, pickup limit, lifetime access, number style.

### P2 — visual/content polish

1. Standardize the illustration style across splash, home, tips, vehicle, and History empty states.
2. Reduce card/shadow repetition and introduce flat navigation rows.
3. Tighten Tip copy and control the neighboring-card peek.
4. Improve exact-value entry and accessibility cues for sliders.
5. Refine splash loading/fade behavior.

## New ideas worth implementing

Keep these small and tied to the core job:

1. **Rule impact preview:** while a threshold changes, show how many recent offers would have moved between GOOD, OK, and BAD. Only show this after enough History exists.
2. **Shift readiness check:** one compact Home status before going live—watched apps, overlay permission, announcements, and detection are ready; tap only when action is needed.
3. **Post-shift insight:** after ending a shift, show one useful observation such as “Pickup distance filtered out 4 low-value offers.” This creates a strong ending without adding a full analytics system.
4. **Preset explanation:** when selecting More offers/Balanced/Higher value, preview the changed thresholds before applying.
5. **Contextual help:** link rule labels directly to the relevant FAQ answer instead of making users search a separate long page.

Avoid adding more dashboard cards or a new navigation tab. The current four-tab foundation is enough; the value will come from clearer grouping and stronger state feedback.

## Suggested target flow

```text
Home
  Start/end shift
  Readiness only when action is needed
  Current shift summary
  Last shift / post-shift insight
  One concise tip

Rules
  Offer scoring -> thresholds, guards, delivery mode, live preview
  Watched apps -> selection and support status
  Voice alerts -> verdicts, interval, previews

History
  Summary
  Active filter chips -> filter sheet
  Offer list or purposeful empty state

Settings
  App health -> readiness and fixes
  Garage -> vehicle and reminders
  Appearance -> bubble, type, theme, units, currency
  History & data -> retention, export, clear
  Account -> identity and access
  Help -> FAQs, troubleshooting, feedback, diagnostics
  About -> version, legal, affiliations
```

## Bottom line

The app is visually cohesive, memorable, and already communicates its core purpose well. Home is the strongest screen, and Live Preview is the strongest product-specific interaction. The next improvement should not be more features or more cards: it should be clearer grouping, fewer nested accordions, consistent language, and focused detail screens. Fix the few visible state/data inconsistencies first, then simplify Rules, Settings, and Help around the user’s actual questions.
