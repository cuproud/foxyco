import 'package:flutter/material.dart';

const accessibilityDisclosureTitle = 'Read-only offer access';
const accessibilityDisclosureBody =
    'FoxyCo uses Accessibility only for offer-related text in Uber Driver, '
    'Lyft Driver and Hopp Driver. It reads pay, distance and duration to '
    'calculate your verdict. Extracted offer numbers stay in private storage '
    'on this device; raw screen text is never saved, uploaded or shared. '
    'FoxyCo cannot tap, accept, decline or control any driver app.';

Future<bool> showAccessibilityDisclosure(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(accessibilityDisclosureTitle),
        content: const SingleChildScrollView(
          child: Text(accessibilityDisclosureBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Agree & open settings'),
          ),
        ],
      ),
    ) ??
    false;
