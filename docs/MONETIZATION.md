# FoxyCo — Monetization & Entitlement Architecture

**Decision date:** 2026-07-27  
**Replaces:** `references/FoxyCo_Monetization_Architecture_Production.md`  
**Amends:** `docs/PLAY_RELEASE.md` §4 (trial design section superseded here)

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

| Phase | Price | Trigger |
|---|---|---|
| Launch promo | $7.99 | First 30 days live |
| Standard | $12.99 | After promo window |

Play takes 15% (first $1M/year). Net at $12.99 ≈ $11.04/unlock.

---

## 3. Entitlement design

### 3.1 State machine

```
INSTALL
  └─ anonymous Firebase Auth UID created silently
       └─ "Start 7-day trial" tapped → Google Sign-In
            └─ TRIAL_ACTIVE  (Firestore write-once, server clock)
                 ├─ ENTITLED  (Play Billing purchase verified)
                 └─ TRIAL_EXPIRED → LOCKED
```

### 3.2 Two sources of truth — never mix them

| What | Source of truth | Why |
|---|---|---|
| Trial start date | Firestore (server clock) | Unresettable — clearing app data, reinstalling, or rolling device clock back cannot touch it |
| Purchase / unlock | Play Billing `queryPurchases()` | Survives reinstall, account transfer, refund; no record needed on our side |

Entitlement = `purchased OR (now − trialStart) < 7 days`.  
Cached locally (SharedPreferences) with a grace window (see §3.5).

### 3.3 Why Firestore, not SharedPreferences, for the trial

SharedPreferences resets on app-data clear. A determined user can regrant
themselves the trial. Firestore with write-once rules makes the trial record
permanent per Google account. The Spark (free) tier covers this — one read
per launch, no Cloud Functions, no Blaze plan, no card on file.

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

### 3.5 Offline grace window (decided: 7 days)

Cache the entitlement verdict locally. Honour the cache for up to 7 days
without a successful Firestore/Billing check. A driver in a dead zone must
not get locked mid-shift.

This is simultaneously:
- The UX floor (offline works for a week)
- The piracy ceiling (a network-blocked cracker stays unlocked for 7 days)

Accept it. Fighting it requires always-online enforcement, which breaks the
offline story for legitimate users.

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
   Works offline forever.

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
   Overlay independently rejects payloads with the flag missing or stale.

**Paywall UI:**
- Banner at top of Home: "Trial ended — unlock FoxyCo"
- Tapping Start while locked → bottom sheet with price + Play Billing button
  + "Restore purchase" link.

---

## 5. What changes in the manifest / papers

Adding Firebase + Play Billing requires:

| Change | Detail |
|---|---|
| `INTERNET` permission | Add to `AndroidManifest.xml`. The listing claim changes from "100% offline" to "no offer data ever leaves your phone" — still true. |
| Privacy policy | Must exist at a public URL before Play review. Declare: anonymous usage analytics (Firebase), Google account email (for trial identity), no offer data transmitted. |
| Data safety form | Declare: Account info (email), App activity (trial/purchase state). No location, no financial data. |
| Account deletion | Play requires an in-app deletion path AND a web URL once you collect accounts. Add "Delete my account" in Settings → About, which calls `firebase.auth().currentUser.delete()` + deletes the Firestore trial doc. |

---

## 6. Testers (decided)

Cap at 20–30. Play has no "limit reached" banner — the cap IS the email
list / Google Group. Keep the opt-in link private (DM only).

Three layers ensure no permanent free copies:

1. **Trial gate applies to testers.** 7 days from their first launch.
2. **License testing is temporary.** Add tester Gmails to Play Console →
   License testing so they can exercise the purchase flow (test card, no
   charge). **At production launch: clear the list.** Their test purchases
   vanish. They pay like everyone.
3. **Build kill-date.** Closed-track builds bake in a drop-dead date:
   `now > buildExpiry → paywall regardless of trial state`. One const.

---

## 7. Build order (implementation roadmap)

Each step is independently shippable and testable.

| Step | What | Est. |
|---|---|---|
| 1 | Firebase project setup (dev + prod), `google-services.json` per flavor, anonymous Auth at launch | 0.5 day |
| 2 | Google Sign-In + `linkWithCredential`, Firestore trial doc write-once | 0.5 day |
| 3 | `TrialGate` service: reads Firestore trial, caches locally, `entitled` bool | 0.5 day |
| 4 | `in_app_purchase` dep, `foxyco.lifetime` product in Play Console, `queryPurchases()` + RSA signature verify | 1 day |
| 5 | `entitlementProvider` wires TrialGate + Billing result; overlay payload carries `entitled` flag; pill locked state | 0.5 day |
| 6 | Paywall sheet + "Restore purchase" + Home banner | 0.5 day |
| 7 | Anti-piracy layers: random re-verify, packageName check, boring class names | 0.5 day |
| 8 | Account deletion flow (Settings + web URL) | 0.5 day |
| 9 | Papers: privacy policy page, Data safety form, manifest INTERNET permission | 0.5 day |
| 10 | SHA-1 registration in Firebase (upload key + Play App Signing key — both required) | 0.5 day |

**Total: ~5–6 days.** No Cloud Functions, no Blaze plan, no RTDN, no admin
dashboard. Maintenance after launch: Firebase SDK bumps at your leisure.

---

## 8. What this is NOT doing (and why)

| Dropped from original doc | Reason |
|---|---|
| Cloud Functions (createTrial, verifyPurchase, etc.) | Firestore rules replace them. Functions = runtime deprecations to chase, Blaze plan required. |
| RTDN (Real-Time Developer Notifications) | Only needed for subscriptions. One-time purchase has no expiry to reconcile. |
| Admin dashboard | Firebase Console + a CLI script covers support needs at launch scale. |
| Subscriptions | Adds RTDN, grace periods, account holds, churn. Revisit if revenue data justifies it. |
| Redeem codes via Cloud Functions | Play Console promo codes cover launch needs, free, no backend. |
| Anonymous-only trial (no Google account) | Resettable by clearing app data. Google account = unresettable trial via Firestore. |

---

## 9. One open decision before coding starts

**Offline grace window** is set to 7 days above. If you want stricter
(e.g. 3 days), change it before the `TrialGate` service is built — it
affects both the UX copy ("works offline for X days") and the cache TTL.

---

_Last updated: 2026-07-27_
