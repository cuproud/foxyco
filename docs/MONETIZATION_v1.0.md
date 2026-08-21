# FoxyCo — Monetization & Entitlement Architecture

**Version:** 1.3  
**Decision date:** 2026-07-27 (last revised 2026-08-20)  
**Replaces:** `references/FoxyCo_Monetization_Architecture_Production.md`  
**Supersedes:** `docs/PLAY_RELEASE.md` §4, §4a, §4b (trial + anti-piracy design)

This document is authoritative wherever it disagrees with `PLAY_RELEASE.md`.
That guide was written 2026-07-20 against a no-server, no-account design and
has been annotated to point here.

**Two reversals of `PLAY_RELEASE.md`, both deliberate:**

1. **Line 120** accepted a resettable local trial to preserve the "100%
   offline" claim. Reversed: the trial lives in Firestore, the app gains
   `INTERNET`, and the listing claim becomes "no offer data ever leaves your
   phone" — still true, since only auth and a trial timestamp cross the wire.
   An app-data clear regranting the trial indefinitely was judged the larger
   cost. See §3.3.
2. **The old $7.99/$12.99 launch pricing** is superseded. §2 records the
   current Canada and US prices after reviewing the product in build 55.

---

## 1. Model (decided)

Free download on Google Play. One-time in-app unlock via Play Billing.  
7-day trial before the paywall appears.  
No subscription. No server-side Cloud Functions. No RTDN.

**Why no subscription:** one-time removes churn, refund complexity, and RTDN
reconciliation. Gig drivers are cost-sensitive; a subscription is a recurring
argument against keeping the app.

---

## 2. Pricing (decided)

| Market | Lifetime price |
|---|---:|
| Canada | **CA$24.99** |
| United States | **US$17.99** |

These are one-time lifetime prices. The trial remains 7 days and there is no
subscription.

**No launch promo.** `PLAY_RELEASE.md` §2 proposed $7.99 as a founding price
rising to $12.99 around day 14–30. Dropped for three reasons: a one-time
unlock bought at $7.99 is owned forever, so every early buyer is permanently
capped at the low price; the trial already supplies the urgency a promo would
manufacture; and a price rise inside the first month reads badly in reviews
from the people who evangelized you. Play price-change scheduling stays
available if launch conversion argues otherwise.

Set Canada and the US manually because they are the key launch markets. Use a
Play price template as the international baseline, then review important
markets for sensible local purchasing power and psychological endings. Do not
force a single mathematical currency conversion everywhere.

---

## 3. Entitlement design

### 3.1 State machine

```
INSTALL
  └─ anonymous Firebase Auth UID created silently
       └─ PRE_TRIAL  ← free-forever features only (§4); pill is LOCKED
            └─ "Start 7-day trial" tapped → Google Sign-In
                 └─ TRIAL_ACTIVE  (Firestore write-once, server clock)
                      ├─ ENTITLED  (Play Billing purchase verified)
                      └─ TRIAL_EXPIRED → LOCKED
```

**PRE_TRIAL is a locked state.** A user who installs and never taps "Start
trial" gets the free-forever surface in §4 and a locked pill — identical to
TRIAL_EXPIRED. Entitlement is never granted by default; the trial is opt-in
and starts on an explicit tap, so the 7 days are not silently burned by
someone who installed and forgot. Fail closed everywhere.

### 3.2 Two sources of truth — never mix them

| What | Source of truth | Why |
|---|---|---|
| Trial start date | Firestore (server clock) | Unresettable — clearing app data, reinstalling, or rolling the device clock back cannot touch it |
| Purchase / unlock | Play Billing `queryPurchases()` | Survives reinstall, device swap and account transfer; reflects refunds automatically; no record needed on our side |

Entitlement = `purchased OR (now − trialStart) < 7 days`.  
Cached locally (SharedPreferences) with a grace window (see §3.5).

**On refunds:** a refunded purchase simply stops appearing in
`queryPurchases()`, so no reconciliation is needed — but the local cache and
its grace window (§3.5) mean a refunded user keeps access for up to 7 more
days. Accepted; the alternative is an online check on every launch.

### 3.3 Why Firestore, not SharedPreferences, for the trial

SharedPreferences resets on app-data clear. A determined user can regrant
themselves the trial. Firestore with write-once rules makes the trial record
permanent per Google account. The Spark (free) tier covers this — one read
per entitlement refresh (not every launch; see §3.7 layer 2), no Cloud
Functions, no Blaze plan, no card on file.

Firestore security rules (the entire backend):

```javascript
match /trials/{uid} {
  // Write-once: create allowed only by the owning user, stamped with
  // Google's server clock. Update and delete are never allowed.
  allow create: if request.auth != null
             && request.auth.uid == uid
             && request.resource.data.keys().hasOnly(['startedAt'])
             && request.resource.data.startedAt == request.time;
  allow read:   if request.auth != null && request.auth.uid == uid;
  allow update, delete: if false;
}
```

No Cloud Functions. No admin SDK. No RTDN. Rules deploy once:
`firebase deploy --only firestore:rules`.

> **Client must write `FieldValue.serverTimestamp()`** for the `startedAt`
> field. `request.resource.data.startedAt == request.time` only holds for a
> server-stamped sentinel. Writing `DateTime.now()` makes every create fail
> with `permission-denied` — which is the point (the client cannot choose its
> own trial start), but it is a confusing first failure if unexpected.

### 3.4 Sign-in timing (funnel-first)

Do NOT require sign-in at first launch — it kills installs.

```
First launch  → anonymous Firebase Auth (silent, no UI)
Onboarding    → show what the pill does
"Start trial" → Google Sign-In sheet appears here
               → on success: linkWithCredential (anonymous → Google)
               → Firestore trial doc created
               → trial clock starts
```

`linkWithCredential` preserves the UID so nothing is lost if the user
explored the app anonymously before signing in.

#### 3.4.1 `credential-already-in-use` — the case that makes or breaks this

**This is the single most important implementation detail in the document.**
Get it wrong and Firebase buys nothing over SharedPreferences.

A returning user — cleared app data, reinstalled, new phone — arrives with a
**fresh anonymous UID**. When they sign in with a Google account that already
has a Firebase user, `linkWithCredential` throws
`FirebaseAuthException(code: 'credential-already-in-use')`. It does not
silently succeed.

Required handling:

```dart
try {
  await FirebaseAuth.instance.currentUser!.linkWithCredential(cred);
} on FirebaseAuthException catch (e) {
  if (e.code == 'credential-already-in-use' ||
      e.code == 'email-already-in-use') {
    // Returning user. Sign in to the ORIGINAL account — this returns the
    // original UID, whose trial doc already exists and is likely expired.
    // The throwaway anonymous user is abandoned.
    await FirebaseAuth.instance.signInWithCredential(cred);
  } else {
    rethrow;
  }
}
```

If the catch is missing, the exception surfaces as "sign-in failed" and the
user retries forever. If the catch swallows the error without falling back to
`signInWithCredential`, the app keeps the fresh anonymous UID, writes a brand
new trial doc, and **the reinstall just regranted 7 days** — the exact hole
Firestore was adopted to close.

After the fallback, the trial doc read must use the post-sign-in UID, not the
one captured before the call. The UID changes underneath you.

Orphaned anonymous users accumulate in Firebase Auth. Harmless and free;
clean up with a console script if the list ever gets noisy.

### 3.5 Offline grace window (decided: 7 days)

Cache the entitlement verdict locally. Honour the cache for up to 7 days
without a successful Firestore/Billing check. A driver in a dead zone must
not get locked mid-shift.

This is simultaneously:
- The UX floor (offline works for a week)
- The piracy ceiling (a network-blocked cracker stays unlocked for 7 days)

Accept it. Fighting it requires always-online enforcement, which breaks the
offline story for legitimate users.

Show a warning banner from day 5 of an unverified cache ("Couldn't reach
Google Play — unlock check needed in 2 days") so expiry is never a surprise
mid-shift.

### 3.6 Device binding (soft, not hard)

Do NOT hard-lock to a device ID. `ANDROID_ID` resets on factory reset and
changes across signing keys. Hard lock = manual support emails.

Soft check only: if a new Google account starts a trial on a device that
already has an active trial under a different account, log it but do not
block. Never let a device check block a purchase.

### 3.7 Anti-piracy (no server required)

Three layers, all client-side:

1. **Play purchase signature verification.** Play Billing returns purchase
   JSON + RSA signature. Embed the Base64 public key from Play Console.
   Verify locally. Fake-purchase tools ("Lucky Patcher") fail signature.
   Works offline forever. See §3.9 for how the key is injected.

2. **Random re-verification.** Every launch: if 1-in-5 roll OR cached
   entitlement older than 7 days → re-query Billing + re-verify signature
   + refresh Firestore trial check. A patch that removes the launch check
   re-locks days later.

3. **Tamper frictions (free).** R8 obfuscation already on. Give the
   entitlement class a boring name (crackers grep for `Purchase*`).
   `packageName` + signing-cert sanity check at boot (resigned repacks
   quietly stay locked). Duplicate entitlement check in the overlay isolate
   (two patch sites, not one — see §4).

Deliberately NOT doing: Play Integrity API (needs server-side decryption,
breaks offline), root/emulator detection, online activation. Hostile to
legit users; pirates strip them first anyway.

### 3.8 Purchase acknowledgment (mandatory — revenue-critical)

Google auto-refunds any purchase not acknowledged within **72 hours**. The
money silently reverses and the user keeps a receipt that no longer verifies.

Rules:

- Product type is **non-consumable** (`buyNonConsumable`). Never call
  `consumePurchase` — that would let a user re-buy and, worse, drop the
  entitlement.
- Every event from the `purchaseStream` with status `purchased` or `restored`
  and `pendingCompletePurchase == true` must get `completePurchase(details)`.
  This is the acknowledgment.
- Verify the RSA signature **before** granting entitlement. Acknowledge
  regardless of the signature result: a forged receipt is already denied
  entitlement, and acknowledging it changes nothing because Play never billed
  it — whereas skipping acknowledgment on a *genuine* receipt that failed
  verification for an unrelated reason (bad key, clock, encoding) silently
  refunds a real customer.
- `queryPurchases()` at launch re-emits owned purchases through the same
  stream, so a purchase interrupted mid-flight (app killed after payment,
  before acknowledgment) gets acknowledged on the next launch. This is the
  only recovery path — there is no server to reconcile from.
- Status `pending` (slow payment methods: cash, carrier billing) is not
  entitlement. Show "payment processing", grant nothing until it flips to
  `purchased`.

### 3.9 Licensing public key injection

The Play Console licensing key (Play Console → Monetization setup →
Licensing) is **not a secret** — it ships in every APK by design — but it is
environment-specific and must not be a hardcoded literal that a dev build
silently inherits.

Injected at build time:

```
flutter build appbundle --dart-define=PLAY_PUBLIC_KEY=<base64 from Console>
```

Read via `String.fromEnvironment('PLAY_PUBLIC_KEY')`, defaulting to empty.
**With no key configured, verification denies everything** rather than waving
purchases through unchecked. A release build shipped without the define
therefore locks all paying users out — add a CI assertion or a release-mode
startup check that the key is non-empty.

---

## 4. What locks when the trial ends (decided)

**Free forever** (goodwill + demo value):
- App opens, Home, Settings, offer history, demo pill.

**Locked** (the actual value):
- Live watching still STARTS, but the pill renders "🦊 Unlock" instead of
  verdict/numbers. Tapping it opens the paywall sheet.

Rationale: driver sees the pill working during a real offer and can't read
the verdict — frustration at the exact moment of value converts better than
blocking go-live outright.

**Enforcement — two isolates, two patch sites:**

1. Main isolate: `entitlementProvider` gates the overlay payload. Payload
   carries an `entitled: bool` flag.
2. Overlay isolate: pill widget branches locked/unlocked on that flag.
   Overlay independently rejects payloads with the flag missing.

The overlay isolate has no Riverpod, no SharedPreferences read, and no clock
it trusts — it only knows what `shareData` hands it. So "reject stale" means
exactly one rule: **`entitled` absent or not `true` renders the locked pill.**
A patch that strips the flag from the main isolate produces a locked pill,
not an unlocked one. Fail closed, no timestamp needed — `OverlayPayload` is
built fresh per offer in `OverlayService.showOffer`, so it cannot be stale in
any other sense.

**Paywall UI:**
- Banner at top of Home: "Trial ended — unlock FoxyCo"
- Tapping Start while locked → bottom sheet with price + Play Billing button
  + "Restore purchase" link.

---

## 5. What changes in the manifest / papers

Adding Firebase + Play Billing requires:

| Change | Detail |
|---|---|
| `INTERNET` permission | Add to `AndroidManifest.xml`. The listing claim changes from "100% offline" to "no offer data ever leaves your phone" — still true. Update `AUDIT.md`, which currently verifies the no-INTERNET claim. |
| Privacy policy | Must exist at a public URL before Play review. Declare exactly what is collected: **Google account email** (trial identity) and **trial/purchase state**. No offer data, no location, no analytics. |
| Data safety form | Declare: Account info (email), App activity (trial/purchase state). No location, no financial data (Play handles payment; we never see card data). |
| Account deletion | Play requires an in-app deletion path AND a public web URL once you collect accounts. See §5.1. |

**Do not declare Firebase Analytics.** Only `firebase_auth` and
`cloud_firestore` are being added. An earlier draft of this table listed
"anonymous usage analytics" — that would be a false Data safety declaration.
If Analytics is ever added, this table and the privacy policy change with it.

### 5.1 Account deletion vs. the write-once rule

These two requirements collide and the resolution must be deliberate.

The Firestore rule is `allow update, delete: if false`. **The client cannot
delete its own trial doc.** Any "Delete my account" implementation that calls
`delete()` on `trials/{uid}` fails with `permission-denied`.

Resolution: **delete the auth user, retain the trial document.**

```dart
// Settings → About → Delete my account
await FirebaseAuth.instance.currentUser?.delete();
// The trials/{uid} doc is intentionally NOT deleted.
```

Once the auth user is gone, the retained document is a random UID string and
a timestamp with no link to a person — non-identifying, so retaining it is
consistent with the privacy policy, which must say so in plain words: *"a
non-identifying record of when your trial started is kept to prevent trial
abuse."*

**Known ceiling:** deleting the account and signing up again with the same
Google address produces a *new* Firebase UID, hence a new trial doc, hence a
fresh 7 days. So account deletion is a trial reset — just a much slower one
than clearing app data was. Accepted at launch scale.

*Upgrade path if abuse appears:* key the trial doc by
`sha256(lowercase(email))` instead of the UID, matched in rules with
`hashing.sha256(request.auth.token.email.lower()).toHexString()`. The same
address then always maps to the same document regardless of how many times
the account is deleted, and a one-way hash is still non-identifying. Costs
one rule rewrite and a migration of existing docs — not worth doing before
there is evidence of the abuse.

---

## 6. Testers

Cap at 20–30. Play has no "limit reached" banner — the cap IS the email
list / Google Group. Keep the opt-in link private (DM only).

Closed-track membership does not grant premium access. In the current app,
ordinary closed testers receive the same 7-day trial and paywall as everyone
else.

Use **License testing only for trusted billing QA accounts**. License testers
can use Google's test payment methods. Do not add random recruits to that list.
An acknowledged test purchase of the non-consumable may remain owned; removing
the account from License testing is not the reset mechanism. Refund and revoke
the order in Play Console before repeating the purchase test.

Lifetime promo codes are permanent lifetime grants. Use them only as deliberate
rewards. Time-limited tester access is a separate planned app entitlement and
is not implemented in build 55. The existing `BUILD_EXPIRY` define only cuts
off trial access after a date; it does not grant temporary access and never
overrides a verified purchase. Do not use it for ordinary Play builds.

### 6.1 Redeem codes (Play Console promo codes)

The **Redeem Code** option in **Settings → Profile → Access** uses Google Play promo
codes. Redemption grants the same permanent entitlement as a purchased
lifetime unlock — it arrives through `queryPurchases()` as an ordinary
purchase, so `entitlementProvider` treats redeemed and purchased users
identically and `TrialGate` is skipped whenever entitlement is true.

Promo codes are quota-limited per app per quarter in Play Console. Fine for
hand-issued exceptions; not a distribution channel.

### 6.2 Development-only unlock

`kDebugUnlocked`, gated on `kDebugMode`. Forces entitlement true and bypasses
`TrialGate`. Because `kDebugMode` is a compile-time constant, the branch is
tree-shaken out of release builds entirely — it must never be a runtime
setting, a flavor string, or a hidden preference.

### 6.3 Unlock screen copy

- **Unlock FoxyCo for life. One payment. No subscription.**
- **Use every feature free for 7 days, then choose whether to buy lifetime access.**
- **Google Play shows your local one-time price before you confirm.**

Avoid income or payback promises. A safe value frame is: *"See weak offers
before you decide."* An earlier draft compared
against "$9.99/mo elsewhere"; a hardcoded competitor price rots the moment
they change it and is a comparative claim you would have to be able to
substantiate.

---

## 7. Build order (implementation roadmap)

Each step is independently shippable and testable.

| Step | What | Est. | Status |
|---|---|---|---|
| 0 | **Play Console account** — $25 one-time, ID verification 1–3 days, merchant profile. Blocks steps 4b, 6 and the 14-day closed test clock. Start it first; it is calendar time, not work time. | — | ✅ signed up 2026-07-28, ⏳ ID verification |
| 1 | Firebase project setup (dev + prod), `google-services.json` per flavor, anonymous Auth at launch | 0.5 day | ✅ code 2026-07-28 / ⏳ console: `docs/FIREBASE_SETUP.md` §1–2, §4–5 |
| 1b | **SHA-1 registration (upload key)** in Firebase. Google Sign-In fails without it — must land before step 2, not last. | 0.25 day | ⏳ yours: FIREBASE_SETUP §3 — fingerprint is known, `8E:FB:79:2F:D5:62:7A:9B:B5:BA:17:76:19:2F:6E:67:EC:A8:32:49` (PLAY_RELEASE §0 A2) |
| 2 | Google Sign-In + `linkWithCredential` **with the `credential-already-in-use` fallback (§3.4.1)**, Firestore trial doc write-once | 0.5 day | ✅ 2026-07-28 `TrialStore.startTrial` |
| 3 | `TrialGate` service: reads Firestore trial, caches locally, `entitled` bool | 0.5 day | ✅ 2026-07-28 — shipped as `TrialStore` (`lib/services/billing/trial_store.dart`), name changed to match the codebase's `*Store` providers |
| 4a | `in_app_purchase` dep, `queryPurchases()` + RSA signature verify + `completePurchase()` acknowledgment (§3.8) | 0.5 day | ✅ done 2026-07-28 |
| 4b | `foxyco.lifetime` **non-consumable** product in Play Console; paste licensing key via `--dart-define` (§3.9); verify a real purchase on an internal-testing build | 0.5 day | ⛔ blocked on step 0 verification — FIREBASE_SETUP §6 |
| 5 | `entitlementProvider` wires TrialGate + Billing result; overlay payload carries `entitled` flag; pill locked state | 0.5 day | ✅ 2026-07-28 — `accessProvider`/`entitledProvider`, `OverlayPayload.entitled`, `LockedPill` |
| 6 | Paywall sheet + "Restore purchase" + "Redeem code" + Home banner | 0.5 day | ✅ 2026-07-28 — `ui/paywall/` (sheet, `AccessBanner`, Settings → Profile → Access) |
| 7 | Anti-piracy layers: random re-verify, packageName check, boring class names | 0.5 day | 🟡 partial — 1-in-5 re-verify done; resign check deferred (see below) |
| 8 | Account deletion flow (§5.1) + public web URL | 0.5 day | ✅ in-app path and published instructions use Settings → Profile → Access |
| 9 | Papers: privacy policy page, Data safety form, manifest INTERNET permission, `AUDIT.md` update | 0.5 day | 🟡 `INTERNET` + `AUDIT.md` done; privacy/terms drafted `docs/legal/`; ⏳ publish them + Data safety form (PLAY_RELEASE §0 A1, B5) |
| 10 | **SHA-1 registration (Play App Signing key)** in Firebase — this key only exists in Play Console *after* the first bundle upload, so it cannot be done earlier. Skipping it means Google Sign-In works in debug and fails in production. | 0.25 day | ⛔ blocked on first upload — FIREBASE_SETUP §7 |

### Deviations from this plan, and why (2026-07-28 implementation)

1. **§3.7 layer 3 — the resigned-repack check is NOT built.** It compares the
   running app's signing certificate against an expected fingerprint, and the
   Play App Signing fingerprint does not exist until after the first bundle
   upload (step 10). Building it now would mean shipping a comparison against a
   placeholder, which is worse than not shipping it. Revisit with step 10.
2. **"Boring class names" was skipped as ineffective, not forgotten.** That
   advice comes from Java/Android, where R8 leaves class names in the DEX and a
   cracker greps for `Purchase*`. Dart is AOT-compiled to machine code for
   release builds; Dart class names are not retained the way Java ones are, so
   renaming `Access`/`BillingStore` buys obscurity against nothing and costs
   readability every day. The load-bearing layers are the local RSA receipt
   verification and the sampled re-verify.
3. **Clock rollback needed a mechanism the doc didn't specify.** §10 requires
   that winding the device clock back cannot extend a trial, but the trial end
   was to be computed locally from a server start date. `FoxClock` keeps a
   high-water mark of the latest time seen and never reads earlier than it, and
   *overwrites* that mark with the Firebase ID token's `issuedAtTime` on every
   successful refresh — so a device clock briefly set years ahead heals on the
   next online check instead of expiring a paying driver's trial early.
4. **`entitled` is stamped per offer, not cached in the overlay.** §4 asked the
   overlay to reject stale payloads; since `OverlayPayload` is rebuilt for every
   offer, "stale" reduces to "flag absent or not literally `true`", which is the
   single rule implemented and unit-tested.

**Total: ~5–6 days of work.** No Cloud Functions, no Blaze plan, no RTDN, no
admin dashboard. Maintenance after launch: Firebase SDK bumps at your leisure.

**Two SHA-1 registrations, not one, and they happen at opposite ends of the
schedule.** The upload-key fingerprint (step 1b) is needed before any Google
Sign-In testing; the Play App Signing fingerprint (step 10) does not exist
until Google has re-signed your first upload. This is the classic
"sign-in worked all through development and broke in production" bug.

**What is not blocked by the Play Console account:** steps 1, 1b, 2, 3, 5, 7,
8, 9. Firebase is free (Spark tier, no card). Billing code exists but reports
`unavailable` on any build Play does not recognize — which is correct
behavior, and the trial governs entitlement meanwhile.

---

## 8. What this is NOT doing (and why)

| Dropped | Reason |
|---|---|
| Cloud Functions (createTrial, verifyPurchase, etc.) | Firestore rules replace them. Functions = runtime deprecations to chase, Blaze plan required. |
| RTDN (Real-Time Developer Notifications) | Only needed for subscriptions. One-time purchase has no expiry to reconcile. |
| Admin dashboard | Firebase Console + a CLI script covers support needs at launch scale. |
| Subscriptions | Adds RTDN, grace periods, account holds, churn. Revisit if revenue data justifies it. |
| Redeem codes via Cloud Functions | Play Console promo codes cover launch needs, free, no backend. |
| Anonymous-only trial (no Google account) | Resettable by clearing app data. Google account = unresettable trial via Firestore. |
| Firebase Analytics / Crashlytics | Not added. Keeps the Data safety form to two rows. Revisit post-launch. |
| $7.99 founding launch price | See §2 — a permanently-owned unlock sold cheap stays cheap forever. |

---

## 9. Open decisions

1. **Offline grace window** is set to 7 days (§3.5). If you want stricter
   (e.g. 3 days), change it before `TrialGate` is built — it affects both the
   UX copy ("works offline for X days") and the cache TTL.
2. **Dropping the $7.99 founding price** (§2) is a revenue call made here on
   consistency grounds. Reconfirm before the store listing is filled in.

---

## 10. Acceptance criteria

### Trial
- A fresh install shows PRE_TRIAL: free-forever surface, locked pill, no
  clock running.
- "Start trial" writes `trials/{uid}.startedAt` with
  `FieldValue.serverTimestamp()`; a client-supplied timestamp is rejected.
- Clearing app data, reinstalling, or signing in on a second device resolves
  to the **same** UID and the **same** original trial start (§3.4.1).
- Rolling the device clock back does not extend the trial.

### Purchase
- Product is non-consumable; `consumePurchase` is never called.
- Every `purchased`/`restored` event with `pendingCompletePurchase` gets
  `completePurchase()` — within 72h, else Google auto-refunds.
- A purchase interrupted before acknowledgment is acknowledged on next launch
  via `queryPurchases()`.
- A receipt failing RSA verification grants no entitlement.
- A release build with no `PLAY_PUBLIC_KEY` defined grants no entitlement
  (fails closed) and trips the release-mode startup check.
- `pending` status grants no entitlement; UI shows "payment processing".

### Offline
- Entitlement survives 7 days with no network.
- A warning banner appears from day 5 of an unverified cache.

### Redeem code
- Redeeming a Google Play promo code grants the same lifetime entitlement as
  a purchase; `entitlementProvider` reports `true`.
- Trial status is ignored once entitled.
- "Restore purchase" recognizes redeemed entitlements.

### Debug unlock
- Available only in debug builds; the branch is absent from release output.
- Skips `TrialGate` and forces entitlement to `true`.

### Unlock screen
- Displays the localized Play price; expected key-market prices are
  **CA$24.99** in Canada and **US$17.99** in the United States. No hardcoded
  fallback price is shown while product details load.
- Clearly states **No subscription**.
- Includes **Buy**, **Restore purchase**, and **Redeem code** actions.

---

## 11. Entitlement flow

```text
Google Play Purchase / Promo Code        Firebase Auth (Google)
          │                                       │
          ▼                                       ▼
   queryPurchases()                      Firestore trials/{uid}
          │                                       │
          ▼                                       ▼
   RSA verification                          TrialGate
   + completePurchase()                  (cached, 7-day grace)
          │                                       │
          └──────────────┬────────────────────────┘
                         ▼
                 entitlementProvider
                         │
                         ▼
              Home / Overlay UI (entitled: bool)
```

---

## Changelog

### Version 1.3 (2026-08-20)
- Set the launch prices to CA$24.99 and US$17.99 after the build-55 product
  review; kept the 7-day trial and lifetime model.
- Corrected tester guidance: closed-track membership grants nothing, license
  testing is for trusted billing QA, and lifetime promo codes are permanent.
- Recorded that `BUILD_EXPIRY` is a trial cutoff, not temporary tester access.
- Replaced earnings/payback promises with plain product-value wording.

### Version 1.2 (2026-07-28)
- **§3.4.1 added — `credential-already-in-use` handling.** Without the
  fallback to `signInWithCredential`, a reinstall gets a fresh anonymous UID
  and a brand new trial doc, defeating the entire reason Firestore was chosen.
  Previously undocumented.
- **§5.1 added — account deletion vs. write-once.** The old §5 told the
  client to delete the Firestore trial doc, which the rules forbid
  (`allow update, delete: if false`); it would have failed at runtime.
  Resolved as delete-auth-user / retain-doc, with the known reset ceiling and
  an email-hash upgrade path stated.
- **§5 corrected — removed "anonymous usage analytics (Firebase)"** from the
  privacy policy row. No Analytics SDK is being added; declaring it would
  have been a false Data safety declaration. Also fixed the deletion snippet
  from JavaScript (`firebase.auth()...`) to Dart.
- **§3.2 corrected** — "survives refund" was wrong; a refund revokes the
  purchase. Now states refunds are reflected automatically, plus the up-to-7-
  day cache lag.
- **§2 / §8 — dropped the $7.99 founding price**, resolving a direct
  contradiction with `PLAY_RELEASE.md` §2 and §5. Flagged in §9 for
  reconfirmation.
- **§3.1 — PRE_TRIAL defined** as an explicitly locked state. Previously the
  gap between install and trial start was undefined.
- **§3.3 — noted that `startedAt` must be `FieldValue.serverTimestamp()`**,
  else every create is rejected by the rule.
- **§3.9 added** — licensing key injected by `--dart-define`, fails closed
  when absent.
- **§7 reordered** — SHA-1 registration split into 1b (upload key, blocks
  Google Sign-In) and 10 (Play App Signing key, impossible before first
  upload). It was a single step at the end, which would have broken sign-in
  during development and again in production. Added step 0 (Play Console
  account) and per-step status.
- §6.2 clarified that `kDebugMode` is compile-time and tree-shaken.
- §6.3 dropped the "$9.99/mo elsewhere" comparative claim.
- §3.5 added the day-5 offline warning banner.
- Header restructured: explicit version, and both PLAY_RELEASE reversals
  named up front.

### Version 1.1 (2026-07-27)
- Added §3.8 purchase acknowledgment: non-consumable, `completePurchase()`
  within 72h, `pending` grants nothing. Missing acknowledgment = silent
  auto-refund.
- §4 overlay staleness defined concretely: `entitled` absent or non-`true`
  renders locked. Fail closed, no timestamp.
- Flagged the `PLAY_RELEASE.md` line 120 reversal in the header.

### Version 1.0 (2026-07-27)
- Initial $12.99 lifetime unlock decision (superseded by version 1.3).
- Added Play promo code redemption.
- Added debug-only unlock mode.
- Added Unlock screen copy.
- Added acceptance criteria and entitlement flow diagram.

---

_Last updated: 2026-08-20_
