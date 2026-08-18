import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/ui/legal/legal_links.dart';

/// The legal surface is a compliance requirement, not decoration: Play needs a
/// reachable privacy policy, and the affiliation disclaimer is what keeps three
/// other companies' trademarks a description rather than an implied endorsement.
/// Both are one careless refactor away from vanishing, hence this file.
void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('the onboarding click-wrap names both documents', (tester) async {
    await tester.pumpWidget(host(const LegalConsent()));

    // Rendered as one rich paragraph, so assert on the laid-out text.
    final text = tester.widget<Text>(find.byType(Text));
    final rendered = text.textSpan!.toPlainText();
    expect(rendered, contains('By continuing'));
    expect(rendered, contains('Terms'));
    expect(rendered, contains('Privacy Policy'));
  });

  testWidgets('About carries the disclaimer and all three links', (
    tester,
  ) async {
    await tester.pumpWidget(host(const LegalFooter()));

    expect(find.text('Terms'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Delete my account'), findsOneWidget);
    expect(find.text(FoxLegal.disclaimer), findsOneWidget);
  });

  test('the disclaimer disclaims what it needs to', () {
    final d = FoxLegal.disclaimer.toLowerCase();
    expect(d, contains('not affiliated'));
    expect(d, contains('endorsed'));
    for (final platform in ['uber', 'lyft', 'hopp']) {
      expect(d, contains(platform), reason: '$platform must be named');
    }
  });

  test('every legal URL is a real https address', () {
    for (final url in [
      FoxLegal.terms,
      FoxLegal.privacy,
      FoxLegal.deleteAccount,
    ]) {
      final uri = Uri.tryParse(url);
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https', reason: '$url must be https');
      expect(uri.host, isNotEmpty);
    }
  });
}
