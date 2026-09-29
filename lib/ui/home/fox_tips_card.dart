import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/fox_tip.dart';
import '../../services/tips_provider.dart';
import '../shell/root_shell.dart';
import '../theme/tokens.dart';

class FoxTipsCard extends ConsumerStatefulWidget {
  const FoxTipsCard({super.key});

  @override
  ConsumerState<FoxTipsCard> createState() => _FoxTipsCardState();
}

class _FoxTipsCardState extends ConsumerState<FoxTipsCard> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tips = ref.watch(tipsProvider);
    if (tips.isEmpty) return const SizedBox.shrink();
    final tip = tips[_index % tips.length];
    final (category, action, destination) = switch (tip.category) {
      TipCategory.earnings => ('Earnings', 'Review History', 3),
      TipCategory.maintenance => ('Car care', 'Open Garage', 2),
      TipCategory.app
          when tip.headline == 'Review your results after each shift' =>
        ('FoxyCo', 'Review History', 3),
      TipCategory.app => ('FoxyCo', 'Open Rules', 1),
      TipCategory.gigLife => ('Gig life', 'Open Garage', 2),
      TipCategory.safety => ('Safety', null, null),
    };
    return Container(
      key: const Key('fox-quick-tip'),
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: FoxColors.bgSurface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: FoxColors.borderSoft),
        boxShadow: Shadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.field),
                child: Image.asset(
                  tip.asset,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.lightbulb_outline_rounded),
                  ),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  category,
                  style: TextStyle(
                    color: FoxColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(tip.headline, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Gap.sm),
          Text(
            tip.body,
            style: TextStyle(
              color: FoxColors.textSecondary,
              fontSize: 13,
              height: 1.42,
            ),
          ),
          const SizedBox(height: Gap.sm),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: Gap.sm,
            children: [
              if (action != null && destination != null)
                TextButton.icon(
                  key: const Key('quick-tip-action'),
                  onPressed: () =>
                      ref.read(tabIndexProvider.notifier).go(destination),
                  style: TextButton.styleFrom(
                    foregroundColor: FoxColors.brandText,
                    minimumSize: const Size(48, 48),
                  ),
                  label: Text(action),
                  icon: const Icon(Icons.chevron_right_rounded, size: 18),
                  iconAlignment: IconAlignment.end,
                ),
              if (tips.length > 1)
                Tooltip(
                  message: 'Next tip',
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _index = (_index + 1) % tips.length),
                    style: TextButton.styleFrom(
                      foregroundColor: FoxColors.textSecondary,
                      minimumSize: const Size(48, 48),
                    ),
                    label: const Text('Next tip'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    iconAlignment: IconAlignment.end,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
