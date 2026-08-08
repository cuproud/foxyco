---
title: FoxyCo — Delete your account and data
---

# Delete your FoxyCo account and data

**Last updated: 7 August 2026**

This page exists because Google Play requires a publicly reachable account
deletion route for any app that collects an account. It applies to the FoxyCo
Android app (`com.foxyco.app`).

## What FoxyCo holds

| Where | What | How to delete |
|---|---|---|
| Firebase Authentication | Your Google account identity and email, created when you start a free trial or choose account sign-in | In-app, or by request while the account still exists (below) |
| Cloud Firestore | One row: a random user ID and the date your trial started | By request before using in-app deletion (below), or retained de-identified for trial-abuse prevention |
| Your phone only | Offer history, settings, garage, reminders, local logs | Uninstall the app, or clear its storage |

FoxyCo stores no location data, no earnings data and no payment data on any
server. Purchases are held by Google Play, not by us.

## Option 1 — delete it in the app (fastest)

1. Open FoxyCo.
2. Go to **Settings → Unlock**.
3. Tap **Delete my account** and confirm.

This deletes your Firebase Authentication account, including the email address
attached to it. You may be asked to sign in again first if it has been a while —
that is a security check by Google, not an error.

**What this leaves behind:** the single trial-start row. Once your account is
deleted, FoxyCo's live records hold that row as a random identifier plus a date,
with no email attached. It is kept so that a used free trial cannot be restarted
indefinitely.

## Option 2 — ask us to delete both server records

Use this option **before** deleting the account in the app. Email
**foxyco.dev@gmail.com** from the Google account you signed into FoxyCo with,
with the subject **"Delete my FoxyCo data"**. While the Authentication account
still exists, we can use that verified email to locate its random user ID and
delete both the Authentication account and trial row.

We will confirm within 7 days and complete the deletion within 30 days.

After in-app deletion, FoxyCo's live Authentication records no longer provide
the email-to-ID link used by this request process. The remaining random ID and
timestamp are kept only to prevent repeated free trials and contain no offer
data.

## Deleting the data on your phone

Uninstall FoxyCo, or open **Android Settings → Apps → FoxyCo → Storage → Clear
storage**. This removes your offer history, settings, garage, reminders and
local logs. It does not cancel or refund a purchase — a purchase belongs to your
Google Play account and can be restored.

## A note on purchases

Deleting your account does not delete or refund a FoxyCo purchase. The lifetime
unlock is owned by your Google Play account. To request a refund, use
[Google Play's refund process](https://support.google.com/googleplay/answer/2479637).

## Contact

**foxyco.dev@gmail.com**
