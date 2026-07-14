import 'hopp_parser.dart';
import 'lyft_parser.dart';
import 'offer_parser.dart';
import 'uber_parser.dart';

/// Maps a foreground Android package name to the parser that reads it.
///
/// The accessibility service is already scoped to these packages in
/// `res/xml/accessibility_service_config.xml`, so this is the second, in-Dart
/// gate: an event from anything not listed here resolves to `null` and is
/// dropped. Adding a platform (M6) = one line here + one `OfferParser` impl,
/// with zero changes to the engine or overlay.
class ParserRegistry {
  const ParserRegistry();

  /// Uber Driver's package is stable and well-known.
  static const uberPackage = 'com.ubercab.driver';

  /// Hopp Driver. Confirmed on device 2026-07-12 (`pm list packages` on an
  /// S24) — Hopp is Estonian, hence the `ee.` prefix. Keep in sync with the
  /// res/xml accessibility scope.
  static const hoppPackage = 'ee.hopp.driver';

  /// Lyft Driver. Confirmed on device 2026-07-12.
  static const lyftPackage = 'com.lyft.android.driver';

  static const _uber = UberParser();
  static const _hopp = HoppParser();
  static const _lyft = LyftParser();

  /// The parser for a package, or `null` if FoxyCo doesn't handle it.
  OfferParser? forPackage(String? packageName) => switch (packageName) {
    uberPackage => _uber,
    hoppPackage => _hopp,
    lyftPackage => _lyft,
    _ => null,
  };

  /// Packages FoxyCo watches — handy for wiring the accessibility scope and
  /// asserting the res/xml config stays in sync.
  static const watchedPackages = [uberPackage, hoppPackage, lyftPackage];
}
