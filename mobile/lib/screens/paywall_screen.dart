import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../models/plan.dart';
import '../theme.dart';
import '../widgets/mystic.dart';

/// Plan picker: Lucid, Mystic and Oracle, paid in XAF through Flutterwave
/// (MTN MoMo, Orange Money or card) in the browser.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> with WidgetsBindingObserver {
  late Future<List<Plan>> _futurePlans;
  String? _selectedId;
  bool _isStarting = false;
  bool _awaitingPayment = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPlans();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _loadPlans() {
    _futurePlans = context.read<AppState>().api.getPlans();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the checkout page: pick up the new plan.
    if (state == AppLifecycleState.resumed && _awaitingPayment) {
      _refreshStatus(quiet: true);
    }
  }

  Future<void> _refreshStatus({bool quiet = false}) async {
    final appState = context.read<AppState>();
    final before = appState.planId;
    setState(() => _isRefreshing = true);
    await appState.refreshSubscription();
    if (!mounted) return;
    setState(() => _isRefreshing = false);

    final after = appState.planId;
    if (after != 'free' && after != before) {
      _awaitingPayment = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Welcome to ${_nameFor(after)} ✨')),
      );
      Navigator.of(context).pop();
    } else if (!quiet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No new payment yet. Mobile money payments can take a minute to confirm.'),
        ),
      );
    }
  }

  String _nameFor(String planId) => planId[0].toUpperCase() + planId.substring(1);

  Future<void> _checkout(Plan plan) async {
    setState(() => _isStarting = true);
    try {
      final url = await context.read<AppState>().api.startCheckout(plan.id);
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('Could not open checkout');
      _awaitingPayment = true;
    } on DioException catch (e) {
      final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
      _showError(detail is String ? detail : "Couldn't start the payment. Please try again.");
    } catch (_) {
      _showError("Couldn't open the payment page. Please try again.");
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _showError(String message) {
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
            child: FutureBuilder<List<Plan>>(
              future: _futurePlans,
              builder: (context, snapshot) {
                final plans = snapshot.data ?? const <Plan>[];
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
                                'Simple monthly plans in XAF. Pay with MTN MoMo, Orange Money or card.',
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
                              _LoadError(onRetry: () => setState(_loadPlans))
                            else
                              for (final (i, plan) in plans.indexed) ...[
                                Reveal(
                                  delayMs: 260 + i * 90,
                                  child: _PlanCard(
                                    plan: plan,
                                    selected: plan.id == selected?.id,
                                    isCurrent: plan.id == currentPlan,
                                    onTap: () => setState(() => _selectedId = plan.id),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                          ],
                        ),
                      ),
                    ),
                    if (selected != null)
                      _CheckoutBar(
                        plan: selected,
                        isCurrent: selected.id == currentPlan,
                        busy: _isStarting,
                        refreshing: _isRefreshing,
                        onContinue: () => _checkout(selected),
                        onRefresh: () => _refreshStatus(),
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
  final bool selected;
  final bool isCurrent;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
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
      label: '${plan.name}, ${plan.price} per month',
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
                                Text(plan.name, style: AppTheme.display(size: 25, weight: FontWeight.w600, height: 1)),
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
                            plan.price,
                            style: AppTheme.display(size: 22, color: AppTheme.accent, weight: FontWeight.w700, height: 1)
                                .copyWith(fontFeatures: const [FontFeature.liningFigures()]),
                          ),
                          const SizedBox(height: 4),
                          const Text('per month', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5)),
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
                          if (selected)
                            Text(
                              plan.perDay,
                              style: AppTheme.eyebrow(color: AppTheme.textSecondary).copyWith(
                                fontSize: 10,
                                letterSpacing: 1.6,
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
  final bool isCurrent;
  final bool busy;
  final bool refreshing;
  final VoidCallback onContinue;
  final VoidCallback onRefresh;

  const _CheckoutBar({
    required this.plan,
    required this.isCurrent,
    required this.busy,
    required this.refreshing,
    required this.onContinue,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.hairline, width: 0.6)),
        color: Color(0x990A0816),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlowButton(
            label: isCurrent
                ? 'Renew ${plan.name} · ${plan.price}'
                : 'Continue with ${plan.name} · ${plan.price}',
            busyLabel: 'Opening secure checkout…',
            busy: busy,
            onPressed: onContinue,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 13, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Secure payment by Flutterwave · MTN MoMo · Orange Money · Card',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.9), fontSize: 11.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            plan.autoRenews
                ? 'Renews monthly. Cancel anytime.'
                : 'One month of access. No automatic charges — renew whenever you like.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.75), fontSize: 11.5),
          ),
          TextButton(
            onPressed: refreshing ? null : onRefresh,
            child: Text(refreshing ? 'Checking…' : 'Already paid? Refresh my plan'),
          ),
        ],
      ),
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
