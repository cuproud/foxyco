# FoxyCo R8 keep rules.
# Flutter's default rules come from the Flutter Gradle plugin; these cover the
# two VENDORED plugins, whose classes the engine reaches reflectively via
# GeneratedPluginRegistrant + AndroidManifest service entries.

-keep class flutter.overlay.window.flutter_overlay_window.** { *; }
-keep class slayer.accessibility.service.flutter_accessibility_service.** { *; }

# flutter_overlay_window resolves the overlay dart entrypoint through the
# FlutterEngineGroup/DartExecutor — keep engine loader surface intact.
-keep class io.flutter.embedding.engine.FlutterEngineGroup { *; }
