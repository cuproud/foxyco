import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/overlay_action.dart';
import 'package:foxyco/domain/overlay_control.dart';
import 'package:foxyco/domain/overlay_payload.dart';
import 'package:foxyco/domain/verdict.dart';

void main() {
  group('OverlayAction — overlay→main wire format', () {
    test('round-trips through toMap/fromMap', () {
      for (final a in OverlayAction.values) {
        expect(OverlayAction.fromMap(a.toMap()), a);
      }
    });

    test('tags itself as an action', () {
      expect(OverlayAction.openApp.toMap()['kind'], 'action');
    });

    test('ignores non-action maps (fail safe)', () {
      expect(OverlayAction.fromMap({'kind': 'offer'}), isNull);
      expect(OverlayAction.fromMap({'kind': 'action', 'action': 'bogus'}),
          isNull);
      expect(OverlayAction.fromMap({}), isNull);
    });
  });

  group('message kinds are distinguishable on the shared channel', () {
    test('offer / control / action never collide', () {
      final offer = const OverlayPayload(
              verdict: Verdict.good, totalKm: 8, payout: 12)
          .toMap();
      final control = OverlayControl.paused(true);
      final action = OverlayAction.togglePause.toMap();

      expect(offer['kind'], 'offer');
      expect(control['kind'], 'control');
      expect(action['kind'], 'action');

      // A control/action map must NOT decode as an offer verdict, and vice versa.
      expect(OverlayControl.isControl(offer), isFalse);
      expect(OverlayAction.fromMap(control), isNull);
    });

    test('control carries its paused flag', () {
      expect(OverlayControl.paused(true)['paused'], isTrue);
      expect(OverlayControl.clearPill()['clearPill'], isTrue);
    });
  });
}
