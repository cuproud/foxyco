import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'services/accessibility/offer_watcher.dart';
import 'ui/home/dashboard_controller.dart';
import 'ui/onboarding/onboarding_gate.dart';
import 'ui/overlay/overlay_controller.dart';
import 'ui/overlay/overlay_entry.dart';
import 'ui/settings/settings_controller.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/tokens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0C1210), // FoxColors.bgBase
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  // Read the first-run flag BEFORE runApp so the app boots straight into the
  // right screen — no flash of Home before onboarding takes over.
  final onboarded = await OnboardingGate.isDone();
  runApp(ProviderScope(child: FoxyCoApp(showOnboarding: !onboarded)));
}

/// Entry point for the overlay ISOLATE. `flutter_overlay_window` looks this up
/// by name (`overlayMain`) in the app's `main.dart`, so it must live here — it
/// just boots the overlay UI defined in `ui/overlay/overlay_entry.dart`.
@pragma('vm:entry-point')
void overlayMain() {
  // The overlay runs in a fresh isolate — its binding isn't initialized for us,
  // so without this the isolate boots and silently renders nothing.
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    debugPrint('FoxyCo[overlay] overlayMain — isolate booted, runApp');
  }
  runApp(const FoxOverlayApp());
}

class FoxyCoApp extends ConsumerStatefulWidget {
  const FoxyCoApp({super.key, this.showOnboarding = false});

  /// First run → boot into `/onboarding` instead of Home.
  final bool showOnboarding;

  @override
  ConsumerState<FoxyCoApp> createState() => _FoxyCoAppState();
}

class _FoxyCoAppState extends ConsumerState<FoxyCoApp>
    with WidgetsBindingObserver {
  late final _router = createRouter(
    showOnboarding: widget.showOnboarding,
    showSplash: !widget.showOnboarding,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Boot the main-isolate side of the app AFTER the first frame, so provider
    // reads don't run during build:
    //  • overlayController — subscribes to the bubble's gesture stream
    //  • offerWatcher      — the M3 pipeline (accessibility → parser → overlay)
    //  • refreshPermissions — reflect the real OS grant state on the dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(overlayControllerProvider);
      ref.read(offerWatcherProvider);
      ref.read(dashboardProvider.notifier).refreshPermissions();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the Accessibility / overlay settings pages: re-check the
    // grants so the dashboard flips out of "blocked" without a manual reload.
    if (state == AppLifecycleState.resumed) {
      ref.read(dashboardProvider.notifier).refreshPermissions();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Money-font pick lives in settings; poking the static before the theme
    // builds means every `fontFamily: FoxFonts.display` call site follows on
    // the rebuild this watch triggers.
    final moneyFont = ref.watch(settingsProvider.select((s) => s.moneyFont));
    FoxFonts.display = moneyFont.family;
    return MaterialApp.router(
      title: 'FoxyCo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}
