import 'package:flutter/material.dart';

import '../../domain/platform.dart';
import 'tokens.dart';

/// A lettered roundel on the canonical platform color. Used wherever a
/// platform identity is shown; the enum owns the label, initial, and color.
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

  @override
  Widget build(BuildContext context) {
    final color = switch (platform) {
      GigPlatform.uber || GigPlatform.uberEats => FoxColors.uber,
      _ => Color(platform.colorValue),
    };
    // Contrast against the ROUNDEL, not the page: bgBase resolved to cream in
    // light mode, which put a white letter on Uber's near-white badge (device
    // 2026-07-25). Near-black rather than pure black to match Uber's brand.
    final letterColor = color.computeLuminance() > 0.5
        ? const Color(0xFF111111)
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
          platform.initial,
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

class PlatformBadges extends StatelessWidget {
  const PlatformBadges({super.key, required this.platforms});
  final List<GigPlatform> platforms;

  @override
  Widget build(BuildContext context) {
    const maxVisible = 4;
    final visible = platforms.take(maxVisible);
    final remaining = platforms.length - maxVisible;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final platform in visible) ...[
          PlatformBadge(platform: platform),
          const SizedBox(width: 6),
        ],
        if (remaining > 0)
          CircleAvatar(
            radius: 11,
            backgroundColor: FoxColors.textDisabled,
            child: Text(
              '+$remaining',
              style: const TextStyle(fontSize: 9, color: Colors.white),
            ),
          ),
        if (platforms.isEmpty)
          Text(
            'No watched apps',
            style: TextStyle(fontSize: 11, color: FoxColors.textSecondary),
          ),
      ],
    );
  }
}
