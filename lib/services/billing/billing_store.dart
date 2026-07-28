import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'purchase_verifier.dart';

/// Where the one-time unlock stands right now.
enum UnlockStatus {
  /// Still asking Play. Never lock the UI on this — it is the boot state.
  unknown,

  /// Play knows of no purchase for this account.
  notPurchased,

  /// Payment is in flight (cash, carrier billing). Grants nothing yet.
  pending,

  /// Signature-verified purchase. The unlock.
  purchased,

  /// Play Billing unreachable (no Play Store, no network at first launch).
  unavailable,
}

/// Lifetime unlock state, owned by Google Play (MONETIZATION §3.2).
///
/// Play is the only source of truth for the purchase: it survives reinstall,
/// device swap and account transfer, so nothing is recorded on our side. That
/// also makes promo-code redemptions indistinguishable from purchases here,
/// which is exactly what §6.2 wants.
class BillingStore extends Notifier<UnlockStatus> {
  /// Play Console product ID. Must be configured **non-consumable** — a
  /// consumable would let the unlock be spent and re-bought.
  static const productId = 'foxyco.lifetime';

  /// A getter, not a field: `InAppPurchase.instance` registers the Android
  /// platform on first touch, which needs a platform binding. As a field it
  /// would fire while the Notifier is being CONSTRUCTED, outside the guard in
  /// [build] — so any test that reaches entitlement would blow up before we
  /// could degrade to `unavailable`. It's a singleton, so the getter is free.
  InAppPurchase get _iap => InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;

  /// Shop price straight from Play, already localized to the user's currency.
  /// Null until [_loadProduct] returns — show the hardcoded price until then.
  String? get price => _product?.price;

  @override
  UnlockStatus build() {
    // Play Billing exists on Android and nowhere else. Checked BEFORE touching
    // the plugin because `InAppPurchase.instance` immediately opens a
    // BillingClient connection, and off-device (widget tests on the Linux host)
    // that fails inside a `Future.sync` — an UNHANDLED async error that no
    // try/catch here can hold. So don't start it at all.
    if (!Platform.isAndroid) return UnlockStatus.unavailable;
    // Still guarded: an Android device with no Play Store (sideloaded, some
    // Huawei builds) throws synchronously instead. Either way `unavailable` is
    // the honest answer — Play can tell us nothing, and the trial governs
    // entitlement meanwhile.
    try {
      _sub = _iap.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) {
          if (kDebugMode) debugPrint('FoxyCo billing stream error: $e');
        },
      );
      ref.onDispose(() => _sub?.cancel());
      _start();
      return UnlockStatus.unknown;
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo billing unavailable: $e');
      return UnlockStatus.unavailable;
    }
  }

  Future<void> _start() async {
    if (!await _iap.isAvailable()) {
      state = UnlockStatus.unavailable;
      return;
    }
    await _loadProduct();
    // Re-emits every owned purchase through _onPurchases. Doubles as the
    // recovery path for a purchase that was paid for but never acknowledged
    // (app killed mid-flow) — see §3.8.
    await _iap.restorePurchases();
  }

  Future<void> _loadProduct() async {
    try {
      final res = await _iap.queryProductDetails({productId});
      if (res.productDetails.isNotEmpty) {
        _product = res.productDetails.first;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo product query skipped: $e');
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != productId) continue;
      switch (p.status) {
        case PurchaseStatus.pending:
          // Slow payment method. Not entitlement — §3.8.
          if (state != UnlockStatus.purchased) state = UnlockStatus.pending;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (_isGenuine(p)) {
            state = UnlockStatus.purchased;
          } else {
            if (kDebugMode) debugPrint('FoxyCo purchase failed signature');
            if (state != UnlockStatus.purchased) {
              state = UnlockStatus.notPurchased;
            }
          }
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          if (state != UnlockStatus.purchased) {
            state = UnlockStatus.notPurchased;
          }
      }
      // Acknowledge unconditionally once Play has taken the money. Skipping
      // this for 72h makes Google auto-refund a purchase the user genuinely
      // made (§3.8) — a forged receipt is already denied entitlement above,
      // and acknowledging it changes nothing since Play never billed it.
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (e) {
          if (kDebugMode) debugPrint('FoxyCo acknowledge failed: $e');
        }
      }
    }
  }

  /// Signed by Google, not by a patcher. Android-only check; a non-Play
  /// platform has no signature to inspect and is rejected.
  bool _isGenuine(PurchaseDetails p) {
    if (p is! GooglePlayPurchaseDetails) return false;
    return PurchaseVerifier.verify(
      p.verificationData.localVerificationData,
      p.billingClientPurchase.signature,
    );
  }

  /// Open Play's buy sheet. No-op if Play never handed us the product.
  Future<void> buy() async {
    final product = _product;
    if (product == null) return;
    try {
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo buy failed: $e');
    }
  }

  /// "Restore purchase" — also how a redeemed promo code is picked up.
  Future<void> restore() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo restore failed: $e');
    }
  }
}

final billingProvider = NotifierProvider<BillingStore, UnlockStatus>(
  BillingStore.new,
);
