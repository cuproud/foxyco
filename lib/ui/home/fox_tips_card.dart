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

    // The card used to be a hard `SizedBox(height: 252)`, which left the body
    // an 78dp slot regardless of the text in it — tip #2's last line ("every
    // verdict") was ellipsed on device even though nothing else filled the
    // card (2026-08-06), and at 1.1x font scale most tips clipped. Measure the
    // LONGEST tip at the real width instead and size the deck to that, so every
    // page shows its full text and the deck doesn't resize as you swipe.
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        // Measure with the SAME resolved style the body renders with. `Text`
        // merges its style onto DefaultTextStyle, so measuring bare _bodyStyle
        // would use a different typeface than the one drawn and reserve the
        // wrong height.
        final measured = DefaultTextStyle.of(context).style.merge(_bodyStyle);
        // Card padding (L/R); the body spans the card's full inner width.
        final bodyWidth = constraints.maxWidth - _padH;
        var tallestBody = 0.0;
        for (final tip in tips) {
          final painter = TextPainter(
            text: TextSpan(text: tip.body, style: measured),
            textScaler: scaler,
            textDirection: Directionality.of(context),
          )..layout(maxWidth: bodyWidth > 0 ? bodyWidth : constraints.maxWidth);
          if (painter.height > tallestBody) tallestBody = painter.height;
          painter.dispose();
        }

        return SizedBox(
          height: _chromeHeight(scaler) + tallestBody,
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
      },
    );
  }
}

/// Body text style — shared by the measuring pass and the rendered page so the
/// height the deck reserves is the height the text actually takes.
const _bodyStyle = TextStyle(fontSize: 13, height: 1.42);

/// Horizontal padding inside the card (see [_TipPage]'s Container).
const _padH = Gap.md + Gap.sm;

/// Everything in the card that isn't body text: padding, the header row
/// (illustration is the tallest element at 92dp), the gap, and the control row.
/// Text-dependent parts scale with the user's font size.
double _chromeHeight(TextScaler scaler) =>
    Gap.md + // top padding
    92 + // header row — illustration is the tallest element
    Gap.sm + // gap above body
    Gap.sm + // gap below body
    44 + // control row (IconButton tap target)
    Gap.sm + // bottom padding
    (scaler.scale(13) - 13) * 2; // headroom as type scales up

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
      // Was a flat fill + soft hairline, which read as a plain box. Three cheap
      // STATIC layers give it depth and let each category identify itself: a
      // wash of the category accent falling off across the card, an accent-tinted
      // border instead of the neutral one, and the accent carried into the
      // shadow. No animation, so the home screen's repaint cost is unchanged.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              accent.withValues(alpha: 0.10),
              FoxColors.bgSurface,
            ),
            Color.alphaBlend(
              accent.withValues(alpha: 0.025),
              FoxColors.bgSurface,
            ),
            FoxColors.bgSurface,
          ],
          stops: const [0, 0.55, 1],
        ),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
        boxShadow: [
          ...Shadows.card,
          BoxShadow(
            color: accent.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
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
                      // Flexible, not fixed: "MAINTENANCE" plus the counter
                      // overran this row by 23dp on a 320dp phone at default
                      // type size, and by 67dp at 1.3x (probe, 2026-08-06).
                      // The chip gives way first — the counter is short and
                      // reads as one glance.
                      Row(
                        children: [
                          Flexible(
                            child: Container(
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: Gap.sm),
                          Text(
                            '${index + 1} / $count',
                            maxLines: 1,
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
          // No maxLines cap: the deck reserves the tallest tip's real height
          // (see [_FoxTipsCardState.build]), so every body fits in full. A cap
          // here would silently re-introduce the ellipsis it was measured to
          // avoid.
          Expanded(
            child: Text(
              tip.body,
              style: _bodyStyle.copyWith(color: FoxColors.textSecondary),
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
