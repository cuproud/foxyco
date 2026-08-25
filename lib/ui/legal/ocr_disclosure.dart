import 'package:flutter/material.dart';

const ocrDisclosureTitle = 'Enable Uber screen-reading fallback?';
const ocrDisclosureBody =
    'When Android Accessibility cannot read a visible Uber offer, FoxyCo can '
    'take one screenshot of your visible screen after an active watched-app '
    'event and recognize its text on this device. Other platforms continue '
    'using Accessibility text only. '
    'Screenshots are held only in memory, never saved or uploaded, and are cleared '
    'immediately after recognition. Accessibility remains the primary reader. '
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
