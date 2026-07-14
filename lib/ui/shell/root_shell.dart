import 'package:flutter/material.dart';

import '../history/history_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import '../theme/tokens.dart';

/// The app's three tabs behind one floating pill nav (references/*.html
/// `.bottom-nav`). An [IndexedStack] keeps each tab's scroll + filter state
/// alive when you switch, matching the mockups' instant tab feel.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Nav floats OVER the content, so let pages pad their own bottom.
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: const [HomeScreen(), HistoryScreen(), SettingsScreen()],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _NavDest {
  final IconData icon;
  final String label;
  const _NavDest(this.icon, this.label);
}

const _dests = [
  _NavDest(Icons.home_outlined, 'Home'),
  _NavDest(Icons.history, 'History'),
  _NavDest(Icons.settings_outlined, 'Settings'),
];

/// Floating cream pill with a sliding cream indicator behind the active tab.
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: FoxColors.bgSurface,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: FoxColors.borderSoft),
            boxShadow: Shadows.hero,
          ),
          padding: const EdgeInsets.all(6),
          child: LayoutBuilder(
            builder: (context, c) {
              final slot = c.maxWidth / _dests.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: Motion.base,
                    curve: Curves.easeOutBack,
                    left: slot * index,
                    top: 0,
                    bottom: 0,
                    width: slot,
                    child: Container(
                      decoration: BoxDecoration(
                        color: FoxColors.cream,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < _dests.length; i++)
                        Expanded(
                          child: _NavItem(
                            dest: _dests[i],
                            active: i == index,
                            onTap: () => onTap(i),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.dest, required this.active, required this.onTap});

  final _NavDest dest;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? FoxColors.ink : FoxColors.textDisabled;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(dest.icon, size: 21, color: active ? FoxColors.brandFox : color),
          const SizedBox(height: 3),
          Text(
            dest.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
