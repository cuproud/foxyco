import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxyco/domain/offer_summary.dart';
import 'package:foxyco/domain/fox_settings.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/domain/session_summary.dart';
import 'package:foxyco/domain/verdict.dart';
import 'package:foxyco/services/offer_log.dart';
import 'package:foxyco/services/play_update_service.dart';
import 'package:foxyco/services/session_log.dart';
import 'package:foxyco/ui/home/home_screen.dart';
import 'package:foxyco/ui/home/dashboard_controller.dart';
import 'package:foxyco/ui/home/dashboard_state.dart';
import 'package:foxyco/ui/home/slide_to_live.dart';
import 'package:foxyco/ui/settings/settings_controller.dart';
import 'package:foxyco/ui/theme/app_theme.dart';
import 'package:foxyco/ui/theme/tokens.dart';

class _GrantedDashboardController extends DashboardController {
  @override
  DashboardState build() => const DashboardState(
    status: WatchStatus.stopped,
    permissions: PermissionStatus(
      overlayGranted: true,
      accessibilityGranted: true,
    ),
  );
}

class _BlockedDashboardController extends DashboardController {
  @override
  DashboardState build() => const DashboardState(
    status: WatchStatus.blocked,
    permissions: PermissionStatus(
      overlayGranted: true,
      accessibilityGranted: false,
    ),
  );
}

class _WatchingDashboardController extends DashboardController {
  @override
  DashboardState build() => const DashboardState(
    status: WatchStatus.watching,
    permissions: PermissionStatus(
      overlayGranted: true,
      accessibilityGranted: true,
    ),
  );
}

class _SelectedAppsSettingsController extends SettingsController {
  @override
  FoxSettings build() =>
      FoxSettings.defaults.copyWith(watchedApps: {GigPlatform.uber});
}

class _AvailableUpdateController extends PlayUpdateController {
  @override
  PlayUpdateStatus build() => const PlayUpdateStatus(PlayUpdateState.available);
}

class _FixedHomeLog extends OfferLog {
  _FixedHomeLog(this._offers);
  final List<OfferSummary> _offers;

  @override
  List<OfferSummary> build() => _offers;
}

class _FixedSessionLog extends SessionLog {
  _FixedSessionLog(this._sessions);
  final List<SessionSummary> _sessions;

  @override
  List<SessionSummary> build() => _sessions;
}

OfferSummary _homeOffer(DateTime seenAt) => OfferSummary(
  platform: GigPlatform.uber,
  verdict: Verdict.good,
  payout: 20,
  totalKm: 10,
  seenAt: seenAt,
);

void main() {
  // The dashboard is a tall scroll; give the test a tall viewport so the
  // lazy ListView builds every section (hero + ticket) at once.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Home dashboard renders its core sections', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(_GrantedDashboardController.new),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    // Brand bar + hero status + today's tally + full-day session recap.
    // Boot lands stopped (spec M5 §4): monitoring waits for an explicit start.
    expect(find.text('FoxyCo'), findsOneWidget);
    expect(find.text('Ready when you are'), findsOneWidget);
    expect(find.textContaining('offers seen'), findsOneWidget);
    expect(find.text('SESSION RECAP'), findsOneWidget);
    expect(find.text('Review Inbox'), findsNothing);
    expect(find.text('MY GOAL'), findsOneWidget);

    // Off-device the session log is empty — the card shows its empty state.
    expect(find.textContaining('No sessions yet'), findsOneWidget);
  });

  testWidgets('blocked Home shows one corrective access card', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(_BlockedDashboardController.new),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    expect(find.text('Access needed'), findsOneWidget);
    expect(find.textContaining('Offer access is off.'), findsOneWidget);
    expect(find.textContaining('Tap Fix to enable it.'), findsOneWidget);
    expect(find.text('Fix'), findsOneWidget);
    expect(find.text('Offer access required'), findsNothing);
    expect(find.text('Offer access unavailable.'), findsNothing);
    expect(find.byType(SlideToLive), findsNothing);
  });

  testWidgets('idle Home shows an available update prompt', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(_GrantedDashboardController.new),
          playUpdateProvider.overrideWith(_AvailableUpdateController.new),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    expect(find.text('FoxyCo update available'), findsOneWidget);
    expect(
      find.text('A newer version is ready with fixes and improvements.'),
      findsNothing,
    );
    expect(find.text('Later'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
    expect(find.byKey(const ValueKey('play-update-start')), findsOneWidget);
  });

  testWidgets('active Home suppresses the update prompt', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(_WatchingDashboardController.new),
          playUpdateProvider.overrideWith(_AvailableUpdateController.new),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    expect(find.text('FoxyCo update available'), findsNothing);
  });

  testWidgets('Session recap shows the full-day amount without outcomes', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(_GrantedDashboardController.new),
          sessionLogProvider.overrideWith(
            () => _FixedSessionLog([
              SessionSummary(
                startedAt: DateTime(2026, 8, 19, 8),
                endedAt: DateTime(2026, 8, 19, 10),
                good: 4,
                ok: 3,
                accepted: 0,
                completed: 0,
                declined: 2,
                platforms: {GigPlatform.uber, GigPlatform.lyft},
                estimatedEarnings: 42,
                bestPerKm: 2.1,
                goodAvgPerKm: 1.8,
                busiestHour: 9,
              ),
            ]),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('ACCEPTED AMOUNT'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('session-recap-accepted-count')))
          .data,
      '0',
    );
    expect(find.text(r'$42.00'), findsOneWidget);
    expect(find.text('offers seen'), findsOneWidget);
    expect(find.textContaining(r'Best $/km'), findsNothing);
    expect(find.textContaining('Good avg'), findsNothing);
    expect(find.textContaining('Busiest'), findsNothing);
  });

  testWidgets('expanded recap fits narrow screens with enlarged text', (
    tester,
  ) async {
    tall(tester);
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('fonts/Inter.ttf'));
    await font.load();
    addTearDown(() => FoxColors.apply(FoxPalette.dark));
    final sessions = [
      for (final day in [27, 24, 21])
        SessionSummary(
          startedAt: DateTime(2026, 9, day, 12, 13),
          endedAt: DateTime(2026, 9, day, 17, 50),
          good: 2,
          ok: 7,
          bad: 122,
          accepted: 17,
          declined: 114,
          estimatedEarnings: day == 27 ? 142.85 : 0,
        ),
      SessionSummary(
        startedAt: DateTime(2026, 9, 27, 18),
        endedAt: DateTime(2026, 9, 27, 19),
        good: 3,
        accepted: 3,
      ),
    ];
    for (final palette in [FoxPalette.light, FoxPalette.dark]) {
      final preview = ValueNotifier<Widget?>(null);
      addTearDown(preview.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardProvider.overrideWith(_GrantedDashboardController.new),
            sessionLogProvider.overrideWith(() => _FixedSessionLog(sessions)),
          ],
          child: MaterialApp(
            theme: AppTheme.of(palette),
            home: ValueListenableBuilder<Widget?>(
              valueListenable: preview,
              child: const HomeScreen(),
              builder: (context, card, home) => Stack(
                children: [
                  Offstage(offstage: card != null, child: home),
                  if (card != null)
                    SingleChildScrollView(
                      child: Center(
                        child: SizedBox(
                          width: 288,
                          child: MediaQuery(
                            data: MediaQuery.of(
                              context,
                            ).copyWith(textScaler: const TextScaler.linear(2)),
                            child: Material(
                              color: Colors.transparent,
                              child: card,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('session-recap-toggle')));
      await tester.tap(find.byKey(const Key('session-recap-toggle')));
      await tester.pump();
      // Keep Home mounted while checking just the recap at a phone's width.
      preview.value = tester.widget<Container>(
        find.byKey(const Key('session-recap-card')),
      );
      await tester.pump();
      expect(find.text(r'$142.85'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('session-recap-accepted-count')))
            .data,
        '20',
      );
      expect(find.text(r'$0.00'), findsNWidgets(2));
      expect(find.text('accept rate'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('small yesterday baseline uses an absolute comparison', (
    tester,
  ) async {
    tall(tester);
    final now = DateTime.now();
    final offers = [
      ...List.generate(56, (_) => _homeOffer(now)),
      ...List.generate(
        5,
        (_) => _homeOffer(now.subtract(const Duration(days: 1))),
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(_GrantedDashboardController.new),
          offerLogProvider.overrideWith(() => _FixedHomeLog(offers)),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('51 more than yesterday'), findsOneWidget);
    expect(find.textContaining('% more than yesterday'), findsNothing);
    expect(find.textContaining('% fewer than yesterday'), findsNothing);
  });

  testWidgets('Go live / Stop toggles monitoring', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(_GrantedDashboardController.new),
          settingsProvider.overrideWith(_SelectedAppsSettingsController.new),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    // Boots stopped with the slide-to-go-live CTA showing.
    expect(find.text('Ready when you are'), findsOneWidget);
    expect(find.text('Slide to go live'), findsOneWidget);

    // Slide the thumb fully right past the commit threshold → onStart.
    await tester.drag(
      find.byKey(const ValueKey('slide-thumb')),
      const Offset(1080, 0),
    );
    await tester.pump();
    expect(find.text('Watching offers'), findsOneWidget); // hero status
    // 'Live' shows in the above-car status chip and the slide live bar — the
    // brand-bar pill is gone (2026-07-25).
    expect(find.text('Live'), findsNWidgets(2));
    expect(find.text('Live Status'), findsOneWidget);
    expect(find.byKey(const ValueKey('slide-stop-thumb')), findsOneWidget);

    // Slide the stop thumb fully left past the threshold → onStop.
    await tester.drag(
      find.byKey(const ValueKey('slide-stop-thumb')),
      const Offset(-1080, 0),
    );
    await tester.pump();
    expect(find.text('Ready when you are'), findsOneWidget); // fully stopped
    expect(find.text('Slide to go live'), findsOneWidget);
    // The brand-bar pill is gone; the above-car chip carries the state now.
    expect(find.text('Off'), findsNothing);
    expect(find.text('Offline'), findsOneWidget);
  });
}
