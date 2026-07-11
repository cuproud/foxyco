/// The verdict FoxyCo renders for an offer. Pure Dart — no Flutter imports.
///
/// Each verdict is presented as color + shape + word (see ui/theme + widgets)
/// so it's readable under glare and safe for colorblind drivers.
enum Verdict {
  good,
  ok,
  bad,

  /// Parse confidence too low to call — fail safe, never a confident wrong call.
  unknown,
}
