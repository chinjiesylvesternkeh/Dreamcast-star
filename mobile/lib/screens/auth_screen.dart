import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text('DreamCast',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary)),
              const SizedBox(height: 8),
              Text(
                _isSignup
                    ? 'Every dream has something to say.\nCreate an account to start listening.'
                    : 'Welcome back — your dreams missed you.',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 36),
              if (_isSignup) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(hintText: 'Name (optional)'),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'Email'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Password (min. 8 characters)'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isSignup ? 'Create account' : 'Log in'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _isSignup = !_isSignup),
                  child: Text(
                    _isSignup ? 'Already have an account? Log in' : "New here? Create an account",
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
