import 'package:flutter/material.dart';

import '../../domain/offer_summary.dart';
import 'tokens.dart';

/// Visual language for the driver's inferred action. Kept separate from
/// verdict styling: GOOD/BAD describes offer value; accepted/not taken
/// describes what happened afterward.
class OutcomeStyle {
  const OutcomeStyle({
    required this.label,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String label;
  final String detail;
  final IconData icon;
  final Color color;

  static OutcomeStyle of(OfferOutcome outcome) => switch (outcome) {
    OfferOutcome.taken => OutcomeStyle(
      label: 'Accepted',
      detail: 'Trip activity confirmed after this offer.',
      icon: Icons.check_circle_rounded,
      color: VerdictColors.good,
    ),
    OfferOutcome.missed => OutcomeStyle(
      label: 'Not taken',
      detail: 'The app returned to its offer map.',
      icon: Icons.cancel_rounded,
      color: VerdictColors.bad,
    ),
    OfferOutcome.unknown => OutcomeStyle(
      label: 'Unconfirmed',
      detail: 'No reliable trip state was visible afterward.',
      icon: Icons.help_rounded,
      color: VerdictColors.unknown,
    ),
  };
}
