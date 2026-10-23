import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

/// A glowing crescent moon with a slow breathing halo — the app's emblem.
class MoonGlyph extends StatefulWidget {
  final double size;

  const MoonGlyph({super.key, this.size = 80});

  @override
  State<MoonGlyph> createState() => _MoonGlyphState();
}

class _MoonGlyphState extends State<MoonGlyph> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(painter: _MoonPainter(_controller)),
    );
  }
}

class _MoonPainter extends CustomPainter {
  final Animation<double> animation;

  _MoonPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide * 0.3;
    final breathe = Curves.easeInOut.transform(animation.value);

    final haloRect = Rect.fromCircle(center: center, radius: r * 1.65);
    canvas.drawCircle(
      center,
      r * 1.65,
      Paint()
        ..shader = RadialGradient(colors: [
          AppTheme.accent.withValues(alpha: 0.22 + 0.14 * breathe),
          AppTheme.accent.withValues(alpha: 0),
        ]).createShader(haloRect),
    );

    final disc = Path()..addOval(Rect.fromCircle(center: center, radius: r));
    final bite = Path()
      ..addOval(Rect.fromCircle(center: center + Offset(r * 0.42, -r * 0.22), radius: r * 0.86));
    canvas.drawPath(
      Path.combine(PathOperation.difference, disc, bite),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF1D0), AppTheme.accent, Color(0xFFB98B4E)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );

    // A small four-point star resting in the moon's curve.
    final sparkle = center + Offset(r * 0.55, -r * 0.35);
    final arm = r * (0.16 + 0.06 * breathe);
    final sparklePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55 + 0.45 * breathe)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(sparkle - Offset(arm, 0), sparkle + Offset(arm, 0), sparklePaint);
    canvas.drawLine(sparkle - Offset(0, arm), sparkle + Offset(0, arm), sparklePaint);
  }

  @override
  bool shouldRepaint(_MoonPainter oldDelegate) => false;
}

/// Frosted, faintly gold-edged panel that lets the night sky glow through.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final bool blur;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 22,
    this.onTap,
    this.blur = true,
  });

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: shape,
          splashColor: AppTheme.accent.withValues(alpha: 0.08),
          highlightColor: AppTheme.primary.withValues(alpha: 0.05),
          child: content,
        ),
      );
    }

    final panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        border: Border.all(color: AppTheme.hairline, width: 0.8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.075), Colors.white.withValues(alpha: 0.02)],
        ),
      ),
      child: content,
    );

    return ClipRRect(
      borderRadius: shape,
      child: blur ? BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: panel) : panel,
    );
  }
}

/// Moonlit-gold call to action with a slow shimmer passing across it.
class GlowButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final String? busyLabel;
  final IconData? icon;

  const GlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.busyLabel,
    this.icon,
  });

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..repeat();
  bool _pressed = false;

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final radius = BorderRadius.circular(18);

    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedOpacity(
            opacity: enabled || widget.busy ? 1 : 0.55,
            duration: const Duration(milliseconds: 200),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF6E3B4), AppTheme.accent, Color(0xFFC9A062)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: enabled ? 0.35 : 0.12),
                    blurRadius: 28,
                    spreadRadius: -4,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (enabled)
                      AnimatedBuilder(
                        animation: _shimmer,
                        builder: (context, _) {
                          // Sweep during the first part of the cycle, then rest.
                          final p = _shimmer.value / 0.45;
                          if (p > 1) return const SizedBox.shrink();
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: const Alignment(-1, -0.3),
                                end: const Alignment(1, 0.3),
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.55),
                                  Colors.white.withValues(alpha: 0),
                                ],
                                stops: const [0.4, 0.5, 0.6],
                                transform: _SlideGradient(p * 2.4 - 1.2),
                              ),
                            ),
                          );
                        },
                      ),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.busy)
                            const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.ink),
                            )
                          else if (widget.icon != null)
                            Icon(widget.icon, color: AppTheme.ink, size: 20),
                          if (widget.busy || widget.icon != null) const SizedBox(width: 10),
                          Text(
                            widget.busy ? (widget.busyLabel ?? widget.label) : widget.label,
                            style: GoogleFonts.manrope(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: AppTheme.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double fraction;

  const _SlideGradient(this.fraction);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * fraction, 0, 0);
}

/// Fades its child in while it drifts up into place, after an optional delay.
class Reveal extends StatefulWidget {
  final Widget child;
  final int delayMs;

  const Reveal({super.key, required this.child, this.delayMs = 0});

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(offset: Offset(0, (1 - _curve.value) * 18), child: child),
      ),
    );
  }
}

/// Small gold, widely tracked label with a sparkle — used above headings.
class Eyebrow extends StatelessWidget {
  final String text;
  final bool center;

  const Eyebrow(this.text, {super.key, this.center = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: center ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        const Icon(Icons.auto_awesome, size: 12, color: AppTheme.accent),
        const SizedBox(width: 8),
        Flexible(child: Text(text, style: AppTheme.eyebrow())),
      ],
    );
  }
}
