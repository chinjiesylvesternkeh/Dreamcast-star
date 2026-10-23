/// A paid DreamCast plan as served by GET /subscriptions/plans.
class Plan {
  final String id;
  final String name;
  final int priceXaf;
  final String tagline;
  final List<String> features;
  final String? highlight;
  final bool autoRenews;

  Plan({
    required this.id,
    required this.name,
    required this.priceXaf,
    required this.tagline,
    required this.features,
    this.highlight,
    this.autoRenews = false,
  });

  /// e.g. "XAF 2,000"
  String get price => formatXaf(priceXaf);

  /// e.g. "≈ XAF 67 a day"
  String get perDay => '≈ ${formatXaf((priceXaf / 30).round())} a day';

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id'] as String,
      name: json['name'] as String,
      priceXaf: json['price_xaf'] as int,
      tagline: json['tagline'] as String? ?? '',
      features: (json['features'] as List<dynamic>? ?? []).cast<String>(),
      highlight: json['highlight'] as String?,
      autoRenews: json['auto_renews'] as bool? ?? false,
    );
  }
}

String formatXaf(int amount) {
  final digits = amount.toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return 'XAF $grouped';
}
