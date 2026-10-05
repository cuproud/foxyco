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

const aboutIntro = 'Your drive. Your rules.';

/// Guarded against pubspec drift by about_content_test.dart.
const aboutVersion = '1.0.19 (build 128)';

const aboutSections = <AboutSection>[
  AboutSection(
    title: 'Using FoxyCo',
    entries: [
      AboutEntry(
        'What does FoxyCo do?',
        'Reads offers from your selected driver apps, applies your Rules and '
            'shows GOOD, OK or BAD. You accept or decline in the driver app '
            'yourself.',
      ),
      AboutEntry(
        'Which apps can I watch?',
        'Choose up to three in Rules → Watched apps: Uber, Lyft, Hopp, '
            'DoorDash, Instacart and Skip. Delivery detection is in beta.',
      ),
      AboutEntry(
        'How are verdicts decided?',
        'Rules has separate rideshare and delivery thresholds. Offers below '
            'minimum payout are BAD. Otherwise the selected distance or hourly '
            'rate determines the verdict. Hourly mode uses distance when no time '
            'estimate is available. Pickup distance changes its indicator only.',
      ),
      AboutEntry(
        'Can FoxyCo accept offers?',
        'No. FoxyCo never taps or controls driver apps and does not request '
            'gesture permission. It is independent and is not affiliated with or '
            'endorsed by a gig platform.',
      ),
    ],
  ),
  AboutSection(
    title: 'Home & History',
    entries: [
      AboutEntry(
        'How do I start or stop Watching?',
        'Slide to go live on Home. Long-press the bubble to pause or resume; '
            'slide back on Home to stop. The bubble hides when the phone is '
            'locked.',
      ),
      AboutEntry(
        'How do goals update?',
        'Goals use recorded earnings for their calendar period. The weekly '
            'goal resets on Monday. Accepted jobs use offered pay until final '
            'earnings are saved; manual jobs and cancellation fees also '
            'contribute.',
      ),
      AboutEntry(
        'Can I add a completed job?',
        'Use Add trip or delivery in History. Enter the platform, payout, '
            'distance, minutes and date. Manual jobs count toward earnings '
            'without inflating captured-offer or acceptance statistics.',
      ),
      AboutEntry(
        'How do I enter fare and tip?',
        'Fare before tip starts with the offered fare. Keep or edit it, then '
            'enter the tip separately; the tip is added once. Toll reimbursement '
            'is already included in the fare and is excluded from performance '
            'rates.',
      ),
      AboutEntry(
        'Can I correct a job?',
        'Open its History entry to edit the outcome, distance or final '
            'earnings. Manual outcomes are preserved. Cancelled jobs contribute '
            'only their saved cancellation fee, including zero.',
      ),
      AboutEntry(
        'How are outcomes detected?',
        'Auto-detect outcome uses clear trip screens in Uber, Lyft and Hopp. '
            'Ambiguous screens stay unmarked; delivery acceptance is not '
            'automatically detected. Correct outcomes in History or turn tracking '
            'off in Settings.',
      ),
    ],
  ),
  AboutSection(
    title: 'Garage & income',
    entries: [
      AboutEntry(
        'What does income include?',
        'Recorded earnings from History for the displayed week, month, '
            'quarter or year. Final payouts replace estimates; manual jobs and '
            'cancellation fees are included. History edits update the chart. '
            'Expenses are separate; report balance is payouts minus expenses.',
      ),
      AboutEntry(
        'What does the percentage compare?',
        'The displayed period versus the previous week, month, quarter or '
            'year. Selecting a bar changes its value bubble. No percentage is '
            'calculated when the previous period has no income.',
      ),
      AboutEntry(
        'How do I manage vehicles?',
        'Use the header plus to add a car. The active car stays first; expand '
            'Other vehicles to switch. Record running costs under Vehicle '
            'expenses and care dates under Maintenance reminders.',
      ),
    ],
  ),
  AboutSection(
    title: 'Preferences',
    entries: [
      AboutEntry(
        'Can I change the look?',
        'Settings → Look & feel has Pill size, Text size and Appearance. '
            'Choose a bubble, theme or money font without changing your verdict '
            'rules.',
      ),
      AboutEntry(
        'Does currency convert earnings?',
        'No. It labels reported amounts without currency conversion. USD '
            'defaults to miles; other currencies default to kilometres. Override '
            'Distance in Appearance and review your Rules thresholds.',
      ),
      AboutEntry(
        'Does a reset delete History?',
        'Reset preferences keeps History. Clear all history deletes offers '
            'and session summaries. Export an offer backup first if needed; '
            'session summaries are not backed up.',
      ),
    ],
  ),
  AboutSection(
    title: 'Access & billing',
    entries: [
      AboutEntry(
        'Is FoxyCo a subscription?',
        'No. One Google Play purchase unlocks FoxyCo for life. There is no '
            'monthly or annual renewal. Play shows the local price before you '
            'confirm.',
      ),
      AboutEntry(
        'How does the trial work?',
        'Tap Start trial to begin seven days of full verdict access without a '
            'card. Google sign-in preserves the start date across reinstalling or '
            'changing phones.',
      ),
      AboutEntry(
        'How do I restore access?',
        'Settings → Profile → Access has Restore purchase and Redeem code. '
            'Use the Google Play account that owns the purchase. After redeeming '
            'a code in Play, return here and restore if needed.',
      ),
      AboutEntry(
        'What happens when I sign out?',
        'Local settings and history stay on this phone. Sign into the same '
            'Google account for remaining trial days. Lifetime purchases are '
            'owned separately by your Google Play account.',
      ),
      AboutEntry(
        'Can I use FoxyCo offline?',
        'Offer detection and local history work offline. Trials and purchases '
            'need an online check. Cached verification has a seven-day grace '
            'window; it does not extend the trial. Reconnect if FoxyCo asks to '
            'refresh access.',
      ),
      AboutEntry(
        'Can I delete my account?',
        'Settings → Profile → Access → Delete my account removes your '
            'Firebase account. Only the random user ID and trial start time are '
            'retained to prevent repeat trials; no email or offer data remains in '
            'that row.',
      ),
    ],
  ),
  AboutSection(
    title: 'Privacy',
    blurb: 'No Firebase Analytics. Offer history stays on this phone.',
    entries: [
      AboutEntry(
        'What gets stored?',
        'History, sessions, goals, preferences and Garage data stay locally. '
            'Firebase stores an app identity and, for trials, Google identity and '
            'one server-stamped trial start time. Raw screen text is used briefly '
            'in memory. Firebase never receives offer text, history or earnings.',
      ),
      AboutEntry(
        'Why Accessibility?',
        'It reads offers from selected driver apps. Google Maps and Waze '
            'window events refresh the bubble only; navigation content nodes, '
            'text and screenshots are not used for detection. Browser, message '
            'and banking content is not read.',
      ),
      AboutEntry(
        'How does Uber OCR work?',
        'Selecting Uber enables on-device OCR on Android 11+. A watched-app '
            'event can trigger one screenshot for an inaccessible or overlapping '
            'Uber card. It is recognized in memory, cleared immediately and never '
            'saved or uploaded. There is no continuous recording.',
      ),
      AboutEntry(
        'How do backups work?',
        'Settings → History lets you export and import an offer backup, with '
            'Merge or Replace. It includes manual entries, outcomes and final '
            'earnings. Sessions, preferences, goals and Garage data are excluded.',
      ),
      AboutEntry(
        'What does feedback share?',
        'Only the message, diagnostics and screenshots you choose, through '
            'the email or sharing app you confirm. Exported backups can also '
            'leave the phone if you share them.',
      ),
    ],
  ),
  AboutSection(
    title: 'Troubleshooting',
    entries: [
      AboutEntry(
        'Why is no verdict showing?',
        'Check Accessibility, Display over other apps, selected apps and '
            'Watching status. Check Profile → Access if the verdict is locked. An '
            'entry in History means capture worked; a missing entry points to '
            'detection.',
      ),
      AboutEntry(
        'Why did Watching stop?',
        'Android may stop the service to save battery. Exclude FoxyCo from '
            'battery optimisation, reopen it and check permissions. Report missed '
            'offers from Settings → Offer detection.',
      ),
      AboutEntry(
        'Why is the bubble still visible?',
        'The verdict normally expires after five seconds; the resting bubble '
            'remains while Watching. Maps/Waze handoffs trigger recovery, with a '
            'retry around 30 seconds later when no verdict is showing. Stop and '
            'restart Watching if a patch persists.',
      ),
      AboutEntry(
        'How do I get help?',
        'Settings → Send feedback for problems or missed offers. Add useful '
            'screenshots only. Diagnostic logs provides technical details if '
            'support requests them.',
      ),
    ],
  ),
];
