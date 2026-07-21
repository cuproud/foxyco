import 'package:flutter/material.dart';

import '../../domain/platform.dart';
import 'tokens.dart';

/// A lettered roundel (U / L / H) on the platform's brand color (spec M6
/// §3.3/§5.2). Used in the home hero's watched-apps row and reused by History
/// (Task 9). [active] dims the badge for platforms that aren't currently live.
class PlatformBadge extends StatelessWidget {
  const PlatformBadge({
    super.key,
    required this.platform,
    this.size = 22,
    this.active = true,
  });

  final GigPlatform platform;
  final double size;
  final bool active;

  static const _colors = <GigPlatform, Color>{
    GigPlatform.uber: FoxColors.uber,
    GigPlatform.lyft: FoxColors.lyft,
    GigPlatform.hopp: FoxColors.hopp,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[platform] ?? FoxColors.textDisabled;
    // Uber's badge is near-white → dark letter; others take light letter.
    final letterColor = color.computeLuminance() > 0.5
        ? FoxColors.bgBase
        : Colors.white;
    return Opacity(
      opacity: active ? 1.0 : 0.45,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: active ? 1.0 : 0.6),
          shape: BoxShape.circle,
        ),
        child: Text(
          platform.label[0].toUpperCase(),
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w800,
            color: letterColor,
            height: 1,
          ),
        ),
      ),
    );
  }
}
