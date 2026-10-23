import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../l10n/app_localizations.dart';
import '../services/billing_service.dart';
import '../theme.dart';
import '../widgets/account_sheet.dart';
import 'history_screen.dart';
import 'paywall_screen.dart';
import 'record_dream_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _screens = const [RecordDreamScreen(), HistoryScreen()];
  late final AppState _appState = context.read<AppState>();

  @override
  void initState() {
    super.initState();
    _appState.billingNotice.addListener(_showBillingNotice);
  }

  @override
  void dispose() {
    _appState.billingNotice.removeListener(_showBillingNotice);
    super.dispose();
  }

  void _showBillingNotice() {
    final notice = _appState.billingNotice.value;
    if (notice == null || !mounted) return;
    final l = AppLocalizations.of(context);
    final message = switch (notice) {
      BillingNotice.pending => l.billingPending,
      BillingNotice.failed => l.billingFailed,
      BillingNotice.unverified => l.billingUnverified,
      BillingNotice.error => l.billingError,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    _appState.billingNotice.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l = AppLocalizations.of(context);

    return Scaffold(
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: KeyedSubtree(key: ValueKey(_index), child: _screens[_index]),
          ),
          Positioned(
            top: 0,
            right: 16,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    _ProPill(
                      label: appState.isPro ? appState.planId.toUpperCase() : l.plansPill,
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const PaywallScreen())),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: l.accountTooltip,
                      onPressed: () => showAccountSheet(context),
                      icon: const Icon(Icons.person_outline, color: AppTheme.textSecondary),
                      style: IconButton.styleFrom(
                        side: const BorderSide(color: AppTheme.hairline),
                        backgroundColor: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.hairline, width: 0.6)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.nights_stay_outlined),
              selectedIcon: const Icon(Icons.nights_stay),
              label: l.navDream,
            ),
            NavigationDestination(
              icon: const Icon(Icons.auto_stories_outlined),
              selectedIcon: const Icon(Icons.auto_stories),
              label: l.navArchive,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ProPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(30);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: shape,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: shape,
            color: AppTheme.accent.withValues(alpha: 0.08),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5), width: 0.8),
            boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.18), blurRadius: 16)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 14, color: AppTheme.accent),
              const SizedBox(width: 6),
              Text(label, style: AppTheme.eyebrow().copyWith(letterSpacing: 2.4)),
            ],
          ),
        ),
      ),
    );
  }
}
