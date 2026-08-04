import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/ui/theme/hero_stage.dart';
import 'package:foxyco/ui/theme/plasma_border.dart';
import 'package:foxyco/ui/theme/tokens.dart';

/// The stage runs an endless ambient loop, so the two things worth pinning are
/// (a) every layer composites in both palettes without throwing — the gradients
/// and shadows are built from runtime palette statics — and (b) reduced motion
/// really stops the clock, which `pumpAndSettle` proves by returning at all.
void main() {
  Widget host({
    required bool reduced,
    Widget? silhouette,
    Color? plasmaColor,
  }) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 360,
          child: HeroStage(
            silhouette: silhouette,
            plasmaColor: plasmaColor,
            child: const AspectRatio(
              aspectRatio: 1536 / 1024,
              child: Placeholder(key: ValueKey('car')),
            ),
          ),
        ),
      ),
    ),
  );

  for (final palette in [FoxPalette.dark, FoxPalette.light]) {
    final name = palette.brightness.name;
    testWidgets('composites and animates in $name', (tester) async {
      FoxColors.apply(palette);
      await tester.pumpWidget(host(reduced: false));
      expect(find.byKey(const ValueKey('car')), findsOneWidget);

      // Walk a full 24 s master cycle in coarse steps: every layer's animated
      // alpha, the float and the 900 ms sweep window all get built at least
      // once, and any bad gradient stop / negative alpha throws here.
      for (var i = 0; i < 24; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reflection sweep builds only inside its 900 ms window', (
    tester,
  ) async {
    FoxColors.apply(FoxPalette.dark);
    await tester.pumpWidget(
      host(reduced: false, silhouette: const ColoredBox(color: Colors.black)),
    );
    // Sweep fires in the first 900 ms of each 8 s loop.
    expect(find.byType(ShaderMask), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(ShaderMask), findsNothing);
    await tester.pump(const Duration(seconds: 6)); // next loop's window
    expect(find.byType(ShaderMask), findsOneWidget);
  });

  testWidgets('reduced motion leaves nothing ticking', (tester) async {
    FoxColors.apply(FoxPalette.dark);
    await tester.pumpWidget(host(reduced: true));
    // Would time out if the ambient controller were still repeating.
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('car')), findsOneWidget);
  });

  testWidgets('live plasma outline wraps the stage and honors reduced motion', (
    tester,
  ) async {
    FoxColors.apply(FoxPalette.light);
    await tester.pumpWidget(
      host(reduced: true, plasmaColor: FoxColors.brandFox),
    );
    expect(find.byType(PlasmaBorder), findsOneWidget);
    final plasmaPaint = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.foregroundPainter is PlasmaBorderPainter,
    );
    expect(plasmaPaint, findsOneWidget);
    expect(
      tester.widget<CustomPaint>(plasmaPaint).foregroundPainter,
      isA<PlasmaBorderPainter>(),
    );
    await tester.pumpAndSettle();
  });

  tearDown(() => FoxColors.apply(FoxPalette.dark));
}
