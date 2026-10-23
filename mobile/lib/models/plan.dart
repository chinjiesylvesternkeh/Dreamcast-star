/// A paid DreamCast plan as served by GET /subscriptions/plans.
class Plan {
  final String id;
  final String name;
  final String productId; // Google Play subscription product id
  final String priceUsd; // Play Console base price; Play's localized price is shown when available
  final String tagline;
  final List<String> features;
  final String? highlight;

  Plan({
    required this.id,
    required this.name,
    required this.productId,
    required this.priceUsd,
    required this.tagline,
    required this.features,
    this.highlight,
  });

  /// Shown only when Google Play can't supply the localized price.
  String get referencePrice => 'US\$$priceUsd';

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id'] as String,
      name: json['name'] as String,
      productId: json['product_id'] as String,
      priceUsd: json['price_usd'] as String,
      tagline: json['tagline'] as String? ?? '',
      features: (json['features'] as List<dynamic>? ?? []).cast<String>(),
      highlight: json['highlight'] as String?,
    );
  }
}
