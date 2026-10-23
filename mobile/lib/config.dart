/// Public links the app must surface (Google Play requires an in-app privacy
/// policy link and clear subscription terms). Override per build with
/// --dart-define=PRIVACY_POLICY_URL=... etc. The same privacy policy URL
/// must be entered in Play Console > App content.
class AppConfig {
  static const packageName = 'com.dreamcast.app';

  static const privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://dreamcast.app/privacy',
  );

  static const termsUrl = String.fromEnvironment(
    'TERMS_URL',
    defaultValue: 'https://dreamcast.app/terms',
  );

  /// Google Play's subscription center, optionally focused on one product.
  static Uri manageSubscriptionUri([String? productId]) => Uri.https(
        'play.google.com',
        '/store/account/subscriptions',
        {if (productId != null) 'sku': productId, 'package': packageName},
      );
}
