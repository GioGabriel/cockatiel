import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';

enum _AuthView { welcome, signIn, signUp, forgotPassword }

class AuthenticationPage extends StatefulWidget {
  const AuthenticationPage({
    super.key,
    required this.appState,
    required this.apiClient,
  });

  final AppState appState;
  final ApiClient apiClient;

  @override
  State<AuthenticationPage> createState() => _AuthenticationPageState();
}

class _AuthenticationPageState extends State<AuthenticationPage> {
  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();
  final _signUpNameController = TextEditingController();
  final _signUpEmailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  final _signUpConfirmController = TextEditingController();
  final _resetEmailController = TextEditingController();

  _AuthView _view = _AuthView.welcome;

  @override
  void dispose() {
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _signUpNameController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    _signUpConfirmController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  Future<void> _submitSignIn() async {
    if (!(_signInFormKey.currentState?.validate() ?? false)) {
      return;
    }
    await widget.appState.signInWithEmailPassword(
      apiClient: widget.apiClient,
      email: _signInEmailController.text,
      password: _signInPasswordController.text,
    );
  }

  Future<void> _submitSignUp() async {
    if (!(_signUpFormKey.currentState?.validate() ?? false)) {
      return;
    }
    await widget.appState.signUpWithEmailPassword(
      apiClient: widget.apiClient,
      email: _signUpEmailController.text,
      password: _signUpPasswordController.text,
      displayName: _signUpNameController.text,
    );
  }

  Future<void> _submitPasswordReset() async {
    if (!(_resetFormKey.currentState?.validate() ?? false)) {
      return;
    }
    await widget.appState.sendPasswordResetEmail(_resetEmailController.text);
  }

  void _setView(_AuthView view) {
    if (_view == view) {
      return;
    }
    FocusScope.of(context).unfocus();
    widget.appState.clearAuthMessages();
    setState(() {
      _view = view;
    });
  }

  String? _validateEmail(String? value) {
    final input = (value ?? '').trim();
    if (input.isEmpty) {
      return 'Email is required.';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(input)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final input = value ?? '';
    if (input.isEmpty) {
      return 'Password is required.';
    }
    if (input.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE2F3F7), Color(0xFFF6F9FC)],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: widget.appState,
            builder: (_, __) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BrandHeader(
                            onBack: _view == _AuthView.welcome
                                ? null
                                : () => _setView(_AuthView.welcome)),
                        const SizedBox(height: 20),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 240),
                              child: _buildView(theme),
                            ),
                          ),
                        ),
                        if (widget.appState.authError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            widget.appState.authError!,
                            style: TextStyle(color: theme.colorScheme.error),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (widget.appState.authNotice != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            widget.appState.authNotice!,
                            style: TextStyle(color: theme.colorScheme.primary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildView(ThemeData theme) {
    switch (_view) {
      case _AuthView.welcome:
        return _WelcomePanel(
          onSignIn: () => _setView(_AuthView.signIn),
          onSignUp: () => _setView(_AuthView.signUp),
        );
      case _AuthView.signIn:
        return Form(
          key: _signInFormKey,
          child: Column(
            key: const ValueKey('signInForm'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Welcome back', style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('Sign in to continue your training journey.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _signInEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _signInPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: _validatePassword,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.appState.isAuthenticating
                      ? null
                      : () {
                          _resetEmailController.text =
                              _signInEmailController.text;
                          _setView(_AuthView.forgotPassword);
                        },
                  child: const Text('Forgot password?'),
                ),
              ),
              FilledButton(
                onPressed:
                    widget.appState.isAuthenticating ? null : _submitSignIn,
                child: Text(widget.appState.isAuthenticating
                    ? 'Signing in...'
                    : 'Sign In'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: widget.appState.isAuthenticating
                    ? null
                    : () => _setView(_AuthView.signUp),
                child: const Text('New here? Create account'),
              ),
            ],
          ),
        );
      case _AuthView.signUp:
        return Form(
          key: _signUpFormKey,
          child: Column(
            key: const ValueKey('signUpForm'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Create account', style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('Build your personalized vocal coaching profile.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _signUpNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Display name is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _signUpEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _signUpPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: _validatePassword,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _signUpConfirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (value) {
                  final confirm = value ?? '';
                  if (confirm.isEmpty) {
                    return 'Please confirm your password.';
                  }
                  if (confirm != _signUpPasswordController.text) {
                    return 'Passwords do not match.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed:
                    widget.appState.isAuthenticating ? null : _submitSignUp,
                child: Text(widget.appState.isAuthenticating
                    ? 'Creating account...'
                    : 'Create Account'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: widget.appState.isAuthenticating
                    ? null
                    : () => _setView(_AuthView.signIn),
                child: const Text('Already have an account? Sign in'),
              ),
            ],
          ),
        );
      case _AuthView.forgotPassword:
        return Form(
          key: _resetFormKey,
          child: Column(
            key: const ValueKey('forgotPasswordForm'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Reset password', style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('We will send a reset link to your email address.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: widget.appState.isSendingPasswordReset
                    ? null
                    : _submitPasswordReset,
                child: Text(widget.appState.isSendingPasswordReset
                    ? 'Sending link...'
                    : 'Send Reset Link'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: widget.appState.isSendingPasswordReset
                    ? null
                    : () => _setView(_AuthView.signIn),
                child: const Text('Back to sign in'),
              ),
            ],
          ),
        );
    }
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (onBack != null)
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          )
        else
          const SizedBox(width: 48),
        const Expanded(
          child: Column(
            children: [
              Text(
                'Vocal Coach',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4),
              Text(
                'Train with confidence, powered by AI feedback.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({
    required this.onSignIn,
    required this.onSignUp,
  });

  final VoidCallback onSignIn;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('welcomePanel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ready to level up your voice?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Get instant coaching, track progress, and practice with guided sessions tailored to your growth.',
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: onSignIn,
          child: const Text('Sign In'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: onSignUp,
          child: const Text('Create Account'),
        ),
      ],
    );
  }
}
