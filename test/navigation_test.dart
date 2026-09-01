import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/session_summary.dart';
import 'package:foxyco/domain/offer_summary.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/domain/verdict.dart';
import 'package:foxyco/parser/parser_registry.dart';
import 'package:foxyco/router.dart';
import 'package:foxyco/services/offer_log.dart';
import 'package:foxyco/services/session_log.dart';
import 'package:foxyco/services/play_update_service.dart';
import 'package:foxyco/ui/settings/about_content.dart';
import 'package:foxyco/ui/theme/platform_badge.dart';
import 'package:foxyco/ui/settings/logs_screen.dart';
import 'package:foxyco/ui/shell/root_shell.dart';

class _NavigationOfferLog extends OfferLog {
  _NavigationOfferLog(this.offers);
  final List<OfferSummary> offers;

  @override
  List<OfferSummary> build() => offers;
}

/// Shell navigation: the connective tissue between the four tabs. Everything
/// here used to be a dead end — back left the app, tab jumps landed on a
/// collapsed accordion, and Logs had no route at all.
void main() {
  // The pages are long; a tall viewport lets the ListViews lay out enough of
  // themselves that the targets are findable without scrolling.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// The shell runs a permanent idle loop (the hero stage's ambient pulse), so
  /// `pumpAndSettle` never returns here — pump a fixed beat instead.
  Future<void> beat(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  Future<void> pumpShell(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: createRouter(showOnboarding: false),
        ),
      ),
    );
    await beat(tester);
  }

  ProviderContainer scope([List<dynamic> overrides = const []]) {
    final container = ProviderContainer(overrides: overrides.cast());
    addTearDown(container.dispose);
    return container;
  }

  /// Phone HEIGHT (780 logical) so "below the fold" means something, at a
  /// roomier 600 width. Not 360: widget tests render in a placeholder font whose
  /// every glyph is a fontSize-wide square, so Home's legend chips ("0 good")
  /// measure ~2× their real width and blow their Row at true phone widths. That
  /// overflow is a measurement artifact of the test font, not a device bug —
  /// and Home lays out even while Settings is the visible IndexedStack child,
  /// so it would fail this test for reasons that have nothing to do with it.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 1560);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Only built while the Watched apps group is expanded — the platform badge
  /// is what tells these switches apart from Outcome tracking's.
  final watchedAppSwitches = find.descendant(
    of: find.byType(SwitchListTile),
    matching: find.byType(PlatformBadge),
  );

  /// The system back gesture, as the framework delivers it.
  Future<void> systemBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await beat(tester);
  }

  testWidgets('system back steps to Home before leaving the app', (
    tester,
  ) async {
    tall(tester);
    final container = scope();
    await pumpShell(tester, container);

    container.read(tabIndexProvider.notifier).go(3);
    await beat(tester);
    expect(container.read(tabIndexProvider), 3);

    await systemBack(tester);
    expect(container.read(tabIndexProvider), 0, reason: 'back lands on Home');
  });

  testWidgets('recent accepted trip opens its editable History detail', (
    tester,
  ) async {
    tall(tester);
    final seenAt = DateTime(2026, 8, 24, 10, 3);
    final offer = OfferSummary(
      platform: GigPlatform.uber,
      verdict: Verdict.good,
      payout: 18.60,
      totalKm: 8.5,
      totalMinutes: 24,
      seenAt: seenAt,
      outcome: OfferOutcome.taken,
    );
    final container = scope([
      offerLogProvider.overrideWith(() => _NavigationOfferLog([offer])),
    ]);
    await pumpShell(tester, container);

    expect(find.text('Recent accepted'), findsOneWidget);
    expect(
      find.byKey(ValueKey('recent-accepted-${seenAt.microsecondsSinceEpoch}')),
      findsNothing,
    );

    await tester.tap(find.text('Recent accepted'));
    await beat(tester);
    final card = find.byKey(
      ValueKey('recent-accepted-${seenAt.microsecondsSinceEpoch}'),
    );
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.text(r'$18.60')), findsOne);
    expect(
      find.descendant(of: card, matching: find.text(r'CA$18.60')),
      findsNothing,
    );
    expect(
      tester
          .widget<PlatformBadge>(
            find.byKey(
              ValueKey(
                'recent-accepted-platform-${seenAt.microsecondsSinceEpoch}',
              ),
            ),
          )
          .size,
      24,
    );
    expect(
      find.descendant(of: card, matching: find.byType(PlatformBadge)),
      findsOne,
    );

    await tester.tap(card);
    await beat(tester);

    expect(container.read(tabIndexProvider), 0);
    expect(find.text('Add final'), findsOneWidget);

    await tester.tap(find.text('Add final'));
    await beat(tester);
    expect(find.text(r'Upfront: CA$18.60 · tip is added'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('final-payout-total')),
      '38,34',
    );
    await tester.enterText(find.byKey(const Key('final-payout-tip')), '5,19');
    await tester.enterText(find.byKey(const Key('final-payout-toll')), '9,16');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await beat(tester);

    expect(find.text(r'CA$43.53'), findsAtLeastNWidgets(1));
    expect(container.read(offerLogProvider).single.finalPayout, 43.53);
    expect(container.read(offerLogProvider).single.tip, 5.19);
    expect(container.read(offerLogProvider).single.tollReimbursement, 9.16);
    expect(find.text(r'Tip CA$5.19'), findsOneWidget);
    expect(find.text(r'Toll CA$9.16'), findsOneWidget);

    await tester.tap(find.byKey(const Key('correct-distance')));
    await beat(tester);
    expect(
      tester
          .widget<TextField>(find.byType(TextField).last)
          .decoration
          ?.helperMaxLines,
      2,
    );
    await tester.enterText(find.byType(TextField).last, '30.4');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await beat(tester);

    expect(container.read(offerLogProvider).single.totalKm, 30.4);
    expect(find.text('30.4 km'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await beat(tester);
    expect(container.read(tabIndexProvider), 0);
    expect(find.text('Recent accepted'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a completed app update is confirmed once Home mounts', (
    tester,
  ) async {
    tall(tester);
    final container = scope([appUpdatedProvider.overrideWithValue(true)]);

    await pumpShell(tester, container);

    expect(find.text('Updated to $aboutVersion'), findsOneWidget);
  });

  testWidgets('deep link opens the Rules group it was aimed at', (
    tester,
  ) async {
    // A REAL phone viewport (360×780 logical), not the tall one: Watched apps
    // falls past the fold at this height, so the jump
    // genuinely has to scroll. On a 3200px view it lands on screen either way
    // and the assertion passes without ensureVisible ever running.
    phone(tester);
    final container = scope();
    await pumpShell(tester, container);

    container.read(tabIndexProvider.notifier).go(1, section: 3);
    // TWO beats: the first lands the rebuild whose post-frame callback KICKS OFF
    // ensureVisible's animation — nothing has ticked it yet at that point, and
    // AnimatedSize is still growing the group (maxScrollExtent is still moving).
    // The second beat actually runs the scroll.
    await beat(tester);
    await beat(tester);

    // The group's BODY is what proves it's open — a collapsed group still
    // renders its title, so find.text('Watched apps') would pass either way.
    // The per-app switches are built only while it's expanded.
    expect(
      watchedAppSwitches,
      findsNWidgets(ParserRegistry.supportedPlatforms.length),
    );

    // ...and it was scrolled to, not just expanded somewhere off-screen.
    final list = tester.widget<Scrollable>(find.byType(Scrollable).first);
    expect(list.controller!.offset, greaterThan(0), reason: 'list moved');
    final header = tester.getRect(find.text('Watched apps'));
    expect(header.top, greaterThanOrEqualTo(0.0));
    expect(header.bottom, lessThanOrEqualTo(780.0));

    // One-shot: consumed, so a later hand-switch to Rules leaves it alone.
    expect(container.read(tabIndexProvider.notifier).pendingSection, isNull);
  });

  testWidgets('switching to Rules by hand leaves the accordion alone', (
    tester,
  ) async {
    phone(tester);
    final container = scope();
    await pumpShell(tester, container);

    // No section → no jump, no scroll: all groups stay shut as Rules boots.
    container.read(tabIndexProvider.notifier).go(1);
    await beat(tester);
    expect(watchedAppSwitches, findsNothing);
    expect(find.text('GOOD at or above'), findsNothing);
    final list = tester.widget<Scrollable>(find.byType(Scrollable).first);
    expect(list.controller!.offset, 0);
  });

  testWidgets('Diagnostic logs is reachable from Settings', (tester) async {
    tall(tester);
    await pumpShell(tester, scope());

    await tester.tap(find.text('Settings').last);
    await beat(tester);
    await tester.scrollUntilVisible(
      find.text('Diagnostic logs'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Diagnostic logs'));
    await beat(tester);

    expect(find.byType(LogsScreen), findsOneWidget);
  });

  testWidgets('the last-session card opens History', (tester) async {
    tall(tester);
    final container = scope([
      sessionLogProvider.overrideWith(
        () => _FakeSessionLog([
          SessionSummary(
            startedAt: DateTime(2026, 7, 20, 18),
            endedAt: DateTime(2026, 7, 20, 22),
            good: 4,
            ok: 3,
            bad: 2,
            bestPerKm: 2.10,
            goodAvgPerKm: 1.80,
            busiestHour: 19,
          ),
        ]),
      ),
    ]);
    await pumpShell(tester, container);

    await tester.tap(find.textContaining('offers scored'));
    await beat(tester);
    expect(container.read(tabIndexProvider), 2);
  });

  testWidgets('re-tapping the active tab scrolls it back to the top', (
    tester,
  ) async {
    // Deliberately SHORT so Home overflows and has somewhere to scroll to.
    tester.view.physicalSize = const Size(1080, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpShell(tester, scope());

    // Drag from high on the page: the hero's slide-to-live sits mid-viewport
    // and would rather have the gesture.
    await tester.dragFrom(const Offset(540, 220), const Offset(0, -400));
    await beat(tester);
    final home = tester.widget<Scrollable>(find.byType(Scrollable).first);
    expect(home.controller!.offset, greaterThan(0));

    await tester.tap(find.text('Home'));
    await beat(tester);
    expect(home.controller!.offset, 0);
  });
}

class _FakeSessionLog extends SessionLog {
  _FakeSessionLog(this.seed);
  final List<SessionSummary> seed;

  @override
  List<SessionSummary> build() => seed;
}
