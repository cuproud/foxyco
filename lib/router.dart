import 'package:go_router/go_router.dart';

import 'ui/home/home_screen.dart';
import 'ui/settings/settings_screen.dart';

/// App routes (docs/UI_DESIGN §4). Home is the root; more screens land in later
/// milestones (/onboarding).
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
