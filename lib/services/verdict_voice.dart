import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/verdict.dart';

/// Android's installed text-to-speech voice. Each call replaces any speech
/// still queued, so a burst of offers never becomes a spoken backlog.
class VerdictVoice {
  VerdictVoice({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('foxyco/voice');

  final MethodChannel _channel;
  DateTime? _lastSpokenAt;

  Future<void> speak(Verdict verdict, int cooldownSeconds) async {
    if (verdict != Verdict.good && verdict != Verdict.ok) return;
    final now = DateTime.now();
    if (_lastSpokenAt != null &&
        now.difference(_lastSpokenAt!) < Duration(seconds: cooldownSeconds)) {
      return;
    }
    _lastSpokenAt = now;
    await _speak(verdict);
  }

  Future<void> preview(Verdict verdict) => _speak(verdict);

  Future<void> _speak(Verdict verdict) => _invoke('speak', {
    'text': verdict == Verdict.ok ? 'Okay offer' : 'Good offer',
  });

  Future<void> stop() async {
    _lastSpokenAt = null;
    await _invoke('stop');
  }

  Future<void> _invoke(String method, [Map<String, Object?>? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } catch (error) {
      if (kDebugMode) debugPrint('FoxyCo voice skipped: $error');
    }
  }
}

final verdictVoiceProvider = Provider<VerdictVoice>((ref) => VerdictVoice());
