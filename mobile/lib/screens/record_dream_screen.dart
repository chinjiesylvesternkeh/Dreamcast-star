import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../app_state.dart';
import '../models/dream.dart';
import '../theme.dart';
import '../widgets/mystic.dart';
import 'result_screen.dart';
import 'paywall_screen.dart';

class RecordDreamScreen extends StatefulWidget {
  const RecordDreamScreen({super.key});

  @override
  State<RecordDreamScreen> createState() => _RecordDreamScreenState();
}

class _RecordDreamScreenState extends State<RecordDreamScreen> {
  final _controller = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isSubmitting = false;

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    final available = await _speech.initialize();
    if (!available) return;

    setState(() => _isListening = true);
    _speech.listen(
      onResult: (result) {
        setState(() => _controller.text = result.recognizedWords);
      },
    );
  }

  Future<void> _submit() async {
    if (_controller.text.trim().length < 3) return;

    setState(() => _isSubmitting = true);
    final appState = context.read<AppState>();

    try {
      final Dream dream = await appState.api.submitDream(_controller.text.trim());
      if (!mounted) return;
      _controller.clear();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultScreen(dream: dream)));
    } on Exception catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('429')) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("The meaning stayed hidden this time. Please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Reveal(child: Eyebrow('BEFORE IT FADES')),
                  const SizedBox(height: 14),
                  Reveal(
                    delayMs: 100,
                    child: Text('What did the night\nshow you?', style: AppTheme.display(size: 38)),
                  ),
                  const SizedBox(height: 10),
                  const Reveal(
                    delayMs: 200,
                    child: Text(
                      'Dreams slip away within minutes of waking. Write or speak it now, while it still lingers.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Reveal(
                      delayMs: 300,
                      child: GlassPanel(
                        padding: EdgeInsets.zero,
                        child: TextField(
                          controller: _controller,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          textCapitalization: TextCapitalization.sentences,
                          style: AppTheme.display(size: 21, weight: FontWeight.w400, height: 1.5),
                          decoration: InputDecoration(
                            hintText: 'I was flying over a city made of glass...',
                            hintStyle: AppTheme.display(
                              size: 21,
                              weight: FontWeight.w400,
                              style: FontStyle.italic,
                              color: AppTheme.textSecondary.withValues(alpha: 0.6),
                              height: 1.5,
                            ),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.all(22),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Reveal(
                    delayMs: 400,
                    child: Row(
                      children: [
                        _MicOrb(listening: _isListening, onTap: _toggleListening),
                        const SizedBox(width: 14),
                        Expanded(
                          child: GlowButton(
                            label: 'Reveal its meaning',
                            busyLabel: 'Reading the signs…',
                            busy: _isSubmitting,
                            onPressed: _submit,
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
    );
  }
}

/// Microphone button that sends out soft ripples while it is listening.
class _MicOrb extends StatefulWidget {
  final bool listening;
  final VoidCallback onTap;

  const _MicOrb({required this.listening, required this.onTap});

  @override
  State<_MicOrb> createState() => _MicOrbState();
}

class _MicOrbState extends State<_MicOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _ripple =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didUpdateWidget(_MicOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listening && !_ripple.isAnimating) {
      _ripple.repeat();
    } else if (!widget.listening && _ripple.isAnimating) {
      _ripple.stop();
      _ripple.value = 0;
    }
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    return Semantics(
      button: true,
      label: widget.listening ? 'Stop listening' : 'Speak your dream',
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox.square(
          dimension: size,
          child: AnimatedBuilder(
            animation: _ripple,
            builder: (context, child) => Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (widget.listening)
                  for (final offset in const [0.0, 0.5])
                    Builder(builder: (context) {
                      final v = (_ripple.value + offset) % 1;
                      return Transform.scale(
                        scale: 1 + v * 0.8,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.accent.withValues(alpha: (1 - v) * 0.6)),
                          ),
                        ),
                      );
                    }),
                child!,
              ],
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.listening
                    ? AppTheme.accent.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.55), width: 0.8),
              ),
              child: Icon(
                widget.listening ? Icons.stop_rounded : Icons.mic_none_rounded,
                color: AppTheme.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
