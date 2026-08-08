import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/services/billing/fox_clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('trusted server time heals a future-poisoned high-water mark', () async {
    final poisoned = DateTime.now().toUtc().add(const Duration(days: 365));
    SharedPreferences.setMockInitialValues({
      'foxyco.clock.highwater.v1': poisoned.millisecondsSinceEpoch,
    });
    expect(
      await FoxClock.now(),
      DateTime.fromMillisecondsSinceEpoch(
        poisoned.millisecondsSinceEpoch,
        isUtc: true,
      ),
    );

    final serverNow = DateTime.now().toUtc();
    await FoxClock.syncFromServer(serverNow);
    final healed = await FoxClock.now();

    expect(healed.isBefore(poisoned), isTrue);
    expect(healed.difference(serverNow), lessThan(const Duration(seconds: 1)));
  });
}
