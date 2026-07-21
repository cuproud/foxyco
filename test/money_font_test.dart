import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/fox_settings.dart';
import 'package:foxyco/domain/money_font.dart';

void main() {
  test('defaults to inter', () {
    expect(FoxSettings.defaults.moneyFont, MoneyFont.inter);
  });

  test('round-trips through json', () {
    final s = FoxSettings.defaults.copyWith(moneyFont: MoneyFont.spaceGrotesk);
    final back = FoxSettings.fromJson(s.toJson());
    expect(back.moneyFont, MoneyFont.spaceGrotesk);
  });

  test('old blobs without moneyFont fall back to inter', () {
    final j = FoxSettings.defaults.toJson()..remove('moneyFont');
    expect(FoxSettings.fromJson(j).moneyFont, MoneyFont.inter);
  });

  test('unknown persisted name falls back to inter', () {
    final j = FoxSettings.defaults.toJson()..['moneyFont'] = 'wingdings';
    expect(FoxSettings.fromJson(j).moneyFont, MoneyFont.inter);
  });
}
