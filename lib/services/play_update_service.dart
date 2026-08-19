import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PlayUpdateState {
  idle,
  available,
  notAllowed,
  starting,
  downloading,
  downloaded,
  failure,
}

class PlayUpdateStatus {
  const PlayUpdateStatus(this.state, {this.progress});

  final PlayUpdateState state;
  final double? progress;

  static const idle = PlayUpdateStatus(PlayUpdateState.idle);
}

abstract interface class PlayUpdateGateway {
  Stream<PlayUpdateStatus> get statusChanges;
  Future<PlayUpdateStatus> check();
  Future<bool> startFlexible();
  Future<void> complete();
}

class MethodChannelPlayUpdateGateway implements PlayUpdateGateway {
  MethodChannelPlayUpdateGateway()
    : _method = const MethodChannel('foxyco/play_updates'),
      _events = const EventChannel('foxyco/play_updates/events');

  final MethodChannel _method;
  final EventChannel _events;

  @override
  Stream<PlayUpdateStatus> get statusChanges =>
      _events.receiveBroadcastStream().map((event) => _status(event));

  @override
  Future<PlayUpdateStatus> check() async {
    final result = await _method.invokeMethod<Object?>('check');
    return _status(result);
  }

  @override
  Future<bool> startFlexible() async =>
      await _method.invokeMethod<bool>('startFlexible') ?? false;

  @override
  Future<void> complete() => _method.invokeMethod<void>('complete');

  PlayUpdateStatus _status(Object? raw) {
    if (raw is! Map) return PlayUpdateStatus(PlayUpdateState.failure);
    final state = switch (raw['state']) {
      'available' => PlayUpdateState.available,
      'notAllowed' => PlayUpdateState.notAllowed,
      'starting' => PlayUpdateState.starting,
      'downloading' => PlayUpdateState.downloading,
      'downloaded' => PlayUpdateState.downloaded,
      _ => PlayUpdateState.idle,
    };
    final downloaded = (raw['downloaded'] as num?)?.toDouble();
    final total = (raw['total'] as num?)?.toDouble();
    return PlayUpdateStatus(
      state,
      progress: downloaded != null && total != null && total > 0
          ? (downloaded / total).clamp(0.0, 1.0)
          : null,
    );
  }
}

final playUpdateGatewayProvider = Provider<PlayUpdateGateway>(
  (ref) => MethodChannelPlayUpdateGateway(),
);

final playUpdateProvider =
    NotifierProvider<PlayUpdateController, PlayUpdateStatus>(
      PlayUpdateController.new,
    );

class PlayUpdateController extends Notifier<PlayUpdateStatus> {
  StreamSubscription<PlayUpdateStatus>? _subscription;
  bool _dismissed = false;

  @override
  PlayUpdateStatus build() {
    final gateway = ref.read(playUpdateGatewayProvider);
    _subscription = gateway.statusChanges.listen(_receive, onError: (_) {});
    ref.onDispose(() => _subscription?.cancel());
    return PlayUpdateStatus.idle;
  }

  void beginForegroundSession() {
    _dismissed = false;
    unawaited(check());
  }

  void _receive(PlayUpdateStatus next) {
    if (!ref.mounted) return;
    if (!_dismissed ||
        next.state == PlayUpdateState.starting ||
        next.state == PlayUpdateState.downloading ||
        next.state == PlayUpdateState.downloaded) {
      state = next;
    }
  }

  Future<void> check() async {
    try {
      final next = await ref.read(playUpdateGatewayProvider).check();
      if (ref.mounted &&
          (!_dismissed || next.state == PlayUpdateState.downloaded)) {
        state = next;
      }
    } catch (_) {
      if (ref.mounted) state = PlayUpdateStatus.idle;
    }
  }

  Future<void> startFlexible() async {
    if (state.state != PlayUpdateState.available) return;
    state = PlayUpdateStatus(PlayUpdateState.starting);
    try {
      final started = await ref.read(playUpdateGatewayProvider).startFlexible();
      if (!started && ref.mounted) state = PlayUpdateStatus.idle;
    } catch (_) {
      if (ref.mounted) state = PlayUpdateStatus.idle;
    }
  }

  Future<void> complete() async {
    if (state.state != PlayUpdateState.downloaded) return;
    try {
      await ref.read(playUpdateGatewayProvider).complete();
    } catch (_) {
      // Play owns installation. A transient failure should not affect FoxyCo.
    }
  }

  void later() {
    _dismissed = true;
    if (state.state == PlayUpdateState.available ||
        state.state == PlayUpdateState.downloaded) {
      state = PlayUpdateStatus.idle;
    }
  }
}
