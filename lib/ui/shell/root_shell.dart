import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/offer_summary.dart';
import '../history/history_screen.dart';
import '../history/offer_detail_sheet.dart';
import '../home/home_screen.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_screen.dart';
import '../theme/tokens.dart';

/// Active tab index — a provider so any screen can deep-link to another tab
/// (e.g. Home's platform badges → Settings watched-apps).
final tabIndexProvider = NotifierProvider<TabIndex, int>(TabIndex.new);

class TabIndex extends Notifier<int> {
  @override
  int build() => 0;

  /// Which [SettingsScreen] accordion group the pending jump should expand,
  /// consumed once by that screen. A tab jump that lands on a collapsed
  /// accordion, two scrolls above the thing you actually tapped for, isn't a
  /// deep link — it's a shrug.
  int? pendingSection;

  void go(int i, {int? section}) {
    pendingSection = section;
    state = i;
  }
}

/// Offer whose detail sheet should open as soon as the shell can show it — set
/// when the driver taps the overlay bubble while a pill is up. One-shot:
/// [RootShell] clears it the moment it opens the sheet.
final pendingOfferProvider = NotifierProvider<PendingOffer, OfferSummary?>(
  PendingOffer.new,
);

class PendingOffer extends Notifier<OfferSummary?> {
  @override
  OfferSummary? build() => null;

  void set(OfferSummary? offer) => state = offer;
}

/// The app's three tabs behind one floating pill nav (references/*.html
/// `.bottom-nav`). An [IndexedStack] keeps each tab's scroll + filter state
/// alive when you switch, matching the mockups' instant tab feel.
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  /// One controller per tab, handed down through [PrimaryScrollController] so
  /// the pages' plain `ListView`s attach to them without knowing we exist
  /// (a vertical ListView with no controller of its own takes the primary one).
  /// Re-tapping the ACTIVE tab then scrolls it home — the standard bottom-nav
  /// affordance, which the shell had no way to offer before.
  final _scrolls = List.generate(3, (_) => ScrollController());

  @override
  void dispose() {
    for (final c in _scrolls) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTap(int tapped, int current) {
    if (tapped != current) {
      ref.read(tabIndexProvider.notifier).go(tapped);
      return;
    }
    final c = _scrolls[tapped];
    if (c.hasClients && c.offset > 0) {
      c.animateTo(0, duration: Motion.morph, curve: Motion.curve);
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(tabIndexProvider);

    // The bubble asked us to open a specific offer (see OverlayController).
    ref.listen<OfferSummary?>(pendingOfferProvider, (_, offer) {
      if (offer == null) return;
      ref.read(pendingOfferProvider.notifier).set(null);
      showOfferDetail(context, offer);
    });

    // Palette tokens are plain statics ([FoxColors]), not an InheritedWidget,
    // so changing them signals NOTHING to the element tree — a widget that
    // isn't rebuilt for some other reason keeps painting the colors it baked in
    // at its last build. That is invisible while the app has one theme and
    // becomes a stale-color bug the moment it has two: switching to dark left
    // Home's greeting drawn in light-mode ink on the dark page, and only
    // scrolling it out of the ListView's cache and back fixed it (device
    // 2026-07-25).
    //
    // So make the switch an explicit teardown: watch both inputs that can
    // change the resolved palette, and key the pages on them. A change discards
    // the three tab subtrees and rebuilds them against the new statics. Costs
    // the tabs' scroll offsets on a theme switch, which is a fair price and
    // roughly what a user expects from one.
    final skin = ref.watch(settingsProvider.select((s) => s.skin));
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final paletteKey = ValueKey('$skin-$platformDark');

    return PopScope(
      // Tabs are IndexedStack state, not routes, so system back had nothing to
      // pop here — on History or Settings it dropped the driver straight out of
      // the app. Step back to Home first, then let the next back leave.
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(tabIndexProvider.notifier).go(0);
      },
      child: Scaffold(
        // Nav floats OVER the content, so let pages pad their own bottom.
        extendBody: true,
        // Ambient wash over the scaffold's flat fill: light falls from above, so
        // the top of the page is a touch brighter than the bottom. Barely
        // perceptible on its own — it's what stops the cards' shadows from
        // sitting on a dead backdrop (device 2026-07-25: "everything is flat").
        // Painted as a body overlay rather than by making the Scaffold
        // transparent, which would flash black behind the floating nav.
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(FoxColors.bgBase, FoxColors.bgSurface, 0.55)!,
                FoxColors.bgBase,
              ],
              stops: const [0, 0.45],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: KeyedSubtree(
              key: paletteKey,
              child: IndexedStack(
                index: index,
                children: [
                  PrimaryScrollController(
                    controller: _scrolls[0],
                    child: const HomeScreen(),
                  ),
                  PrimaryScrollController(
                    controller: _scrolls[1],
                    child: const HistoryScreen(),
                  ),
                  PrimaryScrollController(
                    controller: _scrolls[2],
                    child: const SettingsScreen(),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: _BottomNav(
          index: index,
          onTap: (i) => _onTap(i, index),
        ),
      ),
    );
  }
}

class _NavDest {
  final IconData active; // filled glyph when selected
  final IconData inactive; // outline glyph otherwise
  final String label;
  const _NavDest(this.active, this.inactive, this.label);
}

// Filled-when-active pairs; History uses the receipt glyph to echo the app's
// "receipt" hero metaphor rather than a generic clock.
const _dests = [
  _NavDest(Icons.home_rounded, Icons.home_outlined, 'Home'),
  _NavDest(Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'History'),
  _NavDest(Icons.settings_rounded, Icons.settings_outlined, 'Settings'),
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
            // Stronger ring + hero shadow so the bar floats clearly above the
            // page underneath (was blending into scrolled content, device
            // 2026-07-23). borderSoft was too faint against cream cards.
            border: Border.all(color: FoxColors.border, width: 1.5),
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
                        // Brand-orange chip (user 2026-07-25), const in both
                        // themes — so the ink on it is const too ([_onBrand] in
                        // _NavItem). The two have to stay a matched pair.
                        color: FoxColors.brandFox,
                        borderRadius: BorderRadius.circular(Radii.pill),
                        boxShadow: Shadows.glowSoft,
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

  /// Ink on the orange indicator: FoxyCo's deep green-black, const in both
  /// themes because the fill is (user asked for green on orange, 2026-07-25).
  ///
  /// It has to be this dark. A *saturated* green — the verdict tier's #1F7A48 —
  /// sits at 1.7:1 on #FF5A36, which is unreadable at 10 dp; this green-black
  /// clears 5.5:1 (AA). Cream, the old inverted-chip ink, only managed 3.1:1.
  static const _onBrand = Color(0xFF0E1F17);

  @override
  Widget build(BuildContext context) {
    // Active = the ink on the orange indicator above; the two are a pair.
    final color = active ? _onBrand : FoxColors.textDisabled;
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
            AnimatedScale(
              scale: active ? 1.0 : 0.9,
              duration: Motion.base,
              curve: Curves.easeOutBack,
              // The active glyph is the same ink as its label — orange-on-
              // orange would erase it now that the chip carries the brand.
              child: Icon(
                active ? dest.active : dest.inactive,
                size: 23,
                color: color,
              ),
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
