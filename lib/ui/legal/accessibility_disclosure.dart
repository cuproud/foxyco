import 'package:flutter/material.dart';

const accessibilityDisclosureTitle = 'Offer access';
const accessibilityDisclosureBody =
    'Uses Android Accessibility to read offers from the driver apps you select '
    'and show a private GOOD, OK or BAD verdict. Choose up to three supported '
    'apps. When Uber is selected, FoxyCo may take a temporary screenshot of a '
    'visible Uber offer and recognize it on this device. Screenshots and raw '
    'screen text are never saved or uploaded. FoxyCo only reads—it cannot tap, '
    'accept, decline or control another app.';

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
