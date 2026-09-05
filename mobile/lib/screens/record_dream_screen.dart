import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../app_state.dart';
import '../models/dream.dart';
import '../theme.dart';
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
          const SnackBar(content: Text("Couldn't interpret that dream — try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New dream')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'What did you dream last night?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'I was flying over a city made of glass...',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _toggleListening,
                    icon: Icon(_isListening ? Icons.stop : Icons.mic),
                    style: IconButton.styleFrom(
                      backgroundColor: _isListening ? AppTheme.accent : AppTheme.surface,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Interpret my dream'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
