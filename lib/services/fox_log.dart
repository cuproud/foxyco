import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Persistent, buffered, fail-soft file logger (spec M5 §2).
///
/// Lines: `2026-07-16T21:04:11.123 [tag] message`. Appends go to an in-memory
/// queue and hit disk on a short timer — hot a11y paths never block on I/O.
/// At [maxBytes] the file rolls to `foxyco.log.1` (previous `.1` deleted);
/// two files max. Every I/O error is swallowed: a logger must never crash the
/// pipeline. Off-device (tests without an injected dir) it is a silent no-op.
class FoxLog {
  FoxLog({
    Future<Directory?> Function()? dirResolver,
    this.maxBytes = 1024 * 1024,
  }) : _dirResolver = dirResolver ?? _defaultDir;

  final Future<Directory?> Function() _dirResolver;
  final int maxBytes;

  final List<String> _buffer = [];
  Timer? _flushTimer;

  static Future<Directory?> _defaultDir() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return null; // plugin channel missing (tests) → no-op logger
    }
  }

  Future<File?> _file() async {
    final dir = await _dirResolver();
    if (dir == null) return null;
    final logs = Directory('${dir.path}/logs');
    if (!logs.existsSync()) logs.createSync(recursive: true);
    return File('${logs.path}/foxyco.log');
  }

  /// Queue a line; flushed to disk within ~2s (or on [flush]).
  void log(String tag, String message) {
    _buffer.add('${DateTime.now().toIso8601String()} [$tag] $message');
    _flushTimer ??= Timer(const Duration(seconds: 2), () {
      _flushTimer = null;
      flush();
    });
  }

  /// Write the buffer out now. Safe to call anytime; fail-soft.
  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_buffer.isEmpty) return;
    final lines = List.of(_buffer);
    _buffer.clear();
    try {
      final file = await _file();
      if (file == null) return;
      // Sync write: keeps FoxLog usable under FakeAsync (widget tests) where
      // real async I/O futures never complete. Writes are small + buffered.
      file.writeAsStringSync('${lines.join('\n')}\n',
          mode: FileMode.append, flush: true);
      if (file.lengthSync() > maxBytes) _rotate(file);
    } catch (_) {/* fail-soft */}
  }

  void _rotate(File file) {
    try {
      final old = File('${file.path}.1');
      if (old.existsSync()) old.deleteSync();
      file.renameSync(old.path);
    } catch (_) {/* fail-soft */}
  }

  /// Last [maxChars] of the current file (viewer shows the tail).
  Future<String> tail({int maxChars = 64 * 1024}) async {
    try {
      await flush();
      final file = await _file();
      if (file == null || !file.existsSync()) return '';
      final content = file.readAsStringSync();
      return content.length <= maxChars
          ? content
          : content.substring(content.length - maxChars);
    } catch (_) {
      return '';
    }
  }

  /// Truncate both files (Settings → Clear).
  Future<void> clear() async {
    try {
      _buffer.clear();
      final file = await _file();
      if (file == null) return;
      if (file.existsSync()) file.deleteSync();
      final old = File('${file.path}.1');
      if (old.existsSync()) old.deleteSync();
    } catch (_) {/* fail-soft */}
  }
  /// Cancel the pending flush timer and write out whatever is queued.
  /// Called on provider dispose so widget tests don't leak the timer.
  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
    unawaited(flush());
  }
}

final foxLogProvider = Provider<FoxLog>((ref) {
  final log = FoxLog();
  ref.onDispose(log.dispose);
  return log;
});
