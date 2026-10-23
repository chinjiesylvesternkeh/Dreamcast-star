import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../l10n/app_localizations.dart';
import '../models/dream.dart';
import '../theme.dart';
import '../widgets/mystic.dart';
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
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: FutureBuilder<List<Dream>>(
              future: _futureDreams,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: MoonGlyph(size: 72));
                }
                if (snapshot.hasError) {
                  return _Quiet(title: l.historyErrorTitle, body: l.historyErrorBody);
                }
                final dreams = snapshot.data ?? [];
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Reveal(child: Eyebrow(l.historyEyebrow)),
                            const SizedBox(height: 14),
                            Reveal(
                              delayMs: 100,
                              child: Text(l.historyTitle, style: AppTheme.display(size: 38)),
                            ),
                            const SizedBox(height: 6),
                            Reveal(
                              delayMs: 150,
                              child: Text(
                                l.historyCount(dreams.length),
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (dreams.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _Quiet(title: l.historyEmptyTitle, body: l.historyEmptyBody),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        sliver: SliverList.separated(
                          itemCount: dreams.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) => Reveal(
                            delayMs: 200 + (i < 8 ? i * 70 : 560),
                            child: _DreamTile(dream: dreams[i]),
                          ),
                        ),
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
}

class _DreamTile extends StatelessWidget {
  final Dream dream;

  const _DreamTile({required this.dream});

  @override
  Widget build(BuildContext context) {
    final date = dream.createdAt.toLocal();
    // Short month in the active language, e.g. "OCT" (fr "oct." -> "OCT").
    final month = DateFormat.MMM(Localizations.localeOf(context).toLanguageTag())
        .format(date)
        .replaceAll('.', '')
        .toUpperCase();
    return GlassPanel(
      blur: false,
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultScreen(dream: dream))),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text('${date.day}', style: AppTheme.display(size: 28, color: AppTheme.accent, height: 1)),
                const SizedBox(height: 4),
                Text(month,
                    style: AppTheme.eyebrow(color: AppTheme.textSecondary)
                        .copyWith(fontSize: 10, letterSpacing: 2)),
              ],
            ),
          ),
          Container(
            width: 0.8,
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: AppTheme.hairline,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dream.cardHeadline ?? dream.rawText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.display(size: 19, weight: FontWeight.w600, height: 1.25),
                ),
                if (dream.moodTags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    dream.moodTags.take(3).join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
        ],
      ),
    );
  }
}

class _Quiet extends StatelessWidget {
  final String title;
  final String body;

  const _Quiet({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Reveal(
          delayMs: 200,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MoonGlyph(size: 84),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: AppTheme.display(size: 24)),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
