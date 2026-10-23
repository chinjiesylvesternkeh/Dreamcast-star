import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../config.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';

/// Account options: subscription management, language, legal links, sign out
/// and in-app account deletion (required by Google Play for apps with sign-up).
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
    final l = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;

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
                plan == 'free'
                    ? l.accountFreePlan
                    : l.accountPlan('${plan[0].toUpperCase()}${plan.substring(1)}'),
                style: AppTheme.display(size: 24),
              ),
            ),
            _Item(
              icon: Icons.credit_card_outlined,
              label: l.manageSubscription,
              onTap: () => _open(AppConfig.manageSubscriptionUri()),
            ),
            _Item(
              icon: Icons.translate,
              label: l.language,
              trailing: _languageName(appState.locale, l),
              onTap: () => _pickLanguage(context, appState),
            ),
            _Item(
              icon: Icons.privacy_tip_outlined,
              label: l.privacyPolicy,
              onTap: () => _open(AppConfig.privacyPolicy(language)),
            ),
            _Item(
              icon: Icons.description_outlined,
              label: l.termsOfService,
              onTap: () => _open(AppConfig.terms(language)),
            ),
            _Item(
              icon: Icons.logout,
              label: l.logOut,
              onTap: () {
                Navigator.of(context).pop();
                appState.logout();
              },
            ),
            _Item(
              icon: Icons.delete_outline,
              label: l.deleteAccount,
              color: const Color(0xFFFF8FA3),
              onTap: () => _confirmDelete(context, appState),
            ),
          ],
        ),
      ),
    );
  }

  /// Language names are shown in their own language, as is conventional.
  static String _languageName(Locale? locale, AppLocalizations l) => switch (locale?.languageCode) {
        'en' => 'English',
        'fr' => 'Français',
        _ => l.languageSystem,
      };

  Future<void> _pickLanguage(BuildContext context, AppState appState) async {
    final l = AppLocalizations.of(context);
    const options = <String?>[null, 'en', 'fr'];
    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: AppTheme.surface,
        title: Text(l.language, style: AppTheme.display(size: 24)),
        children: [
          RadioGroup<String>(
            groupValue: appState.locale?.languageCode ?? 'system',
            onChanged: (value) => Navigator.of(dialogContext).pop(value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final code in options)
                  RadioListTile<String>(
                    value: code ?? 'system',
                    title: Text(_languageName(code == null ? null : Locale(code), l)),
                    activeColor: AppTheme.accent,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null) return;
    await appState.setLocale(picked == 'system' ? null : Locale(picked));
  }

  Future<void> _confirmDelete(BuildContext context, AppState appState) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(l.deleteTitle, style: AppTheme.display(size: 24)),
        content: Text(
          appState.isPro ? '${l.deleteBody}\n\n${l.deleteSubscriptionWarning}' : l.deleteBody,
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          if (appState.isPro)
            TextButton(
              onPressed: () => _open(AppConfig.manageSubscriptionUri()),
              child: Text(l.openGooglePlay),
            ),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l.cancel)),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.delete, style: const TextStyle(color: Color(0xFFFF8FA3))),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    try {
      await appState.deleteAccount();
      messenger.showSnackBar(SnackBar(content: Text(l.deleteDone)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.deleteError)));
    }
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final String? trailing;

  const _Item({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppTheme.textPrimary,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color == AppTheme.textPrimary ? AppTheme.textSecondary : color),
      title: Text(label, style: TextStyle(color: color)),
      trailing:
          trailing == null ? null : Text(trailing!, style: const TextStyle(color: AppTheme.textSecondary)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
