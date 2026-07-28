import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// What the pill becomes when the driver isn't entitled (MONETIZATION_v1.0 §4).
///
/// Watching still runs and the pill still lands on the offer — it just refuses
/// to say what the offer is worth. A driver staring at a real offer they can't
/// read converts far better than blocking go-live outright, and the fox badge
/// keeps it recognisably FoxyCo rather than an error state.
///
/// Tap opens the paywall in the app. Same plain-widget discipline as
/// [VerdictPill]: no plugin imports, so it renders in the overlay isolate and in
/// an in-app preview alike.
class LockedPill extends StatelessWidget {
  const LockedPill({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.fromLTRB(10, 9, 16, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.pill),
            // Brand orange, not a verdict color: this is a FoxyCo message, not
            // a call on the offer. Deliberately unmistakable from good/ok/bad.
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF203026), Color(0xFF141C17)],
            ),
            border: Border.all(color: FoxColors.brandFox.withValues(alpha: 0.7)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E141C17),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/branding/foxyco_bubble.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unlock FoxyCo',
                    style: TextStyle(
                      fontFamily: FoxFonts.sans,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.1,
                      // creamConst, not the palette token: the pill is dark in
                      // BOTH themes because it floats over other apps.
                      color: FoxColors.creamConst,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Tap to see this offer',
                    style: TextStyle(
                      fontFamily: FoxFonts.sans,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                      height: 1.1,
                      color: FoxColors.creamConst.withValues(alpha: 0.66),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
