import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../history/history_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import '../theme/tokens.dart';

/// Active tab index — a provider so any screen can deep-link to another tab
/// (e.g. Home's platform badges → Settings watched-apps).
final tabIndexProvider = NotifierProvider<TabIndex, int>(TabIndex.new);

class TabIndex extends Notifier<int> {
  @override
  int build() => 0;

  void go(int i) => state = i;
}

/// The app's three tabs behind one floating pill nav (references/*.html
/// `.bottom-nav`). An [IndexedStack] keeps each tab's scroll + filter state
/// alive when you switch, matching the mockups' instant tab feel.
class RootShell extends ConsumerWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(tabIndexProvider);
    return Scaffold(
      // Nav floats OVER the content, so let pages pad their own bottom.
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: index,
          children: const [HomeScreen(), HistoryScreen(), SettingsScreen()],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        index: index,
        onTap: (i) => ref.read(tabIndexProvider.notifier).go(i),
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
  const _NavItem({
    required this.dest,
    required this.active,
    required this.onTap,
  });

  final _NavDest dest;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? FoxColors.ink : FoxColors.textDisabled;
    return Semantics(
      button: true,
      selected: active,
      label: dest.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              dest.icon,
              size: 21,
              color: active ? FoxColors.brandFox : color,
            ),
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
      ),
    );
  }
}
