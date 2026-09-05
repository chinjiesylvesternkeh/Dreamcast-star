import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/dream.dart';
import '../theme.dart';
import 'result_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Dream>> _futureDreams;

  @override
  void initState() {
    super.initState();
    _futureDreams = context.read<AppState>().api.listDreams();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your dreams')),
      body: FutureBuilder<List<Dream>>(
        future: _futureDreams,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final dreams = snapshot.data ?? [];
          if (dreams.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  "No dreams logged yet. Tap 'New dream' to record last night's.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: dreams.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final dream = dreams[i];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    dream.cardHeadline ?? dream.rawText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${dream.createdAt.month}/${dream.createdAt.day}/${dream.createdAt.year}',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => ResultScreen(dream: dream))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
