import 'package:flutter/material.dart';

/// The resting-state overlay bubble (docs/OVERLAY §bubble).
///
/// When no offer is on screen, FoxyCo collapses to this small fox dot pinned to
/// the screen edge. Tap = open FoxyCo, long-press = pause/resume watching. The
/// plugin handles the actual drag/snap at the window level; this widget is just
/// the visual + gesture targets, so it stays device-independent and previewable.
class FoxBubble extends StatelessWidget {
  const FoxBubble({
    super.key,
    required this.paused,
    this.onTap,
    this.onLongPress,
    this.size = 56,
  });

  /// Paused dims the fox and swaps the ring to a muted state — at a glance you
  /// know whether FoxyCo is actually watching.
  final bool paused;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Opacity(
          // Paused just dims the fox — no ring, no box, so state still reads.
          opacity: paused ? 0.55 : 1,
          child: Container(
            width: size,
            height: size,
            // Only a soft drop shadow so the fox lifts off other apps. The
            // shape comes entirely from clipping the art to a circle — no
            // background fill, no border ring (that was the box-in-a-box).
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x73000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/branding/foxyco_launcher.png',
                width: size,
                height: size,
                fit: BoxFit.cover, // fill edge-to-edge: just the fox, no gap
              ),
            ),
          ),
        ),
      ),
    );
  }
}
