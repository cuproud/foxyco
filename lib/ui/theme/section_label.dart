import 'package:flutter/material.dart';

import 'tokens.dart';

/// A small-caps section rule: label on the left, hairline running out to the
/// right edge. The app's one way of breaking a long page into named stretches —
/// Home's "Last session", History's date headers, and Settings' group bands
/// were three separate copies of this before.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(width: Gap.sm + Gap.xs),
        Expanded(child: Divider(color: FoxColors.border, height: 1)),
      ],
    );
  }
}
