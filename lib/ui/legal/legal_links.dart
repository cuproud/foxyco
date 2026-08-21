import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/tokens.dart';

/// The published legal pages, and the two widgets that link to them.
///
/// Play requires a live privacy-policy URL and, because FoxyCo collects a
/// Google account, a public account-deletion URL as well (AUDIT go/no-go).
/// Terms are not required by Play — Play's own licence agreement covers the
/// transaction — but FoxyCo scores offers a driver acts on for money, and names
/// companies it has nothing to do with, so it carries its own.
///
/// ⚠️ These must point at pages that are actually live before the first upload.
/// The drafts are in `docs/legal/`; publish them, then confirm these three
/// strings resolve.
class FoxLegal {
  const FoxLegal._();

  // GitHub Pages, served from this repo's `docs/` folder, so the path mirrors
  // the source layout: docs/legal/privacy.md → /foxyco/legal/privacy.html.
  static const _base = 'https://cuproud.github.io/foxyco/legal';
  static const terms = '$_base/terms.html';
  static const privacy = '$_base/privacy.html';
  static const deleteAccount = '$_base/delete-account.html';

  /// Platform names are other companies' trademarks; never imply endorsement.
  static const disclaimer =
      'FoxyCo is an independent app. It is not affiliated with, authorised by '
      'or endorsed by Uber, Lyft, Hopp, DoorDash, Instacart or Skip, and those '
      'names are their owners\' trademarks.';

  static Future<void> open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

/// Click-wrap consent, shown directly above the onboarding CTA.
///
/// Inline consent rather than a blocking modal: assent is given by continuing,
/// which is the accepted standard for a one-time-purchase utility and does not
/// cost an install. The links must be tappable for that to hold, so they are
/// real recognizers and not decoration.
/// One line, deliberately. This sits in the fixed footer of a wizard whose
/// pages are already tight on a small screen — two lines here pushed the
/// preset picker off the bottom.
class LegalConsent extends StatefulWidget {
  const LegalConsent({super.key});

  @override
  State<LegalConsent> createState() => _LegalConsentState();
}

class _LegalConsentState extends State<LegalConsent> {
  // Recognizers hold a gesture-arena subscription; they must be disposed.
  final _terms = TapGestureRecognizer();
  final _privacy = TapGestureRecognizer();

  @override
  void initState() {
    super.initState();
    _terms.onTap = () => FoxLegal.open(FoxLegal.terms);
    _privacy.onTap = () => FoxLegal.open(FoxLegal.privacy);
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: 11.5, color: FoxColors.textDisabled);
    final link = base.copyWith(
      fontWeight: FontWeight.w700,
      color: FoxColors.brandFox,
      decoration: TextDecoration.underline,
      decorationColor: FoxColors.brandFox,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'By continuing you agree to the '),
          TextSpan(text: 'Terms', style: link, recognizer: _terms),
          const TextSpan(text: ' and '),
          TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacy),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// The same links, plus the disclaimer, for the bottom of About.
class LegalFooter extends StatelessWidget {
  const LegalFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: const [
            _LegalLink('Terms', FoxLegal.terms),
            _Dot(),
            _LegalLink('Privacy Policy', FoxLegal.privacy),
            _Dot(),
            _LegalLink('Delete my account', FoxLegal.deleteAccount),
          ],
        ),
        const SizedBox(height: Gap.sm),
        Text(
          FoxLegal.disclaimer,
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: FoxColors.textDisabled,
          ),
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink(this.label, this.url);

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => FoxLegal.open(url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: FoxColors.brandFox,
            decoration: TextDecoration.underline,
            decorationColor: FoxColors.brandFox,
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Text(
    '  ·  ',
    style: TextStyle(fontSize: 12, color: FoxColors.textDisabled),
  );
}
