class SubscriptionStatus {
  final String status; // free | active | past_due | canceled | trial
  final String provider;
  final String plan; // free | lucid | mystic | oracle
  final DateTime? currentPeriodEnd;

  SubscriptionStatus({
    required this.status,
    required this.provider,
    this.plan = 'free',
    this.currentPeriodEnd,
  });

  bool get isPro => status == 'active' || status == 'trial';

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      status: json['status'] as String,
      provider: json['provider'] as String,
      plan: json['plan'] as String? ?? 'free',
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.parse(json['current_period_end'] as String)
          : null,
    );
  }
}
