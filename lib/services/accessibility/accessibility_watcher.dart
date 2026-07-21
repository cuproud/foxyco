import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_accessibility_service/accessibility_event.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// DI seam for the accessibility wrapper so the dashboard/pipeline depend on the
/// class, not the plugin, and tests can override it with a fake. Lives here (not
/// with the pipeline) so `dashboard_controller` can read it without an import
/// cycle through the pipeline.
final accessibilityWatcherProvider = Provider<AccessibilityWatcher>(
  (ref) => AccessibilityWatcher(),
);

/// One screen's worth of text read off a watched app, ready for a parser.
///
/// [texts] is the flattened node text (this node + every descendant), in view
/// order — exactly what an [OfferParser] expects. [packageName] picks the parser.
class ScreenRead {
  final String packageName;
  final List<String> texts;
  const ScreenRead({required this.packageName, required this.texts});
}

/// Thin wrapper over `flutter_accessibility_service` (docs/ARCHITECTURE
/// services/accessibility). Everything plugin-specific lives here so the rest of
/// the app talks in [ScreenRead]s and `parser/`/`domain/` stay plugin-free.
///
/// Battery discipline (AUDIT #4): the Android service is already scoped to
/// Uber + Hopp in res/xml, but content-change events still machine-gun, so we
///   1. **debounce** — only parse after the screen settles briefly, and
///   2. **dedupe** — drop a read identical to the one we just emitted.
/// Both cut redundant parses to hit the <300 ms detect→verdict budget without
/// re-parsing the same frame dozens of times.
class AccessibilityWatcher {
  AccessibilityWatcher({this.debounce = const Duration(milliseconds: 250)});

  /// How long the screen must settle before we parse (AUDIT #4 debounce).
  final Duration debounce;

  /// Is the accessibility service enabled for FoxyCo right now?
  Future<bool> isEnabled() =>
      FlutterAccessibilityService.isAccessibilityPermissionEnabled();

  /// Open the system Accessibility settings; resolves true once granted.
  Future<bool> requestPermission() =>
      FlutterAccessibilityService.requestAccessibilityPermission();

  /// Fires whenever the OS reports the service turning on/off (e.g. the user
  /// revokes it in settings) so the dashboard's permission state stays truthful.
  Stream<bool> get statusChanges =>
      FlutterAccessibilityService.onAccessibilityServiceStatusChanged;

  /// A debounced, deduped stream of screen reads from the watched apps. Wrap the
  /// raw plugin stream so callers never touch `AccessibilityEvent`.
  Stream<ScreenRead> reads() {
    final controller = StreamController<ScreenRead>();
    Timer? debounceTimer;
    AccessibilityEvent? pending;
    String? lastKey;

    void flush() {
      final event = pending;
      pending = null;
      if (event == null) return;
      final texts = _flatten(event);
      if (texts.isEmpty) {
        // Do NOT stay silent here. A window frame with ZERO readable text from
        // a watched app is the signature of a canvas/Compose-rendered screen
        // (suspected Uber offer card, device 2026-07-18) — exactly the case an
        // OCR fallback would need. Emitting the empty read lets the pipeline
        // count textless frames per platform, so logcat/Settings can tell
        // "Uber sends nothing" apart from "Uber sends unreadable frames".
        controller.add(
          ScreenRead(packageName: event.packageName ?? '', texts: const []),
        );
        return;
      }
      // Dedupe: skip if identical to the last emitted read for this package.
      final key = '${event.packageName}|${texts.join('')}';
      if (key == lastKey) return;
      lastKey = key;
      controller.add(
        ScreenRead(packageName: event.packageName ?? '', texts: texts),
      );
    }

    if (kDebugMode) {
      debugPrint('FoxyCo[watch] reads() subscribing to accessStream');
    }
    final sub = FlutterAccessibilityService.accessStream.listen((event) {
      if (kDebugMode) {
        debugPrint(
          'FoxyCo[watch] RAW event pkg=${event.packageName} '
          'sub=${event.subNodes?.length}',
        );
      }
      pending = event;
      // TRAILING THROTTLE, not a reset-on-every-event debounce. A live offer
      // screen (Uber's map panning, a countdown ticking) fires content-change
      // events far faster than `debounce`; a debounce that cancels its timer on
      // each event NEVER settles, so `flush` never runs and ZERO reads are ever
      // emitted — the app looked dead on exactly the screens that matter. By
      // arming the timer only when one isn't already pending (and never
      // cancelling it), we guarantee a flush of the latest frame at least once
      // per `debounce`, whether or not events keep streaming.
      debounceTimer ??= Timer(debounce, () {
        debounceTimer = null;
        flush();
      });
    }, onError: controller.addError);

    controller.onCancel = () {
      debounceTimer?.cancel();
      return sub.cancel();
    };
    return controller.stream;
  }

  /// Depth-first flatten of an event's text + all sub-node texts, in view order,
  /// dropping empties. Node order mirrors the view hierarchy top→bottom, which
  /// is what the parsers rely on (first `$` = payout, first leg = pickup…).
  static List<String> _flatten(AccessibilityEvent event) {
    final out = <String>[];
    void walk(AccessibilityEvent e) {
      final t = _unwrap(e.text?.trim());
      // The plugin fills missing text with the literal string "null".
      if (t != null && t.isNotEmpty && t != 'null') out.add(t);
      for (final child in e.subNodes ?? const <AccessibilityEvent>[]) {
        walk(child);
      }
    }

    walk(event);
    return out;
  }

  /// Some nodes arrive as an Android SpannableString's `toString()`, e.g.
  /// `{mSpanCount: 0, mSpanData: [], mSpans: [], mText: $14.66 (NET, tax included)}`.
  /// The real text is in `mText:`; pull it out so parsers see clean content.
  /// Plain (non-wrapped) nodes pass through unchanged.
  static final _spanWrap = RegExp(r'^\{.*\bmText:\s*(.*)\}$', dotAll: true);
  static String? _unwrap(String? t) {
    if (t == null) return null;
    final m = _spanWrap.firstMatch(t);
    return m != null ? m.group(1)!.trim() : t;
  }
}
