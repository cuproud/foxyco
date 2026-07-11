import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'ui/overlay/overlay_entry.dart';
import 'ui/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: FoxyCoApp()));
}

/// Entry point for the overlay ISOLATE. `flutter_overlay_window` looks this up
/// by name (`overlayMain`) in the app's `main.dart`, so it must live here — it
/// just boots the overlay UI defined in `ui/overlay/overlay_entry.dart`.
@pragma('vm:entry-point')
void overlayMain() {
  // The overlay runs in a fresh isolate — its binding isn't initialized for us,
  // so without this the isolate boots and silently renders nothing.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FoxOverlayApp());
}

class FoxyCoApp extends StatelessWidget {
  const FoxyCoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FoxyCo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
