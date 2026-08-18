import 'package:flutter/material.dart';

const accessibilityDisclosureTitle = 'Offer access';
const accessibilityDisclosureBody =
    'Uses Android Accessibility to read gig offer details and calculate your '
    'verdict. Numbers stay on this device; '
    'raw screen text is not saved or uploaded. FoxyCo cannot tap, accept, '
    'decline or control any driver app.';

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
