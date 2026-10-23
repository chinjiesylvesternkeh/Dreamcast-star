import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../config.dart';
import '../l10n/app_localizations.dart';
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
    final l = AppLocalizations.of(context);
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
    } on DioException catch (e) {
      setState(() => _error = switch (e.response?.statusCode) {
            null => l.errorOffline,
            400 when _isSignup => l.authErrorEmailTaken,
            401 => l.authErrorInvalidCredentials,
            422 => l.authErrorInvalidInput,
            _ => l.authErrorGeneric,
          });
    } catch (_) {
      setState(() => _error = l.authErrorGeneric);
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
    final l = AppLocalizations.of(context);
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
                      l.appTitle,
                      textAlign: TextAlign.center,
                      style: AppTheme.display(size: 48, weight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Reveal(
                    delayMs: 250,
                    child: Eyebrow(_isSignup ? l.authEyebrowSignup : l.authEyebrowLogin, center: true),
                  ),
                  const SizedBox(height: 18),
                  Reveal(
                    delayMs: 350,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        _isSignup ? l.authTaglineSignup : l.authTaglineLogin,
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
                                    decoration: InputDecoration(
                                      hintText: l.authNameHint,
                                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                                    ),
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: l.authEmailHint,
                            prefixIcon: const Icon(Icons.mail_outline, size: 20),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          onSubmitted: (_) => _isSubmitting ? null : _submit(),
                          decoration: InputDecoration(
                            hintText: l.authPasswordHint,
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
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
                      label: _isSignup ? l.authSignupButton : l.authLoginButton,
                      busyLabel: l.authBusy,
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
                        _isSignup ? l.authSwitchToLogin : l.authSwitchToSignup,
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
    final l = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final plain = TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.8));
    void open(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(l.legalAgreePrefix, style: plain),
        GestureDetector(
          onTap: () => open(AppConfig.terms(language)),
          child: Text(l.termsOfService, style: linkStyle),
        ),
        Text(l.legalAgreeMiddle, style: plain),
        GestureDetector(
          onTap: () => open(AppConfig.privacyPolicy(language)),
          child: Text(l.privacyPolicy, style: linkStyle),
        ),
        Text(l.legalAgreeSuffix, style: plain),
      ],
    );
  }
}
