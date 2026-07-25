import 'package:flutter/material.dart';

import '../../../app/shell/main_shell_page.dart';
import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/animations/page_transitions.dart';

enum _AuthView { signIn, signUp, forgotPassword }

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

  _AuthView _view = _AuthView.signIn;
  bool _showSuccess = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

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
    if (!(_signInFormKey.currentState?.validate() ?? false)) return;
    await widget.appState.signInWithEmailPassword(
      apiClient: widget.apiClient,
      email: _signInEmailController.text,
      password: _signInPasswordController.text,
    );
    if (!mounted) return;
    if (widget.appState.isAuthenticated) {
      setState(() => _showSuccess = true);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        scaleWelcomeRoute(
          builder: (_) => MainShellPage(
            appState: widget.appState,
            apiClient: widget.apiClient,
          ),
        ),
      );
    }
  }

  Future<void> _submitSignUp() async {
    if (!(_signUpFormKey.currentState?.validate() ?? false)) return;
    await widget.appState.signUpWithEmailPassword(
      apiClient: widget.apiClient,
      email: _signUpEmailController.text,
      password: _signUpPasswordController.text,
      displayName: _signUpNameController.text,
    );
    if (!mounted) return;
    if (widget.appState.isAuthenticated) {
      setState(() => _showSuccess = true);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        scaleWelcomeRoute(
          builder: (_) => MainShellPage(
            appState: widget.appState,
            apiClient: widget.apiClient,
          ),
        ),
      );
    }
  }

  Future<void> _submitPasswordReset() async {
    if (!(_resetFormKey.currentState?.validate() ?? false)) return;
    await widget.appState.sendPasswordResetEmail(_resetEmailController.text);
  }

  void _setView(_AuthView view) {
    if (_view == view) return;
    FocusScope.of(context).unfocus();
    widget.appState.clearAuthMessages();
    setState(() => _view = view);
  }

  String? _validateEmail(String? value) {
    final input = (value ?? '').trim();
    if (input.isEmpty) return 'Email is required.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(input)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final input = value ?? '';
    if (input.isEmpty) return 'Password is required.';
    if (input.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF09090F),
      body: Stack(
        children: [
          // Dark gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF09090F),
                    Color(0xFF0D0D1A),
                    Color(0xFF0A0A14),
                  ],
                ),
              ),
            ),
          ),
          // Decorative glow orbs
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.tertiary.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: AnimatedBuilder(
              animation: widget.appState,
              builder: (_, __) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  child: switch (_view) {
                    _AuthView.signIn => _buildSignInPage(theme),
                    _AuthView.signUp => _buildSignUpPage(theme),
                    _AuthView.forgotPassword => _buildForgotPasswordPage(theme),
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── SIGN IN ───────────────────────────────────────────────────────────

  Widget _buildSignInPage(ThemeData theme) {
    return SingleChildScrollView(
      key: const ValueKey('signIn'),
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Form(
        key: _signInFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo
            _buildLogo(theme),
            const SizedBox(height: 40),
            // Heading
            Text(
              'Sign in to your\nAccount',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your email and password to sign in.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            // Email field
            TextFormField(
              controller: _signInEmailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'yourname@email.com',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),
            // Password field
            TextFormField(
              controller: _signInPasswordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: _validatePassword,
              onFieldSubmitted: (_) => _submitSignIn(),
            ),
            const SizedBox(height: 12),
            // Forgot password
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
                child: const Text('Forgot Password?'),
              ),
            ),
            const SizedBox(height: 16),
            // Sign in button
            _PrimaryActionButton(
              onPressed:
                  widget.appState.isAuthenticating ? null : _submitSignIn,
              isLoading: widget.appState.isAuthenticating,
              showSuccess: _showSuccess,
              label: 'Sign In',
            ),
            // Error message
            _buildErrorNotice(theme),
            const SizedBox(height: 32),
            // Switch to register
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: theme.textTheme.bodyMedium,
                ),
                GestureDetector(
                  onTap: widget.appState.isAuthenticating
                      ? null
                      : () => _setView(_AuthView.signUp),
                  child: Text(
                    'Sign Up',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── SIGN UP ───────────────────────────────────────────────────────────

  Widget _buildSignUpPage(ThemeData theme) {
    return SingleChildScrollView(
      key: const ValueKey('signUp'),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Form(
        key: _signUpFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Back button
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => _setView(_AuthView.signIn),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Create your\nAccount',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Build your personalized vocal coaching profile.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _signUpNameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Name is required.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _signUpEmailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'yourname@email.com',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _signUpPasswordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: _validatePassword,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _signUpConfirmController,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
              validator: (v) {
                if ((v ?? '').isEmpty) return 'Confirm your password.';
                if (v != _signUpPasswordController.text) {
                  return 'Passwords do not match.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submitSignUp(),
            ),
            const SizedBox(height: 28),
            _PrimaryActionButton(
              onPressed:
                  widget.appState.isAuthenticating ? null : _submitSignUp,
              isLoading: widget.appState.isAuthenticating,
              showSuccess: _showSuccess,
              label: 'Create Account',
            ),
            _buildErrorNotice(theme),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: theme.textTheme.bodyMedium,
                ),
                GestureDetector(
                  onTap: widget.appState.isAuthenticating
                      ? null
                      : () => _setView(_AuthView.signIn),
                  child: Text(
                    'Sign In',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── FORGOT PASSWORD ───────────────────────────────────────────────────

  Widget _buildForgotPasswordPage(ThemeData theme) {
    return SingleChildScrollView(
      key: const ValueKey('forgot'),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Form(
        key: _resetFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => _setView(_AuthView.signIn),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primaryContainer,
                ),
                child: Icon(
                  Icons.lock_reset_rounded,
                  size: 36,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Forgot Password?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Enter your email address and we'll send you a link to reset your password.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _resetEmailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: _validateEmail,
              onFieldSubmitted: (_) => _submitPasswordReset(),
            ),
            const SizedBox(height: 24),
            _PrimaryActionButton(
              onPressed: widget.appState.isSendingPasswordReset
                  ? null
                  : _submitPasswordReset,
              isLoading: widget.appState.isSendingPasswordReset,
              showSuccess: false,
              label: 'Continue',
            ),
            _buildErrorNotice(theme),
            if (widget.appState.authNotice != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.appState.authNotice!,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── SHARED COMPONENTS ─────────────────────────────────────────────────

  Widget _buildLogo(ThemeData theme) {
    return Center(
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.music_note_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildErrorNotice(ThemeData theme) {
    if (widget.appState.authError == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: theme.colorScheme.error,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.appState.authError!,
                style: TextStyle(
                  color: theme.colorScheme.onErrorContainer,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── REUSABLE WIDGETS ──────────────────────────────────────────────────────

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.onPressed,
    required this.isLoading,
    required this.showSuccess,
    required this.label,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final bool showSuccess;
  final String label;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (showSuccess) {
      child = const Icon(Icons.check_rounded, color: Colors.white, size: 22);
    } else if (isLoading) {
      child = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    } else {
      child = Text(label);
    }

    return FilledButton(onPressed: onPressed, child: child);
  }
}
