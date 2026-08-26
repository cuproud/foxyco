import 'package:flutter/material.dart';

const ocrDisclosureTitle = 'Enable Uber screen-reading fallback?';
const ocrDisclosureBody =
    'When enabled, FoxyCo reads Uber offers with one screenshot of your visible '
    'screen after an active watched-app event, then recognizes its text on this '
    'device. This includes an Uber request '
    'drawn over another selected driver app. Recognized screenshot text is sent '
    'only to the Uber parser; other offers continue using Accessibility text. '
    'Screenshots are held only in memory, never saved or uploaded, and are cleared '
    'immediately after recognition. Accessibility remains enabled for watched-app '
    'events and screenshot access; non-Uber offers use its text directly. '
    'Uber OCR works only while FoxyCo monitoring and Accessibility are on.';

Future<bool> showOcrDisclosure(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(ocrDisclosureTitle),
        content: const Text(ocrDisclosureBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enable Uber OCR'),
          ),
        ],
      ),
    ) ??
    false;
