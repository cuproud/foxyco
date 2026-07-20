# FoxyCo — Google Play Release & Monetization Guide

**Audience:** first-time Play Store publisher. Written 2026-07-20.
**Companion docs:** `AUDIT.md` (policy risks + release checklist), `MANUAL_TESTS.md` (device test matrix).

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
| Trial = drivers feel the value during real shifts before paying | Needs Play Billing integration (~1–2 days work, see §5) |
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

- Launch promo: first month at **$7.99** ("founding driver price") — Play lets you schedule price changes; scarcity converts trial users sitting on the fence.
- Worked example at $12.99: 100 unlocks/mo → $1,299 gross → ~$1,104 after Google's 15% → minus ~your income tax. 1,000 trials at a typical 5–10% trial→paid conversion = 50–100 unlocks.
- Set prices per-country with Play's "price template" auto-conversion, then round weird amounts (₹999, not ₹1,067).

---

## 3. First-publish walkthrough (what actually happens)

1. **Developer account** — play.google.com/console, one-time $25, ID verification takes 1–3 days. Individual account is fine to start.
2. **Merchant profile** — required to charge money (Option A or B). Payments profile + bank account + tax forms (W-8/W-9 or local equivalent). Do this early; verification can take days.
3. **Create app** in Console → fill the forms:
   - **Store listing:** title (30 chars), short desc (80), full desc (4000), screenshots (min 2, take from the new showroom UI — splash ignition, home hero, pill over a fake offer), feature graphic 1024×500.
   - **Privacy policy URL** — mandatory. One static page: "FoxyCo stores everything on-device, collects nothing, no network permission." Host on GitHub Pages, free.
   - **Data safety form** — declare: no data collected, no data shared. TRUE for us (verified in AUDIT.md — no INTERNET permission).
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
     - Use ONE Google Group as tester list — adding a tester = adding to the
       group, no new build/review.
     - No penalty for falling short — production just stays locked; app can
       sit in closed testing indefinitely. Failure mode is purely lost days.
       Rejection at the questionnaire has no cooldown; fix and reapply.
     - Budget ~3 weeks total: recruit → 14 clean days → questionnaire →
       review (1–3 days). Billing code (~2 days) fits inside the wait.
   - *Production* — after the 14-day gate, promote the same build.
7. **Review time** — first submission: 1–7 days (accessibility apps often get the longer end + questions). Updates after: hours–2 days.

---

## 4. The 7-day welcome trial — how we build it (design sketch)

No server. Trial state lives on-device; purchase state lives with Play (source of truth, survives reinstall).

```
first launch  → store trialStart = now (SharedPreferences, same pattern as OnboardingGate)
every launch  → entitled = purchased || (now - trialStart) < 7 days
day 5–6       → soft banner on Home: "Founding driver price ends soon — 2 days left"
day 7+        → watching still ALLOWED to start, but pill shows "🦊 unlock" instead of
                verdicts; Home hero shows the paywall card with the one-time price
purchase      → Play Billing non-consumable "foxyco.lifetime" → everything on, forever
reinstall     → "Restore purchase" button queries Play → entitled again
```

Honest limitation, decided up front: a determined user can clear app data to reset the 7 days. Accept it — the people who do that were never buying, and fighting it needs a server + accounts + privacy policy rewrite. Not worth destroying "100% offline" over.

**Code needed (future task, ~1–2 days):**
- `in_app_purchase` package (first-party Flutter, BSD-3 — license-clean)
- `TrialGate` service mirroring `OnboardingGate`
- Paywall card + "Restore purchase" in Settings
- Pill "locked" state in the overlay isolate
- NOTE: billing runs through the Play Store app — FoxyCo itself still needs **no INTERNET permission**. Offline story survives.

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
   flag missing/stale (second patch site for crackers, no new channel).

### 4b. Anti-piracy — decided approach (bar-raiser, not DRM)

No server; keep the no-INTERNET story. Three layers:

1. **Signature-verified purchase (highest value).** Play Billing returns
   purchase JSON + RSA signature; the app's Base64 public key from Play
   Console is embedded and verified LOCALLY. Fake-purchase-store patches
   ("lucky patcher") fail signature. Works offline forever.
2. **Random re-verification.** Every launch: if 1-in-5 roll OR cached
   entitlement older than 7 days → re-query Billing, re-verify signature,
   refresh cache. A patch that removes the launch check still re-locks days
   later. Cache in SharedPreferences next to trial state.
3. **Tamper frictions (free).** R8 obfuscation already on; give the
   entitlement class a boring name (crackers grep for `Purchase*`);
   packageName + signing-cert sanity check at boot (resigned repacks
   quietly stay locked); duplicate check in the overlay isolate (see 4a).

**Deliberately NOT doing:** Play Integrity API (verdicts need server-side
decryption — breaks offline), root/emulator detection, online activation.
Hostile to legit users; pirates strip them first anyway. Pirate users ≈
people who'd never pay; layers 1–3 cost half a day inside the billing task
and beat what most paid apps ship.

### 4c. Testers at production launch

- Closed track survives production promotion; testers keep the app and update
  normally — no reinstall, nothing breaks.
- Their on-device trials started at THEIR first launch — most expired by
  launch day; they hit the paywall like everyone.
- During testing, add tester Gmails to Play Console → **License testing** —
  they see the real purchase dialog, test card, no charge. Remove them after
  launch; license-test "purchases" aren't real entitlements owed.
- Thank-you option: Play **promo codes** for the unlock product — generate
  free codes, hand to testers.

---

## 5. Launch-week playbook (the "welcome trail")

| Day | Action |
|---|---|
| T-14 | Start the mandatory closed test (12+ testers). Fix what they find. |
| T-3 | Freeze build, promote to production review, prepare screenshots + 30s screen-recording |
| Day 0 | Production live at $7.99 founding price. Post in r/uberdrivers, r/couriersofreddit, local driver Facebook/WhatsApp groups — with the trial pitch, not the price pitch |
| Day 1–7 | Watch Play Console → Ratings + ANRs/crashes daily. Reply to EVERY review (reviewers get notified, often revise stars) |
| Day 7 | First trial cohort hits the paywall — watch conversion % |
| Day 14–30 | Raise to $12.99. A/B the paywall copy (Play "store listing experiments" is free) |

---

## 6. Where the app stands today (honest inventory)

### Has ✅
- Live offer reading (Uber/Lyft/Hopp) via scoped read-only a11y service — device-verified
- Verdict pill + draggable bubble overlay, drop-to-dismiss, edge restore
- $/km and $/hr scoring, custom thresholds, pickup-distance guard
- Offer history with filters + parse-health self-diagnostics
- Showroom UI: photographic car hero (stealth↔reveal states), splash ignition, dark premium theme
- 100% offline, zero data collection, license-clean, R8 release build green
- 155 automated tests + manual device matrix (MANUAL_TESTS.md)

### Missing before charging money ❌
1. **Billing + trial gate + anti-piracy layers** (§4–4b) — the monetization code
2. **Play Console papers** (§3.3) — privacy page, forms, screenshots
3. **Upload keystore** — one manual command (AUDIT.md)
4. **Closed-test cohort** — 12 testers × 14 days, calendar-blocking (§3.6)
5. Real-shift battery numbers on a mid-range phone (AUDIT #4 measure)

### Nice-to-have, post-launch
- More platforms (DoorDash, Grubhub…) — each is a parser + package name
- Per-platform thresholds; shift earnings summary
- Localized store listings (ES/PT = big driver demographics)

---
_Last updated: 2026-07-20._
