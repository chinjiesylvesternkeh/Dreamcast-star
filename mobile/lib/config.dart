/// Public links the app must surface (Google Play requires an in-app privacy
/// policy link and clear subscription terms). The pages live in docs/ — English
/// at the root, French under fr/ — and are served by GitHub Pages. Point a
/// build at another host with --dart-define=SITE_URL=https://example.com.
/// The English privacy policy URL is the one entered in Play Console.
class AppConfig {
  static const packageName = 'com.dreamcast.app';

  static const siteUrl = String.fromEnvironment(
    'SITE_URL',
    defaultValue: 'https://chinjiesylvesternkeh.github.io/Dreamcast-star',
  );

  static Uri _page(String page, String languageCode) =>
      Uri.parse('$siteUrl/${languageCode == 'fr' ? 'fr/' : ''}$page.html');

  static Uri privacyPolicy(String languageCode) => _page('privacy', languageCode);

  static Uri terms(String languageCode) => _page('terms', languageCode);

  /// Google Play's subscription center, optionally focused on one product.
  static Uri manageSubscriptionUri([String? productId]) => Uri.https(
        'play.google.com',
        '/store/account/subscriptions',
        {if (productId != null) 'sku': productId, 'package': packageName},
      );
}
