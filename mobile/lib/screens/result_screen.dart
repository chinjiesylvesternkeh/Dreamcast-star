import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../models/dream.dart';
import '../theme.dart';
import '../widgets/mystic.dart';

class ResultScreen extends StatelessWidget {
  final Dream dream;
  final ScreenshotController _screenshotController = ScreenshotController();

  ResultScreen({super.key, required this.dream});

  Future<void> _shareCard(BuildContext context) async {
    final Uint8List? bytes = await _screenshotController.capture();
    if (bytes == null) return;
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: 'dream_card.png', mimeType: 'image/png')],
      text: 'My dream, decoded by DreamCast ✨',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YOUR DREAM, DECODED')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Reveal(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.28),
                            blurRadius: 48,
                            spreadRadius: -8,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Screenshot(
                        controller: _screenshotController,
                        child: _DreamCard(dream: dream),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  if (dream.moodTags.isNotEmpty)
                    Reveal(
                      delayMs: 200,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: dream.moodTags.map((tag) => _MoodTag(tag)).toList(),
                      ),
                    ),
                  const SizedBox(height: 28),
                  const Reveal(delayMs: 300, child: Eyebrow('WHAT IT MEANS')),
                  const SizedBox(height: 12),
                  Reveal(
                    delayMs: 380,
                    child: Text(
                      dream.interpretation ?? '',
                      style: AppTheme.display(size: 20, weight: FontWeight.w400, height: 1.55),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Reveal(
                    delayMs: 460,
                    child: GlowButton(
                      icon: Icons.ios_share,
                      label: 'Share your Dream Card',
                      onPressed: () => _shareCard(context),
                    ),
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

class _MoodTag extends StatelessWidget {
  final String tag;

  const _MoodTag(this.tag);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: AppTheme.accent.withValues(alpha: 0.06),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        tag.trim().toLowerCase(),
        style: const TextStyle(color: AppTheme.accent, fontSize: 13, letterSpacing: 0.6),
      ),
    );
  }
}

class _DreamCard extends StatelessWidget {
  final Dream dream;
  const _DreamCard({required this.dream});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (dream.imageUrl != null)
              CachedNetworkImage(
                imageUrl: dream.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => const _CardNebula(),
                errorWidget: (_, __, ___) => const _CardNebula(),
              )
            else
              const _CardNebula(),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, const Color(0xFF05040C).withValues(alpha: 0.92)],
                  stops: const [0.35, 1.0],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35), width: 0.8),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dream.cardHeadline ?? '',
                    style: AppTheme.display(size: 28, color: Colors.white, weight: FontWeight.w600, height: 1.2),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.nights_stay, size: 12, color: AppTheme.accent),
                      const SizedBox(width: 6),
                      Text('DREAMCAST', style: AppTheme.eyebrow().copyWith(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stand-in artwork while the dream image loads, or when there isn't one.
class _CardNebula extends StatelessWidget {
  const _CardNebula();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.4, -0.5),
          radius: 1.3,
          colors: [Color(0xFF4B3C9E), Color(0xFF241A4F), Color(0xFF0B0819)],
          stops: [0, 0.45, 1],
        ),
      ),
      child: Align(
        alignment: const Alignment(0.35, -0.45),
        child: MoonGlyph(size: MediaQuery.sizeOf(context).width * 0.32),
      ),
    );
  }
}
