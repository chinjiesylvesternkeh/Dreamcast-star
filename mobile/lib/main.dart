import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
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
      child: MaterialApp(
        title: 'DreamCast',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        builder: (context, child) => NightSky(child: child ?? const SizedBox.shrink()),
        home: const _RootRouter(),
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
