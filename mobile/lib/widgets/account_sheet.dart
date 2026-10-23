import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../config.dart';
import '../theme.dart';

/// Account options: subscription management, legal links, sign out and
/// in-app account deletion (required by Google Play for apps with sign-up).
Future<void> showAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _AccountSheet(),
  );
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet();

  void _open(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final plan = appState.planId;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: AppTheme.hairline, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                plan == 'free' ? 'Free plan' : '${plan[0].toUpperCase()}${plan.substring(1)} plan',
                style: AppTheme.display(size: 24),
              ),
            ),
            _Item(
              icon: Icons.credit_card_outlined,
              label: 'Manage subscription',
              onTap: () => _open(AppConfig.manageSubscriptionUri()),
            ),
            _Item(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              onTap: () => _open(Uri.parse(AppConfig.privacyPolicyUrl)),
            ),
            _Item(
              icon: Icons.description_outlined,
              label: 'Terms of Service',
              onTap: () => _open(Uri.parse(AppConfig.termsUrl)),
            ),
            _Item(
              icon: Icons.logout,
              label: 'Log out',
              onTap: () {
                Navigator.of(context).pop();
                appState.logout();
              },
            ),
            _Item(
              icon: Icons.delete_outline,
              label: 'Delete account',
              color: const Color(0xFFFF8FA3),
              onTap: () => _confirmDelete(context, appState),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppState appState) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Delete your account?', style: AppTheme.display(size: 24)),
        content: Text(
          'This permanently deletes your account, every dream and reading, and your Dream Cards. '
          'It cannot be undone.'
          '${appState.isPro ? '\n\nDeleting your account does not cancel your Google Play subscription. '
              'Cancel it in Google Play › Subscriptions to stop future charges.' : ''}',
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          if (appState.isPro)
            TextButton(
              onPressed: () => _open(AppConfig.manageSubscriptionUri()),
              child: const Text('Open Google Play'),
            ),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF8FA3))),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    try {
      await appState.deleteAccount();
      messenger.showSnackBar(const SnackBar(content: Text('Your account and data have been deleted.')));
    } catch (_) {
      messenger
          .showSnackBar(const SnackBar(content: Text("Couldn't delete your account. Please try again.")));
    }
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _Item(
      {required this.icon, required this.label, required this.onTap, this.color = AppTheme.textPrimary});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color == AppTheme.textPrimary ? AppTheme.textSecondary : color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
