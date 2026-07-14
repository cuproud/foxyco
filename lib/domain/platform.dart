/// Gig platforms FoxyCo watches. Base set = Uber + Hopp (DECISIONS #6); Lyft
/// added M3 (2026-07-12) — same timeline-leg card idiom as Hopp, gross pay.
enum GigPlatform {
  uber('Uber'),
  hopp('Hopp'),
  lyft('Lyft');

  const GigPlatform(this.label);
  final String label;
}
