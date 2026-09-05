import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../models/dream.dart';
import '../theme.dart';

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
      appBar: AppBar(title: const Text('Your dream, decoded')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Screenshot(
                controller: _screenshotController,
                child: _DreamCard(dream: dream),
              ),
              const SizedBox(height: 24),
              if (dream.moodTags.isNotEmpty)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: dream.moodTags
                      .map((tag) => Chip(
                            label: Text(tag),
                            backgroundColor: AppTheme.surface,
                            labelStyle: const TextStyle(color: AppTheme.textPrimary),
                          ))
                      .toList(),
                ),
              const SizedBox(height: 16),
              Text(
                dream.interpretation ?? '',
                style: const TextStyle(fontSize: 15, height: 1.5, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _shareCard(context),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Share your Dream Card'),
                ),
              ),
            ],
          ),
        ),
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
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (dream.imageUrl != null)
              CachedNetworkImage(imageUrl: dream.imageUrl!, fit: BoxFit.cover)
            else
              Container(color: AppTheme.surface),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dream.cardHeadline ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('DreamCast', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
