/// The artwork used by the resting overlay bubble.
enum BubbleStyle {
  coolFox('Cool Fox', 'coolFox', 'assets/branding/foxyco_bubble.png'),
  foxycoF('FoxyCo F', 'foxycoF', 'assets/branding/foxyco_f_bubble.png'),
  foxPaw('Fox Paw', 'foxPaw', 'assets/branding/foxyco_paw_bubble.png');

  const BubbleStyle(this.label, this.id, this.assetPath);

  final String label;
  final String id;
  final String assetPath;

  static BubbleStyle fromId(String? id) => values.firstWhere(
    (style) => style.id == id,
    orElse: () => BubbleStyle.coolFox,
  );
}
