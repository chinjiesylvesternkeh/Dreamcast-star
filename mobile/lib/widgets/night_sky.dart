import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Drifting nebulae, twinkling stars and the occasional shooting star,
/// painted once behind every screen of the app.
class NightSky extends StatefulWidget {
  final Widget child;

  const NightSky({super.key, required this.child});

  @override
  State<NightSky> createState() => _NightSkyState();
}

class _NightSkyState extends State<NightSky> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();
  final List<_Star> _stars = _Star.scatter(160);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0E0B26), AppTheme.background, AppTheme.backgroundDeep],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
        RepaintBoundary(child: CustomPaint(painter: _SkyPainter(_controller, _stars))),
        widget.child,
      ],
    );
  }
}

class _Star {
  final Offset position; // 0..1 in both axes
  final double radius;
  final double phase;
  final int twinkles; // whole number per cycle so the loop is seamless
  final bool bright;

  const _Star(this.position, this.radius, this.phase, this.twinkles, this.bright);

  static List<_Star> scatter(int count) {
    final rng = math.Random(7);
    return List.generate(count, (_) {
      final bright = rng.nextDouble() < 0.08;
      return _Star(
        Offset(rng.nextDouble(), rng.nextDouble()),
        bright ? 1.3 + rng.nextDouble() * 0.8 : 0.3 + rng.nextDouble() * 0.9,
        rng.nextDouble(),
        1 + rng.nextInt(5),
        bright,
      );
    });
  }
}

class _SkyPainter extends CustomPainter {
  final Animation<double> animation;
  final List<_Star> stars;

  _SkyPainter(this.animation, this.stars) : super(repaint: animation);

  final _starPaint = Paint();
  final _glowPaint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

  @override
  void paint(Canvas canvas, Size size) {
    final v = animation.value;
    final t = v * 2 * math.pi;

    _nebula(canvas, size, Offset(0.15 + 0.06 * math.sin(t), 0.18 + 0.04 * math.cos(t)), 0.75,
        AppTheme.primary.withValues(alpha: 0.20));
    _nebula(canvas, size, Offset(0.92 + 0.05 * math.cos(t), 0.55 + 0.05 * math.sin(t)), 0.6,
        AppTheme.rose.withValues(alpha: 0.11));
    _nebula(canvas, size, Offset(0.35 + 0.05 * math.sin(t + 2), 1.02), 0.8,
        const Color(0xFF3A4BFF).withValues(alpha: 0.10));

    for (final star in stars) {
      final shimmer = 0.5 + 0.5 * math.sin((v * star.twinkles + star.phase) * 2 * math.pi);
      final alpha = 0.15 + 0.85 * shimmer;
      final center = Offset(star.position.dx * size.width, star.position.dy * size.height);
      if (star.bright) {
        _glowPaint.color = AppTheme.accent.withValues(alpha: alpha * 0.45);
        canvas.drawCircle(center, star.radius * 3, _glowPaint);
      }
      _starPaint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(center, star.radius, _starPaint);
    }

    _shootingStar(canvas, size, v, start: 0.30, from: const Offset(0.88, 0.06), to: const Offset(0.42, 0.30));
    _shootingStar(canvas, size, v, start: 0.78, from: const Offset(0.12, 0.10), to: const Offset(0.58, 0.34));
  }

  void _nebula(Canvas canvas, Size size, Offset relative, double spread, Color color) {
    final center = Offset(relative.dx * size.width, relative.dy * size.height);
    final radius = size.longestSide * spread * 0.6;
    final paint = Paint()
      ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _shootingStar(
    Canvas canvas,
    Size size,
    double v, {
    required double start,
    required Offset from,
    required Offset to,
  }) {
    const duration = 0.035; // fraction of the 40s cycle (~1.4s)
    final p = (v - start) / duration;
    if (p < 0 || p > 1) return;

    final a = Offset(from.dx * size.width, from.dy * size.height);
    final b = Offset(to.dx * size.width, to.dy * size.height);
    final head = Offset.lerp(a, b, Curves.easeIn.transform(p))!;
    final tail = Offset.lerp(a, b, Curves.easeIn.transform((p - 0.25).clamp(0.0, 1.0)))!;
    if ((head - tail).distance < 1) return;

    final fade = math.sin(p * math.pi);
    final paint = Paint()
      ..shader = ui.Gradient.linear(tail, head, [
        Colors.white.withValues(alpha: 0),
        Colors.white.withValues(alpha: 0.9 * fade),
      ])
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(tail, head, paint);
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) => oldDelegate.stars != stars;
}
