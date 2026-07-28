import 'dart:convert';

import 'package:basic_utils/basic_utils.dart';

/// Verifies that a purchase receipt was actually signed by Google Play.
///
/// Play returns the receipt as `originalJson` plus an RSA-SHA1 `signature` over
/// those exact bytes. Only Google holds the private key, so a valid signature
/// proves the receipt is genuine. Fake-purchase tooling ("Lucky Patcher")
/// injects receipts it cannot sign — they fail here. Verification is pure
/// local crypto, so it works offline forever (MONETIZATION §3.7 layer 1).
class PurchaseVerifier {
  /// Base64 RSA public key from Play Console → Monetization setup → Licensing.
  ///
  /// Not a secret (it ships in every APK by design), but until the real one is
  /// pasted in, [verify] refuses everything rather than waving purchases
  /// through unchecked.
  static const publicKeyBase64 = String.fromEnvironment(
    'PLAY_PUBLIC_KEY',
    defaultValue: '',
  );

  const PurchaseVerifier._();

  /// True only if [signatureBase64] is Google's RSA-SHA1 signature over
  /// [originalJson]. Any malformed input, bad key, or crypto error is a
  /// verification failure — never an exception, never a pass.
  static bool verify(String originalJson, String signatureBase64) {
    if (publicKeyBase64.isEmpty) return false;
    if (originalJson.isEmpty || signatureBase64.isEmpty) return false;
    try {
      final key = CryptoUtils.rsaPublicKeyFromDERBytes(
        base64Decode(publicKeyBase64),
      );
      return CryptoUtils.rsaVerify(
        key,
        utf8.encode(originalJson),
        base64Decode(signatureBase64),
        algorithm: 'SHA-1/RSA',
      );
    } catch (_) {
      return false;
    }
  }
}
