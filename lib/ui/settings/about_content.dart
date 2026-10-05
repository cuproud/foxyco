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
const aboutVersion = '1.0.19 (build 125)';

const aboutSections = <AboutSection>[
  AboutSection(
    title: 'Using FoxyCo',
    entries: [
      AboutEntry(
        'What does FoxyCo do?',
        'Go live on Home to read offers from the apps selected in Settings → Offer '
            'detection. Choose up to three supported apps: Uber, Lyft, Hopp, DoorDash, '
            'Instacart and Skip. Delivery detection is in beta. FoxyCo calculates '
            'rates, applies your Rules and shows GOOD, OK or BAD in a floating pill. '
            'You still accept or decline in the driver app yourself.',
      ),
      AboutEntry(
        'Can FoxyCo tap or accept offers for me?',
        'No. FoxyCo reads offers, calculates rates and shows a verdict. It does not '
            'request permission to perform gestures or press buttons in driver apps. '
            'Every accept and decline is yours.',
      ),
      AboutEntry(
        'How are GOOD, OK and BAD decided?',
        'In Rules, set separate rideshare and delivery thresholds for distance '
            'rate, hourly rate and minimum payout. Below the minimum payout is BAD. '
            'Otherwise the selected rate mode compares the offer with your GOOD and BAD '
            'thresholds; values between them are OK. Hourly mode falls back to distance '
            'rate when the offer has no time estimate.',
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
        'With Auto-detect outcome enabled in Settings, explicit trip or pickup '
            'screens in Uber, Lyft and Hopp can mark an offer as accepted. A clearly '
            'recognized return to browsing can mark it as missed. Ambiguous screens '
            'stay unmarked. Delivery apps do not currently have automatic accepted-trip '
            'detection. Correct outcomes in History; automatic tracking never '
            'overwrites your manual choice.',
      ),
      AboutEntry(
        'How does pickup distance affect a verdict?',
        'Set the pickup distance you consider near in Rules. The pickup indicator '
            'changes colour for longer pickups. This indicator does not change the '
            'GOOD, OK or BAD verdict by itself.',
      ),
    ],
  ),
  AboutSection(
    title: 'Home & sessions',
    entries: [
      AboutEntry(
        'How do I start, pause or stop Watching?',
        'Complete the permissions setup, then slide to go live on Home. '
            'Long-press the bubble to pause or resume. Slide back on Home to '
            'stop, end the session and remove the overlay. Session summaries '
            'are available in History.',
      ),
      AboutEntry(
        'How do earnings goals stay up to date?',
        'Home goals use recorded earnings for the selected goal period. '
            'Accepted offers use their offered payout until a final payout is '
            'saved. Final payouts and completed manual entries update the total. '
            'Cancelled jobs contribute only their saved cancellation fee.',
      ),
    ],
  ),
  AboutSection(
    title: 'History & earnings',
    entries: [
      AboutEntry(
        'Can I add a trip or delivery manually?',
        'Use Add trip or delivery in History for a completed job that was not '
            'captured. Enter the platform, payout, distance, minutes and date. '
            'Manual jobs count toward earnings and completed jobs, but do not '
            'inflate captured-offer or acceptance statistics.',
      ),
      AboutEntry(
        'How do fare, tip and toll reimbursement work?',
        'Final earnings prefills the offered fare when no final payout exists. '
            'The first field is Fare before tip: keep it or edit it, then enter '
            'the tip separately. The tip is added once. Toll reimbursement is '
            'already part of the entered fare; it is excluded from performance '
            'rates rather than added again.',
      ),
      AboutEntry(
        'Can I correct an outcome or distance?',
        'Open the offer in History to correct its outcome or distance and save '
            'final earnings. Manual outcomes are preserved. A cancelled job '
            'uses its cancellation fee, including zero, instead of its '
            'original fare and is excluded from trip performance rates.',
      ),
    ],
  ),
  AboutSection(
    title: 'Garage & income',
    entries: [
      AboutEntry(
        'What does Total income include?',
        'The Income chart uses recorded earnings from History for the displayed '
            'week, month, quarter or year. Final payouts replace offered '
            'estimates; completed manual jobs and cancellation fees are '
            'included. Editing History updates the report. Expenses are '
            'shown separately and are not drawn in the income chart.',
      ),
      AboutEntry(
        'What does the percentage beside income compare?',
        'It compares the entire displayed period with the previous period: '
            'week versus previous week, month versus previous month, and '
            'likewise for quarter and year. Selecting a bar changes its value '
            'bubble, not that period comparison. If the previous period has '
            'no income, no percentage is calculated.',
      ),
      AboutEntry(
        'What are Final, Estimated and Report balance?',
        'Final is saved actual earnings. Estimated is the offered payout for '
            'accepted jobs still waiting for final earnings. Payouts combines '
            'them. Report balance is payouts minus recorded vehicle expenses '
            'for the displayed period.',
      ),
      AboutEntry(
        'How do I manage vehicles and running costs?',
        'Use the plus icon in the vehicle heading to add a car. The active '
            'vehicle stays first; expand Other vehicles to switch cars. Cards '
            'show brand/model, type and saved colour, then plate and year. '
            'Record costs under Vehicle expenses and manage care reminders '
            'in Garage.',
      ),
    ],
  ),
  AboutSection(
    title: 'Preferences',
    entries: [
      AboutEntry(
        'Can I change the bubble, text size and theme?',
        'Settings → Look & feel contains Pill size, Text size and Appearance. '
            'Choose the bubble style, theme and money typeface there. These '
            'display choices do not change offer rates or verdict rules.',
      ),
      AboutEntry(
        'Does changing currency convert my earnings?',
        'No. Offer currency labels fares as reported; it does not convert '
            'amounts or exchange rates. USD defaults to miles and the other '
            'currency choices default to kilometres. Override Distance in '
            'Appearance if needed and review your Rules thresholds.',
      ),
      AboutEntry(
        'Does resetting preferences delete History?',
        'Reset preferences and Clear all history are separate actions in '
            'Settings. Reset preferences restores the app settings. Use '
            'Clear all history to remove offers and session summaries. Export '
            'an offer backup first; session summaries are not backed up.',
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
        'Offer reading, scoring and local history work on your phone without a '
            'network. Starting or restoring a trial and buying or restoring lifetime '
            'access need a connection. Cached trial or purchase verification has a '
            '7-day offline grace window; this does not extend the 7-day trial itself. '
            'If FoxyCo warns that verification is getting stale, reconnect and open the '
            'app to refresh access.',
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
        'On this device: your profile name, preferences, offer history, session '
            'summaries, earnings goals, vehicles, expenses and reminders. Firebase '
            'creates a random app identity on first launch. If you start or restore a '
            'trial, it also stores your Google account identity and one server-stamped '
            'trial start time. Google Play handles purchases; FoxyCo never receives '
            'card details. Set offer retention or clear history in Settings → History.',
      ),
      AboutEntry(
        'Why does it need the accessibility permission?',
        'Accessibility provides offer text from selected supported driver apps. '
            'Google Maps and Waze window-state events also help refresh the floating '
            'bubble after navigation handoff; their screen text, content nodes and '
            'screenshots are not used for offer detection. FoxyCo does not read your '
            'browser, messages or banking apps.',
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
        'Raw screen text is used briefly in memory and is never saved or uploaded. '
            'Extracted pay, distance, duration, platform and verdict are stored in '
            'private local history. Firebase never receives offer text, offer history '
            'or earnings. If you choose to export a backup or send feedback, the file '
            'or screenshots you select can leave the phone through the sharing or email '
            'app you confirm.',
      ),
      AboutEntry(
        'How do I back up or restore offer history?',
        'In Settings → History, choose Export history backup. Import history backup '
            'validates the file, then offers Merge or Replace. Manual entries, manual '
            'outcomes, final payouts and scoring details are preserved. Preferences, '
            'session summaries, goals, vehicles, expenses and reminders are not '
            'included. Keep exported files somewhere private.',
      ),
    ],
  ),
  AboutSection(
    title: 'Troubleshooting',
    entries: [
      AboutEntry(
        'The pill never appears',
        'Check Accessibility and Display over other apps in Settings, select your '
            'driver apps under Offer detection, and go live on Home. Check Profile → '
            'Access if the verdict is locked. If the offer appears in History, capture '
            'worked and the problem is likely overlay display or access. If it never '
            'appears in History, check detection and report the missed offer.',
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
        'Check that the app is selected in Settings → Offer detection. Needs update '
            'may indicate a changed offer layout. Delivery detection is in beta, and '
            'some cards may not expose enough information. Use Report a missed offer '
            'with the platform and a useful screenshot so the reader can be '
            'investigated.',
      ),
      AboutEntry(
        'The pill stays up after I leave the gig app',
        'The temporary verdict normally expires after five seconds and may clear '
            'sooner when the card is confirmed gone. The resting bubble remains while '
            'Watching is active. Maps and Waze handoffs also trigger bubble recovery, '
            'with a follow-up attempt around 30 seconds later when no verdict is '
            'showing. If a visual patch persists, stop Watching and start again; '
            'device-specific recovery still needs checking.',
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
