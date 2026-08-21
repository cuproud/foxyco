import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/services/play_update_service.dart';
import 'package:foxyco/ui/home/update_prompt.dart';

class _Gateway implements PlayUpdateGateway {
  final events = StreamController<PlayUpdateStatus>.broadcast();
  var starts = 0;
  var completions = 0;

  @override
  Stream<PlayUpdateStatus> get statusChanges => events.stream;

  @override
  Future<PlayUpdateStatus> check() async => PlayUpdateStatus.idle;

  @override
  Future<bool> startFlexible() async {
    starts++;
    return true;
  }

  @override
  Future<void> complete() async => completions++;
}

class _Available extends PlayUpdateController {
  @override
  PlayUpdateStatus build() => const PlayUpdateStatus(PlayUpdateState.available);
}

class _Downloading extends PlayUpdateController {
  @override
  PlayUpdateStatus build() =>
      const PlayUpdateStatus(PlayUpdateState.downloading, progress: 0.64);
}

class _Preparing extends PlayUpdateController {
  @override
  PlayUpdateStatus build() =>
      const PlayUpdateStatus(PlayUpdateState.downloading, progress: 0);
}

class _Downloaded extends PlayUpdateController {
  @override
  PlayUpdateStatus build() =>
      const PlayUpdateStatus(PlayUpdateState.downloaded);
}

Widget _app(PlayUpdateController Function() controller, _Gateway gateway) =>
    ProviderScope(
      overrides: [
        playUpdateGatewayProvider.overrideWithValue(gateway),
        playUpdateProvider.overrideWith(controller),
      ],
      child: const MaterialApp(home: Scaffold(body: PlayUpdatePrompt())),
    );

void main() {
  testWidgets('available update is compact and actionable', (tester) async {
    final gateway = _Gateway();
    addTearDown(gateway.events.close);
    await tester.pumpWidget(_app(_Available.new, gateway));

    expect(find.text('FoxyCo update available'), findsOneWidget);
    expect(
      find.text('A newer version is ready with fixes and improvements.'),
      findsNothing,
    );
    expect(find.text('Later'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(
      tester
          .getSemantics(find.text('FoxyCo update available'))
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );

    await tester.tap(find.text('Update now'));
    expect(gateway.starts, 1);
  });

  testWidgets('downloading update stays compact', (tester) async {
    final gateway = _Gateway();
    addTearDown(gateway.events.close);
    await tester.pumpWidget(_app(_Downloading.new, gateway));

    expect(find.text('Updating FoxyCo… 64%'), findsOneWidget);
    expect(find.text('Later'), findsNothing);
    expect(find.text('Update now'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('zero progress reads as preparation, not a stalled download', (
    tester,
  ) async {
    final gateway = _Gateway();
    addTearDown(gateway.events.close);
    await tester.pumpWidget(_app(_Preparing.new, gateway));

    expect(find.text('Preparing update…'), findsOneWidget);
    expect(find.textContaining('0%'), findsNothing);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      isNull,
    );
  });

  testWidgets('downloaded update offers restart', (tester) async {
    final gateway = _Gateway();
    addTearDown(gateway.events.close);
    await tester.pumpWidget(_app(_Downloaded.new, gateway));

    expect(find.text('FoxyCo update ready'), findsOneWidget);
    expect(find.text('Restart now'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.text('FoxyCo update ready'))
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );

    await tester.tap(find.text('Restart now'));
    expect(gateway.completions, 1);
  });
}
