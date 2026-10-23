import 'package:flutter/material.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../config.dart';
import '../models/plan.dart';
import '../services/billing_service.dart';
import '../theme.dart';
import '../widgets/mystic.dart';

/// Plan picker: Lucid, Mystic and Oracle, sold as Google Play subscriptions.
///
/// Follows Play's subscriptions policy: the localized price and billing
/// period are shown with every offer, auto-renewal and how to cancel are
/// stated before purchase, and restore / manage-subscription are one tap away.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _Catalog {
  final List<Plan> plans;
  final Map<String, GooglePlayProductDetails> products;
  final bool billingAvailable;

  const _Catalog(this.plans, this.products, this.billingAvailable);
}

class _PaywallScreenState extends State<PaywallScreen> {
  late final AppState _appState = context.read<AppState>();
  late String _planOnOpen = _appState.planId;
  late Future<_Catalog> _futureCatalog;
  String? _selectedId;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onAppStateChanged);
    _load();
  }

  @override
  void dispose() {
    _appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _load() {
    _futureCatalog = () async {
      final plans = await _appState.api.getPlans();
      final available = await _appState.billing.isAvailable();
      final products =
          available ? await _appState.billing.queryProducts(plans) : <String, GooglePlayProductDetails>{};
      return _Catalog(plans, products, available);
    }();
  }

  /// Closes with a welcome once a purchase is verified and the plan changes.
  void _onAppStateChanged() {
    final plan = _appState.planId;
    if (!mounted || plan == 'free' || plan == _planOnOpen) return;
    _planOnOpen = plan;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Welcome to ${plan[0].toUpperCase()}${plan.substring(1)} ✨')),
    );
    Navigator.of(context).maybePop();
  }

  Future<void> _buy(_Catalog catalog, Plan plan) async {
    final product = catalog.products[plan.productId];
    if (product == null) return;
    setState(() => _isPurchasing = true);
    try {
      await _appState.billing.buy(product, plans: catalog.plans);
    } catch (_) {
      _snack("Couldn't open Google Play. Please try again.");
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _restore() async {
    await _appState.billing.restorePurchases();
    await _appState.refreshSubscription();
    if (mounted && _appState.planId == 'free') {
      _snack('No active DreamCast subscription was found on this Google account.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final currentPlan = context.watch<AppState>().planId;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: FutureBuilder<_Catalog>(
              future: _futureCatalog,
              builder: (context, snapshot) {
                final catalog = snapshot.data;
                final plans = catalog?.plans ?? const <Plan>[];
                final selected = _resolveSelection(plans, currentPlan);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Reveal(child: Center(child: MoonGlyph(size: 76))),
                            const SizedBox(height: 8),
                            const Reveal(delayMs: 80, child: Eyebrow('DREAMCAST MEMBERSHIP', center: true)),
                            const SizedBox(height: 12),
                            Reveal(
                              delayMs: 140,
                              child: Text(
                                'Choose how deep\nyou want to go.',
                                textAlign: TextAlign.center,
                                style: AppTheme.display(size: 32, weight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Reveal(
                              delayMs: 200,
                              child: Text(
                                'Monthly plans, billed securely through Google Play. Change or cancel anytime.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (snapshot.connectionState != ConnectionState.done)
                              const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            else if (snapshot.hasError || plans.isEmpty)
                              _LoadError(onRetry: () => setState(_load))
                            else ...[
                              for (final (i, plan) in plans.indexed) ...[
                                Reveal(
                                  delayMs: 260 + i * 90,
                                  child: _PlanCard(
                                    plan: plan,
                                    price: catalog!.products[plan.productId]?.price ?? plan.referencePrice,
                                    selected: plan.id == selected?.id,
                                    isCurrent: plan.id == currentPlan,
                                    onTap: () => setState(() => _selectedId = plan.id),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              const SizedBox(height: 4),
                              const _LegalLinks(),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (catalog != null && selected != null)
                      _CheckoutBar(
                        plan: selected,
                        plans: catalog.plans,
                        product: catalog.products[selected.productId],
                        billingAvailable: catalog.billingAvailable,
                        currentPlan: currentPlan,
                        busy: _isPurchasing,
                        onBuy: () => _buy(catalog, selected),
                        onRestore: _restore,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// The user's pick, else the next tier up from their plan, else the highlighted plan.
  Plan? _resolveSelection(List<Plan> plans, String currentPlan) {
    if (plans.isEmpty) return null;
    for (final plan in plans) {
      if (plan.id == _selectedId) return plan;
    }
    final currentIndex = plans.indexWhere((p) => p.id == currentPlan);
    if (currentIndex >= 0) return plans[(currentIndex + 1).clamp(0, plans.length - 1)];
    return plans.firstWhere((p) => p.highlight == 'Most popular', orElse: () => plans.first);
  }
}

class _PlanCard extends StatelessWidget {
  final Plan plan;
  final String price;
  final bool selected;
  final bool isCurrent;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.price,
    required this.selected,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    final badge = isCurrent ? 'Your plan' : plan.highlight;

    return Semantics(
      selected: selected,
      button: true,
      label: '${plan.name}, $price per month',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: selected ? AppTheme.accent.withValues(alpha: 0.85) : AppTheme.hairline,
            width: selected ? 1.3 : 0.8,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [AppTheme.accent.withValues(alpha: 0.10), AppTheme.primary.withValues(alpha: 0.06)]
                : [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.02)],
          ),
          boxShadow: selected
              ? [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.16), blurRadius: 28, spreadRadius: -6)]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Radio(selected: selected),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(plan.name,
                                    style: AppTheme.display(size: 25, weight: FontWeight.w600, height: 1)),
                                if (badge != null) _Badge(badge, filled: !isCurrent),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              plan.tagline,
                              style: AppTheme.display(
                                size: 16,
                                color: AppTheme.textSecondary,
                                style: FontStyle.italic,
                                weight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            price,
                            style: AppTheme.display(
                                    size: 22, color: AppTheme.accent, weight: FontWeight.w700, height: 1)
                                .copyWith(fontFeatures: const [FontFeature.liningFigures()]),
                          ),
                          const SizedBox(height: 4),
                          const Text('per month',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5)),
                        ],
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 34, top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final feature in selected ? plan.features : plan.features.take(1))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: selected ? AppTheme.accent : AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      feature,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.4,
                                        color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  final bool selected;

  const _Radio({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(top: 3),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppTheme.accent : Colors.transparent,
        border: Border.all(color: selected ? AppTheme.accent : AppTheme.textSecondary, width: 1.2),
      ),
      child: selected ? const Icon(Icons.check_rounded, size: 15, color: AppTheme.ink) : null,
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final bool filled;

  const _Badge(this.text, {required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: filled ? AppTheme.accent : Colors.transparent,
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.7), width: 0.8),
      ),
      child: Text(
        text.toUpperCase(),
        style: AppTheme.eyebrow(color: filled ? AppTheme.ink : AppTheme.accent).copyWith(
          fontSize: 9,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  final Plan plan;
  final List<Plan> plans;
  final GooglePlayProductDetails? product;
  final bool billingAvailable;
  final String currentPlan;
  final bool busy;
  final VoidCallback onBuy;
  final VoidCallback onRestore;

  const _CheckoutBar({
    required this.plan,
    required this.plans,
    required this.product,
    required this.billingAvailable,
    required this.currentPlan,
    required this.busy,
    required this.onBuy,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = plan.id == currentPlan;
    final currentIndex = plans.indexWhere((p) => p.id == currentPlan);
    final isSwitch = currentIndex >= 0 && !isCurrent;
    final isUpgrade = isSwitch && plans.indexOf(plan) > currentIndex;
    final price = product?.price;

    final String label;
    if (isCurrent) {
      label = 'Your current plan';
    } else if (price == null) {
      label = 'Continue with ${plan.name}';
    } else {
      label = '${isSwitch ? 'Switch' : 'Subscribe'} to ${plan.name} · $price/month';
    }

    final String terms;
    if (!BillingService.isSupported) {
      terms = 'Subscriptions are purchased through Google Play in the DreamCast Android app.';
    } else if (!billingAvailable || price == null) {
      terms =
          'Google Play Billing is unavailable on this device right now. Make sure the Play Store is installed and signed in.';
    } else if (isCurrent) {
      terms = 'Manage, change or cancel your subscription anytime in Google Play.';
    } else {
      final timing = !isSwitch
          ? ''
          : isUpgrade
              ? ' Your upgrade starts now and unused time on your current plan is credited.'
              : ' Your new plan starts at your next renewal date.';
      terms = '$price per month, charged to your Google Play account. Renews automatically every month until '
          'you cancel. Cancel anytime in Google Play › Subscriptions — you keep access until the end of the '
          'period you have paid for.$timing';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.hairline, width: 0.6)),
        color: Color(0x990A0816),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlowButton(
            label: label,
            busyLabel: 'Opening Google Play…',
            busy: busy,
            onPressed: isCurrent || product == null ? null : onBuy,
          ),
          const SizedBox(height: 10),
          Text(
            terms,
            textAlign: TextAlign.center,
            style:
                TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.9), fontSize: 11.5, height: 1.45),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => launchUrl(
                  AppConfig.manageSubscriptionUri(isCurrent ? plan.productId : null),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('Manage subscription', style: TextStyle(fontSize: 12.5)),
              ),
              const Text('·', style: TextStyle(color: AppTheme.textSecondary)),
              TextButton(
                onPressed: BillingService.isSupported ? onRestore : null,
                child: const Text('Restore purchases', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  @override
  Widget build(BuildContext context) {
    const style =
        TextStyle(fontSize: 12, color: AppTheme.textSecondary, decoration: TextDecoration.underline);
    return Column(
      children: [
        const Text(
          'Readings are AI-generated for reflection and entertainment, not medical or psychological advice.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.45),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => launchUrl(Uri.parse(AppConfig.termsUrl), mode: LaunchMode.externalApplication),
              child: const Text('Terms of Service', style: style),
            ),
            TextButton(
              onPressed: () =>
                  launchUrl(Uri.parse(AppConfig.privacyPolicyUrl), mode: LaunchMode.externalApplication),
              child: const Text('Privacy Policy', style: style),
            ),
          ],
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _LoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        children: [
          Text("Plans couldn't load", style: AppTheme.display(size: 22)),
          const SizedBox(height: 6),
          const Text(
            'Check your connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
