import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/billing_service.dart';
import '../theme.dart';

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
    'Unlimited daily dream interpretations',
    'Full dream pattern tracking over time',
    'Personal symbol dictionary',
    'HD Dream Cards with no watermark',
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
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              Text('DreamCast Pro',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary)),
              const SizedBox(height: 8),
              const Text(
                'Unlock the full meaning behind every dream.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),
              ..._features.map((f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppTheme.accent, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(f)),
                      ],
                    ),
                  )),
              const Spacer(),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_products.isEmpty)
                const Text(
                  'Subscriptions are not available on this device right now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                )
              else
                ..._products.map((product) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isPurchasing
                              ? null
                              : () async {
                                  setState(() => _isPurchasing = true);
                                  await _billing.buySubscription(product);
                                  if (mounted) setState(() => _isPurchasing = false);
                                },
                          child: Text('Subscribe — ${product.price}/month'),
                        ),
                      ),
                    )),
              TextButton(
                onPressed: () => _billing.restorePurchases(),
                child: const Text('Restore purchases', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
