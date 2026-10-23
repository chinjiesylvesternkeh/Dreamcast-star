import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart' show ReplacementMode;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../models/plan.dart';
import 'api_client.dart';

/// Billing events the UI turns into a localized message.
enum BillingNotice { pending, failed, unverified, error }

/// Google Play Billing for the Lucid / Mystic / Oracle subscriptions.
///
/// PLAY CONSOLE SETUP (Monetize > Products > Subscriptions), one per plan:
///   dreamcast_lucid_monthly   base plan "monthly", auto-renewing, US$1.79
///   dreamcast_mystic_monthly  base plan "monthly", auto-renewing, US$3.49
///   dreamcast_oracle_monthly  base plan "monthly", auto-renewing, US$8.79
/// Let Play convert the USD base price into local currencies. Product ids
/// must match backend/app/plans.py.
///
/// Rules this class follows (Play Billing policy):
///   * Access is granted only after the backend verifies the purchase token
///     with Google — never on the client's word alone.
///   * Every verified purchase is acknowledged (completePurchase); Play
///     refunds purchases left unacknowledged for 3 days.
///   * Pending payments (e.g. cash at a store) grant nothing until Play
///     reports them as purchased.
///   * Switching plans replaces the existing subscription instead of
///     stacking a second one.
class BillingService {
  final ApiClient _api;
  final InAppPurchase? _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Subscriptions the Play account currently owns, keyed by product id.
  final Map<String, GooglePlayPurchaseDetails> _owned = {};

  BillingService(this._api) : _iap = isSupported ? InAppPurchase.instance : null;

  /// Play Billing exists only in the Android app.
  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> isAvailable() async => _iap != null && await _iap.isAvailable();

  /// Starts listening for purchase updates for the whole app session and
  /// finishes any purchase that was paid but never verified/acknowledged.
  void start({
    required VoidCallback onEntitlementChanged,
    required void Function(BillingNotice notice) onNotice,
  }) {
    final iap = _iap;
    if (iap == null || _subscription != null) return;

    _subscription = iap.purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        switch (purchase.status) {
          case PurchaseStatus.pending:
            onNotice(BillingNotice.pending);
          case PurchaseStatus.canceled:
            break;
          case PurchaseStatus.error:
            onNotice(BillingNotice.failed);
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            if (await _verifyAndAcknowledge(purchase)) {
              onEntitlementChanged();
            } else {
              onNotice(BillingNotice.unverified);
            }
        }
      }
    }, onError: (Object _) => onNotice(BillingNotice.error));

    unawaited(_syncOwned(onEntitlementChanged));
  }

  /// Verifies with the backend first, then acknowledges with Play.
  Future<bool> _verifyAndAcknowledge(PurchaseDetails purchase) async {
    try {
      await _api.verifyMobilePurchase(
        purchaseToken: purchase.verificationData.serverVerificationData,
        productId: purchase.productID,
      );
    } catch (_) {
      return false;
    }
    if (purchase.pendingCompletePurchase) {
      await _iap!.completePurchase(purchase);
    }
    if (purchase is GooglePlayPurchaseDetails) _owned[purchase.productID] = purchase;
    return true;
  }

  Future<void> _syncOwned(VoidCallback onEntitlementChanged) async {
    final addition = _iap?.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    if (addition == null) return;
    final response = await addition.queryPastPurchases();
    _owned
      ..clear()
      ..addEntries(response.pastPurchases.map((p) => MapEntry(p.productID, p)));
    for (final purchase in response.pastPurchases) {
      if (!purchase.billingClientPurchase.isAcknowledged && purchase.status == PurchaseStatus.purchased) {
        if (await _verifyAndAcknowledge(purchase)) onEntitlementChanged();
      }
    }
  }

  /// Localized base-plan details for each plan's product, keyed by product id.
  Future<Map<String, GooglePlayProductDetails>> queryProducts(List<Plan> plans) async {
    final iap = _iap;
    if (iap == null) return {};
    final response = await iap.queryProductDetails(plans.map((p) => p.productId).toSet());
    final products = <String, GooglePlayProductDetails>{};
    for (final details in response.productDetails.whereType<GooglePlayProductDetails>()) {
      final offers = details.productDetails.subscriptionOfferDetails;
      final index = details.subscriptionIndex;
      // Only the base plan (no promotional offer) is sold, at its regular price.
      final isBasePlan = offers != null && index != null && offers[index].offerId == null;
      if (isBasePlan) products[details.id] = details;
    }
    return products;
  }

  /// Opens the Play purchase sheet. If the user already subscribes to another
  /// plan, it is replaced: upgrades apply now (unused time is credited),
  /// downgrades take effect at the next renewal.
  Future<void> buy(GooglePlayProductDetails product, {required List<Plan> plans}) async {
    final iap = _iap;
    if (iap == null) return;

    final rank = {for (final (i, plan) in plans.indexed) plan.productId: i};
    GooglePlayPurchaseDetails? current;
    for (final purchase in _owned.values) {
      if (purchase.productID != product.id && rank.containsKey(purchase.productID)) current = purchase;
    }

    final param = GooglePlayPurchaseParam(
      productDetails: product,
      offerToken: product.offerToken,
      changeSubscriptionParam: current == null
          ? null
          : ChangeSubscriptionParam(
              oldPurchaseDetails: current,
              replacementMode: (rank[product.id] ?? 0) > (rank[current.productID] ?? 0)
                  ? ReplacementMode.withTimeProration
                  : ReplacementMode.deferred,
            ),
    );
    await iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() async => _iap?.restorePurchases();

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
