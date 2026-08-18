import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/bubble_style.dart';
import 'package:foxyco/domain/fox_settings.dart';

void main() {
  test('defaults and invalid ids use Cool Fox', () {
    expect(BubbleStyle.fromId(null), BubbleStyle.coolFox);
    expect(BubbleStyle.fromId('future-style'), BubbleStyle.coolFox);
    expect(FoxSettings.defaults.bubbleStyle, BubbleStyle.coolFox);
  });

  test('bubble style persists through settings JSON', () {
    final saved = FoxSettings.defaults.copyWith(
      bubbleStyle: BubbleStyle.foxPaw,
    );
    expect(
      FoxSettings.fromJson(saved.toJson()).bubbleStyle,
      BubbleStyle.foxPaw,
    );
  });

  test('each style maps to its bundled bubble asset', () {
    expect(BubbleStyle.coolFox.assetPath, contains('foxyco_bubble.png'));
    expect(BubbleStyle.foxycoF.assetPath, contains('foxyco_f_bubble.png'));
    expect(BubbleStyle.foxPaw.assetPath, contains('foxyco_paw_bubble.png'));
  });
}
