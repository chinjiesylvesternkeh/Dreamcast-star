import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppTheme.surface,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.nights_stay_outlined), label: 'Dream'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
      floatingActionButton: appState.isPro
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const PaywallScreen())),
              backgroundColor: AppTheme.accent,
              icon: const Icon(Icons.star, color: Colors.black87),
              label: const Text('Go Pro', style: TextStyle(color: Colors.black87)),
            ),
    );
  }
}
