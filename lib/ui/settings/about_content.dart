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
    'FoxyCo reads the offer card on your screen, scores it against the numbers '
    'you set, and shows you a verdict — good, ok, or bad — before you decide. '
    'That is the whole job. It never touches the offer itself.';

/// Version string. Kept as a plain const rather than adding a native plugin for
/// one label; `about_content_test.dart` guards it against `pubspec.yaml` drift.
const aboutVersion = '1.0.0 (build 6)';

const aboutSections = <AboutSection>[
  AboutSection(
    title: 'How it works',
    entries: [
      AboutEntry(
        'What FoxyCo actually does',
        'While the watcher is live, FoxyCo reads the text of the offer card '
            'showing in Uber Driver, Hopp or Lyft. It works out the pay per '
            'kilometre (or per hour, your choice), compares that to your '
            'thresholds, and paints a floating pill green, amber or red. You '
            'still accept or decline the offer yourself, exactly as before.',
      ),
      AboutEntry(
        'Does it ever tap for me?',
        'No. FoxyCo cannot press anything in the gig apps — it never requests '
            'the permission that would let it. It reads, scores and shows. '
            'Every accept and decline is yours. This is deliberate: '
            'auto-accepting would breach the gig apps\' terms and put your '
            'account at risk.',
      ),
      AboutEntry(
        'Where do good / ok / bad come from?',
        'From Settings. You set the rate at or above which an offer counts as '
            'good, and the rate below which it counts as bad; everything '
            'between the two is ok. Switch between \$/km and \$/hr in Settings '
            '— each mode keeps its own pair of numbers, since the scales are '
            'about twenty times apart.',
      ),
      AboutEntry(
        'Is FoxyCo made by Uber, Lyft or Hopp?',
        'No. FoxyCo is an independent app, not affiliated with, authorised by '
            'or endorsed by any of them — those are their own companies and '
            'trademarks. FoxyCo just reads what is already on your screen and '
            'does the arithmetic you would otherwise do in your head.',
      ),
      AboutEntry(
        'What is the pickup distance for?',
        'Dead mileage. An offer that pays well but starts far away is worth '
            'less than it looks. Set the distance you consider "near" and the '
            'pill colours the trip distance accordingly.',
      ),
    ],
  ),
  AboutSection(
    title: 'Trial & lifetime unlock',
    entries: [
      AboutEntry(
        'Is FoxyCo a subscription?',
        'No. The paid option is one non-consumable Google Play purchase that '
            'unlocks FoxyCo for life. There is no monthly or annual renewal. '
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
        'Why do I sign in with Google?',
        'Only to keep one trial start date attached to the same account. '
            'FoxyCo does not use the account for ads or analytics. Your Google '
            'email appears in Settings → Profile so you can see which account '
            'is active.',
      ),
      AboutEntry(
        'What happens if I log out?',
        'Your name, settings, garage and offer history stay on this phone. You '
            'must sign into the same Google account again to use any remaining '
            'trial days. A lifetime unlock remains owned by your Play account.',
      ),
      AboutEntry(
        'How do I restore a purchase?',
        'Open Settings → Unlock and tap Restore purchase while Google Play is '
            'using the account that bought FoxyCo. Promo-code unlocks restore '
            'the same way.',
      ),
      AboutEntry(
        'I was given a code — how do I use it?',
        'Open Settings → Unlock and tap Redeem code. That opens Google Play, '
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
        'Yes. Open Settings → Unlock → Delete my account. FoxyCo removes the '
            'Firebase Auth account. It keeps only a random user ID and the '
            'trial start time to limit trial abuse; that retained row does not '
            'contain your email or offer data.',
      ),
    ],
  ),
  AboutSection(
    title: 'Privacy',
    blurb:
        'Offer text, history, garage data and settings stay on your phone. '
        'Firebase stores only the identity and timestamp needed for the trial. '
        'There is no Firebase Analytics. The full Privacy Policy and Terms are '
        'linked at the bottom of this screen.',
    entries: [
      AboutEntry(
        'What gets stored?',
        'On this device: your name, settings, garage, reminders and offer '
            'history. In Firebase after you start a trial: your Google-backed '
            'account identity and one server-stamped trial start time. Google '
            'Play handles purchases; FoxyCo never receives card details. You '
            'can set how long offers are kept or clear them in Settings.',
      ),
      AboutEntry(
        'Why does it need the accessibility permission?',
        'It is the only way on Android to read what another app is drawing on '
            'screen. FoxyCo asks for the narrowest version of it: read-only, '
            'and scoped to the three gig apps, so it is not woken by anything '
            'else you do on your phone.',
      ),
    ],
  ),
  AboutSection(
    title: 'Troubleshooting',
    entries: [
      AboutEntry(
        'The pill never appears',
        'Check both permissions first — Settings shows them at the top, and '
            'the slide control says "Grant access" when either is missing. '
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
        'Open Parser health in Settings. If an app shows misses with no '
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
        'Settings → Logs keeps a running record of what the watcher saw and '
            'did. Copy it to the clipboard from there — it is the fastest way '
            'to show what went wrong.',
      ),
    ],
  ),
];
