import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/services/billing/purchase_verifier.dart';

void main() {
  // With no PLAY_PUBLIC_KEY compiled in (the default), verification must deny
  // everything. The failure this guards is the inverse: an empty/missing key
  // silently accepting forged receipts and unlocking the app for free.
  test('rejects everything when no public key is configured', () {
    expect(PurchaseVerifier.publicKeyBase64, isEmpty);
    expect(PurchaseVerifier.verify('{"productId":"foxyco.lifetime"}', 'sig'),
        isFalse);
  });

  test('rejects empty receipt or signature', () {
    expect(PurchaseVerifier.verify('', 'sig'), isFalse);
    expect(PurchaseVerifier.verify('{}', ''), isFalse);
  });

  test('returns false instead of throwing on malformed base64', () {
    expect(PurchaseVerifier.verify('{}', 'not!valid!base64'), isFalse);
  });
}
