# Closed testers, recruitment and production release

## Links to verify before posting

Create or open the Google Group and confirm that outside users can join it:

1. Group: <https://groups.google.com/g/foxyco-testers>
2. Opt in: <https://play.google.com/apps/testing/com.foxyco.app>
3. Store listing: <https://play.google.com/store/apps/details?id=com.foxyco.app>

Always post the Group link first and the opt-in link second. The opt-in page
will reject someone who is not yet on the tester list. In Play Console, Closed
testing → Testers must contain `foxyco-testers@googlegroups.com`. Internal
testing does not count toward the production-access gate.

## Ordered closed-test checklist

1. Upload the latest bumped AAB to Internal, verify it, then promote that same
   release to Closed testing.
2. Confirm the one-time product and its only purchase option are Active.
3. Confirm the group is self-joinable and connected to the closed track.
4. Test the three links above in a browser/account that is not the Play Console
   owner.
5. Recruit 16–20 people. Google requires at least 12 opted-in testers for 14
   consecutive days; extra people protect the clock from dropouts.
6. Ask testers to keep the app installed, open it several times, test the trial
   and submit feedback. Follow up around days 3, 7 and 12.
7. On day 15, collect evidence: tester count/date screenshots, feedback notes,
   fixes shipped and accessibility disclosure video. Use it in the production
   access questionnaire.

## Required disclosure in every recruitment post

- Android only.
- FoxyCo uses a read-only accessibility service to read selected supported-app
  offer text and show an on-screen verdict. DoorDash, Instacart and Skip are
  Beta and off by default.
- It never taps Accept/Decline and provides no automation.
- Offer details and History stay on the phone.
- Internet is used for Google trial sign-in and Play purchase checks.
- FoxyCo is independent and is not affiliated with any supported gig platform.

Check each community's self-promotion and research rules before posting. Ask a
moderator first where required. Do not spam the same text repeatedly.

## Reddit / driver-forum post

> **[Android] Looking for closed testers for a read-only ride-offer analyzer**
>
> I built FoxyCo for Uber, Lyft, Hopp and delivery drivers. It reads the offer card shown
> on your phone and displays pay per distance/hour, pickup distance and a
> driver-set GOOD/OK/BAD verdict. It is read-only: it never accepts or declines
> a trip, and offer details/history stay on the phone.
>
> Android closed-test steps:
> 1. Join the tester group: https://groups.google.com/g/foxyco-testers
> 2. Opt in: https://play.google.com/apps/testing/com.foxyco.app
> 3. Install from the Play link and keep it installed for 14 days.
>
> The app uses Accessibility only to read offer text and draw its verdict. It
> uses internet for Google trial sign-in and Play purchase checks. FoxyCo is
> independent and not affiliated with Uber, Lyft, Hopp, DoorDash, Instacart or
> Skip. I would especially
> value screenshots/logs when an offer is missed or parsed incorrectly.

Good candidates include local driver communities and
`r/AndroidClosedTesting`; check the rules of Uber/Lyft/courier subreddits before
posting because many prohibit promotion.

## Facebook group post

> Hi drivers — I am looking for Android testers for FoxyCo, a read-only app
> that calculates offer pay per km/mi or hour and shows a GOOD/OK/BAD verdict.
> It does not auto-accept or control any gig app. Offer data remains on
> the phone. Please join the Google tester group first, then opt in:
>
> 1. https://groups.google.com/g/foxyco-testers
> 2. https://play.google.com/apps/testing/com.foxyco.app
>
> Please keep it installed for 14 days and tell me about any missed/wrong card.
> Accessibility is used only to read visible offer text; internet is used for
> trial sign-in and Play purchase checks. Independent, no platform affiliation.

## WhatsApp / Telegram message

> Can you help test my Android driver app for 14 days? Join this group first:
> https://groups.google.com/g/foxyco-testers — then opt in here:
> https://play.google.com/apps/testing/com.foxyco.app. FoxyCo reads visible
> selected supported-app offer text and shows a verdict; it never auto-accepts
> and keeps
> offer data on the phone. Internet is only for trial sign-in/purchase checks.

## Direct message

> Would you be willing to test FoxyCo on Android? It takes about two minutes to
> join: first https://groups.google.com/g/foxyco-testers, then
> https://play.google.com/apps/testing/com.foxyco.app. Please keep it installed
> for 14 days and send me any incorrect/missed offer screenshot. It uses a
> read-only accessibility service, never taps driver-app controls, and stores
> offer details locally.

## Feedback questions

Ask testers for concrete observations:

1. Phone model, Android version, driver app and whether offers use km or mi.
2. Did trial sign-in/restore work, especially with multiple Google accounts?
3. Did the verdict appear before the offer expired and avoid important buttons?
4. Were payout, bonus, pickup, total distance/time and ride type correct?
5. After Accept/Decline, did History say Taken, Not taken or Unconfirmed?
6. Did the service stop, drain battery, show a gray window or obstruct taps?
7. What was confusing enough that they would uninstall?

Never request rider names, exact addresses, screenshots containing personal
information, account credentials or payment details. Ask testers to crop or
redact sensitive data.

## Production-access evidence

In the questionnaire, state what testers actually tested, summarize recurring
feedback and name the fixes made. Keep screenshots of 12+ continuous opt-ins,
dated feedback, release notes and the consent video. Do not describe inactive
friends as engaged testers. Before submission, re-check Data safety and the
accessibility declaration against the shipped build, including Google account
trial data and the `INTERNET` permission.
