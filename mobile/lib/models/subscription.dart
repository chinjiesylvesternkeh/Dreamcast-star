class SubscriptionStatus {
  final String status; // free | active | past_due | canceled | trial
  final String provider;
  final DateTime? currentPeriodEnd;

  SubscriptionStatus({
    required this.status,
    required this.provider,
    this.currentPeriodEnd,
  });

  bool get isPro => status == 'active' || status == 'trial';

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      status: json['status'] as String,
      provider: json['provider'] as String,
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.parse(json['current_period_end'] as String)
          : null,
    );
  }
}
