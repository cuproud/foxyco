import 'package:go_router/go_router.dart';

import 'domain/garage.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/settings/vehicle_editor_screen.dart';
import 'ui/shell/root_shell.dart';
import 'ui/splash/splash_screen.dart';

/// App routes. The root is the three-tab [RootShell] (Home / History /
/// Settings); the overlay bubble tap just foregrounds the app at this root.
/// `/onboarding` is the first-run permission walkthrough — `main()` reads
/// [OnboardingGate.isDone] before `runApp` and picks the initial location, so
/// there's never a flash of the wrong screen.
GoRouter createRouter({
  required bool showOnboarding,
  bool showSplash = false,
}) => GoRouter(
  initialLocation: showOnboarding
      ? '/onboarding'
      : showSplash
      ? '/splash'
      : '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const RootShell()),
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/vehicle-editor',
      builder: (context, state) =>
          VehicleEditorScreen(initial: state.extra as Vehicle?),
    ),
  ],
);
