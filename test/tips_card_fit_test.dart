import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/services/tips_provider.dart';
import 'package:foxyco/ui/home/fox_tips_card.dart';

/// The tips deck used to be a hard `SizedBox(height: 252)`, so the body always
/// got the same 78dp regardless of the text in it — tip #2's last line ("every
/// verdict") was ellipsed on device, and at 1.1x font scale most tips clipped
/// (2026-08-06). The deck now measures the longest tip and sizes to it.
///
/// Uses the REAL typeface: the default test font is Ahem (every glyph a
/// square), which over-measures so badly the assertions would pass for the
/// wrong reason.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('Inter')
      ..addFont(
        File('fonts/Inter.ttf').readAsBytes().then(
          (b) => ByteData.view(Uint8List.fromList(b).buffer),
        ),
      );
    await loader.load();
  });

  for (final screen in const [320.0, 360.0, 375.0, 412.0]) {
    for (final scale in const [1.0, 1.1, 1.3]) {
      testWidgets('every tip fits at ${screen.toInt()}dp x$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(screen, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final tips = ProviderContainer().read(tipsProvider);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData(fontFamily: 'Inter'),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: const Scaffold(
                  body: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: FoxTipsCard(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // No RenderFlex overflow anywhere in the card (the category chip +
        // counter row overran by 23dp at 320dp before it was made Flexible).
        expect(tester.takeException(), isNull);

        final slot = tester.getSize(find.text(tips.first.body));
        for (final tip in tips) {
          final painter = TextPainter(
            text: TextSpan(
              text: tip.body,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.42,
              ),
            ),
            textScaler: TextScaler.linear(scale),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: slot.width);
          expect(
            painter.height,
            lessThanOrEqualTo(slot.height + 0.5),
            reason:
                '"${tip.headline}" needs ${painter.height.toStringAsFixed(0)}dp '
                'but the deck reserves ${slot.height.toStringAsFixed(0)}dp',
          );
          painter.dispose();
        }
      });
    }
  }
}
