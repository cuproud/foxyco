import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain/app_skin.dart';
import 'router.dart';
import 'services/accessibility/offer_watcher.dart';
import 'services/billing/entitlement.dart';
import 'services/play_update_service.dart';
import 'ui/home/dashboard_controller.dart';
import 'ui/onboarding/onboarding_gate.dart';
import 'ui/settings/about_content.dart';
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
  // Firebase backs the unresettable trial and nothing else (MONETIZATION §3.3):
  // one anonymous auth session and one trial timestamp. Fails SOFT — a missing
  // google-services.json or a dead network must never stop the app booting, so
  // entitlement falls back to the cached verdict and, once the offline grace
  // window lapses, to locked.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    if (kDebugMode) debugPrint('FoxyCo Firebase init skipped: $e');
  }
  // Read the first-run flag BEFORE runApp so the app boots straight into the
  // right screen — no flash of Home before onboarding takes over.
  final onboarded = await OnboardingGate.isDone();
  var updated = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString('foxyco.last_seen_version');
    updated = onboarded && previous != aboutVersion;
    await prefs.setString('foxyco.last_seen_version', aboutVersion);
  } catch (_) {
    // A confirmation message must never delay or block startup.
  }
  runApp(
    ProviderScope(
      overrides: [appUpdatedProvider.overrideWithValue(updated)],
      child: FoxyCoApp(showOnboarding: !onboarded),
    ),
  );
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
    //  • access            — starts Play + the trial check, so the pill knows
    //                        whether it may draw numbers on the first offer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(overlayControllerProvider);
      ref.read(offerWatcherProvider);
      ref.read(dashboardProvider.notifier).refreshPermissions();
      ref.read(accessProvider);
      ref.read(playUpdateProvider.notifier).beginForegroundSession();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the Accessibility / overlay settings pages: re-check the
    // grants so the dashboard flips out of "blocked" without a manual reload.
    if (state == AppLifecycleState.resumed) {
      ref.read(dashboardProvider.notifier).refreshPermissions();
      // Also the moment to reconcile entitlement: the driver may have just come
      // back from Play's buy sheet, or from a week offline. Re-asks Play every
      // time (local, cheap) and Firestore only when due (§3.7 layer 2).
      ref.read(accessProvider.notifier).refresh(sampled: true);
      ref.read(playUpdateProvider.notifier).beginForegroundSession();
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
    // Same deal for the palette: AppTheme.of() applies it to FoxColors before
    // building, so the static token call sites across the app follow the switch
    // on the rebuild this watch triggers. Building BOTH themes here would leave
    // whichever ran last applied, so only the active one is built.
    final skin = ref.watch(settingsProvider.select((s) => s.skin));
    final appTextSize = ref.watch(
      settingsProvider.select((s) => s.appTextSize),
    );
    final mode = switch (skin) {
      AppSkin.dark => ThemeMode.dark,
      AppSkin.light => ThemeMode.light,
      AppSkin.system => ThemeMode.system,
    };
    final systemDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final active = switch (mode) {
      ThemeMode.dark => FoxPalette.dark,
      ThemeMode.light => FoxPalette.light,
      ThemeMode.system => systemDark ? FoxPalette.dark : FoxPalette.light,
    };
    final theme = AppTheme.of(active);
    final systemUi = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: active.brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
      statusBarBrightness: active.brightness == Brightness.dark
          ? Brightness.dark
          : Brightness.light,
      systemNavigationBarColor: active.bgBase,
      systemNavigationBarIconBrightness: active.brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarDividerColor: active.bgBase,
      systemNavigationBarContrastEnforced: false,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUi,
      child: MaterialApp.router(
        title: 'FoxyCo',
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: theme,
        themeMode: mode,
        routerConfig: _router,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          final systemScale = media.textScaler.scale(1);
          final scale = (systemScale * appTextSize.factor).clamp(0.8, 2.0);
          return MediaQuery(
            data: media.copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          );
        },
      ),
    );
  }
}
