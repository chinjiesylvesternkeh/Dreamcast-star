import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'api_client.dart';

/// Wraps Google Play Billing (via the `in_app_purchase` plugin) for
/// DreamCast Pro subscriptions.
///
/// SETUP CHECKLIST (do this in Google Play Console before going live):
///   1. Create a subscription product with ID [monthlyProductId] under
///      Monetize > Subscriptions. Suggested price: $4.99–$7.99/month.
///   2. Create a service account (Play Console > Users & permissions) with
///      "View financial data" + "Manage orders and subscriptions" access,
///      download its JSON key, and set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON on
///      the backend so purchases can be verified server-side.
///   3. Add closed/internal testers so you can test real purchase flows
///      before launch.
///
/// This class only handles the CLIENT side (launching the purchase flow).
/// The actual entitlement grant happens server-side in
/// POST /subscriptions/verify-mobile-purchase — never trust the client
/// alone to decide a user is "Pro".
class BillingService {
  static const String monthlyProductId = 'dreamcast_pro_monthly';

  final InAppPurchase _iap = InAppPurchase.instance;
  final ApiClient _api;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  BillingService(this._api);

  Future<bool> isAvailable() => _iap.isAvailable();

  /// Call once (e.g. in main.dart or a top-level provider) to start
  /// listening for purchase updates, including ones that complete after
  /// the app was backgrounded.
  void startListening({
    required void Function() onPurchaseSuccess,
    required void Function(String error) onPurchaseError,
  }) {
    if (!Platform.isAndroid) return; // Play Billing is Android-only.

    _subscription = _iap.purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        if (purchase.status == PurchaseStatus.pending) {
          continue;
        }
        if (purchase.status == PurchaseStatus.error) {
          onPurchaseError(purchase.error?.message ?? 'Unknown billing error');
          continue;
        }
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          try {
            // Server-side verification — this is what actually unlocks Pro.
            await _api.verifyMobilePurchase(
              purchaseToken: purchase.verificationData.serverVerificationData,
              productId: purchase.productID,
            );
            if (purchase.pendingCompletePurchase) {
              await _iap.completePurchase(purchase);
            }
            onPurchaseSuccess();
          } catch (e) {
            onPurchaseError('Purchase verification failed: $e');
          }
        }
      }
    }, onError: (e) => onPurchaseError(e.toString()));
  }

  Future<ProductDetailsResponse> queryProducts() {
    return _iap.queryProductDetails({monthlyProductId});
  }

  Future<void> buySubscription(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() => _iap.restorePurchases();

  void dispose() {
    _subscription?.cancel();
  }
}
