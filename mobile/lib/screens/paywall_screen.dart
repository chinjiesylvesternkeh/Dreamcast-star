import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/billing_service.dart';
import '../theme.dart';
import '../widgets/mystic.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late final BillingService _billing;
  List<ProductDetails> _products = [];
  bool _isLoading = true;
  bool _isPurchasing = false;

  static const _features = [
    (Icons.all_inclusive, 'Unlimited daily dream interpretations'),
    (Icons.timeline, 'Full dream pattern tracking over time'),
    (Icons.menu_book_outlined, 'Personal symbol dictionary'),
    (Icons.photo_outlined, 'HD Dream Cards with no watermark'),
  ];

  @override
  void initState() {
    super.initState();
    _billing = BillingService(context.read<AppState>().api);
    _billing.startListening(
      onPurchaseSuccess: () {
        context.read<AppState>().refreshSubscription();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Welcome to DreamCast Pro ✨')));
          Navigator.of(context).pop();
        }
      },
      onPurchaseError: (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        }
      },
    );
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final available = await _billing.isAvailable();
    if (!available) {
      setState(() => _isLoading = false);
      return;
    }
    final response = await _billing.queryProducts();
    setState(() {
      _products = response.productDetails;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _billing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Reveal(child: Center(child: MoonGlyph(size: 104))),
                          const SizedBox(height: 12),
                          const Reveal(delayMs: 100, child: Eyebrow('DREAMCAST PRO', center: true)),
                          const SizedBox(height: 14),
                          Reveal(
                            delayMs: 180,
                            child: Text(
                              'Unveil everything\nyour dreams conceal.',
                              textAlign: TextAlign.center,
                              style: AppTheme.display(size: 34, weight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Reveal(
                            delayMs: 260,
                            child: Text(
                              'Unlock the full meaning behind every dream.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Reveal(
                            delayMs: 340,
                            child: GlassPanel(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              child: Column(
                                children: [
                                  for (final (icon, text) in _features)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppTheme.accent.withValues(alpha: 0.08),
                                              border: Border.all(color: AppTheme.hairline),
                                            ),
                                            child: Icon(icon, size: 18, color: AppTheme.accent),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
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
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  else if (_products.isEmpty)
                    const Text(
                      'Subscriptions are not available on this device right now.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    )
                  else
                    ..._products.map((product) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GlowButton(
                            label: 'Subscribe — ${product.price}/month',
                            busy: _isPurchasing,
                            onPressed: () async {
                              setState(() => _isPurchasing = true);
                              await _billing.buySubscription(product);
                              if (mounted) setState(() => _isPurchasing = false);
                            },
                          ),
                        )),
                  TextButton(
                    onPressed: () => _billing.restorePurchases(),
                    child: const Text('Restore purchases'),
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
