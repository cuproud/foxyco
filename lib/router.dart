import 'package:go_router/go_router.dart';

import 'ui/onboarding/onboarding_screen.dart';
import 'ui/shell/root_shell.dart';

/// App routes. The root is the three-tab [RootShell] (Home / History /
/// Settings); the overlay bubble tap just foregrounds the app at this root.
/// `/onboarding` is the first-run permission walkthrough — `main()` reads
/// [OnboardingGate.isDone] before `runApp` and picks the initial location, so
/// there's never a flash of the wrong screen.
GoRouter createRouter({required bool showOnboarding}) => GoRouter(
  initialLocation: showOnboarding ? '/onboarding' : '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const RootShell()),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
  ],
);
