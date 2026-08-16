import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/app_skin.dart';
import 'package:foxyco/domain/app_currency.dart';
import 'package:foxyco/domain/fox_settings.dart';
import 'package:foxyco/ui/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DelayedSettingsController extends SettingsController {
  final loadPreferences = Completer<SharedPreferences>();
  var _firstRead = true;

  @override
  Future<SharedPreferences> preferences() {
    if (_firstRead) {
      _firstRead = false;
      return loadPreferences.future;
    }
    return SharedPreferences.getInstance();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('startup edit is replayed over saved settings and persisted', () async {
    final saved = FoxSettings.defaults.copyWith(retentionDays: 7);
    SharedPreferences.setMockInitialValues({
      'foxyco.settings.v1': jsonEncode(saved.toJson()),
    });
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(_DelayedSettingsController.new),
      ],
    );
    addTearDown(container.dispose);
    container.read(settingsProvider);
    final controller =
        container.read(settingsProvider.notifier) as _DelayedSettingsController;

    controller.setSkin(AppSkin.dark);
    controller.loadPreferences.complete(await SharedPreferences.getInstance());
    while (container.read(settingsProvider).retentionDays != 7) {
      await Future<void>.delayed(Duration.zero);
    }

    final combined = container.read(settingsProvider);
    expect(combined.skin, AppSkin.dark);
    expect(combined.retentionDays, 7);

    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> disk() =>
        jsonDecode(prefs.getString('foxyco.settings.v1')!)
            as Map<String, dynamic>;
    while (disk()['skin'] != AppSkin.dark.name) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(disk()['retentionDays'], 7);
  });

  test('new install defaults to the Google Play storefront currency', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [playStoreCountryProvider.overrideWithValue(() async => 'AU')],
    );
    addTearDown(container.dispose);
    container.read(settingsProvider);

    while (container.read(settingsProvider).currency != AppCurrency.aud) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(container.read(settingsProvider).currency, AppCurrency.aud);
  });
}
