import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/services/tips_provider.dart';
import 'package:foxyco/ui/home/fox_tips_card.dart';

/// Verify real Inter text remains fully visible as each quick tip changes.
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
    for (final scale in const [1.0, 1.1, 1.3, 2.0]) {
      testWidgets('every tip fits at ${screen.toInt()}dp x$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(screen, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final container = ProviderContainer();
        addTearDown(container.dispose);
        final tips = container.read(tipsProvider);
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

        for (final tip in tips) {
          final body = tester.renderObject<RenderParagraph>(
            find.text(tip.body),
          );
          expect(body.didExceedMaxLines, isFalse);
          expect(tester.takeException(), isNull, reason: tip.headline);
          await tester.tap(find.byTooltip('Next tip'));
          await tester.pumpAndSettle();
        }
      });
    }
  }
}
