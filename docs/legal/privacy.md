---
title: FoxyCo — Privacy Policy
---

# FoxyCo — Privacy Policy

**Last updated: 20 August 2026**

FoxyCo ("the app") is published by **Vamsi Naradasu**
("we", "us"), contactable at **foxyco.dev@gmail.com**.

This policy explains, in plain terms, what FoxyCo does and does not do with
information. It covers the Android app distributed on Google Play under the
package name `com.foxyco.app`.

## The short version

FoxyCo reads offer-related text only in Uber Driver, Lyft Driver, Hopp Driver,
DoorDash Dasher and Instacart Shopper to score offers, and that reading never
leaves your phone. You choose up to three apps to monitor; DoorDash and
Instacart support is beta and off by default. On first launch,
Firebase creates a random anonymous identity for trial-abuse prevention. If you
start a trial, Google account identity and the server-recorded trial date also
reach Firebase.

## What stays on your device

The following is stored in FoxyCo's private app storage. It is not sent anywhere
unless you deliberately include it in feedback or share diagnostic logs:

- **Offer data** — the pay, distance, duration and platform of each offer FoxyCo
  scores, plus the verdict it gave and whether you appeared to take or pass it.
- **Your settings** — rate thresholds, rate mode ($/km or $/hr), pickup-distance
  limits, which platforms to watch, retention period, theme.
- **Your garage and profile** — the name you enter, your vehicles and any
  reminders you set.
- **Diagnostic logs** — a rolling local log of what the watcher did, capped at
  two files. You can view it in Settings → Diagnostic logs and share it manually if you are
  reporting a problem. Nothing is uploaded automatically.

You control how long offer history is kept in **Settings → History** and can
clear it at any time.

## What FoxyCo reads on screen, and what it does with it

FoxyCo primarily uses Android's AccessibilityService API to read supported
driver-app offer cards. You can separately enable **Pixel Capture (OCR)** as a
fallback when a card exposes too little Accessibility text.

- The Accessibility event stream is **restricted to five apps**: Uber Driver,
  Lyft Driver, Hopp Driver, DoorDash Dasher and Instacart Shopper. FoxyCo
  processes offer text only for the one to three apps you select. DoorDash and
  Instacart parsing is labelled beta and is disabled until you select it. A
  Pixel Capture frame can contain whatever is visible at that instant; FoxyCo
  requests one only after an active selected-app frame is unreadable.
  FoxyCo's Accessibility service receives no events from any other app,
  including your browser, messages, banking apps or launcher. Supporting
  another driver app requires a FoxyCo update that explicitly adds and
  discloses that app.
- It is **read-only**. FoxyCo never requests the ability to perform gestures and
  cannot tap, accept, decline or otherwise act inside those apps.
- Screen text is used only to detect and score offers and, if outcome tracking
  is enabled, infer whether an offer was taken or passed. The numbers extracted
  (pay, distance, duration) are saved to your local offer history. Raw screen
  text is processed in memory and is never saved, uploaded or shared.
- Pixel Capture is off by default. Enabling it shows a separate FoxyCo
  disclosure and requires an affirmative choice. On Android 11 and newer, OCR
  requests one Accessibility screenshot only after an active
  supported-driver-app frame is empty or card-like but incomplete. There is no
  continuous recording or MediaProjection screen-sharing session. The bundled
  recognition model runs on the device. Captured pixels are cleared immediately
  after recognition and are never written to a file, added to History, uploaded
  or included in logs. On Android 10 and older, FoxyCo continues with
  Accessibility text only.
- Pausing or stopping FoxyCo, swiping its task away, or revoking Accessibility
  cancels pending OCR results. Protected or unavailable screens produce no OCR
  result.

## What leaves your device

FoxyCo contacts Google Firebase on first launch, before a trial is started:

1. **Anonymous identity.** Firebase Authentication assigns the installation a
   random user ID. No name or email is attached at this stage. Google also
   processes the ordinary technical metadata needed to provide and secure the
   service: Firebase Authentication documents IP addresses and user-agent
   strings for security and abuse prevention. This identity exists so it can
   later be linked to one trial account and to prevent trial abuse.
2. **Google account identity, if you start a trial or choose account sign-in.**
   When you tap "Start trial" or use Profile's sign-in option to restore/check a
   prior trial, you sign in with Google.
   Firebase Authentication receives your Google account identifier and email
   address so that one trial belongs to one account.
3. **Trial start timestamp, if a trial is started.** A single record is written to Cloud Firestore
   containing your account's user ID and the server time your trial began.
   Nothing else. This record is what stops the trial from restarting when the app
   is reinstalled or moved to a new phone.

These are processed by Google (Firebase) as our data processor. See
[Firebase privacy and security](https://firebase.google.com/support/privacy/)
and [Google's Privacy Policy](https://policies.google.com/privacy).

**Purchases** are handled entirely by Google Play. We never see or receive your
payment card, billing address or any financial data. FoxyCo asks Google Play
whether your account owns the unlock, and receives a yes or no.

**Feedback is sent only when you choose Send feedback and confirm an external
email or sharing app.** FoxyCo includes your description, feedback category,
app version, Android version and device model. You may select up to three
screenshots with Android's system photo picker; FoxyCo does not request access
to your whole photo library. Selected images are copied to FoxyCo's private
cache so they can be attached, then removed after 24 hours when the app next
starts. Screenshots can contain personal, trip or earnings information, so the
app asks you to review them first. Diagnostic logs are never attached
automatically. The external app you choose handles the message under its own
privacy terms.

## What FoxyCo never collects

- No location data. FoxyCo does not request location permission.
- No advertising identifiers, no ad networks, no ad SDKs.
- No analytics or crash-reporting SDK. Firebase Analytics is not included.
- No contacts, microphone, camera or call data. FoxyCo can read only the
  screenshots you select for feedback through Android's system photo picker.
- No automatic upload of earnings totals, offer history or driving behaviour.
  We receive these only if you deliberately include them in feedback, a
  screenshot or shared diagnostic logs.

## Legal basis (UK/EU users)

Where GDPR applies, we rely on **legitimate interests** for the minimal
anonymous-authentication processing used to secure the service and prevent
repeated free trials, and **performance of a contract** for the Google identity
and timestamp used to provide a trial you request. There is no processing for
marketing, profiling or automated decision-making with legal effect. These
bases are described in [GDPR Article 6](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32016R0679).

## How long we keep it

The trial record is kept for as long as the app is offered, because its whole
purpose is to be permanent — a trial that expires from our records is a trial
that can be restarted forever. It contains a random user ID and a timestamp.

## Deleting your data

Open **Settings → Profile → Access → Delete my account** in the app. This
deletes your Firebase Authentication account, including the email address
associated with it.

The trial timestamp row is deliberately retained. After your account is deleted
FoxyCo's live records contain only a random identifier and a date, with no email
attached. To request deletion of both records, follow the
[web deletion instructions](delete-account.html) **before** deleting the account
in the app, while the verified email-to-ID link still exists.

Data held only on your phone is deleted by uninstalling the app or clearing its
storage.

## Children

FoxyCo is a tool for working gig drivers and is not directed at children under
13 (or under 16 where local law sets that age). We do not knowingly collect data
from them.

## Security

Traffic to Firebase uses TLS. The trial record is protected by server-side
security rules that permit each account to read and create only its own record,
and permit no updates or deletions by any client. Release builds are code-shrunk
and obfuscated.

## Changes

If this policy changes materially, the updated version will be posted here with
a new date, and the change will be noted in the app's release notes.

## Contact

**foxyco.dev@gmail.com**
