class Dream {
  final String id;
  final String rawText;
  final String? interpretation;
  final List<String> moodTags;
  final String? imageUrl;
  final String? cardHeadline;
  final DateTime createdAt;

  Dream({
    required this.id,
    required this.rawText,
    this.interpretation,
    this.moodTags = const [],
    this.imageUrl,
    this.cardHeadline,
    required this.createdAt,
  });

  factory Dream.fromJson(Map<String, dynamic> json) {
    return Dream(
      id: json['id'] as String,
      rawText: json['raw_text'] as String,
      interpretation: json['interpretation'] as String?,
      moodTags: (json['mood_tags'] as String? ?? '').split(',').where((t) => t.trim().isNotEmpty).toList(),
      imageUrl: json['image_url'] as String?,
      cardHeadline: json['card_headline'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
