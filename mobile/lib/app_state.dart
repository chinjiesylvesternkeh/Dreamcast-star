import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// One-off billing events (pending payment, errors) for the UI to show.
  final ValueNotifier<BillingNotice?> billingNotice = ValueNotifier(null);

  static const _localeKey = 'app_locale';

  /// The language picked in the app, or null to follow the phone's language.
  Locale? locale;

  Future<void> setLocale(Locale? value) async {
    locale = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(_localeKey);
      } else {
        await prefs.setString(_localeKey, value.languageCode);
      }
    } catch (_) {
      // Preference storage is best-effort; the choice still applies this session.
    }
  }

  bool get isPro => subscription?.isPro ?? false;

  /// Current plan id: free | lucid | mystic | oracle.
  String get planId => isPro ? subscription!.plan : 'free';

  Future<void> bootstrap() async {
    isLoading = true;
    notifyListeners();

    try {
      final saved = (await SharedPreferences.getInstance()).getString(_localeKey);
      locale = saved == null ? null : Locale(saved);
    } catch (_) {
      locale = null;
    }

    try {
      isLoggedIn = await api.isLoggedIn();
      if (isLoggedIn) {
        subscription = await api.getSubscription();
        _startBilling();
      }
    } catch (_) {
      // Stale session, unreachable server or unreadable storage: show sign-in
      // rather than staying on the loading screen.
      isLoggedIn = false;
      subscription = null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
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
      onNotice: (notice) => billingNotice.value = notice,
    );
  }

  @override
  void dispose() {
    billing.dispose();
    billingNotice.dispose();
    super.dispose();
  }
}
