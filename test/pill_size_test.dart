import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/overlay_payload.dart';
import 'package:foxyco/domain/verdict.dart';
import 'package:foxyco/ui/overlay/verdict_pill.dart';

/// Small / Medium / Large must be three visibly different, EVENLY spaced pills.
///
/// They weren't: every size rendered wider than its overlay window (natural
/// widths 392 / 435 / 522dp against 300 / 324 / 348dp windows) and simply
/// overflowed, so the text drew unscaled and Medium and Large looked identical
/// on device (2026-08-06). The pill is now scaled to fit its window, which
/// makes the window box the single source of size truth.
void main() {
  // Must mirror OverlayEntry._pillBoxFor.
  const boxes = {
    PillSize.small: (w: 288.0, h: 48.0),
    PillSize.medium: (w: 320.0, h: 56.0),
    PillSize.large: (w: 352.0, h: 64.0),
  };

  Future<Size> drawnSize(
    WidgetTester tester,
    PillSize size,
    OverlayPayload payload,
  ) async {
    final win = boxes[size]!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: win.w,
              height: win.h,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: VerdictPill(animate: false, payload: payload),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final natural = tester.getSize(find.byType(VerdictPill));
    final scale = (win.w / natural.width).clamp(0.0, 1.0);
    return Size(natural.width * scale, natural.height * scale);
  }

  // A typical offer and a deliberately wide one (4-figure payout, long trip) —
  // content length must not change which size looks bigger.
  for (final content in const [
    ('typical', 8.4, 10.2, 42.0),
    ('wide', 31.6, 74.0, 96.0),
  ]) {
    testWidgets('${content.$1} offer: S < M < L, evenly', (tester) async {
      final drawn = <PillSize, Size>{};
      for (final size in PillSize.values) {
        drawn[size] = await drawnSize(
          tester,
          size,
          OverlayPayload(
            verdict: Verdict.good,
            totalKm: content.$2,
            payout: content.$3,
            totalMinutes: content.$4,
            entitled: true,
            size: size,
          ),
        );
      }

      final s = drawn[PillSize.small]!;
      final m = drawn[PillSize.medium]!;
      final l = drawn[PillSize.large]!;

      // Never wider than its window — that overflow was the original bug.
      for (final size in PillSize.values) {
        expect(drawn[size]!.width, lessThanOrEqualTo(boxes[size]!.w + 0.5));
        expect(drawn[size]!.height, lessThanOrEqualTo(boxes[size]!.h + 0.5));
      }

      // Strictly increasing, and each step a real jump (not the 7% that made
      // Medium and Large indistinguishable).
      expect(m.height, greaterThan(s.height * 1.06));
      expect(l.height, greaterThan(m.height * 1.06));

      // Evenly spaced: the two steps must be within 40% of each other. The old
      // metrics stepped +2 then +5 in type size.
      final stepA = m.height - s.height;
      final stepB = l.height - m.height;
      expect(
        (stepA - stepB).abs() / ((stepA + stepB) / 2),
        lessThan(0.4),
        reason:
            'uneven size steps: S→M ${stepA.toStringAsFixed(1)}dp, '
            'M→L ${stepB.toStringAsFixed(1)}dp',
      );
    });
  }

  testWidgets('Uber Eats pill shows the number of deliveries', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VerdictPill(
          animate: false,
          payload: OverlayPayload(
            verdict: Verdict.ok,
            totalKm: 26.6,
            payout: 14.10,
            totalMinutes: 54,
            deliveryCount: 2,
          ),
        ),
      ),
    );
    expect(find.text('2 deliveries'), findsOneWidget);
  });

  testWidgets('pickup target is binary and total distance stays neutral', (
    tester,
  ) async {
    Future<void> pump(bool near) => tester.pumpWidget(
      MaterialApp(
        home: VerdictPill(
          animate: false,
          payload: OverlayPayload(
            verdict: Verdict.good,
            totalKm: 8.4,
            payout: 12,
            totalMinutes: 24,
            pickupKm: near ? 1.5 : 2.0,
            pickupNearKm: 1.5,
          ),
        ),
      ),
    );

    await pump(true);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.gps_fixed_rounded)).color,
      const Color(0xFF5ECD90),
    );
    expect(
      tester.widget<Text>(find.text('8.4 km')).style?.color,
      const Color(0xC6F4EFE1),
    );

    await pump(false);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.gps_fixed_rounded)).color,
      const Color(0xFFFF8A7E),
    );
    expect(
      tester.widget<Text>(find.text('8.4 km')).style?.color,
      const Color(0xC6F4EFE1),
    );
  });
}
