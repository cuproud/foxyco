import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxyco/services/tips_provider.dart';
import 'package:foxyco/ui/home/fox_tips_card.dart';
import 'package:foxyco/ui/theme/app_theme.dart';

void main() {
  test('ships twelve local tips using the optimized fox assets', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final tips = container.read(tipsProvider);
    expect(tips, hasLength(12));
    expect(tips.map((tip) => tip.asset).toSet(), hasLength(6));
    expect(tips.every((tip) => tip.asset.startsWith('assets/tips/')), isTrue);
  });

  testWidgets('tip card advances manually and exposes its position', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: Center(child: SizedBox(width: 375, child: FoxTipsCard())),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Find your best hours in History'), findsOneWidget);
    expect(find.text('1 / 12'), findsOneWidget);

    await tester.tap(find.byTooltip('Next tip'));
    await tester.pumpAndSettle();

    expect(find.text('Include the unpaid pickup distance'), findsOneWidget);
    expect(find.text('2 / 12'), findsOneWidget);
  });

  testWidgets('all tip copy fits without a layout exception at 320 dp', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: Center(child: SizedBox(width: 320, child: FoxTipsCard())),
          ),
        ),
      ),
    );
    await tester.pump();

    for (var page = 1; page < 12; page++) {
      await tester.tap(find.byTooltip('Next tip'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'tip ${page + 1}');
      if (page == 6) {
        final body = find.text(
          'Use your odometer and heavy-use schedule. Busy months may need '
          'service sooner.',
        );
        final paragraph = tester.renderObject<RenderParagraph>(body);
        final probe = TextPainter(
          text: paragraph.text,
          textDirection: paragraph.textDirection,
          textScaler: paragraph.textScaler,
        )..layout(maxWidth: paragraph.size.width);
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason:
              'tip 7 body must not be clipped '
              '(size=${paragraph.size}, maxLines=${paragraph.maxLines}, '
              'scale=${paragraph.textScaler}, '
              'lines=${probe.computeLineMetrics().length})',
        );
      }
    }

    expect(find.text('Gross pay is not take-home pay'), findsOneWidget);
  });
}
