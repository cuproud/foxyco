import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/fox_tip.dart';
import '../../services/tips_provider.dart';
import '../theme/tokens.dart';

class FoxTipsCard extends ConsumerStatefulWidget {
  const FoxTipsCard({super.key});

  @override
  ConsumerState<FoxTipsCard> createState() => _FoxTipsCardState();
}

class _FoxTipsCardState extends ConsumerState<FoxTipsCard> {
  late final PageController _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int index, int length) {
    final next = index.clamp(0, length - 1);
    _pages.animateToPage(next, duration: Motion.base, curve: Motion.curve);
  }

  @override
  Widget build(BuildContext context) {
    final tips = ref.watch(tipsProvider);
    if (tips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 252,
      child: PageView.builder(
        controller: _pages,
        itemCount: tips.length,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (context, index) => _TipPage(
          tip: tips[index],
          index: index,
          count: tips.length,
          onPrevious: index == 0 ? null : () => _go(index - 1, tips.length),
          onNext: index == tips.length - 1
              ? null
              : () => _go(index + 1, tips.length),
          activeIndex: _index,
        ),
      ),
    );
  }
}

class _TipPage extends StatelessWidget {
  const _TipPage({
    required this.tip,
    required this.index,
    required this.count,
    required this.onPrevious,
    required this.onNext,
    required this.activeIndex,
  });

  final FoxTip tip;
  final int index;
  final int count;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final (label, accent) = switch (tip.category) {
      TipCategory.earnings => ('EARNINGS', const Color(0xFFF2B84B)),
      TipCategory.safety => ('SAFETY', const Color(0xFF69A9E8)),
      // Short enough to share the narrow header with "12 / 12" on 320 dp
      // phones, and plainer language than the overflowing "MAINTENANCE".
      TipCategory.maintenance => ('CAR CARE', const Color(0xFF5ECD90)),
      TipCategory.app => ('FOXYCO', FoxColors.brandFox),
      TipCategory.gigLife => ('GIG LIFE', const Color(0xFFA58AE8)),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.sm, Gap.sm),
      decoration: BoxDecoration(
        color: FoxColors.bgSurface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: FoxColors.borderSoft),
        boxShadow: Shadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: Gap.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Gap.sm,
                              vertical: Gap.xs,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(Radii.pill),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ),
                          const SizedBox(width: Gap.sm),
                          Text(
                            '${index + 1} / $count',
                            style: TextStyle(
                              color: FoxColors.textDisabled,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Gap.sm + Gap.xs),
                      Text(
                        tip.headline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: Gap.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.cardSm),
                child: Image.asset(
                  tip.asset,
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                  semanticLabel: '$label fox illustration',
                  errorBuilder: (_, _, _) => SizedBox(
                    width: 92,
                    height: 92,
                    child: Icon(
                      Icons.lightbulb_outline_rounded,
                      color: accent,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Expanded(
            child: Text(
              tip.body,
              // Four lines fit in the card's existing flexible body region.
              // Tip 7 legitimately wrapped to four lines on a 375 dp phone;
              // the old three-line cap replaced its final words with an
              // ellipsis even though the card had enough vertical room.
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.42,
                color: FoxColors.textSecondary,
              ),
            ),
          ),
          Row(
            children: [
              _ArrowButton(
                label: 'Previous tip',
                icon: Icons.arrow_back_rounded,
                onPressed: onPrevious,
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < count; i++)
                      AnimatedContainer(
                        duration: Motion.fast,
                        width: i == activeIndex ? 12 : 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i == activeIndex
                              ? FoxColors.brandFox
                              : FoxColors.border,
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                      ),
                  ],
                ),
              ),
              _ArrowButton(
                label: 'Next tip',
                icon: Icons.arrow_forward_rounded,
                onPressed: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onPressed,
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    icon: Icon(icon, size: 18),
    color: FoxColors.textSecondary,
    disabledColor: FoxColors.textDisabled.withValues(alpha: 0.35),
  );
}
