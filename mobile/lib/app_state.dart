import 'package:flutter/foundation.dart';

import 'models/subscription.dart';
import 'services/api_client.dart';
import 'services/billing_service.dart';

class AppState extends ChangeNotifier {
  final ApiClient api;
  final BillingService billing;

  AppState(this.api) : billing = BillingService(api);

  bool isLoggedIn = false;
  SubscriptionStatus? subscription;
  bool isLoading = true;

  /// One-off billing messages (pending payment, errors) for the UI to show.
  final ValueNotifier<String?> billingNotice = ValueNotifier(null);

  bool get isPro => subscription?.isPro ?? false;

  /// Current plan id: free | lucid | mystic | oracle.
  String get planId => isPro ? subscription!.plan : 'free';

  Future<void> bootstrap() async {
    isLoading = true;
    notifyListeners();

    isLoggedIn = await api.isLoggedIn();
    if (isLoggedIn) {
      try {
        subscription = await api.getSubscription();
        _startBilling();
      } catch (_) {
        // Token might be stale/expired — treat as logged out.
        isLoggedIn = false;
      }
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> refreshSubscription() async {
    try {
      subscription = await api.getSubscription();
      notifyListeners();
    } catch (_) {
      // Non-fatal — UI just keeps showing last known state.
    }
  }

  Future<void> logout() async {
    billing.dispose();
    await api.logout();
    isLoggedIn = false;
    subscription = null;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await api.deleteAccount();
    billing.dispose();
    isLoggedIn = false;
    subscription = null;
    notifyListeners();
  }

  void onAuthenticated() {
    isLoggedIn = true;
    notifyListeners();
    refreshSubscription();
    _startBilling();
  }

  void _startBilling() {
    billing.start(
      onEntitlementChanged: refreshSubscription,
      onMessage: (message) => billingNotice.value = message,
    );
  }

  @override
  void dispose() {
    billing.dispose();
    billingNotice.dispose();
    super.dispose();
  }
}
