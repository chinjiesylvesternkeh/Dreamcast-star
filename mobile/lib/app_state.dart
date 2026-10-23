import 'package:flutter/foundation.dart';

import 'models/subscription.dart';
import 'services/api_client.dart';

class AppState extends ChangeNotifier {
  final ApiClient api;

  AppState(this.api);

  bool isLoggedIn = false;
  SubscriptionStatus? subscription;
  bool isLoading = true;

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
    await api.logout();
    isLoggedIn = false;
    subscription = null;
    notifyListeners();
  }

  void onAuthenticated() {
    isLoggedIn = true;
    notifyListeners();
    refreshSubscription();
  }
}
