/// Gig platforms FoxyCo watches. Base set = Uber + Hopp (DECISIONS #6).
enum GigPlatform {
  uber('Uber'),
  hopp('Hopp');

  const GigPlatform(this.label);
  final String label;
}
