# FoxyCo — Google Play Release & Monetization Guide

**Audience:** first-time Play Store publisher. Written 2026-07-20, updated 2026-08-21.
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
> | §2 pricing | ✅ CA$24.99 Canada / US$17.99 US lifetime (MONETIZATION §2) |
> | §3 publish walkthrough | ⚠️ privacy policy + Data safety answers changed (see §3 notes) |
> | §4 trial design | ❌ **superseded** — trial lives in Firestore, not SharedPreferences |
> | §4a lock behavior | ✅ current (MONETIZATION §4 refines the overlay rule) |
> | §4b anti-piracy | ⚠️ layers unchanged, but "no INTERNET" is no longer true |
> | §4c testers | ✅ still current |
> | §5 launch playbook | ⚠️ price rows updated |
> | §6 inventory | ⚠️ refreshed |
>
> **Start at §0** — it is the ordered runbook for getting into closed testing.
> The sections below are the reasoning behind it.
>
> **The one change that drives all others:** the app now ships the `INTERNET`
> permission and a Google account sign-in for the trial. "100% offline"
> becomes "no offer data ever leaves your phone" — still true, since only
> auth and a trial timestamp cross the wire.

---

## 0. Closed-test runbook — do this now

_Added 2026-08-02. §1–§6 are the reasoning; this is the ordered list of moves.
Everything below is a console/web action except C1. Build 22 was Play-installed
and device-tested; current release bundle is `1.0.10+67`. See
`HANDOFF_2026-08-21_TOUR_FIXES.md` for current verification and remaining
delivery gates; older handoffs remain historical records._

### Phase A — no Play Console needed, do it today

| # | Do | Where |
|---|---|---|
| A1 | ✅ **Done 2026-08-02.** Legal pages are live on GitHub Pages (`main`, `/docs`) and return 200:<br>`https://cuproud.github.io/foxyco/` (landing)<br>`https://cuproud.github.io/foxyco/legal/privacy.html`<br>`https://cuproud.github.io/foxyco/legal/terms.html`<br>`https://cuproud.github.io/foxyco/legal/delete-account.html`<br>Those exact URLs are compiled into `lib/ui/legal/legal_links.dart` — host them elsewhere and that file must change too. **Pages serves `main`, so legal edits on a feature branch are invisible until merged.** `docs/_config.yml` excludes `superpowers/`: a Liquid brace in one plan transcript fails the Jekyll build, which 404s the whole site. | github.com |
| A2 | ✅ **Done on device 2026-08-04.** The ignored local `google-services.json` contains upload/debug clients, the web client and actual Play App Signing SHA-1 `CC:8B:F7:D5:53:81:CF:57:70:98:38:48:13:5A:2E:08:56:4C:88:DC`. The earlier `5C:38:…` fingerprint was wrong and caused `google-sign-in/sign_in_failed`; the refreshed Firebase configuration restored the trial successfully. | console.firebase.google.com |
| A3 | ✅ **Done 2026-08-02.** Publisher name and contact address in `docs/legal/*.md` are now **Vamsi Naradasu / foxyco.dev@gmail.com**. The publisher name must keep matching the Play Console developer name. | this repo |
| A4 | **OAuth consent screen** (Google Cloud → Google Auth Platform → **Branding**), needed because the trial signs in with Google:<br>Application home page → `https://cuproud.github.io/foxyco/`<br>Privacy policy link → `.../legal/privacy.html`<br>Terms of service link → `.../legal/terms.html`<br>Authorized domain 1 → `cuproud.github.io`<br><br>**Do not upload a logo, and ignore "Verify branding."** Uploading a custom logo is what *triggers* the verification requirement; with no logo and non-sensitive scopes only, Google asks for nothing. A verification attempt on 2026-08-02 was refused with "home page is not registered to you" — `cuproud.github.io` belongs to GitHub, so satisfying it needs a Search Console URL-prefix property (and the other two refusal reasons, "no purpose stated" and "name mismatch", were artefacts of Google fetching the page while Pages was still 404). Not worth it for a logo on one dialog.<br><br>⚠️ **Do set Audience → Publishing status to "In production".** FoxyCo requests only `openid`/`email`/`profile` (`trial_store.dart` calls `GoogleSignIn.instance.authenticate()` with no custom scopes), which are non-sensitive, so production needs **no Google review**. Left in **"Testing"**, only 100 hand-added users can sign in and their refresh tokens expire after 7 days — that silently breaks the trial for closed testers. | console.cloud.google.com |
| A5 | **Record the accessibility consent video** (30–60s screen recording): open FoxyCo → onboarding disclosure screen → enable the service → an offer gets scored. Play asks for it, often after submission; having it ready saves a review round-trip. | phone |

### Phase B — Play Console (blocks everything after it)

1. Confirm **ID verification** finished on the $25 account, and the **payments/merchant profile** is set up (needed to sell `foxyco.lifetime`).
2. **Create the app** → package `com.foxyco.app`, free, "app".
3. **Store listing** — title (30), short desc (80), full desc (4000), ≥2 phone screenshots, feature graphic 1024×500. Copy angles in §5.
4. **Privacy policy URL** → the A1 privacy link. **App content → Data deletion** → the A1 delete-account link.
5. **Data safety form** — declare **Account info (email)** and **App activity (trial/purchase state)**. Not location, not financial. See §3 for the exact wording and why the old "collects nothing" answer is now wrong.
6. **Accessibility declaration** — answer with the §3 step 3 text; attach the A5 video if asked.
7. **Content rating** → Everyone. **Target audience** → 18+.
8. **Monetization setup** → copy the **licensing key** (base64 RSA blob). This is the `PLAY_PUBLIC_KEY` for C1.
9. **Products → In-app products** → create `foxyco.lifetime`, **non-consumable**. Set **CA$24.99** in Canada and **US$17.99** in the United States, then activate it.

### Phase C — build and upload

Use the repository build helper so the build code and About label stay in
sync. Install the rules-test tools once with `npm install`. `--bump` increments
the build code only after analysis, the full Flutter suite, and Firestore rules
tests pass; `apk` is optional for an explicit release APK. Every AAB build runs
the same preflight and requires the Play public key:

```bash
./scripts/build.sh aab --bump
./scripts/build.sh apk # optional phone-installable APK at the same version
```

Artifacts are copied to `dist/` with version and timestamped names.

Latest repository-verified bundle (delivery beta still needs live-device verification):

```text
dist/FoxyCo-v1.0.10+67-release-20260821-1339.aab
86,152,711 bytes
SHA-256 f714b94172cd61108852b7ddf3741af929c34999bc290a7ff5eb55cb68147a71
```

The build helper completed dependency resolution, static analysis, all 494
Flutter tests, Firestore rules tests and the signed release bundle. Build 67
selects the topmost offer window across stacked Uber Radar and cross-app cards,
clears stale verdicts when that top card is incomplete, and parses an opened
Lyft Reserve detail without merging scheduled-list cards. History filters now
always expose Uber, Hopp, Lyft, DoorDash, Instacart and Skip. It also applies the
tour's Rules, Settings, Help and vehicle wording/validation improvements.

The licensing key is an RSA **public** key. It is extractable from any shipped
APK, so recording it here costs nothing and makes the build reproducible:

```bash
flutter build appbundle --dart-define=PLAY_PUBLIC_KEY=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqTpiV2mIQJeDVeoIRmabFXEFHtfr1lPWYV56M3GX/fR4D3gqG7YpPRYVKN5JoOB4Pv8qS2Q8VKEv1FGXQODLUxWvhDWSxev0WBHfHUwPS2ZlBbNm+U2dd/Gx9Wf9dvhHZku0oP2hvacWEhHR0Q6Q4Q7TJUxuXoPtkayM6aeagFL7pmw1wUNVKeVyHX9CufKTJdjc48++BACM712kUc5CHpwCcRO5E+MhG9bt0vwWJizNrvNG9iREzPHeMgsaQX5Oeco+sWyC1b5okHiYkmmZMG1Z8S9fqnM8bw90HoA/8EnNkbt/+ZMo4E0D/jzor8RpF+gtTFGMAkzXQilW1OaJqQIDAQAB
# → build/app/outputs/bundle/release/app-release.aab
```

✅ **Built and verified 2026-08-02** — `1.0.0+6`, 66.6 MB, signed by the upload
key (`SHA1: 8E:FB:79:…:32:49`), licensing key confirmed present in the AOT
snapshot. Ready to upload.

Confirm any future bundle actually carries the key before uploading:

```bash
unzip -qo build/app/outputs/bundle/release/app-release.aab 'base/lib/arm64-v8a/*' -d /tmp/aabchk
grep -qa qTpiV2mIQJeDVeoIRmab /tmp/aabchk/base/lib/arm64-v8a/ -r && echo "key present"
```

⚠️ **Do not upload a bundle built without the key.** `PurchaseVerifier`
fails closed: no key compiled in → every receipt is rejected → a real payment
grants nothing. The trial still works, so the bug is invisible until someone
pays. The helper updates `pubspec.yaml` and the About label together, then
bumps the version code before each re-upload — Play rejects duplicate codes.

Then:

1. Upload to **Internal testing** first (live in minutes, just you). Install, run one shift, confirm sign-in works on the *signed* build — that is what A2 protects.
2. Reconfirm the APK installed by Play is signed with the A2 SHA-1. Any Play
   signing-key rotation requires adding the new fingerprint in Firebase and
   downloading a fresh local `google-services.json` before rebuilding.
3. Promote the same bundle to **Closed testing**.

### Phase D — the 14-day tester gate (your Facebook/Reddit plan)

**How Play actually gates it:** a closed tester must be *on your tester list*
before the opt-in link works for them. So the link you post publicly cannot be
the opt-in link alone. Use a self-serve Google Group as the list — then you
never collect or paste a single email address by hand.

1. **groups.google.com → Create group.** Name `FoxyCo Testers`, address e.g. `foxyco-testers@googlegroups.com`. Settings: **Who can join → Anyone on the web can join**, **Who can post → Only owners** (it is a list, not a forum), and turn off the welcome email if you like.
2. **Play Console → Testing → Closed testing → Testers tab → Google Groups** → paste `foxyco-testers@googlegroups.com`. Adding a tester later = they join the group. No new build, no review.
3. Copy the **opt-in URL**: `https://play.google.com/apps/testing/com.foxyco.app`.
4. **Post both links, in this order** — joining the group first is the step people skip:
   - Step 1: join → `https://groups.google.com/g/foxyco-testers`
   - Step 2: opt in → `https://play.google.com/apps/testing/com.foxyco.app`
   - Step 3: install from the Play link that appears after opting in.
5. **Aim for 16–20 joiners**, not 12. The requirement is **12 opted-in testers held for 14 consecutive days** — drop below 12 and the clock pauses, so over-recruit for dropouts. Cap around 20–30 (§4c).
6. **Ping the group twice** during the 14 days ("open it once this week"). Ghost testers are the usual reason the production questionnaire gets rejected.
7. Day 15: **Production access questionnaire**. No cooldown if refused — fix and reapply.

**Fallback if group self-join confuses people:** a Google Form collecting
"your Google account email", then paste the responses into the group's member
list in one bulk add. Slower, but nobody gets stuck at step 1.

#### Recruitment post

Reddit (r/uberdrivers, r/couriersofreddit, r/AndroidClosedTesting, local
driver subs) — check each sub's self-promo rule first, some require a flair or
a mod ping:

> **[Android] Free testers wanted — app that scores ride offers before you accept**
>
> I built FoxyCo, an Android app for gig drivers. It reads the offer card from
> Uber / Lyft / Hopp / DoorDash / Instacart / Skip as it appears and shows a floating pill with $/km, $/hr
> and a take-it-or-not verdict. Read-only — it never taps accept or decline,
> that stays yours.
>
> Google requires 12 testers for 14 days before I can publish, so I need
> people willing to keep it installed for two weeks. Free during testing, and
> you get the 7-day trial after launch like everyone else.
>
> 1. Join the tester group: https://groups.google.com/g/foxyco-testers
> 2. Opt in: https://play.google.com/apps/testing/com.foxyco.app
> 3. Install and open it once a week — that's the whole ask.
>
> Works without driving, if you just want to help: there's a demo offer in the
> app. Android 8+. Feedback very welcome, that's the point.

Facebook / WhatsApp driver groups — same links, shorter, and ask the admin
before posting:

> Building an Android app that scores rideshare and delivery offers before you accept
> (floating pill, $/hr + $/km, read-only). Google needs 12 testers for 14 days
> before I can launch. Free for testers. Join → groups.google.com/g/foxyco-testers,
> then opt in → play.google.com/apps/testing/com.foxyco.app. Two weeks
> installed is the whole commitment.

**Do not** post the raw opt-in link alone: people who skip the group get "not
a tester" and never come back.

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

**CA$24.99 in Canada and US$17.99 in the United States, one time.**

Frame the value without promising earnings: *"See weak offers before you
decide. Compare offers using your own distance or hourly rules."*

- ~~Launch promo: first month at **$7.99** ("founding driver price").~~
  **Dropped 2026-07-28** (MONETIZATION §2). A one-time unlock bought at $7.99
  is owned forever, so every early buyer is permanently capped at the low
  price; the trial already supplies the urgency; and raising the price inside
  the first month reads badly in reviews from the people who evangelized you.
  Play price-change scheduling stays available if launch conversion argues
  otherwise — flagged as an open decision in MONETIZATION §9.
- Set Canada and the US manually. Use a Play price template as the international
  baseline, then review important markets for sensible local prices and endings.

---

## 3. First-publish walkthrough (what actually happens)

1. **Developer account** — play.google.com/console, one-time $25, ID verification takes 1–3 days. Individual account is fine to start.
2. **Merchant profile** — required to charge money (Option A or B). Payments profile + bank account + tax forms (W-8/W-9 or local equivalent). Do this early; verification can take days.
3. **Create app** in Console → fill the forms:
   - **Store listing:** title (30 chars), short desc (80), full desc (4000), screenshots (min 2, take from the new showroom UI — splash ignition, home hero, pill over a fake offer), feature graphic 1024×500.
   - **Privacy policy URL** — mandatory. Host on GitHub Pages, free.
     ⚠️ **Changed 2026-07-28.** The old text ("collects nothing, no network
     permission") is no longer true. Declare exactly: an anonymous Firebase
     **user ID** created on first launch, **Google account email** when a trial
     is started or account sign-in is chosen, and **trial/purchase state**. Firebase Authentication also
     processes IP address and user-agent data for security/abuse prevention.
     No offer data, location or analytics. State that a non-identifying trial
     timestamp is retained after account deletion (MONETIZATION §5.1).
   - **Data safety form** — ⚠️ **Changed 2026-07-28.** No longer "no data
     collected". Declare **Personal info (user ID; email only after Google
     sign-in)** and **App activity (trial/purchase state)**, including the
     applicable service/security and fraud-prevention purposes. Not location or
     financial data — Play handles payment and we never see card data.
   - **Account deletion** — required once you collect accounts: an in-app path
     AND a public web URL. See MONETIZATION §5.1 — the trial doc is
     deliberately retained, and the privacy policy has to say so.
   - **Accessibility declaration** — because we use an AccessibilityService, a special form asks WHY. Answer: "Temporarily reads on-screen offer text in Uber Driver, Lyft Driver, Hopp Driver, DoorDash Dasher, Instacart Shopper and Skip Courier to identify pay, distance, duration and available delivery details and display an earnings verdict. Users choose up to three apps to monitor; delivery-app support is beta and off by default. If the driver separately enables Pixel Capture on Android 11+, an unreadable active selected-app offer can trigger one Accessibility screenshot for bundled on-device OCR. Screenshots and raw text are discarded immediately and are never saved or sent. Read-only; never acts inside another app; user-enabled after in-app disclosure." Accessibility remains the primary reader. Demonstrate the optional **Pixel Capture (OCR)** toggle, its separate FoxyCo disclosure, one fallback verdict, and the absence of MediaProjection/system screen-sharing UI. Expect possible human review + a request for a screen-recording of the consent flow.
   - **Data safety impact of OCR** — no new collected-data row while pixels and recognized text remain on-device and are never transmitted. The published privacy policy must nevertheless disclose temporary screen capture exactly as `docs/legal/privacy.md` does.
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
- Paywall + restore/redeem actions in Settings — ✅ implemented 2026-07-28
- Pill locked state in the overlay isolate — ✅ implemented 2026-07-28

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

### 4c. Testers and temporary access

**Tester cap: 20–30.** Play has no "limit reached" banner; the cap IS the
email list / Google Group — stop adding past 30, outsiders simply can't
access the listing. Keep the opt-in link private (DM only). 20–30 sits
comfortably above the 12-concurrent floor and stays manageable.

Closed-track membership does not grant premium access. In build 66, ordinary
testers get the same 7-day trial and paywall as public users.

Use License testing only for trusted billing-QA accounts. Those accounts can
use Google's test payment methods. Removing an account from License testing is
not a reliable entitlement reset for an acknowledged non-consumable; refund and
revoke the test order in Play Console before repeating the purchase.

Google Play promo codes for `foxyco.lifetime` are permanent lifetime grants.
Do not hand them to random recruits if temporary access is the goal. The planned
fixed-date tester entitlement is separate and is not implemented yet. The
existing `BUILD_EXPIRY` define only cuts off trial access after a date. It does
not grant access and never overrides a verified purchase, so it must not be
treated as tester access.

Closed track survives production promotion — testers keep the app installed
and update normally; the layers above decide what they can USE, not whether
the app runs.

Use a small number of promo codes only as permanent rewards for testers who
made a meaningful contribution.

---

## 5. Launch-week playbook (the "welcome trail")

| Day | Action |
|---|---|
| T-14 | Start the mandatory closed test (12+ testers). Fix what they find. |
| T-3 | Freeze build, promote to production review, prepare screenshots + 30s screen-recording |
| Day 0 | Production live at **CA$24.99 / US$17.99 lifetime**. Post in driver communities with the 7-day-trial and no-subscription message |
| Day 1–7 | Watch Play Console → Ratings + ANRs/crashes daily. Reply to EVERY review (reviewers get notified, often revise stars) |
| Day 3 | **Confirm no purchases are auto-refunding.** Unacknowledged purchases reverse silently at 72h (MONETIZATION §3.8) — day 0 buyers are the first cohort that can expose the bug |
| Day 7 | First trial cohort hits the paywall — watch conversion % |
| Day 14–30 | A/B the store-listing copy. Keep pricing stable until conversion, refund and review data justify a change |

---

## 6. Where the app stands today (honest inventory)

### Has ✅
- Live offer reading (Uber/Lyft/Hopp, plus DoorDash/Instacart/Skip beta) via scoped read-only a11y service — rideshare device-verified; delivery seeded from public cards pending device verification
- Verdict pill + draggable bubble overlay, drop-to-dismiss, edge restore
- $/km and $/hr scoring, custom thresholds, pickup-distance guard
- Offer history with filters + parse-health self-diagnostics
- Showroom UI: photographic car hero (stealth↔reveal states), splash ignition, dark premium theme
- Zero offer-data collection, license-clean, R8 release build green
  (⚠️ was "100% offline" — Firebase adds `INTERNET`; no offer data crosses
  the wire, only auth + a trial timestamp)
- 485 automated Flutter tests + Firestore rules tests + manual device matrix (`MANUAL_TESTS.md`)
- Legal pages drafted (`docs/legal/`) and linked in-app — onboarding click-wrap
  consent, About footer, affiliation disclaimer (`lib/ui/legal/`)
- Release `.aab` builds signed by the upload key; upload-key SHA-1 is
  `8E:FB:79:2F:D5:62:7A:9B:B5:BA:17:76:19:2F:6E:67:EC:A8:32:49`
- Play Billing: signature verification + acknowledgment
  (`lib/services/billing/`, added 2026-07-28)
- Seven-day Firebase-backed trial, entitlement gate, paywall, restore/redeem,
  Home access banner, and in-app account deletion

### Remaining before production ❌

Ordered, actionable version of this list: **§0**. Estimates and code-level
blockers: **MONETIZATION §7**.

1. **Upload build 67 and run the current quick smoke test** — confirm About
   shows build 67; the topmost Uber/Lyft card owns the pill while swiping stacked
   Radar cards; opened Lyft Reserve details score without combining list cards;
   and History offers all six app filters. Recheck the build-66 bubble dismissal,
   delivery rules and purchase/restore flows as regression coverage.
2. **Refund/revoke propagation test** — after Play reports no owned lifetime
   product, Restore purchase must clear `Unlocked forever` while network/query
   errors retain the paid driver's offline grace.
3. **Play Console papers** (§3 step 3) — finish/recheck Data safety,
   accessibility declaration, content rating, merchant details and current
   screenshots before production review.
4. **AccessibilityService declaration and review video** — demonstrate that
   reading offer text is the disclosed core purpose and no taps are automated
5. **Closed-test cohort** — satisfy the current Play Console requirement shown
   for this developer account; this is calendar-blocking
6. **Physical-device release matrix** — real-shift battery numbers, S24
   crash/ANR evidence, mixed Lyft total+bonus cards, overlay drag/cancel cycles,
   and rapid watch start/stop

### Nice-to-have, post-launch
- Promote DoorDash/Instacart/Skip from Beta after genuine Accessibility/OCR fixtures
- More platforms (Grubhub, Spark…) — each is a parser + package name + fixtures
- Per-platform profiles beyond the ride/delivery split; shift earnings summary
- Localized store listings (ES/PT = big driver demographics)

---
_Last updated: 2026-08-21 — build 67 tour fixes and release artifact documented.
Entitlement architecture lives in `MONETIZATION_v1.0.md`._
