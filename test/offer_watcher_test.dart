import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/fox_settings.dart';
import 'package:foxyco/domain/offer_summary.dart';
import 'package:foxyco/domain/overlay_action.dart';
import 'package:foxyco/domain/bubble_style.dart';
import 'package:foxyco/domain/overlay_payload.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/domain/verdict.dart';
import 'package:foxyco/parser/parser_registry.dart';
import 'package:foxyco/services/accessibility/accessibility_watcher.dart';
import 'package:foxyco/services/accessibility/offer_watcher.dart';
import 'package:foxyco/services/offer_log.dart';
import 'package:foxyco/services/ocr/ocr_capture.dart';
import 'package:foxyco/services/overlay_service.dart';
import 'package:foxyco/services/verdict_voice.dart';
import 'package:foxyco/ui/home/dashboard_controller.dart';
import 'package:foxyco/ui/home/dashboard_state.dart';
import 'package:foxyco/ui/overlay/overlay_controller.dart';
import 'package:foxyco/ui/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Feeds a scripted stream of screen reads instead of the real plugin.
class _FakeWatcher extends AccessibilityWatcher {
  final _controller = StreamController<ScreenRead>.broadcast();
  void emit(ScreenRead r) => _controller.add(r);
  @override
  Stream<ScreenRead> reads() => _controller.stream;
}

class _OfferTestSettingsController extends SettingsController {
  _OfferTestSettingsController([
    this.watchedApps = const {
      GigPlatform.uber,
      GigPlatform.hopp,
      GigPlatform.lyft,
    },
  ]);

  final Set<GigPlatform> watchedApps;

  @override
  FoxSettings build() =>
      FoxSettings.defaults.copyWith(watchedApps: watchedApps);
}

class _FakeOcrCapture extends OcrCapture {
  var captures = 0;
  List<String> lines = const [];
  String packageName = '';
  final responses = <OcrFrame>[];
  Completer<OcrFrame>? nextCapture;

  @override
  Future<OcrFrame> capture() async {
    captures++;
    final delayed = nextCapture;
    nextCapture = null;
    if (delayed != null) return delayed.future;
    return responses.isEmpty
        ? OcrFrame(packageName: packageName, lines: lines)
        : responses.removeAt(0);
  }

  @override
  Future<void> stop() async {}
}

class _FakeVerdictVoice extends VerdictVoice {
  final spoken = <(Verdict, int)>[];

  @override
  Future<void> speak(Verdict verdict, int cooldownSeconds) async {
    spoken.add((verdict, cooldownSeconds));
  }
}

/// Records what the overlay was asked to show; no platform channels.
class _FakeOverlayService implements OverlayService {
  final List<OverlayPayload> shown = [];
  final firstShow = Completer<void>();
  final secondShow = Completer<void>();
  final thirdShow = Completer<void>();
  int clears = 0;

  void _record(OverlayPayload payload) {
    shown.add(payload);
    if (!firstShow.isCompleted) firstShow.complete();
    if (shown.length >= 2 && !secondShow.isCompleted) secondShow.complete();
    if (shown.length >= 3 && !thirdShow.isCompleted) thirdShow.complete();
  }

  @override
  Future<void> showOffer(
    OverlayPayload p, {
    BubbleStyle bubbleStyle = BubbleStyle.coolFox,
  }) async {
    _record(p);
  }

  @override
  Stream<OverlayAction> get actionStream => const Stream.empty();
  @override
  Stream<String> get diagnosticStream => const Stream.empty();
  @override
  Future<bool> isPermissionGranted() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool> isActive() async => shown.isNotEmpty;
  @override
  Future<void> startWatching({
    bool paused = false,
    BubbleStyle bubbleStyle = BubbleStyle.coolFox,
  }) async {}
  @override
  Future<void> update(OverlayPayload p) async {
    _record(p);
  }

  @override
  Future<void> setPaused(bool paused) async {}
  @override
  Future<void> setBubbleStyle(BubbleStyle style) async {}
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
  isActive: true,
);

const _hoppBackgroundHome = ScreenRead(
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

const _uberA = ScreenRead(
  packageName: ParserRegistry.uberPackage,
  texts: [
    'UberX',
    r'$10.00',
    '4 mins (1.0 km) away',
    '15 mins (4.0 km) trip',
    'Accept',
  ],
  isActive: true,
);

const _uberB = ScreenRead(
  packageName: ParserRegistry.uberPackage,
  texts: [
    'UberX',
    r'$4.85',
    '3 mins (0.8 km) away',
    '12 mins (3.2 km) trip',
    'Accept',
  ],
  isActive: true,
);

const _lyftA = ScreenRead(
  packageName: ParserRegistry.lyftPackage,
  texts: [r'$10.00', '4 min · 1.0 km', '15 min · 4.0 km', 'Accept'],
  isActive: true,
);

const _lyftB = ScreenRead(
  packageName: ParserRegistry.lyftPackage,
  texts: [r'$4.85', '3 min · 0.8 km', '12 min · 3.2 km', 'Accept'],
  isActive: true,
);

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeWatcher watcher;
  late _FakeOverlayService overlay;
  late _FakeOcrCapture ocr;
  late _FakeVerdictVoice voice;

  ProviderContainer container({Set<GigPlatform>? watchedApps}) {
    final c = ProviderContainer(
      overrides: [
        accessibilityWatcherProvider.overrideWithValue(watcher),
        overlayServiceProvider.overrideWithValue(overlay),
        ocrCaptureProvider.overrideWithValue(ocr),
        verdictVoiceProvider.overrideWithValue(voice),
        dashboardProvider.overrideWith(_GrantedDashboardController.new),
        settingsProvider.overrideWith(
          () => _OfferTestSettingsController(
            watchedApps ??
                const {GigPlatform.uber, GigPlatform.hopp, GigPlatform.lyft},
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    // Boot lands stopped (spec M5 §4) — these tests exercise a live watch.
    c.read(dashboardProvider.notifier).startMonitoring();
    return c;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    watcher = _FakeWatcher();
    overlay = _FakeOverlayService();
    ocr = _FakeOcrCapture();
    voice = _FakeVerdictVoice();
    // Shrink the "offer left screen" grace + min-visible floor so tests don't
    // wait real seconds.
    OfferWatcher.clearGrace = const Duration(milliseconds: 20);
    OfferWatcher.minVisible = const Duration(milliseconds: 10);
    OfferWatcher.voiceStability = const Duration(milliseconds: 1);
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

  test('an event from a switched-off package is ignored', () async {
    final c = container();
    c.read(settingsProvider.notifier).toggleApp(GigPlatform.uber);
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(_uberA);
    await Future<void>.delayed(Duration.zero);

    expect(overlay.shown, isEmpty);
    expect(c.read(offerLogProvider), isEmpty);
  });

  test('voice announces each new GOOD offer only when enabled', () async {
    final c = container();
    c.read(settingsProvider.notifier)
      ..setAnnounceGoodOffers(true)
      ..setGoodVoiceMinimumPayout(0);
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    const good = ScreenRead(
      packageName: ParserRegistry.hoppPackage,
      texts: [
        r'$20.00',
        '(NET, tax included)',
        '11 min · 5.2 km',
        '11 min · 7.7 km',
        'Match',
      ],
    );
    watcher.emit(good);
    await Future<void>.delayed(Duration.zero);
    watcher.emit(good);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(voice.spoken, [(Verdict.good, 15)]);
  });

  test('provisional GOOD is suppressed when the final offer is BAD', () async {
    final c = container();
    c.read(settingsProvider.notifier)
      ..setAnnounceGoodOffers(true)
      ..setGoodVoiceMinimumPayout(0);
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    const good = ScreenRead(
      packageName: ParserRegistry.hoppPackage,
      texts: [
        r'$20.00',
        '(NET, tax included)',
        '11 min · 5.2 km',
        '11 min · 7.7 km',
        'Match',
      ],
    );
    watcher.emit(good);
    watcher.emit(_hoppNodes);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(overlay.shown.last.verdict, Verdict.bad);
    expect(voice.spoken, isEmpty);
  });

  test(
    'provisional GOOD becomes the only OK announcement when enabled',
    () async {
      final c = container();
      c.read(settingsProvider.notifier)
        ..setAnnounceGoodOffers(true)
        ..setAnnounceOkOffers(true)
        ..setGoodVoiceMinimumPayout(0);
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      const good = ScreenRead(
        packageName: ParserRegistry.hoppPackage,
        texts: [
          r'$20.00',
          '(NET, tax included)',
          '11 min · 5.2 km',
          '11 min · 7.7 km',
          'Match',
        ],
      );
      const ok = ScreenRead(
        packageName: ParserRegistry.hoppPackage,
        texts: [
          r'$15.00',
          '(NET, tax included)',
          '11 min · 5.2 km',
          '11 min · 7.7 km',
          'Match',
        ],
      );
      watcher.emit(good);
      watcher.emit(ok);
      for (var i = 0; i < 20 && voice.spoken.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(overlay.shown.last.verdict, Verdict.ok);
      expect(voice.spoken, [(Verdict.ok, 15)]);
    },
  );

  test('accessibility success remains primary and never invokes OCR', () async {
    final c = container();
    c.read(settingsProvider.notifier).setOcrEnabled(true);
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(_hoppNodes);
    await Future<void>.delayed(Duration.zero);

    expect(overlay.shown, hasLength(1));
    expect(ocr.captures, 0);
  });

  test('readable Uber Accessibility text avoids slower OCR', () async {
    final c = container();
    c.read(settingsProvider.notifier).setOcrEnabled(true);
    ocr.lines = _uberB.texts;
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(_uberA);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(ocr.captures, 0);
    expect(overlay.shown.single.payout, 10);
    expect(c.read(offerLogProvider).single.platform, GigPlatform.uber);
  });

  test('active Uber trigger clears a stale non-Uber pill before OCR', () async {
    final c = container();
    c.read(settingsProvider.notifier).setOcrEnabled(true);
    ocr.nextCapture = Completer<OcrFrame>();
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(_lyftA);
    await Future<void>.delayed(Duration.zero);
    watcher.emit(
      const ScreenRead(
        packageName: ParserRegistry.uberPackage,
        texts: [],
        isActive: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(overlay.clears, 1);
    expect(c.read(offerWatcherProvider), isNull);
  });

  test(
    'Uber accepted screen still updates outcome while OCR is enabled',
    () async {
      final c = container();
      c.read(settingsProvider.notifier).setOcrEnabled(true);
      ocr.lines = _uberA.texts;
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(_uberA);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.uberPackage,
          texts: ['Picking up Alex'],
          isActive: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(c.read(offerLogProvider).single.outcome, OfferOutcome.taken);
    },
  );

  test(
    'Uber browse screen still updates outcome while OCR is enabled',
    () async {
      final previous = OfferWatcher.clearGrace;
      OfferWatcher.clearGrace = const Duration(milliseconds: 10);
      addTearDown(() => OfferWatcher.clearGrace = previous);
      final c = container();
      c.read(settingsProvider.notifier).setOcrEnabled(true);
      ocr.lines = _uberA.texts;
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(_uberA);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.uberPackage,
          texts: ['Home', 'Finding trips'],
          isActive: true,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(c.read(offerLogProvider).single.outcome, OfferOutcome.missed);
    },
  );

  test(
    'Uber browse racing first OCR cannot resurrect a dismissed card',
    () async {
      final previous = OfferWatcher.ocrCooldown;
      OfferWatcher.ocrCooldown = const Duration(milliseconds: 10);
      addTearDown(() => OfferWatcher.ocrCooldown = previous);
      final pending = Completer<OcrFrame>();
      final c = container();
      c.read(settingsProvider.notifier).setOcrEnabled(true);
      ocr.nextCapture = pending;
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.uberPackage,
          texts: [],
          isActive: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.uberPackage,
          texts: ['Home', 'Finding trips'],
          isActive: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      pending.complete(
        OcrFrame(packageName: ParserRegistry.uberPackage, lines: _uberA.texts),
      );
      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(overlay.shown, isEmpty);
      expect(c.read(offerLogProvider), isEmpty);
    },
  );

  test(
    'active Hopp offer probes once and detects Uber drawn above it',
    () async {
      final c = container();
      final settings = c.read(settingsProvider.notifier);
      settings.setOcrEnabled(true);
      ocr.responses.add(
        OcrFrame(packageName: ParserRegistry.hoppPackage, lines: _uberA.texts),
      );
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(_hoppNodes); // background frames cannot trigger capture
      await Future<void>.delayed(Duration.zero);
      expect(ocr.captures, 0);
      expect(overlay.shown, hasLength(1));
      expect(c.read(offerLogProvider).single.platform, GigPlatform.hopp);

      watcher.emit(
        ScreenRead(
          packageName: _hoppNodes.packageName,
          texts: _hoppNodes.texts,
          isActive: true,
        ),
      );
      for (var i = 0; i < 20 && overlay.shown.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(ocr.captures, 1);
      expect(overlay.shown, hasLength(2));
      expect(c.read(offerLogProvider).map((offer) => offer.platform), [
        GigPlatform.uber,
        GigPlatform.hopp,
      ]);
    },
  );

  test('OCR result is discarded after switching to a non-driver app', () async {
    final pending = Completer<OcrFrame>();
    final c = container();
    c.read(settingsProvider.notifier).setOcrEnabled(true);
    ocr.nextCapture = pending;
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(
      ScreenRead(
        packageName: ParserRegistry.hoppPackage,
        texts: _hoppNodes.texts,
        isActive: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    pending.complete(
      OcrFrame(packageName: 'com.sec.android.gallery3d', lines: _uberA.texts),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(ocr.captures, 1);
    expect(c.read(offerLogProvider).map((offer) => offer.platform), [
      GigPlatform.hopp,
    ]);
  });

  test('active textless accessibility frame falls back to OCR once', () async {
    final c = container();
    c.read(settingsProvider.notifier).setOcrEnabled(true);
    ocr.lines = _uberA.texts;
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(
      const ScreenRead(
        packageName: ParserRegistry.hoppPackage,
        texts: [],
        isActive: true,
      ),
    );
    watcher.emit(
      const ScreenRead(
        packageName: ParserRegistry.hoppPackage,
        texts: [],
        isActive: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    watcher.emit(
      const ScreenRead(
        packageName: ParserRegistry.hoppPackage,
        texts: [],
        isActive: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(ocr.captures, 1);
    expect(overlay.shown, hasLength(1));
    expect(c.read(offerLogProvider).single.platform, GigPlatform.uber);
  });

  test('OCR never parses a non-Uber offer', () async {
    final c = container();
    c.read(settingsProvider.notifier).setOcrEnabled(true);
    ocr.lines = const [
      '\$4.40 (NET, tax included)',
      '8 min 3.1 km',
      '6 min 2.7 km',
      'Match',
      // The old global parser loop still chose Uber because its labelled trip
      // shape was present, even though Hopp triggered the screenshot.
      '\$99.00',
      '10 mins (5.0 km) trip',
      'Accept',
    ];
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(
      const ScreenRead(
        packageName: ParserRegistry.hoppPackage,
        texts: [],
        isActive: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(ocr.captures, 1);
    expect(c.read(offerLogProvider), isEmpty);
    expect(overlay.shown, isEmpty);
  });

  test('OCR stays off when Uber is not watched', () async {
    final c = container();
    final settings = c.read(settingsProvider.notifier);
    settings.setOcrEnabled(true);
    settings.toggleApp(GigPlatform.uber);
    ocr.lines = _uberA.texts;
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(
      const ScreenRead(
        packageName: ParserRegistry.lyftPackage,
        texts: [],
        isActive: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(ocr.captures, 0);
    expect(c.read(offerLogProvider), isEmpty);
  });

  test('OCR follows the visible Uber card after a Lyft event', () async {
    final c = container();
    c.read(settingsProvider.notifier).setOcrEnabled(true);
    ocr.lines = _uberA.texts;
    ocr.packageName = ParserRegistry.lyftPackage;
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(
      const ScreenRead(
        packageName: ParserRegistry.lyftPackage,
        texts: [],
        isActive: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(offerLogProvider).single.platform, GigPlatform.uber);
    expect(overlay.shown.single.payout, 10);
  });

  test('a plain Lyft map frame probes for an Uber card above it', () async {
    final c = container();
    c.read(settingsProvider.notifier).setOcrEnabled(true);
    ocr.lines = _uberA.texts;
    ocr.packageName = ParserRegistry.lyftPackage;
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(
      const ScreenRead(
        packageName: ParserRegistry.lyftPackage,
        texts: ["You're online"],
        isActive: true,
      ),
    );
    await overlay.firstShow.future.timeout(const Duration(seconds: 10));

    expect(ocr.captures, 1);
    expect(overlay.shown.single.payout, 10);
  });

  test(
    'OCR retries a card that was captured before it finished rendering',
    () async {
      final previous = OfferWatcher.ocrCooldown;
      OfferWatcher.ocrCooldown = Duration.zero;
      addTearDown(() => OfferWatcher.ocrCooldown = previous);
      final c = container();
      c.read(settingsProvider.notifier).setOcrEnabled(true);
      ocr.responses.addAll([
        const OcrFrame(
          packageName: ParserRegistry.uberPackage,
          lines: ['UberX', r'$9.04', 'Accept'],
        ),
        OcrFrame(packageName: ParserRegistry.uberPackage, lines: _uberA.texts),
      ]);
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.uberPackage,
          texts: [],
          isActive: true,
        ),
      );
      for (var i = 0; i < 100 && ocr.captures < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(ocr.captures, 2);
      expect(c.read(offerLogProvider).single.platform, GigPlatform.uber);
      expect(overlay.shown, hasLength(1));
    },
  );

  test(
    'one conflicting OCR frame cannot replace live Uber economics',
    () async {
      final previous = OfferWatcher.ocrCooldown;
      OfferWatcher.ocrCooldown = const Duration(milliseconds: 10);
      addTearDown(() => OfferWatcher.ocrCooldown = previous);
      final c = container();
      c.read(settingsProvider.notifier).setOcrEnabled(true);
      ocr.responses.addAll([
        OcrFrame(packageName: ParserRegistry.uberPackage, lines: _uberA.texts),
        const OcrFrame(
          packageName: ParserRegistry.uberPackage,
          lines: [
            'UberX',
            r'$100.00',
            '4 mins (1.0 km) away',
            '15 mins (15.3 km) trip',
            'Accept',
          ],
        ),
      ]);
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.uberPackage,
          texts: [],
          isActive: true,
        ),
      );
      for (var i = 0; i < 20 && ocr.captures < 1; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 15));
      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.uberPackage,
          texts: [],
          isActive: true,
        ),
      );
      for (var i = 0; i < 20 && ocr.captures < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(ocr.captures, 2);
      expect(overlay.shown, hasLength(1));
      expect(overlay.shown.single.totalKm, 5);
      expect(c.read(offerLogProvider), hasLength(1));
    },
  );

  test(
    'video regression: dropped Uber decimals never show impossible math',
    () async {
      final previous = OfferWatcher.ocrCooldown;
      OfferWatcher.ocrCooldown = Duration.zero;
      addTearDown(() => OfferWatcher.ocrCooldown = previous);
      final c = container();
      c.read(settingsProvider.notifier).setOcrEnabled(true);
      ocr.responses.addAll([
        const OcrFrame(
          packageName: ParserRegistry.uberPackage,
          lines: [
            'UberX',
            r'$748',
            '6 mins (2.3 km) away',
            '16 mins (74 km) trip',
            'Match',
          ],
        ),
        const OcrFrame(
          packageName: ParserRegistry.uberPackage,
          lines: [
            'UberX',
            r'$7.48',
            '6 mins (2.3 km) away',
            '16 mins (7.4 km) trip',
            'Match',
          ],
        ),
      ]);
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.uberPackage,
          texts: [],
          isActive: true,
        ),
      );
      await overlay.firstShow.future.timeout(const Duration(seconds: 10));

      expect(overlay.shown.single.payout, 7.48);
      expect(overlay.shown.single.totalKm, closeTo(9.7, 1e-9));
      expect(overlay.shown.single.pricePerHour, closeTo(20.4, 1e-9));
      expect(c.read(offerLogProvider).single.payout, 7.48);
    },
  );

  test('dropped Uber distance decimal is corrected before display', () async {
    final previous = OfferWatcher.ocrCooldown;
    OfferWatcher.ocrCooldown = Duration.zero;
    addTearDown(() => OfferWatcher.ocrCooldown = previous);
    final c = container();
    c.read(settingsProvider.notifier).setOcrEnabled(true);
    ocr.responses.addAll([
      const OcrFrame(
        packageName: ParserRegistry.uberPackage,
        lines: ['UberX', r'$28.41', '41 mins (304 km) trip', 'Match'],
      ),
      const OcrFrame(
        packageName: ParserRegistry.uberPackage,
        lines: ['UberX', r'$28.41', '41 mins (30.4 km) trip', 'Match'],
      ),
    ]);
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(
      const ScreenRead(
        packageName: ParserRegistry.uberPackage,
        texts: [],
        isActive: true,
      ),
    );
    await overlay.firstShow.future.timeout(const Duration(seconds: 10));

    expect(ocr.captures, 2);
    expect(overlay.shown.single.totalKm, 30.4);
    expect(c.read(offerLogProvider).single.totalKm, 30.4);
  });

  test('a legitimate three-digit Uber payout is not delayed', () async {
    final c = container();
    c.read(settingsProvider.notifier).setOcrEnabled(true);
    ocr.responses.add(
      const OcrFrame(
        packageName: ParserRegistry.uberPackage,
        lines: [
          'UberX',
          r'$125.50',
          '10 mins (5.0 km) away',
          '80 mins (45.0 km) trip',
          'Match',
        ],
      ),
    );
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(
      const ScreenRead(
        packageName: ParserRegistry.uberPackage,
        texts: [],
        isActive: true,
      ),
    );
    for (var i = 0; i < 20 && overlay.shown.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(overlay.shown.single.payout, 125.50);
  });

  test(
    'a stale payout change just after card clear needs confirmation',
    () async {
      final previousCooldown = OfferWatcher.ocrCooldown;
      final previousVisible = OfferWatcher.maxVisible;
      OfferWatcher.ocrCooldown = const Duration(milliseconds: 10);
      OfferWatcher.maxVisible = const Duration(milliseconds: 10);
      addTearDown(() {
        OfferWatcher.ocrCooldown = previousCooldown;
        OfferWatcher.maxVisible = previousVisible;
      });
      final c = container();
      c.read(settingsProvider.notifier).setOcrEnabled(true);
      ocr.responses.addAll([
        const OcrFrame(
          packageName: ParserRegistry.uberPackage,
          lines: [
            'UberX',
            r'$9.48',
            '5 mins (2.0 km) away',
            '19 mins (9.5 km) trip',
            'Match',
          ],
        ),
        const OcrFrame(
          packageName: ParserRegistry.uberPackage,
          lines: [
            'UberX',
            r'$2.00',
            '5 mins (2.0 km) away',
            '19 mins (9.5 km) trip',
            'Match',
          ],
        ),
      ]);
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      const trigger = ScreenRead(
        packageName: ParserRegistry.uberPackage,
        texts: [],
        isActive: true,
      );
      watcher.emit(trigger);
      for (var i = 0; i < 20 && c.read(offerLogProvider).isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      watcher.emit(trigger);
      for (var i = 0; i < 20 && ocr.captures < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(c.read(offerLogProvider), hasLength(1));
      expect(c.read(offerLogProvider).single.payout, 9.48);
    },
  );

  test('lower app events do not discard a visible Uber OCR card', () async {
    final c = container();
    final settings = c.read(settingsProvider.notifier);
    settings.setOcrEnabled(true);
    settings.setOcrTestMode(true);
    ocr.lines = _uberA.texts;
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(_lyftA);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(overlay.shown, hasLength(2));
    expect(overlay.shown.last.payout, 10);
    expect(c.read(offerLogProvider), hasLength(2));
  });

  test('lower app map frames cannot clear a visible Uber OCR card', () async {
    final c = container();
    c.read(settingsProvider.notifier).setOcrEnabled(true);
    ocr.lines = _uberA.texts;
    ocr.packageName = ParserRegistry.lyftPackage;
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    const map = ScreenRead(
      packageName: ParserRegistry.lyftPackage,
      texts: ["You're online", 'Turbo available'],
      isActive: true,
    );
    watcher.emit(map);
    await overlay.firstShow.future.timeout(const Duration(seconds: 10));
    watcher.emit(map);
    await Future<void>.delayed(Duration.zero);

    expect(overlay.clears, 0);
    expect(c.read(offerWatcherProvider)?.platform, GigPlatform.uber);
  });

  for (final entry in {
    GigPlatform.hopp: ParserRegistry.hoppPackage,
    GigPlatform.lyft: ParserRegistry.lyftPackage,
    GigPlatform.doorDash: ParserRegistry.doorDashPackage,
    GigPlatform.instacart: ParserRegistry.instacartPackage,
    GigPlatform.skip: ParserRegistry.skipPackage,
  }.entries) {
    test('Uber OCR probes over selected ${entry.key.label} screens', () async {
      final c = container(watchedApps: {GigPlatform.uber, entry.key});
      c.read(settingsProvider.notifier).setOcrEnabled(true);
      ocr
        ..lines = _uberA.texts
        ..packageName = entry.value;
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(
        ScreenRead(
          packageName: entry.value,
          texts: const ['Map'],
          isActive: true,
        ),
      );
      await overlay.firstShow.future.timeout(const Duration(seconds: 10));

      expect(ocr.captures, 1);
      expect(c.read(offerLogProvider).single.platform, GigPlatform.uber);
    });
  }

  test('covered Lyft returns for five seconds after Uber OCR closes', () async {
    final previousCooldown = OfferWatcher.ocrCooldown;
    OfferWatcher.ocrCooldown = Duration.zero;
    addTearDown(() => OfferWatcher.ocrCooldown = previousCooldown);
    final c = container();
    c.read(settingsProvider.notifier).setOcrEnabled(true);
    ocr.responses.addAll([
      OcrFrame(packageName: ParserRegistry.lyftPackage, lines: _uberB.texts),
      const OcrFrame(
        packageName: ParserRegistry.lyftPackage,
        lines: ['__FOXYCO_NO_UBER_CARD__'],
      ),
    ]);
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(_lyftA);
    await overlay.secondShow.future.timeout(const Duration(seconds: 10));
    watcher.emit(_lyftA);
    await overlay.thirdShow.future.timeout(const Duration(seconds: 10));

    expect(overlay.shown.map((pill) => pill.payout), [10, 4.85, 10]);
    expect(c.read(offerWatcherProvider)?.platform, GigPlatform.lyft);
    expect(c.read(offerLogProvider), hasLength(2));
  });

  test(
    'Lyft first parsed beneath active Uber returns when Uber closes',
    () async {
      final previousCooldown = OfferWatcher.ocrCooldown;
      OfferWatcher.ocrCooldown = Duration.zero;
      addTearDown(() => OfferWatcher.ocrCooldown = previousCooldown);
      final c = container();
      c.read(settingsProvider.notifier).setOcrEnabled(true);
      ocr.responses.addAll([
        OcrFrame(packageName: ParserRegistry.lyftPackage, lines: _uberB.texts),
        const OcrFrame(
          packageName: ParserRegistry.lyftPackage,
          lines: ['__FOXYCO_NO_UBER_CARD__'],
        ),
      ]);
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.lyftPackage,
          texts: ["You're online"],
          isActive: true,
        ),
      );
      await overlay.firstShow.future.timeout(const Duration(seconds: 10));
      watcher.emit(_lyftA);
      await overlay.secondShow.future.timeout(const Duration(seconds: 10));

      expect(overlay.shown.map((pill) => pill.payout), [4.85, 10]);
      expect(c.read(offerWatcherProvider)?.platform, GigPlatform.lyft);
    },
  );

  test('non-Uber incomplete cards remain Accessibility-only', () async {
    final c = container();
    c.read(settingsProvider.notifier).setOcrEnabled(true);
    ocr.lines = _hoppNodes.texts;
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    const incomplete = [r'$8.00', 'Accept'];
    watcher.emit(
      const ScreenRead(
        packageName: ParserRegistry.hoppPackage,
        texts: incomplete,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(ocr.captures, 0);

    watcher.emit(
      const ScreenRead(
        packageName: ParserRegistry.hoppPackage,
        texts: incomplete,
        isActive: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(ocr.captures, 1);
    expect(overlay.shown, isEmpty);
  });

  test('OCR results are discarded after the driver disables OCR', () async {
    final c = container();
    final settings = c.read(settingsProvider.notifier);
    settings.setOcrEnabled(true);
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);
    settings.setOcrEnabled(false);

    watcher.emit(
      ScreenRead(
        packageName: '',
        texts: _hoppNodes.texts,
        isActive: true,
        source: CaptureSource.ocr,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(overlay.shown, isEmpty);
    expect(c.read(offerLogProvider), isEmpty);
  });

  test(
    'same offer re-firing shows the pill only once (flicker guard)',
    () async {
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
      // truly clears), then the same offer returns → remains suppressed.
      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.hoppPackage,
          texts: ['Home', 'Go online'],
          isActive: true,
        ),
      );
      await pastGrace();
      watcher.emit(_hoppNodes);
      await Future<void>.delayed(Duration.zero);

      expect(overlay.shown, hasLength(1));
      expect(
        c.read(offerLogProvider),
        hasLength(1),
        reason: 'a confirmed card exit must not resurrect the same offer',
      );
    },
  );

  test(
    'late Lyft labels do not create a second verdict or history row',
    () async {
      final c = container();
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      const base = ScreenRead(
        packageName: ParserRegistry.lyftPackage,
        texts: [r'$12.40', '4 min · 1.2 km', '18 min · 8.6 km', 'Accept'],
        isActive: true,
      );
      const enriched = ScreenRead(
        packageName: ParserRegistry.lyftPackage,
        texts: [
          r'$12.40',
          r'Incl. CA$2 bonus',
          '4 min · 1.2 km',
          '18 min · 8.6 km',
          'Add to queue',
        ],
        isActive: true,
      );

      watcher.emit(base);
      await Future<void>.delayed(Duration.zero);
      watcher.emit(enriched);
      await Future<void>.delayed(Duration.zero);

      expect(overlay.shown, hasLength(1));
      expect(c.read(offerLogProvider), hasLength(1));
    },
  );

  test(
    'a transient non-offer frame does NOT clear the pill (anti-flash)',
    () async {
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
    },
  );

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

  test('Lyft browse chrome cannot clear a still-active offer card', () async {
    final c = container();
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(
      const ScreenRead(
        packageName: ParserRegistry.lyftPackage,
        texts: [
          'Ride Finder',
          r'$12.40',
          '4 min · 1.2 km',
          '18 min · 8.6 km',
          'Accept',
        ],
        isActive: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    // During animation Lyft may expose only its background chrome plus the
    // card action. The card is still present, so this must cancel any clear.
    watcher.emit(
      const ScreenRead(
        packageName: ParserRegistry.lyftPackage,
        texts: ['Ride Finder', 'Earnings Goal', 'Accept'],
        isActive: true,
      ),
    );
    await pastGrace();

    expect(overlay.clears, 0);
    expect(overlay.shown, hasLength(1));
    expect(c.read(offerLogProvider), hasLength(1));
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

  test('same offer expires at the hard max and cannot resurrect', () async {
    final previous = OfferWatcher.maxVisible;
    OfferWatcher.maxVisible = const Duration(milliseconds: 30);
    addTearDown(() => OfferWatcher.maxVisible = previous);
    final c = container();
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);
    watcher.emit(_hoppNodes);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(overlay.clears, 1);
    watcher.emit(_hoppNodes);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(overlay.shown, hasLength(1));
  });

  test('a confirmed card exit is not held by minimum visibility', () async {
    final previous = OfferWatcher.minVisible;
    OfferWatcher.minVisible = const Duration(milliseconds: 80);
    addTearDown(() => OfferWatcher.minVisible = previous);
    final c = container();
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(_hoppNodes);
    await Future<void>.delayed(Duration.zero);
    watcher.emit(_hoppHome);
    await pastGrace();
    expect(overlay.clears, 1);
  });

  test('visible browse window wins over a stale lower offer window', () async {
    final c = container();
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(_hoppNodes);
    await Future<void>.delayed(Duration.zero);
    watcher.emit(
      const ScreenRead(
        packageName: ParserRegistry.hoppPackage,
        texts: ['Home', 'Go online', 'Current shift'],
        isActive: true,
        windows: [
          ScreenWindow(
            texts: ['Home', 'Go online', 'Current shift'],
            isActive: true,
            layer: 2,
          ),
          ScreenWindow(
            texts: [
              '\$8.50',
              '(NET, tax included)',
              '11 min · 5.2 km',
              '11 min · 7.7 km',
              'Match',
            ],
            layer: 1,
          ),
        ],
      ),
    );
    await pastGrace();

    expect(overlay.clears, 1);
    expect(overlay.shown, hasLength(1));
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

  test('another app cannot keep the current pill idle timer alive', () async {
    final previous = OfferWatcher.idleTimeout;
    OfferWatcher.idleTimeout = const Duration(milliseconds: 30);
    addTearDown(() => OfferWatcher.idleTimeout = previous);
    final c = container();
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(_hoppNodes);
    await Future<void>.delayed(Duration.zero);
    watcher.emit(
      const ScreenRead(
        packageName: ParserRegistry.uberPackage,
        texts: ['UberX', r'$14.20', '18 mins (9.4 km) trip', 'Accept'],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    watcher.emit(_hoppPartial);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(overlay.clears, 1);
  });

  test(
    'foreground app switch clears the previous app pill immediately',
    () async {
      final c = container();
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(_hoppNodes);
      await Future<void>.delayed(Duration.zero);
      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.uberPackage,
          texts: ['Map'],
          isActive: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(overlay.clears, 1);
    },
  );

  test('valid top offer replaces another platform without clearing', () async {
    final c = container();
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(_hoppNodes);
    await Future<void>.delayed(Duration.zero);
    watcher.emit(
      const ScreenRead(
        packageName: ParserRegistry.uberPackage,
        texts: ['UberX', '\$14.20', '18 mins (9.4 km) trip', 'Accept'],
        isActive: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(overlay.shown, hasLength(2));
    expect(overlay.clears, 0);
    expect(c.read(offerLogProvider).first.platform, GigPlatform.uber);
  });

  test(
    'same-platform Uber offer replaces within one and three seconds',
    () async {
      for (final delay in [
        const Duration(seconds: 1),
        const Duration(seconds: 3),
      ]) {
        watcher = _FakeWatcher();
        overlay = _FakeOverlayService();
        final c = container();
        c.read(offerWatcherProvider);
        c.read(overlayControllerProvider);

        watcher.emit(_uberA);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(delay);
        watcher.emit(_uberB);
        await Future<void>.delayed(Duration.zero);

        expect(overlay.shown, hasLength(2));
        expect(overlay.shown.last.payout, 4.85);
        expect(overlay.clears, 0);
        expect(c.read(offerWatcherProvider)!.payout, 4.85);
      }
    },
  );

  test(
    'a previously seen Uber offer can replace a different active offer',
    () async {
      final c = container();
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(_uberB);
      await Future<void>.delayed(Duration.zero);
      watcher.emit(_uberA);
      await Future<void>.delayed(Duration.zero);
      watcher.emit(_uberB);
      await Future<void>.delayed(Duration.zero);

      expect(overlay.shown, hasLength(3));
      expect(overlay.shown.last.payout, 4.85);
    },
  );

  test(
    'materially changed fare, time, or distance replaces the active offer',
    () async {
      final c = container();
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(_uberA);
      await Future<void>.delayed(Duration.zero);
      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.uberPackage,
          texts: [
            'UberX',
            r'$10.00',
            '4 mins (1.0 km) away',
            '20 mins (4.0 km) trip',
            'Accept',
          ],
          isActive: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(overlay.shown, hasLength(2));
      expect(overlay.shown.last.totalMinutes, 24);
    },
  );

  test(
    'Uber and Lyft consecutive offers replace in either direction',
    () async {
      for (final pair in [
        (_uberA, _lyftB),
        (_lyftA, _uberB),
        (_lyftA, _lyftB),
      ]) {
        watcher = _FakeWatcher();
        overlay = _FakeOverlayService();
        final c = container();
        c.read(offerWatcherProvider);
        c.read(overlayControllerProvider);

        watcher.emit(pair.$1);
        await Future<void>.delayed(Duration.zero);
        watcher.emit(pair.$2);
        await Future<void>.delayed(Duration.zero);

        expect(overlay.shown, hasLength(2));
        expect(overlay.shown.last.payout, c.read(offerWatcherProvider)!.payout);
        expect(overlay.clears, 0);
      }
    },
  );

  test(
    'does not clear when a non-offer screen was never showing a pill',
    () async {
      final c = container();
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(_hoppHome);
      await Future<void>.delayed(Duration.zero);

      expect(overlay.shown, isEmpty);
      expect(overlay.clears, 0);
    },
  );

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

    watcher.emit(
      const ScreenRead(
        packageName: 'com.whatsapp',
        texts: ['\$8.50', '11 min · 5.2 km', '11 min · 7.7 km'],
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(overlay.shown, isEmpty);
  });

  test('parses an Uber card attributed to foreground Lyft', () async {
    final c = container();
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(
      const ScreenRead(
        packageName: ParserRegistry.lyftPackage,
        texts: [
          'UberX',
          '\$7.06',
          '5 mins (2.1 km) away',
          '13 mins (6.4 km) trip',
          'Accept',
        ],
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(overlay.shown.single.payout, 7.06);
    expect(c.read(offerLogProvider).single.platform, GigPlatform.uber);
  });

  test('top Uber Radar window replaces a complete Lyft window below', () async {
    final c = container();
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(_lyftA);
    await Future<void>.delayed(Duration.zero);
    watcher.emit(
      const ScreenRead(
        packageName: ParserRegistry.lyftPackage,
        texts: ['UberX', r'$13.45', 'Match'],
        isActive: true,
        windows: [
          ScreenWindow(
            id: 22,
            layer: 9,
            isFocused: true,
            texts: [
              'UberX',
              r'$13.45',
              '2 mins (0.1 km) away',
              '31 mins (16.1 km) trip',
              'Match',
            ],
          ),
          ScreenWindow(
            id: 11,
            layer: 4,
            texts: [
              'Lyft',
              r'$11.04',
              '4 mins · 0.8 km',
              '18 mins · 9.1 km',
              'Accept',
            ],
          ),
        ],
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(overlay.shown.last.payout, 13.45);
    expect(c.read(offerWatcherProvider)!.platform, GigPlatform.uber);
  });

  test('revealed Lyft card regains verdict after Uber closes', () async {
    final c = container();
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(_lyftA);
    await Future<void>.delayed(Duration.zero);
    watcher.emit(_uberA);
    await Future<void>.delayed(Duration.zero);
    watcher.emit(_lyftA);
    await Future<void>.delayed(Duration.zero);

    expect(overlay.shown, hasLength(3));
    expect(c.read(offerWatcherProvider)!.platform, GigPlatform.lyft);
  });

  test('incomplete new top card clears the lower card verdict', () async {
    final c = container();
    c.read(offerWatcherProvider);
    c.read(overlayControllerProvider);

    watcher.emit(
      const ScreenRead(
        packageName: ParserRegistry.lyftPackage,
        texts: [
          'Lyft',
          r'$11.04',
          '4 mins · 0.8 km',
          '18 mins · 9.1 km',
          'Accept',
        ],
        isActive: true,
        windows: [
          ScreenWindow(
            id: 11,
            layer: 4,
            isFocused: true,
            texts: [
              'Lyft',
              r'$11.04',
              '4 mins · 0.8 km',
              '18 mins · 9.1 km',
              'Accept',
            ],
          ),
        ],
      ),
    );
    await Future<void>.delayed(Duration.zero);
    watcher.emit(
      const ScreenRead(
        packageName: ParserRegistry.lyftPackage,
        texts: ['UberX', r'$13.45', 'Match'],
        isActive: true,
        windows: [
          ScreenWindow(
            id: 22,
            layer: 9,
            isFocused: true,
            texts: ['UberX', r'$13.45', 'Match'],
          ),
          ScreenWindow(
            id: 11,
            layer: 4,
            texts: [
              'Lyft',
              r'$11.04',
              '4 mins · 0.8 km',
              '18 mins · 9.1 km',
              'Accept',
            ],
          ),
        ],
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(overlay.clears, 1);
    expect(c.read(offerWatcherProvider), isNull);
  });

  group('outcome inference', () {
    test('card → browse screen marks the offer missed', () async {
      final c = container();
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(_hoppNodes);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(offerLogProvider).first.outcome, OfferOutcome.unknown);

      // "Go online" is a browse marker → driver passed on the offer.
      watcher.emit(_hoppHome);
      await pastGrace();
      expect(c.read(offerLogProvider).first.outcome, OfferOutcome.missed);
    });

    test('card → explicit Hopp trip state marks it taken', () async {
      final c = container();
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(_hoppNodes);
      await Future<void>.delayed(Duration.zero);

      // No card hallmarks, no browse markers — the in-trip navigation screen
      // after an accept.
      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.hoppPackage,
          texts: ['Navigate to rider', '3 min', 'Main St'],
          isActive: true,
        ),
      );
      await pastGrace();
      expect(c.read(offerLogProvider).first.outcome, OfferOutcome.taken);
    });

    test('accepting Hopp cannot mark a newer Uber offer accepted', () async {
      final c = container();
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(_hoppNodes);
      await Future<void>.delayed(Duration.zero);
      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.uberPackage,
          texts: ['UberX', r'$14.20', '18 mins (9.4 km) trip', 'Accept'],
        ),
      );
      await Future<void>.delayed(Duration.zero);

      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.hoppPackage,
          texts: ['Start Trip'],
          isActive: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final log = c.read(offerLogProvider);
      expect(log.first.platform, GigPlatform.uber);
      expect(log.first.outcome, OfferOutcome.unknown);
      expect(log.last.platform, GigPlatform.hopp);
      expect(log.last.outcome, OfferOutcome.taken);
    });

    test('background Hopp home cannot clear or mark newer offers', () async {
      final c = container();
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(_hoppNodes);
      await Future<void>.delayed(Duration.zero);
      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.uberPackage,
          texts: ['UberX', r'$14.20', '18 mins (9.4 km) trip', 'Accept'],
        ),
      );
      await Future<void>.delayed(Duration.zero);
      watcher.emit(_hoppBackgroundHome);
      await pastGrace();

      final log = c.read(offerLogProvider);
      expect(log.first.platform, GigPlatform.uber);
      expect(log.first.outcome, OfferOutcome.unknown);
      expect(log.last.platform, GigPlatform.hopp);
      expect(log.last.outcome, OfferOutcome.unknown);
      expect(overlay.clears, 0);
    });

    for (final stateText in const [
      'You have arrived',
      'Arrived',
      '01:59 Waiting',
      'Start Trip',
      'End Trip',
      'Confirm Price',
      'Rate passenger',
    ]) {
      test('Hopp "$stateText" marks the History offer accepted', () async {
        final c = container();
        c.read(offerWatcherProvider);
        c.read(overlayControllerProvider);

        watcher.emit(_hoppNodes);
        await Future<void>.delayed(Duration.zero);
        watcher.emit(
          ScreenRead(
            packageName: ParserRegistry.hoppPackage,
            texts: [stateText],
            isActive: true,
          ),
        );
        await pastGrace();

        expect(c.read(offerLogProvider).first.outcome, OfferOutcome.taken);
      });
    }

    test('an old Uber LAST TRIP popup never rewrites History', () async {
      final c = container();
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.uberPackage,
          texts: ['UberX', '\$13.21', '20 mins (20.9 km) trip', 'Match'],
        ),
      );
      await Future<void>.delayed(Duration.zero);
      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.uberPackage,
          texts: ['Home', 'Finding trips'],
          isActive: true,
        ),
      );
      await pastGrace();
      expect(c.read(offerLogProvider).single.outcome, OfferOutcome.missed);

      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.uberPackage,
          texts: ['\$13.21', 'LAST TRIP', 'Today at 4:29 p.m.', 'UberX'],
          isActive: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(c.read(offerLogProvider).single.outcome, OfferOutcome.missed);
    });

    test('a background browse frame cannot mark an offer missed', () async {
      final c = container();
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(_hoppNodes);
      await Future<void>.delayed(Duration.zero);
      watcher.emit(_hoppBackgroundHome);
      await pastGrace();

      expect(c.read(offerLogProvider).single.outcome, OfferOutcome.unknown);
      expect(overlay.clears, 0);
    });

    test('a background trip frame cannot mark an offer taken', () async {
      final c = container();
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(_hoppNodes);
      await Future<void>.delayed(Duration.zero);
      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.hoppPackage,
          texts: ['Start Trip'],
        ),
      );
      await pastGrace();

      expect(c.read(offerLogProvider).single.outcome, OfferOutcome.unknown);
      expect(overlay.clears, 0);
    });

    test('active trip evidence corrects a weak missed inference', () async {
      final c = container();
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(_hoppNodes);
      await Future<void>.delayed(Duration.zero);
      watcher.emit(_hoppHome);
      await pastGrace();
      expect(c.read(offerLogProvider).single.outcome, OfferOutcome.missed);

      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.hoppPackage,
          texts: ['You have arrived'],
          isActive: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(c.read(offerLogProvider).single.outcome, OfferOutcome.taken);
    });

    test('Hopp Confirm Price wins over its fare card hallmark', () async {
      final c = container();
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(_hoppNodes);
      await Future<void>.delayed(Duration.zero);
      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.hoppPackage,
          texts: [
            'Confirm Price',
            '\$7.26',
            'In-app payment. Don\'t take money.',
            'Confirm price',
          ],
          isActive: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(c.read(offerLogProvider).single.outcome, OfferOutcome.taken);
    });

    test('ambiguous non-card screen leaves the outcome unknown', () async {
      final c = container();
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(_hoppNodes);
      await Future<void>.delayed(Duration.zero);
      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.hoppPackage,
          texts: ['Main St', '3 min'],
          isActive: true,
        ),
      );
      await pastGrace();
      expect(c.read(offerLogProvider).first.outcome, OfferOutcome.unknown);
      expect(overlay.clears, 1);
    });

    for (final stateText in const [
      'Arrive',
      'Passenger notified Slide to pick up',
      'Slide to drop off',
    ]) {
      test('Lyft "$stateText" marks the offer taken', () async {
        final c = container();
        c.read(offerWatcherProvider);
        c.read(overlayControllerProvider);

        watcher.emit(
          const ScreenRead(
            packageName: ParserRegistry.lyftPackage,
            texts: ['\$9.01', '3 mins · 0.4 km', '16 mins · 7.2 km', 'Accept'],
          ),
        );
        await Future<void>.delayed(Duration.zero);
        watcher.emit(
          ScreenRead(
            packageName: ParserRegistry.lyftPackage,
            texts: [stateText],
            isActive: true,
          ),
        );
        await pastGrace();
        expect(c.read(offerLogProvider).first.outcome, OfferOutcome.taken);
      });
    }

    test('an active trip screen cannot confirm a queued Lyft card', () async {
      final c = container();
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.lyftPackage,
          texts: [
            'Add to queue',
            '\$15.04',
            '3 mins · 1 km',
            '31 mins · 12.5 km',
          ],
        ),
      );
      await Future<void>.delayed(Duration.zero);
      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.lyftPackage,
          texts: ['Slide to drop off'],
          isActive: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(c.read(offerLogProvider).single.outcome, OfferOutcome.unknown);
    });

    test('active Lyft Added to queue confirms the queued card', () async {
      final c = container();
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.lyftPackage,
          texts: [
            'Add to queue',
            '\$15.04',
            '3 mins · 1 km',
            '31 mins · 12.5 km',
          ],
        ),
      );
      await Future<void>.delayed(Duration.zero);
      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.lyftPackage,
          texts: ['Added to queue'],
          isActive: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(c.read(offerLogProvider).single.outcome, OfferOutcome.taken);
    });

    for (final stateText in const [
      'Picking up Alex',
      'Waiting for rider',
      'Start UberX',
      'Start Comfort',
      'Dropping off Alex',
      'Complete Uber Share',
    ]) {
      test('Uber "$stateText" marks the offer taken', () async {
        final c = container();
        c.read(offerWatcherProvider);
        c.read(overlayControllerProvider);

        watcher.emit(
          const ScreenRead(
            packageName: ParserRegistry.uberPackage,
            texts: ['UberX', '\$9', '15 mins (4.3 km) trip', 'Accept'],
          ),
        );
        await Future<void>.delayed(Duration.zero);
        watcher.emit(
          ScreenRead(
            packageName: ParserRegistry.uberPackage,
            texts: [stateText],
            isActive: true,
          ),
        );
        await pastGrace();
        expect(c.read(offerLogProvider).first.outcome, OfferOutcome.taken);
      });
    }

    test(
      'an existing Uber trip cannot accept an offer drawn over it',
      () async {
        final c = container();
        c.read(offerWatcherProvider);
        c.read(overlayControllerProvider);

        watcher.emit(
          const ScreenRead(
            packageName: ParserRegistry.uberPackage,
            texts: ['Dropping off Alex'],
            isActive: true,
          ),
        );
        watcher.emit(
          const ScreenRead(
            packageName: ParserRegistry.uberPackage,
            texts: ['UberX', '\$5.75', '8 mins (5.1 km) trip', 'Accept'],
            isActive: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        watcher.emit(
          const ScreenRead(
            packageName: ParserRegistry.uberPackage,
            texts: ['Dropping off Alex'],
            isActive: true,
          ),
        );
        await pastGrace();

        expect(c.read(offerLogProvider).single.outcome, OfferOutcome.unknown);
      },
    );

    test('repeated Uber trip frames cannot accept two recent offers', () async {
      final c = container();
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.uberPackage,
          texts: ['UberX', '\$5.36', '8 mins (4.8 km) trip', 'Accept'],
          isActive: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.uberPackage,
          texts: ['UberX', '\$19.94', '30 mins (22.4 km) trip', 'Accept'],
          isActive: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      const trip = ScreenRead(
        packageName: ParserRegistry.uberPackage,
        texts: ['Picking up Sarah'],
        isActive: true,
      );
      watcher.emit(trip);
      watcher.emit(trip);
      await pastGrace();

      final log = c.read(offerLogProvider);
      expect(log, hasLength(2));
      expect(log.first.payout, 19.94);
      expect(log.first.outcome, OfferOutcome.taken);
      expect(log.last.payout, 5.36);
      expect(log.last.outcome, OfferOutcome.unknown);
    });

    test('accepted Uber window cannot stamp stale lower offers', () async {
      final c = container();
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      for (final payout in const ['\$5.36', '\$8.72', '\$30.70']) {
        watcher.emit(
          ScreenRead(
            packageName: ParserRegistry.uberPackage,
            texts: ['UberX', payout, '15 mins (8.4 km) trip', 'Accept'],
            isActive: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }

      for (final stalePayout in const ['\$8.72', '\$5.36']) {
        watcher.emit(
          ScreenRead(
            packageName: ParserRegistry.uberPackage,
            texts: const ['Picking up Sarah'],
            isActive: true,
            windows: [
              const ScreenWindow(
                texts: ['Picking up Sarah'],
                isActive: true,
                layer: 2,
              ),
              ScreenWindow(
                texts: [
                  'UberX',
                  stalePayout,
                  '15 mins (8.4 km) trip',
                  'Accept',
                ],
                layer: 1,
              ),
            ],
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }

      final log = c.read(offerLogProvider);
      expect(log, hasLength(3));
      expect(log.first.payout, 30.70);
      expect(log.first.outcome, OfferOutcome.taken);
      expect(log.skip(1).map((offer) => offer.outcome), [
        OfferOutcome.unknown,
        OfferOutcome.unknown,
      ]);
    });

    test('a different gig app cannot stamp the shown offer outcome', () async {
      final c = container();
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(_hoppNodes);
      await Future<void>.delayed(Duration.zero);
      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.uberPackage,
          texts: ['Picking up a rider'],
          isActive: true,
        ),
      );
      await pastGrace();
      expect(c.read(offerLogProvider).first.outcome, OfferOutcome.unknown);
    });

    test('card frame returning cancels a pending missed outcome', () async {
      final c = container();
      c.read(offerWatcherProvider);
      c.read(overlayControllerProvider);

      watcher.emit(_hoppNodes);
      await Future<void>.delayed(Duration.zero);

      // A browse frame weakly arms missed, but the card comes right back before
      // the grace elapses — no outcome may be stamped.
      watcher.emit(_hoppHome);
      watcher.emit(
        const ScreenRead(
          packageName: ParserRegistry.hoppPackage,
          texts: ['\$8.50', '(NET, tax included)', '11 min · 5.2 km', 'Match'],
          isActive: true,
        ),
      );
      await pastGrace();
      expect(c.read(offerLogProvider).first.outcome, OfferOutcome.unknown);
      expect(overlay.clears, 0);
    });

    // Device 2026-08-06: the driver was inside a DIFFERENT gig app when the
    // offer arrived, accepted it, then switched over and set up navigation —
    // far longer than the pill lives, so the accepting app was silent and the
    // pill timed out first. Both an accepted Uber and an accepted Lyft trip
    // logged as not taken. Outcome must survive the pill.
    for (final (label, card, inTrip) in [
      (
        'Lyft',
        const ScreenRead(
          packageName: ParserRegistry.lyftPackage,
          texts: ['\$9.01', '3 mins · 0.4 km', '16 mins · 7.2 km', 'Accept'],
        ),
        'Arrive',
      ),
      (
        'Uber',
        const ScreenRead(
          packageName: ParserRegistry.uberPackage,
          texts: ['UberX', '\$9', '15 mins (4.3 km) trip', 'Accept'],
        ),
        'Picking up Alex',
      ),
    ]) {
      test(
        '$label trip screen after the pill timed out still marks it taken',
        () async {
          OfferWatcher.idleTimeout = const Duration(milliseconds: 10);
          addTearDown(
            () => OfferWatcher.idleTimeout = const Duration(seconds: 7),
          );
          final c = container();
          c.read(offerWatcherProvider);
          c.read(overlayControllerProvider);

          watcher.emit(card);
          await Future<void>.delayed(Duration.zero);
          expect(c.read(offerLogProvider).first.outcome, OfferOutcome.unknown);

          // The driver is still in the other app, so this one sends nothing and
          // the pill times out.
          await Future<void>.delayed(const Duration(milliseconds: 30));
          expect(overlay.clears, 1);

          // Only now does the driver open the app they accepted in.
          watcher.emit(
            ScreenRead(
              packageName: card.packageName,
              texts: [inTrip],
              isActive: true,
            ),
          );
          await pastGrace();
          expect(c.read(offerLogProvider).first.outcome, OfferOutcome.taken);
        },
      );
    }
  });
}
