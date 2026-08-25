import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ocrCaptureProvider = Provider<OcrCapture>((ref) => const OcrCapture());

class OcrFrame {
  const OcrFrame({required this.packageName, required this.lines});

  final String packageName;
  final List<String> lines;
}

/// Android Accessibility screenshot OCR. Each requested frame is processed in
/// memory by bundled ML Kit; only recognized lines cross into Dart.
class OcrCapture {
  const OcrCapture();

  static const _channel = MethodChannel('foxyco/ocr');

  Future<bool> start() async {
    try {
      return await _channel.invokeMethod<bool>('start') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      // Accessibility may already have disconnected or cancelled the request.
    } on MissingPluginException {
      // Off-device tests.
    }
  }

  Future<OcrFrame> capture() async {
    try {
      final value = await _channel
          .invokeMethod<Object?>('capture')
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
      if (value is Map) {
        return OcrFrame(
          packageName: value['packageName'] as String? ?? '',
          lines: List<String>.from(value['lines'] as List? ?? const []),
        );
      }
      // Compatibility with an older installed native runner during hot reload.
      return OcrFrame(
        packageName: '',
        lines: value is List ? List<String>.from(value) : const [],
      );
    } on PlatformException {
      return const OcrFrame(packageName: '', lines: []);
    } on MissingPluginException {
      return const OcrFrame(packageName: '', lines: []);
    }
  }
}
