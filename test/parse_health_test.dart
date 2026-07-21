import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/services/parse_health.dart';

void main() {
  test('fresh session: no data, nothing flagged', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(parseHealthProvider), isEmpty);
    expect(const PlatformHealth().likelyBroken, isFalse);
  });

  test('card misses alone flag likelyBroken at the threshold', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final h = c.read(parseHealthProvider.notifier);

    for (var i = 0; i < PlatformHealth.brokenAfterMisses - 1; i++) {
      h.recordCardMiss(GigPlatform.uber);
    }
    expect(
      c.read(parseHealthProvider)[GigPlatform.uber]!.likelyBroken,
      isFalse,
      reason: 'one under the threshold must not flag',
    );

    h.recordCardMiss(GigPlatform.uber);
    expect(c.read(parseHealthProvider)[GigPlatform.uber]!.likelyBroken, isTrue);
  });

  test('a successful parse clears the miss streak and unflags', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final h = c.read(parseHealthProvider.notifier);

    for (var i = 0; i < PlatformHealth.brokenAfterMisses; i++) {
      h.recordCardMiss(GigPlatform.lyft);
    }
    expect(c.read(parseHealthProvider)[GigPlatform.lyft]!.likelyBroken, isTrue);

    h.recordParse(GigPlatform.lyft);
    final after = c.read(parseHealthProvider)[GigPlatform.lyft]!;
    expect(after.likelyBroken, isFalse);
    expect(after.parsed, 1);
    expect(after.cardMisses, 0);
  });

  test('misses never flag once anything has parsed (partials are normal)', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final h = c.read(parseHealthProvider.notifier);

    h.recordParse(GigPlatform.hopp);
    for (var i = 0; i < PlatformHealth.brokenAfterMisses * 2; i++) {
      h.recordCardMiss(GigPlatform.hopp);
    }
    expect(
      c.read(parseHealthProvider)[GigPlatform.hopp]!.likelyBroken,
      isFalse,
    );
  });

  test('platforms are tracked independently', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final h = c.read(parseHealthProvider.notifier);

    for (var i = 0; i < PlatformHealth.brokenAfterMisses; i++) {
      h.recordCardMiss(GigPlatform.uber);
    }
    h.recordParse(GigPlatform.lyft);

    expect(c.read(parseHealthProvider)[GigPlatform.uber]!.likelyBroken, isTrue);
    expect(
      c.read(parseHealthProvider)[GigPlatform.lyft]!.likelyBroken,
      isFalse,
    );
    expect(c.read(parseHealthProvider)[GigPlatform.hopp], isNull);
  });
}
