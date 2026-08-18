import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../domain/money_font.dart';
import '../../domain/platform.dart';
import '../../domain/thresholds.dart';
import '../../domain/verdict.dart';
import '../../services/parse_health.dart';
import '../theme/step_button.dart';
import '../theme/tokens.dart';
import '../theme/verdict_style.dart';

// The parts SettingsScreen is assembled from: the accordion card itself, the
// link rows that close the page, and the controls the groups fill up with.
// Leaf widgets only — every one takes its value and a callback, so the screen
// keeps all the state and this file stays readable.

/// Settings' closing rows: links out to [AboutScreen] and [LogsScreen]. Shaped
/// like a collapsed [SettingsGroup] header so they sit in the stack without
/// looking bolted on, but they navigate instead of expanding.
class LinkRow extends StatelessWidget {
  const LinkRow({
    super.key,
    required this.icon,
    required this.title,
    required this.trailing,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String trailing;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FoxColors.bgSurface,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: () => context.push(route),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: FoxColors.borderSoft),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF9AA7B8)),
              const SizedBox(width: Gap.sm + Gap.xs),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: FoxColors.textPrimary,
                  ),
                ),
              ),
              Text(
                trailing,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: FoxColors.textDisabled,
                ),
              ),
              const SizedBox(width: Gap.xs),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: FoxColors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One-tap threshold presets (shared trio with onboarding). Highlights the
/// preset matching the current cut points; custom slider positions match none.
class PresetChips extends StatelessWidget {
  const PresetChips({
    super.key,
    required this.current,
    required this.onPick,
    this.presets = Thresholds.presets,
  });

  final Thresholds current;
  final ValueChanged<Thresholds> onPick;
  final List<(String, Thresholds)> presets;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (label, t) in presets) ...[
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onPick(t);
              },
              child: AnimatedContainer(
                duration: Motion.base,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: current == t
                      ? FoxColors.brandFoxSoft
                      : FoxColors.bgSurface2,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(
                    color: current == t
                        ? FoxColors.brandFox.withValues(alpha: 0.6)
                        : FoxColors.borderSoft,
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: current == t
                          ? FoxColors.textPrimary
                          : FoxColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if ((label, t) != presets.last) const SizedBox(width: Gap.sm),
        ],
      ],
    );
  }
}

/// Pill-shaped single-select row (pill size, retention).
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final v in values) ...[
          Expanded(
            child: Semantics(
              button: true,
              selected: v == selected,
              label: labelOf(v),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(v);
                },
                child: AnimatedContainer(
                  key: ValueKey('choice_${labelOf(v)}'),
                  duration: Motion.base,
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: v == selected
                        ? FoxColors.brandFoxSoft
                        : FoxColors.bgSurface,
                    borderRadius: BorderRadius.circular(Radii.pill),
                    border: Border.all(
                      color: v == selected
                          ? FoxColors.brandFox.withValues(alpha: 0.6)
                          : FoxColors.borderSoft,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      labelOf(v),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: v == selected
                            ? FoxColors.textPrimary
                            : FoxColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (v != values.last) const SizedBox(width: Gap.sm),
        ],
      ],
    );
  }
}

/// One platform's session parse health: OK / quiet / needs-update. Row stays
/// dimmed for apps the driver isn't watching (their health is moot).
class HealthRow extends StatelessWidget {
  const HealthRow({
    super.key,
    required this.app,
    required this.watched,
    required this.health,
  });

  final GigPlatform app;
  final bool watched;
  final PlatformHealth health;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (label, color, bg) = !watched
        ? ('Off', FoxColors.textDisabled, FoxColors.bgBase)
        : health.likelyUnreadable
        // Frames arrive but carry no readable text (canvas/Compose UI) —
        // a parser update can't fix this; it needs the OCR fallback.
        ? ('Unreadable · OCR needed', VerdictColors.bad, VerdictColors.badBg)
        : health.likelyBroken
        ? ('Needs update', VerdictColors.bad, VerdictColors.badBg)
        : health.parsed > 0
        ? (
            'OK · ${health.parsed} read',
            VerdictColors.good,
            VerdictColors.goodBg,
          )
        : ('No offers yet', FoxColors.textSecondary, FoxColors.bgBase);

    return Opacity(
      opacity: watched ? 1 : 0.55,
      child: Row(
        children: [
          Expanded(child: Text(app.label, style: text.titleMedium)),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.sm + Gap.xs,
              vertical: Gap.xs,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A live "$24.50" sample in each MoneyFont, tappable to select it app-wide.
class FontChoiceCard extends StatelessWidget {
  const FontChoiceCard({
    super.key,
    required this.font,
    required this.selected,
    required this.onTap,
  });

  final MoneyFont font;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: Motion.base,
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm + Gap.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? FoxColors.brandFoxSoft : FoxColors.bgSurface2,
          borderRadius: BorderRadius.circular(Radii.field),
          border: Border.all(
            color: selected
                ? FoxColors.brandFox.withValues(alpha: 0.6)
                : FoxColors.borderSoft,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r'$24.50',
                    style: TextStyle(
                      fontFamily: font.family,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      // Page token: this chip sits on bgSurface2, not on a
                      // gradient card.
                      color: FoxColors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    font.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: FoxColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: FoxColors.brandFox,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

/// One accordion group card: tappable header (icon chip + title + live
/// summary + chevron) over an AnimatedSize body. Single-open behavior lives
/// in the parent (`_open` index) so the page never grows unbounded.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    required this.icon,
    required this.summary,
    required this.open,
    required this.onTap,
    required this.child,
    this.accent = FoxColors.brandFox,
    this.summaryColor,
  });

  final String title;
  final IconData icon;
  final String summary;
  final bool open;
  final VoidCallback onTap;
  final Widget child;

  /// Per-group hue (flat tiles read boring, device 2026-07-21): tints the icon
  /// chip always, and the border + glow while open.
  final Color accent;
  final Color? summaryColor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: Motion.base,
      decoration: BoxDecoration(
        // Subtle top sheen over the flat surface so cards read as lit panels.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(FoxColors.bgSurface, FoxColors.cream, 0.045)!,
            FoxColors.bgSurface,
          ],
          stops: const [0, 0.45],
        ),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(
          color: open ? accent.withValues(alpha: 0.45) : FoxColors.borderSoft,
        ),
        boxShadow: [
          ...Shadows.card,
          if (open)
            BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 16),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(Radii.card),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: Motion.base,
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: open ? 0.28 : 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: accent.withValues(alpha: open ? 0.55 : 0.25),
                      ),
                      boxShadow: open
                          ? [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.35),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: Color.lerp(accent, FoxColors.cream, 0.25),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: text.titleMedium),
                        if (summary.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: summaryColor ?? FoxColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: Motion.base,
                    curve: Motion.curve,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: FoxColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // AnimatedSize animates the height change; the body is conditionally
          // built, so collapsing discards the group's child state (deliberate —
          // groups are cheap to rebuild).
          AnimatedSize(
            duration: Motion.morph,
            curve: Motion.curve,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.md,
                      0,
                      Gap.md,
                      Gap.md,
                    ),
                    child: child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// A horizontal bar split into BAD / OK / GOOD zones at the current cut points.
class ThresholdBand extends StatelessWidget {
  const ThresholdBand({
    super.key,
    required this.thresholds,
    required this.min,
    required this.max,
    required this.unit,
  });

  final Thresholds thresholds;
  final double min;
  final double max;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final span = max - min;
    final badFlex = ((thresholds.badBelow - min) / span * 1000).round();
    final goodFlex = ((max - thresholds.goodAtOrAbove) / span * 1000).round();
    final okFlex = (1000 - badFlex - goodFlex).clamp(0, 1000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.pill),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                if (badFlex > 0)
                  Expanded(
                    flex: badFlex,
                    child: ColoredBox(color: VerdictColors.bad),
                  ),
                if (okFlex > 0)
                  Expanded(
                    flex: okFlex,
                    child: ColoredBox(color: VerdictColors.ok),
                  ),
                if (goodFlex > 0)
                  Expanded(
                    flex: goodFlex,
                    child: ColoredBox(color: VerdictColors.good),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '\$${min.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            // Cut points, so the band and the sliders visibly connect.
            Text(
              '\$${thresholds.badBelow.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: VerdictColors.bad.withValues(alpha: 0.85),
              ),
            ),
            Text(
              '\$${thresholds.goodAtOrAbove.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: VerdictColors.good.withValues(alpha: 0.85),
              ),
            ),
            Text(
              '\$${max.toStringAsFixed(2)}$unit',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ],
    );
  }
}

class ThresholdSlider extends StatelessWidget {
  const ThresholdSlider({
    super.key,
    required this.label,
    required this.color,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.unit = '',
    this.currencyPrefix = r'$',
    this.editable = false,
    this.onEdit,
    this.enabled = true,
    this.visualValue,
    this.actualValue,
  });

  final String label;
  final Color color;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  /// Empty = dollars ('$1.50'); otherwise suffixed ('2.0 km').
  final String unit;
  final String currencyPrefix;
  final bool editable;
  final ValueChanged<double>? onEdit;
  final bool enabled;
  final double Function(double value)? visualValue;
  final double Function(double value)? actualValue;

  /// One nudge of the −/+ buttons. Matches the slider's own division size for
  /// money; km reads in tenths, so a 5c-equivalent step would take forever.
  double get _step => unit.isEmpty ? 0.05 : 0.1;

  /// Round to the step so repeated nudges can't drift off it in binary float
  /// ($1.3500000000000002 formats fine but never equals a division).
  void _nudge(int dir) {
    final next = ((value + dir * _step) / _step).round() * _step;
    final clamped = next.clamp(min, max);
    if (clamped != value) onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final displayColor = enabled ? color : FoxColors.textDisabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 10, color: displayColor),
            const SizedBox(width: Gap.sm),
            Expanded(child: Text(label, style: text.titleMedium)),
            if (editable)
              SizedBox(
                width: 104,
                child: TextFormField(
                  key: ValueKey('$label-${value.toStringAsFixed(2)}'),
                  initialValue: value.toStringAsFixed(2),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.end,
                  decoration: InputDecoration(
                    prefixText: currencyPrefix,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Gap.xs,
                      vertical: 6,
                    ),
                  ),
                  onFieldSubmitted: (raw) {
                    final parsed = double.tryParse(
                      raw.trim().replaceAll(',', ''),
                    );
                    if (parsed != null) onEdit?.call(parsed);
                  },
                ),
              )
            else
              Text(
                unit.isEmpty
                    ? '$currencyPrefix${value.toStringAsFixed(2)}'
                    : '${value.toStringAsFixed(1)} $unit',
                style: text.titleMedium?.copyWith(
                  fontSize: 13.5,
                  color: displayColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
        // Slider for the ballpark, −/+ to land on an exact number — dragging to
        // a specific $1.35 is fiddly at this track width (device 2026-07-25).
        Row(
          children: [
            StepButton(
              glyph: '−',
              onTap: enabled && value > min ? () => _nudge(-1) : null,
              semanticLabel: 'Decrease $label',
            ),
            Expanded(
              child: RoadSlider(
                value: value,
                min: min,
                max: max,
                divisions: ((max - min) / 0.05).round(),
                color: displayColor,
                enabled: enabled,
                visualValue: visualValue,
                actualValue: actualValue,
                onChanged: onChanged,
              ),
            ),
            StepButton(
              glyph: '+',
              onTap: enabled && value < max ? () => _nudge(1) : null,
              semanticLabel: 'Increase $label',
            ),
          ],
        ),
      ],
    );
  }
}

class RoadSlider extends StatefulWidget {
  const RoadSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.onChanged,
    this.divisions,
    this.enabled = true,
    this.visualValue,
    this.actualValue,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final Color color;
  final ValueChanged<double>? onChanged;
  final bool enabled;
  final double Function(double value)? visualValue;
  final double Function(double value)? actualValue;

  @override
  State<RoadSlider> createState() => _RoadSliderState();
}

class _RoadSliderState extends State<RoadSlider> {
  bool _dragging = false;
  bool _animating = false;
  int _animationToken = 0;

  double get _visualMin => widget.visualValue?.call(widget.min) ?? widget.min;
  double get _visualMax => widget.visualValue?.call(widget.max) ?? widget.max;
  double get _visualValue =>
      widget.visualValue?.call(widget.value) ?? widget.value;
  double get _fraction =>
      ((_visualValue - _visualMin) / (_visualMax - _visualMin)).clamp(0.0, 1.0);

  @override
  void didUpdateWidget(covariant RoadSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_dragging) {
      final token = ++_animationToken;
      setState(() => _animating = true);
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (mounted && token == _animationToken) {
          setState(() => _animating = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const trackInset = 20.0;
          const carWidth = 38.0;
          final trackWidth = constraints.maxWidth - trackInset * 2;
          final carLeft = trackInset + trackWidth * _fraction - carWidth / 2;
          final glow = _dragging || _animating;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _RoadPainter(
                    color: widget.color,
                    fraction: _fraction,
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 18,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbShape: SliderComponentShape.noThumb,
                  overlayShape: SliderComponentShape.noOverlay,
                  showValueIndicator: ShowValueIndicator.never,
                ),
                child: Slider(
                  value: _visualValue,
                  min: _visualMin,
                  max: _visualMax,
                  divisions: widget.divisions,
                  onChangeStart: widget.enabled
                      ? (_) => setState(() => _dragging = true)
                      : null,
                  onChangeEnd: widget.enabled
                      ? (_) => setState(() => _dragging = false)
                      : null,
                  onChanged: widget.enabled
                      ? (value) => widget.onChanged?.call(
                          widget.actualValue?.call(value) ?? value,
                        )
                      : null,
                ),
              ),
              if (_dragging)
                Positioned(
                  left: carLeft,
                  top: 12,
                  width: carWidth,
                  height: 24,
                  child: _car(carWidth, glow),
                )
              else
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  left: carLeft,
                  top: 12,
                  width: carWidth,
                  height: 24,
                  child: _car(carWidth, glow),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _car(double carWidth, bool glow) => IgnorePointer(
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: carWidth - 1,
          top: 8,
          child: AnimatedOpacity(
            opacity: glow ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            child: CustomPaint(
              size: const Size(16, 8),
              painter: const _HeadlightPainter(),
            ),
          ),
        ),
        Image.asset(
          'assets/car/foxy_road_car.png',
          width: carWidth,
          height: 24,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ],
    ),
  );
}

class _RoadPainter extends CustomPainter {
  const _RoadPainter({required this.color, required this.fraction});

  final Color color;
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 20.0;
    final road = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, 15, size.width - inset * 2, 18),
      const Radius.circular(9),
    );
    canvas.drawRRect(road, Paint()..color = FoxColors.border);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(inset, 15, (size.width - inset * 2) * fraction, 18),
        const Radius.circular(9),
      ),
      Paint()..color = color,
    );
    final lane = Paint()
      ..color = FoxColors.bgSurface.withValues(alpha: 0.8)
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;
    for (double x = inset + 8; x < size.width - inset; x += 13) {
      canvas.drawLine(Offset(x, 24), Offset(x + 6, 24), lane);
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.fraction != fraction;
}

class _HeadlightPainter extends CustomPainter {
  const _HeadlightPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xB8FFF1B0), Color(0x00FFF1B0)],
      ).createShader(Offset.zero & size);
    canvas.drawOval(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _HeadlightPainter oldDelegate) => false;
}

/// Drag a sample offer's $/km and watch the verdict flip in real time.
class PreviewCard extends StatelessWidget {
  const PreviewCard({
    super.key,
    required this.sample,
    required this.unit,
    required this.verdict,
    required this.min,
    required this.max,
    required this.onChanged,
    this.currencyPrefix = r'$',
    this.presets = const [],
    this.editable = false,
    this.onEdit,
  });

  final double sample;
  final String unit; // '/km' or '/hr'
  final Verdict verdict;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String currencyPrefix;
  final List<double> presets;
  final bool editable;
  final ValueChanged<double>? onEdit;

  @override
  Widget build(BuildContext context) {
    final style = VerdictStyle.of(verdict);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: style.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(style.icon, color: style.color, size: 20),
                  const SizedBox(width: Gap.sm),
                  Text(
                    style.label,
                    style: text.titleLarge?.copyWith(color: style.color),
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (editable)
              SizedBox(
                width: 104,
                child: TextFormField(
                  key: ValueKey('preview-${sample.toStringAsFixed(2)}$unit'),
                  initialValue: sample.toStringAsFixed(2),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.end,
                  decoration: InputDecoration(
                    prefixText: currencyPrefix,
                    suffixText: unit,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Gap.xs,
                      vertical: 6,
                    ),
                  ),
                  onFieldSubmitted: (raw) {
                    final parsed = double.tryParse(
                      raw.trim().replaceAll(',', ''),
                    );
                    if (parsed != null) onEdit?.call(parsed);
                  },
                ),
              )
            else
              Text(
                '$currencyPrefix${sample.toStringAsFixed(2)}$unit',
                style: text.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
        const SizedBox(height: Gap.xs),
        Text(
          'Verdict for the payout and rate above',
          style: text.bodyMedium?.copyWith(color: FoxColors.textSecondary),
        ),
        if (presets.isNotEmpty) ...[
          const SizedBox(height: Gap.xs),
          Text(
            'Quick values',
            style: text.bodySmall?.copyWith(color: FoxColors.textSecondary),
          ),
          const SizedBox(height: Gap.xs),
          Wrap(
            spacing: Gap.xs,
            runSpacing: Gap.xs,
            children: [
              for (final preset in presets)
                ChoiceChip(
                  label: Text(
                    '$currencyPrefix${preset.toStringAsFixed(unit == '/hr' ? 0 : 2)}$unit',
                  ),
                  selected: (sample - preset).abs() < 0.001,
                  onSelected: (_) =>
                      onChanged(preset.clamp(min, max).toDouble()),
                ),
            ],
          ),
        ],
        RoadSlider(
          value: sample,
          min: min,
          max: max,
          divisions: ((max - min) / 0.05).round(),
          color: style.color,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Driver name with an explicit save; the check button appears only while the
/// draft differs from the stored name (spec M6 §4.2 — no silent live-apply).
class PillLegend extends StatelessWidget {
  const PillLegend({super.key, this.distanceLabel = 'km'});

  final String distanceLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget row(Color dot, String label, String meaning) => Padding(
      padding: const EdgeInsets.only(top: Gap.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dot,
                shape: BoxShape.circle,
                // Hairline so the pale swatches (the cream $/hr one) still read
                // on a white card — these quote the pill's fixed colors and
                // can't follow the theme.
                border: Border.all(color: FoxColors.border),
              ),
            ),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label — ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: FoxColors.textPrimary,
                    ),
                  ),
                  TextSpan(text: meaning),
                ],
              ),
              style: text.bodyMedium?.copyWith(color: FoxColors.textSecondary),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to read it',
          style: text.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: FoxColors.textPrimary,
          ),
        ),
        row(
          const Color(0xFF39A96C),
          '\$/$distanceLabel block',
          'the verdict. Green GOOD, amber OK, red BAD — take it in a glance.',
        ),
        row(
          const Color(0xFF5ECD90),
          'Green GPS target',
          'pickup is within your Pickup Guard.',
        ),
        row(
          const Color(0xFFFF8A7E),
          'Red GPS target',
          'pickup is over your Pickup Guard.',
        ),
        row(
          FoxColors.creamConst.withValues(alpha: 0.78),
          'Distance',
          'total pickup + trip distance; target status does not change the verdict.',
        ),
        row(
          // The pill's own dim cream, const like the swatches above it.
          FoxColors.creamConst.withValues(alpha: 0.78),
          '\$/hr',
          'payout over the full trip time, so long rides don\'t fool you.',
        ),
      ],
    );
  }
}
