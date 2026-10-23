import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'l10n/app_localizations.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'services/api_client.dart';
import 'theme.dart';
import 'widgets/mystic.dart';
import 'widgets/night_sky.dart';

void main() {
  runApp(const DreamCastApp());
}

class DreamCastApp extends StatelessWidget {
  const DreamCastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(ApiClient())..bootstrap(),
      child: Builder(
        builder: (context) {
          final appState = context.watch<AppState>();
          return MaterialApp(
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.dark,
            // English and French; follows the phone unless the user picks one.
            locale: appState.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) {
              // Backend replies (plan copy, errors, AI readings) follow the active locale.
              appState.api.languageCode = Localizations.localeOf(context).languageCode;
              return NightSky(child: child ?? const SizedBox.shrink());
            },
            home: const _RootRouter(),
          );
        },
      ),
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (appState.isLoading) {
      return const Scaffold(body: Center(child: MoonGlyph(size: 96)));
    }
    return appState.isLoggedIn ? const HomeShell() : const AuthScreen();
  }
}
