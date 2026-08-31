/// Everything the About screen says, as plain data.
///
/// Kept apart from the widget on purpose: adding an FAQ entry or a
/// troubleshooting step should be one entry in a list here, with no widget code
/// touched and nothing to lay out. `about_screen.dart` renders whatever this
/// file contains.
library;

/// One expandable question/answer.
class AboutEntry {
  const AboutEntry(this.question, this.answer);
  final String question;
  final String answer;
}

/// A titled group of entries.
class AboutSection {
  const AboutSection({
    required this.title,
    required this.entries,
    this.blurb = '',
  });

  final String title;

  /// Optional plain paragraph shown above the entries.
  final String blurb;
  final List<AboutEntry> entries;
}

/// Shown at the top of the screen, above the sections.
const aboutIntro =
    'FoxyCo reads offer-related text in your watched gig apps, scores each '
    'offer using your rules, and shows a verdict. Raw screen text never leaves '
    'your phone. FoxyCo never taps buttons or changes anything in a driver app.';

/// Version string. Kept as a plain const rather than adding a native plugin for
/// one label; `about_content_test.dart` guards it against `pubspec.yaml` drift.
const aboutVersion = '1.0.14 (build 102)';

const aboutSections = <AboutSection>[
  AboutSection(
    title: 'Using FoxyCo',
    entries: [
      AboutEntry(
        'What does FoxyCo do?',
        'While the watcher is live, FoxyCo uses screen text from your enabled '
            'gig apps only to detect and score offers and, '
            'if enabled, infer whether an offer was taken or passed. It works '
            'out the pay per '
            'kilometre, mile (or per hour, your choice), compares that to your '
            'thresholds, and paints a floating pill green, amber or red. You '
            'still accept or decline the offer yourself, exactly as before.',
      ),
      AboutEntry(
        'Can FoxyCo tap or accept offers for me?',
        'No. FoxyCo cannot press anything in the gig apps — it never requests '
            'the permission that would let it. It reads, scores and shows. '
            'Every accept and decline is yours. This is deliberate: '
            'auto-accepting would breach the gig apps\' terms and put your '
            'account at risk.',
      ),
      AboutEntry(
        'How are GOOD, OK and BAD decided?',
        'From My Rules. You set the rate at or above which an offer counts as '
            'good, and the rate below which it counts as bad; everything '
            'between the two is ok. Switch between distance rate and \$/hr in My Rules '
            '— each mode keeps its own pair of numbers, since the scales are '
            'about twenty times apart.',
      ),
      AboutEntry(
        'Is FoxyCo affiliated with a gig platform?',
        'No. FoxyCo is an independent app, not affiliated with, authorised by '
            'or endorsed by the gig apps it can watch. Their names and '
            'trademarks belong to their respective companies. FoxyCo just '
            'reads what is already on your screen and does the arithmetic you '
            'would otherwise do in your head.',
      ),
      AboutEntry(
        'Does the bubble show on my lock screen?',
        'No. FoxyCo hides the bubble and the pill whenever the screen goes off '
            'or the phone is locked, and brings them back when you unlock. An '
            'offer shown only while the phone is locked may not be read.',
      ),
      AboutEntry(
        'How does FoxyCo detect accepted offers?',
        'It infers it. When the offer card leaves the screen, FoxyCo looks at '
            'what replaced it: a trip screen means taken, the browse or map '
            'screen means passed. It works even if you accept in one app while '
            'watching another. If neither is clear, the offer stays unmarked '
            'rather than guessing. You can turn this off in Settings.',
      ),
      AboutEntry(
        'How does pickup distance affect a verdict?',
        'A long unpaid pickup can make a good-looking offer less useful. Set '
            'the pickup distance you consider near, and the target changes '
            'colour when the pickup is farther away.',
      ),
    ],
  ),
  AboutSection(
    title: 'Access & billing',
    entries: [
      AboutEntry(
        'Is FoxyCo a subscription?',
        'No. One Google Play purchase unlocks FoxyCo for life. '
            'There is no monthly or annual renewal. '
            'Google Play shows the final price in your local currency before '
            'you confirm anything.',
      ),
      AboutEntry(
        'How does the 7-day trial work?',
        'The trial starts only when you choose Start trial. It turns on every '
            'verdict for 7 days and does not need a card. Google sign-in ties '
            'the start date to your account so reinstalling the app or moving '
            'to a new phone does not restart the clock.',
      ),
      AboutEntry(
        'Why sign in with Google?',
        'It protects your trial start date by linking it to the same Google '
            'account. FoxyCo does not use the account for ads or analytics. '
            'Lifetime access is managed separately by the Google Play account '
            'that owns the purchase.',
      ),
      AboutEntry(
        'What happens if I sign out?',
        'Your name, settings, garage and offer history stay on this phone. You '
            'must sign into the same Google account again to use any remaining '
            'trial days. Lifetime access remains owned by your Google Play '
            'account and stays active.',
      ),
      AboutEntry(
        'How do I restore a purchase?',
        'Open Settings → Profile → Access and tap Restore purchase while Google Play is '
            'using the account that bought FoxyCo. Promo-code unlocks restore '
            'the same way.',
      ),
      AboutEntry(
        'I was given a code — how do I use it?',
        'Open Settings → Profile → Access and tap Redeem code. That opens Google Play, '
            'where you enter the code; Play then grants the unlock to whichever '
            'Google account it is signed in with. Come back to FoxyCo and it '
            'picks the unlock up on its own — tap Restore purchase if it has '
            'not caught up yet. A code unlocks FoxyCo outright; it is not a '
            'discount applied at checkout, and it has no cash value.',
      ),
      AboutEntry(
        'Does FoxyCo need an internet connection?',
        'Not while you are driving. Reading offers, scoring them and showing '
            'the pill are all done on your phone with no network at all. '
            'FoxyCo does need to check in with Google roughly once a week to '
            'confirm your trial or purchase is still valid — it keeps working '
            'for 7 days between successful checks, and warns you a couple of '
            'days before that runs out. Open the app once with a signal and '
            'the clock resets.',
      ),
      AboutEntry(
        'Can I delete my FoxyCo account?',
        'Yes. Open Settings → Profile → Access → Delete my account. FoxyCo removes the '
            'Firebase Auth account. It keeps only a random user ID and the '
            'trial start time to limit trial abuse; that retained row does not '
            'contain your email or offer data.',
      ),
    ],
  ),
  AboutSection(
    title: 'Privacy',
    blurb:
        'Raw offer text is processed in memory and never saved or sent. Offer '
        'history, garage data and settings stay on your phone. '
        'Firebase creates a random app identity on first launch. If you start '
        'or restore a trial, it also stores your Google account identity and '
        'trial start time. '
        'There is no Firebase Analytics. The full Privacy Policy and Terms are '
        'linked at the bottom of this screen.',
    entries: [
      AboutEntry(
        'What gets stored?',
        'On this device: your name, settings, garage, reminders and offer '
            'history. Firebase creates a random app identity on first launch. '
            'If you start or restore a trial, it also stores your Google '
            'account identity and one server-stamped trial start time. Google '
            'Play handles purchases; FoxyCo never receives card details. You '
            'can set how long offers are kept or clear them in Settings.',
      ),
      AboutEntry(
        'Why does it need the accessibility permission?',
        'It is the only way on Android to read what another app is drawing on '
            'screen. FoxyCo only reads enabled gig apps, so it receives nothing '
            'from your browser, '
            'messages, banking apps or other apps. Supporting another driver '
            'app requires a FoxyCo update that explicitly adds it.',
      ),
      AboutEntry(
        'What is Uber screen-reading fallback?',
        'Optional OCR for Uber offer cards Android may hide from Accessibility. '
            'It turns on with Uber and off when Uber is unselected. Uber verdicts '
            'use OCR when the card text is otherwise unavailable, while '
            'other supported offers use Accessibility text only. '
            'Because Uber can draw a request over another selected driver app, '
            'that app\'s screen-change event may trigger one frame, but recognized '
            'text is accepted only by the Uber parser. If enabled, '
            'Android 11 and newer can take one Accessibility screenshot only '
            'after an active selected-app event that may correspond to a visible '
            'Uber offer. There is no '
            'continuous recording or screen-sharing session. The frame is '
            'recognized on-device, immediately cleared, and never saved, '
            'uploaded or written to FoxyCo logs. Accessibility remains enabled '
            'to receive watched-app events and provide screenshot access.',
      ),
      AboutEntry(
        'Does offer data leave my phone?',
        'No. Raw screen text is used briefly in memory and is never saved, '
            'uploaded or shared. Extracted pay, distance, duration, platform '
            'and verdict may be saved only in FoxyCo\'s private local history. '
            'Firebase never receives offer text, offer history or earnings.',
      ),
      AboutEntry(
        'How do I back up or restore offer history?',
        'In Settings → History, choose Export history backup to create a local '
            'file. Import history backup validates it first, then lets you Merge '
            'or Replace. Manual outcomes, final payouts, and scoring details '
            'are preserved; settings and session summaries are not included.',
      ),
    ],
  ),
  AboutSection(
    title: 'Troubleshooting',
    entries: [
      AboutEntry(
        'The pill never appears',
        'Check both permissions first — Settings shows them at the top, and '
            'the slide control says "Offer access required" when setup is incomplete. '
            'FoxyCo needs Accessibility (to read the offer) and Display over '
            'other apps (to draw the pill). Then make sure the watcher is '
            'actually live: the control should read "Live" with a pulsing dot.',
      ),
      AboutEntry(
        'It worked, then stopped mid-shift',
        'Android sometimes kills accessibility services to save power. Exclude '
            'FoxyCo from battery optimisation in your phone\'s settings, then '
            'reopen FoxyCo — it re-checks the permission every time you come '
            'back and will tell you if the service was dropped.',
      ),
      AboutEntry(
        'One app scores but another never does',
        'Open Offer detection in Settings. If an app shows misses with no '
            'successes, that app changed its offer screen and FoxyCo\'s reader '
            'needs updating — nothing you can fix from here, but the counter '
            'confirms it is the reader and not your thresholds.',
      ),
      AboutEntry(
        'The pill stays up after I leave the gig app',
        'It should clear within a few seconds. Because the reader is scoped to '
            'the gig apps, FoxyCo stops receiving anything at all once you '
            'switch away, so it treats that silence as "the card is gone" and '
            'drops the pill. If one lingers longer than that, long-press the '
            'bubble to go offline, or drag it to the ✕ at the bottom.',
      ),
      AboutEntry(
        'How do I get rid of the bubble?',
        'Drag it down onto the ✕ target, or slide the control on Home back to '
            'stop. Either one takes the watcher fully offline and removes the '
            'overlay.',
      ),
      AboutEntry(
        'Something else is wrong',
        'Open Settings → Send feedback and describe the problem. Add screenshots '
            'only if they help. If support asks for technical details, open '
            'Settings → Diagnostic logs.',
      ),
    ],
  ),
];
