import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/fox_tip.dart';

/// Local today, wire-ready later: the card only depends on this provider.
final tipsProvider = Provider<List<FoxTip>>(
  (ref) => const [
    FoxTip(
      category: TipCategory.earnings,
      headline: 'Find your best hours in History',
      body:
          'After a few shifts, check which hours brought your best offers. '
          'Your own results are more useful than general city advice.',
      asset: 'assets/tips/fox_tip_earnings.png',
    ),
    FoxTip(
      category: TipCategory.earnings,
      headline: 'Include the unpaid pickup distance',
      body:
          'A good-looking payout can turn into a bad one when the pickup is '
          'far away. FoxyCo includes that unpaid pickup distance in every '
          'verdict.',
      asset: 'assets/tips/fox_tip_earnings.png',
    ),
    FoxTip(
      category: TipCategory.earnings,
      headline: 'Surge can still be a bad offer',
      body:
          'Check the final dollars per kilometre or hour, not just the surge '
          'badge. A higher bonus can still hide a weak trip.',
      asset: 'assets/tips/fox_tip_earnings.png',
    ),
    FoxTip(
      category: TipCategory.safety,
      headline: 'Take a break before you feel tired',
      body:
          'On a long shift, park safely, stretch, drink water and rest your '
          'eyes for a few minutes before taking another trip.',
      asset: 'assets/tips/fox_tip_safety.png',
    ),
    FoxTip(
      category: TipCategory.safety,
      headline: 'Set up your phone before driving',
      body:
          'Start FoxyCo and secure your phone while parked. Read the verdict '
          'with a quick glance and keep your hands on the wheel.',
      asset: 'assets/tips/fox_tip_safety.png',
    ),
    FoxTip(
      category: TipCategory.maintenance,
      headline: 'Check tire pressure when tires are cold',
      body:
          'Use the pressure on the driver-door label. Correct pressure helps '
          'fuel economy, braking and even tire wear.',
      asset: 'assets/tips/fox_tip_maintenance.png',
    ),
    FoxTip(
      category: TipCategory.maintenance,
      headline: 'Track service by kilometres, not only dates',
      body:
          'Use your odometer and heavy-use schedule. Busy months may need '
          'service sooner.',
      asset: 'assets/tips/fox_tip_diagnostics.png',
    ),
    FoxTip(
      category: TipCategory.maintenance,
      headline: 'A quick clean helps every ride',
      body:
          'Clear rubbish, wipe common touch points and check the back seat '
          'between busy periods. Small resets improve the next ride.',
      asset: 'assets/tips/fox_tip_maintenance.png',
    ),
    FoxTip(
      category: TipCategory.app,
      headline: 'Set thresholds that cover your costs',
      body:
          'In My Rules → Verdict thresholds, choose numbers that account for '
          'fuel, maintenance and unpaid pickup distance.',
      asset: 'assets/tips/fox_tip_app.png',
    ),
    FoxTip(
      category: TipCategory.app,
      headline: 'Review your results after each shift',
      body:
          'History uses offers seen on this phone. Review the patterns after a '
          'few shifts and adjust when you choose to drive.',
      asset: 'assets/tips/fox_tip_app.png',
    ),
    FoxTip(
      category: TipCategory.app,
      headline: 'Red means the pickup is too far',
      body:
          'A red pickup distance is beyond the limit you set. Check that '
          'unpaid pickup distance before deciding from the payout alone.',
      asset: 'assets/tips/fox_tip_app.png',
    ),
    FoxTip(
      category: TipCategory.gigLife,
      headline: 'Gross pay is not take-home pay',
      body:
          'Keep a simple record of kilometres and vehicle costs. Your real '
          'earnings are what remain after those expenses.',
      asset: 'assets/tips/fox_tip_giglife.png',
    ),
  ],
);
