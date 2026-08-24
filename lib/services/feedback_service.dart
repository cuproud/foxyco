import 'package:flutter/services.dart';

const feedbackRecipient = 'foxyco.tester@gmail.com';

enum FeedbackCategory {
  bug('Problem'),
  offerDetection('Offer detection'),
  uiUx('App screen'),
  other('Other');

  const FeedbackCategory(this.label);
  final String label;
}

class FeedbackDraft {
  const FeedbackDraft({
    this.category = FeedbackCategory.bug,
    this.description = '',
    this.includeDiagnostics = false,
  });

  const FeedbackDraft.missedOffer()
    : category = FeedbackCategory.offerDetection,
      description =
          'A driver offer appeared, but FoxyCo did not show a verdict.\n\nPlatform: \nApproximate time: ',
      includeDiagnostics = true;

  final FeedbackCategory category;
  final String description;
  final bool includeDiagnostics;
}

class FeedbackContext {
  const FeedbackContext({
    required this.version,
    required this.build,
    required this.android,
    required this.device,
  });

  final String version;
  final String build;
  final String android;
  final String device;

  factory FeedbackContext.fromMap(Map<Object?, Object?> map) => FeedbackContext(
    version: map['version'] as String? ?? 'Unknown',
    build: map['build'] as String? ?? 'Unknown',
    android: map['android'] as String? ?? 'Unknown',
    device: map['device'] as String? ?? 'Unknown',
  );
}

class FeedbackMessage {
  const FeedbackMessage({
    required this.recipient,
    required this.subject,
    required this.body,
    required this.imagePaths,
  });

  final String recipient;
  final String subject;
  final String body;
  final List<String> imagePaths;
}

FeedbackMessage buildFeedbackMessage({
  required FeedbackCategory category,
  required String description,
  required FeedbackContext context,
  List<String> imagePaths = const [],
  String diagnostics = '',
}) => FeedbackMessage(
  recipient: feedbackRecipient,
  subject: 'FoxyCo v${context.version} (${context.build}) — ${category.label}',
  body:
      'What happened?\n\n'
      '${description.trim()}\n\n'
      '---\n\n'
      'App details\n\n'
      'Version: ${context.version} (${context.build})\n'
      'Category: ${category.label}\n'
      'Android: ${context.android}\n'
      'Device: ${context.device}\n'
      '${diagnostics.trim().isEmpty ? '' : '\nRecent FoxyCo diagnostics\n\n${diagnostics.trim()}\n'}',
  imagePaths: List.unmodifiable(imagePaths.take(3)),
);

class FeedbackPlatform {
  const FeedbackPlatform();

  static const _channel = MethodChannel('foxyco/feedback');

  Future<FeedbackContext> context() async => FeedbackContext.fromMap(
    await _channel.invokeMethod<Map<Object?, Object?>>('context') ?? const {},
  );

  Future<List<String>> pickImages(int limit) async =>
      (await _channel.invokeListMethod<String>('pickImages', {
        'limit': limit,
      })) ??
      const [];

  Future<bool> send(FeedbackMessage message) async =>
      await _channel.invokeMethod<bool>('send', {
        'recipient': message.recipient,
        'subject': message.subject,
        'body': message.body,
        'imagePaths': message.imagePaths,
      }) ??
      false;
}
