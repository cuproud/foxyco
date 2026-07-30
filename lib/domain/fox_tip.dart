/// A short piece of gig-driving advice shown on Home.
enum TipCategory { earnings, safety, maintenance, app, gigLife }

class FoxTip {
  const FoxTip({
    required this.category,
    required this.headline,
    required this.body,
    required this.asset,
  });

  final TipCategory category;
  final String headline;
  final String body;
  final String asset;
}
