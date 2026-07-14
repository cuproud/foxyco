import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/overlay_action.dart';
import 'package:foxyco/domain/overlay_payload.dart';
import 'package:foxyco/parser/parser_registry.dart';
import 'package:foxyco/services/accessibility/accessibility_watcher.dart';
import 'package:foxyco/services/accessibility/offer_watcher.dart';
import 'package:foxyco/services/overlay_service.dart';
import 'package:foxyco/ui/home/dashboard_controller.dart';
import 'package:foxyco/ui/home/dashboard_state.dart';
import 'package:foxyco/ui/overlay/overlay_controller.dart';

/// Feeds a scripted stream of screen reads instead of the real plugin.
class _FakeWatcher extends AccessibilityWatcher {
  final _controller = StreamController<ScreenRead>.broadcast();
  void emit(ScreenRead r) => _controller.add(r);
  @override
  Stream<ScreenRead> reads() => _controller.stream;
}

/// Records what the overlay was asked to show; no platform channels.
class _FakeOverlayService implements OverlayService {
  final List<OverlayPayload> shown = [];
  int clears = 0;
  @override
  Future<void> showOffer(OverlayPayload p) async => shown.add(p);
  @override
  Stream<OverlayAction> get actionStream => const Stream.empty();
  @override
  Future<bool> isPermissionGranted() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool> isActive() async => shown.isNotEmpty;
  @override
  Future<void> startWatching({bool paused = false}) async {}
  @override
  Future<void> update(OverlayPayload p) async => shown.add(p);
  @override
  Future<void> setPaused(bool paused) async {}
  @override
  Future<void> clearPill() async => clears++;
  @override
  Future<void> hide() async {}
}

const _hoppNodes = ScreenRead(
  packageName: ParserRegistry.hoppPackage,
  texts: [
    '\$8.50',
    '(NET, tax included)',
    '11 min · 5.2 km',
    '11 min · 7.7 km',
    'Match',
  ],
);

/// A watched-app screen that is NOT an offer (Hopp home / go-online).
const _hoppHome = ScreenRead(
  packageName: ParserRegistry.hoppPackage,
  texts: ['Home', 'Go online', 'Current shift'],
);

/// A frame WHILE the offer card is still up but the full parse fails — the
/// countdown ticked / a leg row half-rendered so the leg shape is momentarily
/// incomplete. The Accept/Match affordance is still present, which is how we
/// know the card hasn't left. Live cards fire mostly frames like this.
const _hoppPartial = ScreenRead(
  packageName: ParserRegistry.hoppPackage,
  texts: ['\$8.50', '(NET, tax included)', '11 min · 5.2 km', 'Match'],
);

/// The exact frame from the 2026-07-13 device log that wrongly cleared the pill:
/// the card is STILL on screen (payout `$8.50` right there) but this frame
/// dropped both the Match button AND the leg rows from the a11y tree. Gating on
/// the affordance cleared here; gating on the payout must NOT.
const _hoppCardNoButton = ScreenRead(
  packageName: ParserRegistry.hoppPackage,
  texts: ['Hopp', 'Card', 'Out of radius', '\$8.50 (NET, tax included)'],
);

/// The 2026-07-14 Lyft device frame that wrongly cleared the pill: the card is
/// STILL up, but this frame is JUST the word "Accept" — the payout AND the legs
/// scrolled out of the a11y tree. Payout-gating cleared here; a card-hallmark
/// (the button) must keep it. Uses Hopp's package so the fixture's parser runs.
const _hoppButtonOnly = ScreenRead(
  packageName: ParserRegistry.hoppPackage,
  texts: ['Accept'],
);

void main() {
  late _FakeWatcher watcher;
  late _FakeOverlayService overlay;

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        accessibilityWatcherProvider.overrideWithValue(watcher),
        overlayServiceProvider.overrideWithValue(overlay),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    watcher = _FakeWatcher();
    overlay = _FakeOverlayService();
    // Shrink the "offer left screen" grace + min-visible floor so tests don't
    // wait real seconds.
    OfferWatcher.clearGrace = const Duration(milliseconds: 20);
    OfferWatcher.minVisible = const Duration(milliseconds: 10);
  });

  /// Longer than [OfferWatcher.clearGrace] so a pending clear timer can fire.
  Future<void> pastGrace() =>
      Future<void>.delayed(const Duration(milliseconds: 40));

  test('a real read flows parse → score → overlay pill', () async {
    final c = container();
    c.read(offerWatcherProvider); // start the pipeline
    c.read(overlayControllerProvider); // wire showFromOffer's service

    watcher.emit(_hoppNodes);
    await Future<void>.delayed(Duration.zero);

    expect(overlay.shown, hasLength(1));
    final pill = overlay.shown.single;
    expect(pill.payout, 8.50);
    expect(pill.totalKm, closeTo(12.9, 1e-9));
    // $0.66/km < 1.0 default BAD cut → BAD verdict.
    expect(pill.verdict.name, 'bad');
  });

  test('same offer re-firing shows the pill only once (flicker guard)', () async {
    final c = container();
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    // Same card emits repeatedly (map pans, chips animate).
    watcher.emit(_hoppNodes);
    await Future<void>.delayed(Duration.zero);
    watcher.emit(_hoppNodes);
    watcher.emit(_hoppNodes);
    await Future<void>.delayed(Duration.zero);

    expect(overlay.shown, hasLength(1)); // not 3

    // Screen leaves the offer for longer than the grace window (so the pill
    // truly clears), then the same offer returns → shows again.
    watcher.emit(const ScreenRead(
      packageName: ParserRegistry.hoppPackage,
      texts: ['Home', 'Go online'],
    ));
    await pastGrace();
    watcher.emit(_hoppNodes);
    await Future<void>.delayed(Duration.zero);

    expect(overlay.shown, hasLength(2));
  });

  test('a transient non-offer frame does NOT clear the pill (anti-flash)', () async {
    final c = container();
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(_hoppNodes);
    await Future<void>.delayed(Duration.zero);
    expect(overlay.shown, hasLength(1));

    // A single blank frame arrives WHILE the card is still up (map pan behind
    // the card / half-rendered tree), then the card re-parses before the grace
    // window elapses. The pill must survive — no clear, no re-show flicker.
    watcher.emit(_hoppHome);
    await Future<void>.delayed(Duration.zero);
    watcher.emit(_hoppNodes);
    await pastGrace();

    expect(overlay.clears, 0); // never blinked out
    expect(overlay.shown, hasLength(1)); // and never re-shown
  });

  test('keeps the pill while the card is up but the full parse fails', () async {
    final c = container();
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(_hoppNodes);
    await Future<void>.delayed(Duration.zero);
    expect(overlay.shown, hasLength(1));

    // A run of partial frames (payout still on screen, legs half-rendered so the
    // full parse fails) — the live-card case that used to age the pill out after
    // a few seconds. Because the SAME payout is still findable, the card is known
    // to be up, so the pill must persist past the grace window and never re-show.
    watcher.emit(_hoppPartial);
    await pastGrace();
    // Device frame: button + legs gone, only the payout remains. Must keep.
    watcher.emit(_hoppCardNoButton);
    await pastGrace();
    // Device frame (Lyft): payout + legs gone, ONLY the "Accept" button remains.
    // The other flicker direction — must ALSO keep.
    watcher.emit(_hoppButtonOnly);
    await pastGrace();

    expect(overlay.clears, 0); // did NOT auto-close under the live card
    expect(overlay.shown, hasLength(1)); // and never re-shown
  });

  test('clears promptly once the offer card (payout) is gone', () async {
    final c = container();
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(_hoppNodes);
    await Future<void>.delayed(Duration.zero);
    expect(overlay.clears, 0);

    // Driver accepts / declines / dismisses → the app returns to the map and the
    // Accept/Match affordance is gone. The pill clears once the (short) grace
    // window elapses — no lingering over the map.
    watcher.emit(_hoppHome);
    await pastGrace();
    expect(overlay.clears, 1);
  });

  test('clears the pill when the offer leaves a watched screen', () async {
    final c = container();
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    // Offer shows…
    watcher.emit(_hoppNodes);
    await Future<void>.delayed(Duration.zero);
    expect(overlay.shown, hasLength(1));
    expect(overlay.clears, 0);

    // …then the driver is on the Hopp home screen (no offer). The clear is
    // debounced (anti-flash), so it fires once the grace window elapses.
    watcher.emit(_hoppHome);
    await pastGrace();
    expect(overlay.clears, 1);

    // A second non-offer read must NOT clear again (nothing is up to clear).
    watcher.emit(_hoppHome);
    await pastGrace();
    expect(overlay.clears, 1);
  });

  test('does not clear when a non-offer screen was never showing a pill', () async {
    final c = container();
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(_hoppHome);
    await Future<void>.delayed(Duration.zero);

    expect(overlay.shown, isEmpty);
    expect(overlay.clears, 0);
  });

  test('drops reads while paused (gating)', () async {
    final c = container();
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);
    c.read(dashboardProvider.notifier).togglePause();
    expect(c.read(dashboardProvider).status, WatchStatus.paused);

    watcher.emit(_hoppNodes);
    await Future<void>.delayed(Duration.zero);

    expect(overlay.shown, isEmpty);
  });

  test('ignores an unhandled package (fail safe)', () async {
    final c = container();
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(const ScreenRead(
      packageName: 'com.whatsapp',
      texts: ['\$8.50', '11 min · 5.2 km', '11 min · 7.7 km'],
    ));
    await Future<void>.delayed(Duration.zero);

    expect(overlay.shown, isEmpty);
  });
}
