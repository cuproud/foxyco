import 'package:go_router/go_router.dart';

import 'ui/shell/root_shell.dart';

/// App routes. The root is the three-tab [RootShell] (Home / History /
/// Settings); the overlay bubble tap just foregrounds the app at this root.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const RootShell()),
  ],
);
