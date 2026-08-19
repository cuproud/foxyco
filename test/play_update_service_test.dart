import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foxyco/services/play_update_service.dart';

class _FakePlayUpdateGateway implements PlayUpdateGateway {
  final events = StreamController<PlayUpdateStatus>.broadcast();
  PlayUpdateStatus next = PlayUpdateStatus.idle;
  var starts = 0;
  var completions = 0;

  @override
  Stream<PlayUpdateStatus> get statusChanges => events.stream;

  @override
  Future<PlayUpdateStatus> check() async => next;

  @override
  Future<bool> startFlexible() async {
    starts++;
    return true;
  }

  @override
  Future<void> complete() async => completions++;

  Future<void> close() => events.close();
}

void main() {
  test('no update leaves the app idle', () async {
    final gateway = _FakePlayUpdateGateway();
    final container = ProviderContainer(
      overrides: [playUpdateGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(() async {
      container.dispose();
      await gateway.close();
    });

    await container.read(playUpdateProvider.notifier).check();
    expect(container.read(playUpdateProvider).state, PlayUpdateState.idle);
  });

  test('available update starts the flexible flow', () async {
    final gateway = _FakePlayUpdateGateway()
      ..next = const PlayUpdateStatus(PlayUpdateState.available);
    final container = ProviderContainer(
      overrides: [playUpdateGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(() async {
      container.dispose();
      await gateway.close();
    });
    final controller = container.read(playUpdateProvider.notifier);

    controller.beginForegroundSession();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(playUpdateProvider).state, PlayUpdateState.available);
    await controller.startFlexible();
    expect(gateway.starts, 1);
  });

  test(
    'Later suppresses the prompt until the next foreground session',
    () async {
      final gateway = _FakePlayUpdateGateway()
        ..next = const PlayUpdateStatus(PlayUpdateState.available);
      final container = ProviderContainer(
        overrides: [playUpdateGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(() async {
        container.dispose();
        await gateway.close();
      });
      final controller = container.read(playUpdateProvider.notifier);

      controller.beginForegroundSession();
      await Future<void>.delayed(Duration.zero);
      controller.later();
      await controller.check();
      expect(container.read(playUpdateProvider).state, PlayUpdateState.idle);

      controller.beginForegroundSession();
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(playUpdateProvider).state,
        PlayUpdateState.available,
      );
    },
  );

  test('downloaded update offers completion through Play', () async {
    final gateway = _FakePlayUpdateGateway()
      ..next = const PlayUpdateStatus(PlayUpdateState.downloaded);
    final container = ProviderContainer(
      overrides: [playUpdateGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(() async {
      container.dispose();
      await gateway.close();
    });
    final controller = container.read(playUpdateProvider.notifier);

    await controller.check();
    expect(
      container.read(playUpdateProvider).state,
      PlayUpdateState.downloaded,
    );
    await controller.complete();
    expect(gateway.completions, 1);
  });
}
