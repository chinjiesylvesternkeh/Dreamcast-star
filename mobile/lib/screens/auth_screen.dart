import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../config.dart';
import '../theme.dart';
import '../widgets/mystic.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSignup = true;
  bool _isSubmitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final appState = context.read<AppState>();
    try {
      if (_isSignup) {
        await appState.api.signup(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        );
      } else {
        await appState.api.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
      appState.onAuthenticated();
    } catch (e) {
      setState(() => _error = 'Something went wrong. Check your details and try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Reveal(child: Center(child: MoonGlyph(size: 112))),
                  const SizedBox(height: 12),
                  Reveal(
                    delayMs: 150,
                    child: Text(
                      'DreamCast',
                      textAlign: TextAlign.center,
                      style: AppTheme.display(size: 48, weight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Reveal(
                    delayMs: 250,
                    child: Eyebrow(_isSignup ? 'THE NIGHT REMEMBERS' : 'WELCOME BACK, DREAMER', center: true),
                  ),
                  const SizedBox(height: 18),
                  Reveal(
                    delayMs: 350,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        _isSignup
                            ? 'Every dream carries a message.\nLearn to hear yours.'
                            : 'Your dreams have been waiting for you.',
                        key: ValueKey(_isSignup),
                        textAlign: TextAlign.center,
                        style: AppTheme.display(
                          size: 20,
                          color: AppTheme.textSecondary,
                          style: FontStyle.italic,
                          weight: FontWeight.w400,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Reveal(
                    delayMs: 450,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          child: _isSignup
                              ? Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: TextField(
                                    controller: _nameController,
                                    textCapitalization: TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      hintText: 'Name (optional)',
                                      prefixIcon: Icon(Icons.person_outline, size: 20),
                                    ),
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline, size: 20),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          onSubmitted: (_) => _isSubmitting ? null : _submit(),
                          decoration: const InputDecoration(
                            hintText: 'Password (min. 8 characters)',
                            prefixIcon: Icon(Icons.lock_outline, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFFF8FA3)),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Reveal(
                    delayMs: 550,
                    child: GlowButton(
                      label: _isSignup ? 'Begin the journey' : 'Return to the dream',
                      busyLabel: 'Opening the door…',
                      busy: _isSubmitting,
                      onPressed: _submit,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Reveal(
                    delayMs: 650,
                    child: TextButton(
                      onPressed: () => setState(() {
                        _isSignup = !_isSignup;
                        _error = null;
                      }),
                      child: Text(
                        _isSignup ? 'Already have an account? Log in' : 'New here? Create an account',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Reveal(delayMs: 700, child: _LegalNotice()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalNotice extends StatelessWidget {
  const _LegalNotice();

  @override
  Widget build(BuildContext context) {
    const linkStyle = TextStyle(
      fontSize: 12,
      color: AppTheme.textSecondary,
      decoration: TextDecoration.underline,
    );
    void open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'By continuing you agree to our ',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.8)),
        ),
        GestureDetector(
          onTap: () => open(AppConfig.termsUrl),
          child: const Text('Terms of Service', style: linkStyle),
        ),
        Text(' and ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.8))),
        GestureDetector(
          onTap: () => open(AppConfig.privacyPolicyUrl),
          child: const Text('Privacy Policy', style: linkStyle),
        ),
        Text('.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.8))),
      ],
    );
  }
}
