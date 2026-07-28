# FoxyCo — Google Play Release & Monetization Guide

**Audience:** first-time Play Store publisher. Written 2026-07-20, annotated 2026-07-28.
**Companion docs:** `MONETIZATION_v1.0.md` (entitlement architecture — **authoritative**), `AUDIT.md` (policy risks + release checklist), `MANUAL_TESTS.md` (device test matrix).

> ## ⚠️ Superseded sections
>
> This guide was written against a **no-server, no-account, no-INTERNET**
> design. That design changed on 2026-07-27. `MONETIZATION_v1.0.md` now owns
> the entitlement architecture and **wins wherever the two disagree**.
>
> | Section | Status |
> |---|---|
> | §1 model (free + one-time unlock) | ✅ still current |
> | §2 pricing | ⚠️ **$7.99 founding promo dropped** — $12.99 flat from launch (MONETIZATION §2) |
> | §3 publish walkthrough | ⚠️ privacy policy + Data safety answers changed (see §3 notes) |
> | §4 trial design | ❌ **superseded** — trial lives in Firestore, not SharedPreferences |
> | §4a lock behavior | ✅ current (MONETIZATION §4 refines the overlay rule) |
> | §4b anti-piracy | ⚠️ layers unchanged, but "no INTERNET" is no longer true |
> | §4c testers | ✅ still current |
> | §5 launch playbook | ⚠️ price rows updated |
> | §6 inventory | ⚠️ refreshed |
>
> **The one change that drives all others:** the app now ships the `INTERNET`
> permission and a Google account sign-in for the trial. "100% offline"
> becomes "no offer data ever leaves your phone" — still true, since only
> auth and a trial timestamp cross the wire.

---

## 1. The two monetization models that fit FoxyCo

Google Play gives you two realistic ways to charge a one-time price. **You must pick one before the first upload** — it shapes the listing.

### Option A — Paid app (pay before download)

Buyer pays on the store page, then installs. Price shows on the listing button ("$9.99" instead of "Install").

| Pros | Cons |
|---|---|
| Zero code — no billing SDK, app stays fully offline | **No trial possible.** Google killed paid-app trials years ago |
| Simplest mental model | Huge install friction — unknown apps rarely sell blind |
| One-time forever | 15-min auto-refund window + 48h no-questions refunds |

### Option B — Free download + one-time in-app unlock ("freemium unlock") ← RECOMMENDED

App is free to install. Everyone gets a **7-day full-featured welcome trial**. When the trial ends, a one-time in-app purchase ("Lifetime unlock") turns everything back on, forever. This is NOT a subscription — a `non-consumable` in-app product is a single charge, owned permanently, restorable on any device signed into the same Google account.

| Pros | Cons |
|---|---|
| Trial = drivers feel the value during real shifts before paying | Needs Play Billing integration (see §4 and MONETIZATION §7) |
| "Free" listing button = 5–10× more installs than paid | Trial logic is ours to build (see §4) |
| One-time price, no subscription fatigue | Must handle "restore purchase" |

**Why B for FoxyCo:** the product's value ("it caught 3 bad offers tonight") is only visible during real driving. A week of live use sells it better than any screenshot.

---

## 2. Pricing — what number to put on it

### What Google takes

Google's service fee is **15% on the first $1M USD/year** (automatic once you enroll in the 15% program in Play Console — do this, it's a checkbox). You receive ~85% minus local taxes/FX.

### Comparable apps (driver-utility market)

| App type | Typical price |
|---|---|
| Mileage trackers (one-time tiers) | $5–10 |
| Gig dashboards / earnings analyzers | $4.99–14.99 one-time, or $3–8/mo subs |
| Niche pro tools with overlay/a11y magic | $10–25 one-time |

### Recommendation

**$12.99 one-time** (experiment range $9.99–14.99).

The math drivers do in their head: *"one avoided bad ride ≈ saved 30 dead minutes ≈ the app paid for itself."* Anchor the paywall copy to exactly that.

- ~~Launch promo: first month at **$7.99** ("founding driver price").~~
  **Dropped 2026-07-28** (MONETIZATION §2). A one-time unlock bought at $7.99
  is owned forever, so every early buyer is permanently capped at the low
  price; the trial already supplies the urgency; and raising the price inside
  the first month reads badly in reviews from the people who evangelized you.
  Play price-change scheduling stays available if launch conversion argues
  otherwise — flagged as an open decision in MONETIZATION §9.
- Worked example at $12.99: 100 unlocks/mo → $1,299 gross → ~$1,104 after Google's 15% → minus ~your income tax. 1,000 trials at a typical 5–10% trial→paid conversion = 50–100 unlocks.
- Set prices per-country with Play's "price template" auto-conversion, then round weird amounts (₹999, not ₹1,067).

---

## 3. First-publish walkthrough (what actually happens)

1. **Developer account** — play.google.com/console, one-time $25, ID verification takes 1–3 days. Individual account is fine to start.
2. **Merchant profile** — required to charge money (Option A or B). Payments profile + bank account + tax forms (W-8/W-9 or local equivalent). Do this early; verification can take days.
3. **Create app** in Console → fill the forms:
   - **Store listing:** title (30 chars), short desc (80), full desc (4000), screenshots (min 2, take from the new showroom UI — splash ignition, home hero, pill over a fake offer), feature graphic 1024×500.
   - **Privacy policy URL** — mandatory. Host on GitHub Pages, free.
     ⚠️ **Changed 2026-07-28.** The old text ("collects nothing, no network
     permission") is no longer true. Declare exactly: **Google account email**
     (trial identity) and **trial/purchase state**. No offer data, no
     location, no analytics. Must also state that a non-identifying record of
     the trial start date is retained after account deletion (MONETIZATION
     §5.1).
   - **Data safety form** — ⚠️ **Changed 2026-07-28.** No longer "no data
     collected". Declare **Account info (email)** and **App activity
     (trial/purchase state)**. Not location, not financial data — Play handles
     payment and we never see card data. `AUDIT.md` still verifies the old
     no-INTERNET claim and must be updated alongside (MONETIZATION §7 step 9).
   - **Account deletion** — required once you collect accounts: an in-app path
     AND a public web URL. See MONETIZATION §5.1 — the trial doc is
     deliberately retained, and the privacy policy has to say so.
   - **Accessibility declaration** — because we use an AccessibilityService, a special form asks WHY. Answer: "Reads ride-offer text from supported driver apps to display an on-screen earnings verdict. Core functionality; read-only; user-enabled with in-app disclosure." Expect possible human review + a request for a screen-recording of the consent flow (our onboarding IS that flow — record it).
   - **Content rating questionnaire** → "Everyone".
   - **Target audience** → 18+ (drivers).
4. **Signing** — generate upload keystore (command in AUDIT.md §blockers), enroll in **Play App Signing** (Google keeps the app signing key, you keep the upload key — lose-proof).
5. **Build** — `flutter build appbundle` (NOT apk — Play requires .aab; also drops install size from ~60MB to ~25MB per device).
6. **Testing tracks — use them in this order:**
   - *Internal testing* (you + up to 100 testers, live in minutes) — your real-shift testing happens here.
   - *Closed testing* — **new personal accounts must run a closed test with
     ≥12 opted-in testers CONCURRENTLY for 14 consecutive days before
     production access.** Recruit driver friends/subreddit. Plan for this —
     it is the real launch gate.

     **Tester math + recruiting (decided):**
     - 12 = opted-in simultaneously; drop below 12 → the 14-day clock pauses.
       Over-recruit to 16–20 so dropouts don't stall it.
     - Ghost testers risk rejection at the production questionnaire — ping
       testers twice in the window ("open it once this week").
     - Sources, easiest first: personal circle (demo pill works for
       non-drivers) → driver subreddits/WhatsApp/Facebook groups (also future
       buyers) → tester-swap communities (r/AndroidClosedTesting etc., fast
       filler, zero real feedback) → Baltics driver groups (exercise the Hopp
       parser for real).
     - **Cap enrollment at 20–30** (see §4c) — over the 12 floor, under
       chaos; private opt-in link only.
     - Use ONE Google Group as tester list — adding a tester = adding to the
       group, no new build/review.
     - No penalty for falling short — production just stays locked; app can
       sit in closed testing indefinitely. Failure mode is purely lost days.
       Rejection at the questionnaire has no cooldown; fix and reapply.
     - Budget ~3 weeks total: recruit → 14 clean days → questionnaire →
       review (1–3 days). Monetization code (~5–6 days now that Firebase is
       in scope — MONETIZATION §7) still fits inside the wait.
     - **Start the $25 account registration before the code is ready.** ID
       verification takes 1–3 days and the 14-day tester clock cannot start
       until the account exists. That is calendar time, not work time.
   - *Production* — after the 14-day gate, promote the same build.
7. **Review time** — first submission: 1–7 days (accessibility apps often get the longer end + questions). Updates after: hours–2 days.

---

## 4. The 7-day welcome trial — ❌ SUPERSEDED

> **This section is kept for history only. The live design is
> `MONETIZATION_v1.0.md` §3.** Read that instead. What follows is the
> 2026-07-20 sketch and the reasoning that was overturned.

### What changed and why

The sketch below stored `trialStart` in SharedPreferences. That resets on
"Clear app data", so the trial was refillable in about ten seconds, forever.
On 2026-07-27 that was judged the larger cost and the trial moved to
Firestore with write-once security rules and Google's server clock.

Consequences, all of which ripple through this guide:

| Old (this section) | New (MONETIZATION §3) |
|---|---|
| No accounts | Anonymous Firebase Auth, upgraded to Google Sign-In when the trial starts |
| No INTERNET permission | `INTERNET` required |
| "100% offline, collects nothing" | "No offer data ever leaves your phone" |
| Data safety: nothing collected | Account email + app activity |
| No account-deletion obligation | In-app + web deletion path required |
| Trial resettable by clearing data | Trial permanent per Google account |
| ~1–2 days of work | ~5–6 days |

### The superseded sketch (historical)

```
first launch  → store trialStart = now (SharedPreferences, same pattern as OnboardingGate)
every launch  → entitled = purchased || (now - trialStart) < 7 days
day 5–6       → soft banner on Home: "Founding driver price ends soon — 2 days left"
day 7+        → watching still ALLOWED to start, but pill shows "🦊 unlock" instead of
                verdicts; Home hero shows the paywall card with the one-time price
purchase      → Play Billing non-consumable "foxyco.lifetime" → everything on, forever
reinstall     → "Restore purchase" button queries Play → entitled again
```

~~Honest limitation, decided up front: a determined user can clear app data to
reset the 7 days. Accept it — the people who do that were never buying, and
fighting it needs a server + accounts + privacy policy rewrite. Not worth
destroying "100% offline" over.~~

**↑ Reversed 2026-07-27.** The server + accounts + privacy policy rewrite is
exactly what was chosen. See MONETIZATION §3.3.

**Still accurate from the original code list:**
- `in_app_purchase` package (first-party Flutter, BSD-3 — license-clean) —
  ✅ implemented 2026-07-28, `lib/services/billing/`
- Paywall card + "Restore purchase" in Settings — still to build
- Pill "locked" state in the overlay isolate — still to build

**No longer accurate:**
- ~~`TrialGate` service mirroring `OnboardingGate`~~ — `TrialGate` still
  exists by name but reads Firestore, not SharedPreferences (it caches
  locally with a 7-day offline grace window).
- ~~FoxyCo itself still needs **no INTERNET permission**. Offline story
  survives.~~ — false now. Billing alone would indeed have needed no
  INTERNET (it proxies through the Play Store app), but Firebase does.

### 4a. What locks when the trial ends (decided)

**Stays free forever** (goodwill + demo value): app opens, Home, Settings,
offer history, demo pill.

**Locked** (the actual value): live watching still STARTS, but the pill
renders "🦊 Unlock" instead of verdict/numbers; tapping it opens the paywall.
Rationale: the driver sees the pill working during a real offer and can't
read the verdict — frustration at the exact moment of value converts better
than blocking go-live outright.

Enforcement points (both isolates):
1. Main isolate — `entitlementProvider` gates overlay payload building.
2. Overlay isolate — the payload carries an `entitled` flag; pill widget
   branches locked/unlocked. Overlay independently rejects payloads with the
   flag missing (second patch site for crackers, no new channel).

> "Missing/stale" is defined concretely in MONETIZATION §4: the overlay
> isolate has no clock it trusts, so the only rule is **`entitled` absent or
> not `true` renders the locked pill**. A patch that strips the flag produces
> a locked pill, not an unlocked one.

### 4b. Anti-piracy — decided approach (bar-raiser, not DRM)

⚠️ **"No server; keep the no-INTERNET story" no longer holds** — Firebase
brought both. The three layers below are unchanged and still current
(MONETIZATION §3.7); only the framing was wrong. They remain worth doing
because they work offline and need no backend of ours.

Three layers:

1. **Signature-verified purchase (highest value).** Play Billing returns
   purchase JSON + RSA signature; the app's Base64 public key from Play
   Console is verified LOCALLY. Fake-purchase-store patches ("lucky patcher")
   fail signature. Works offline forever. ✅ implemented 2026-07-28
   (`lib/services/billing/purchase_verifier.dart`). The key is injected with
   `--dart-define=PLAY_PUBLIC_KEY=...` rather than hardcoded, and verification
   **denies everything when the key is absent** (MONETIZATION §3.9).
2. **Random re-verification.** Every launch: if 1-in-5 roll OR cached
   entitlement older than 7 days → re-query Billing, re-verify signature,
   refresh cache. A patch that removes the launch check still re-locks days
   later. Cache in SharedPreferences — the *entitlement verdict* is cached
   there, but the trial start itself now lives in Firestore.
3. **Tamper frictions (free).** R8 obfuscation already on; give the
   entitlement class a boring name (crackers grep for `Purchase*`);
   packageName + signing-cert sanity check at boot (resigned repacks
   quietly stay locked); duplicate check in the overlay isolate (see 4a).

**Deliberately NOT doing:** Play Integrity API (verdicts need server-side
decryption — breaks offline), root/emulator detection, online activation.
Hostile to legit users; pirates strip them first anyway. Pirate users ≈
people who'd never pay; layers 1–3 cost half a day inside the billing task
and beat what most paid apps ship.

### 4c. Testers at production launch — nobody keeps it free (decided)

**Tester cap: 20–30.** Play has no "limit reached" banner; the cap IS the
email list / Google Group — stop adding past 30, outsiders simply can't
access the listing. Keep the opt-in link private (DM only). 20–30 sits
comfortably above the 12-concurrent floor and stays manageable.

**Three layers guarantee no permanent free copies:**

1. **Trial gate applies to testers too.** 7 days from when THEY start the
   trial, recorded in Firestore against their Google account — most tester
   trials expire mid-window, so they test the paywall for real before launch.
   A tester who reinstalls does not get a fresh 7 days (MONETIZATION §3.4.1).
2. **License testing is temporary by design.** During the test window,
   tester Gmails go on Play Console → License testing so they can exercise
   the purchase flow (real dialog, test card, no charge). **At production
   launch: clear the list → their test "purchases" vanish → locked → they
   pay like everyone.** License-test purchases are not real entitlements.
3. **Build kill-date (belt-and-suspenders).** Closed-track builds bake in a
   drop-dead date: `now > buildExpiry → paywall regardless of trial state`.
   One const + one check inside the billing task.

Closed track survives production promotion — testers keep the app installed
and update normally; the layers above decide what they can USE, not whether
the app runs.

Only deliberate exception, if ever: Play **promo codes** for the unlock —
your call per person, never automatic.

---

## 5. Launch-week playbook (the "welcome trail")

| Day | Action |
|---|---|
| T-14 | Start the mandatory closed test (12+ testers). Fix what they find. |
| T-3 | Freeze build, promote to production review, prepare screenshots + 30s screen-recording |
| Day 0 | Production live at **$12.99** (founding promo dropped — see §2). Post in r/uberdrivers, r/couriersofreddit, local driver Facebook/WhatsApp groups — with the trial pitch, not the price pitch |
| Day 1–7 | Watch Play Console → Ratings + ANRs/crashes daily. Reply to EVERY review (reviewers get notified, often revise stars) |
| Day 3 | **Confirm no purchases are auto-refunding.** Unacknowledged purchases reverse silently at 72h (MONETIZATION §3.8) — day 0 buyers are the first cohort that can expose the bug |
| Day 7 | First trial cohort hits the paywall — watch conversion % |
| Day 14–30 | A/B the paywall copy (Play "store listing experiments" is free). Price stays $12.99 unless conversion data argues otherwise |

---

## 6. Where the app stands today (honest inventory)

### Has ✅
- Live offer reading (Uber/Lyft/Hopp) via scoped read-only a11y service — device-verified
- Verdict pill + draggable bubble overlay, drop-to-dismiss, edge restore
- $/km and $/hr scoring, custom thresholds, pickup-distance guard
- Offer history with filters + parse-health self-diagnostics
- Showroom UI: photographic car hero (stealth↔reveal states), splash ignition, dark premium theme
- Zero offer-data collection, license-clean, R8 release build green
  (⚠️ was "100% offline" — Firebase adds `INTERNET`; no offer data crosses
  the wire, only auth + a trial timestamp)
- 217 automated tests + manual device matrix (MANUAL_TESTS.md)
- Play Billing: signature verification + acknowledgment
  (`lib/services/billing/`, added 2026-07-28)

### Missing before charging money ❌

Full breakdown with estimates and blockers: **MONETIZATION §7**.

1. **Play Console account** — $25 one-time, ID verification 1–3 days (§3 step
   1). Blocks the product setup, the licensing key, any real purchase test,
   and the 14-day tester clock. **Start this first — it is calendar time.**
2. **Firebase project + Google Sign-In + Firestore trial** (MONETIZATION
   §3.3–3.4.1) — free tier, no card, not blocked by the Play account
3. **`entitlementProvider` + paywall UI + locked pill** (§4a) — not blocked
4. **`foxyco.lifetime` product + licensing key** — blocked on item 1
5. **Anti-piracy layers 2 and 3** (§4b) — layer 1 is done
6. **Play Console papers** (§3 step 3) — privacy page, Data safety, account
   deletion URL, screenshots
7. **Upload keystore** — one manual command (AUDIT.md)
8. **Two SHA-1 registrations in Firebase** — upload key (before any sign-in
   testing) and Play App Signing key (only exists after the first upload).
   Missing the second means sign-in works in debug and fails in production.
9. **Closed-test cohort** — 12 testers × 14 days, calendar-blocking (§3 step 6)
10. **`AUDIT.md` update** — it currently verifies a no-INTERNET claim that is
    no longer true
11. Real-shift battery numbers on a mid-range phone (AUDIT #4 measure)

### Nice-to-have, post-launch
- More platforms (DoorDash, Grubhub…) — each is a parser + package name
- Per-platform thresholds; shift earnings summary
- Localized store listings (ES/PT = big driver demographics)

---
_Last updated: 2026-07-28 — annotated for the Firestore-trial decision.
Entitlement architecture lives in `MONETIZATION_v1.0.md`._
