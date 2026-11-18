import 'package:flutter/material.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/widgets/entry_identity.dart';

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
    setState(() {
      _view = view;
      _showSuccess = false;
    });
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AnimatedBuilder(
        animation: widget.appState,
        builder: (_, __) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: switch (_view) {
              _AuthView.signIn => _buildSignInLayout(),
              _AuthView.signUp => _buildSignUpLayout(),
              _AuthView.forgotPassword => _buildForgotPasswordLayout(),
            },
          );
        },
      ),
    );
  }

  // ─── SIGN IN ──────────────────────────────────────────────────────────

  Widget _buildSignInLayout() {
    final theme = Theme.of(context);
    return _FullScreenAuthLayout(
      key: const ValueKey('signIn'),
      topContent: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good to hear you.',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 34,
              letterSpacing: -1.1,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in and pick up where your voice left off.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      bottomContent: Form(
        key: _signInFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildField(
              controller: _signInEmailController,
              label: 'Email address',
              hint: 'you@example.com',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _signInPasswordController,
              label: 'Password',
              obscure: _obscurePassword,
              onToggle: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              validator: _validatePassword,
              onSubmit: (_) => _submitSignIn(),
            ),
            const SizedBox(height: 8),
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
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  padding: EdgeInsets.zero,
                ),
                child: const Text('Forgot Password?',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 24),
            _buildPrimaryButton(
              label: 'Sign In',
              isLoading: widget.appState.isAuthenticating,
              onPressed: _submitSignIn,
            ),
            _buildErrorNotice(),
            const SizedBox(height: 20),
            _buildSwitchRow(
              prefix: "Don't have an account? ",
              linkText: 'Sign Up',
              onTap: () => _setView(_AuthView.signUp),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SIGN UP ──────────────────────────────────────────────────────────

  Widget _buildSignUpLayout() {
    final theme = Theme.of(context);
    return _FullScreenAuthLayout(
      key: const ValueKey('signUp'),
      showBack: true,
      onBack: () => _setView(_AuthView.signIn),
      topContent: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Make room for your voice.',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 34,
              letterSpacing: -1.1,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A little practice. A little more confidence.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      bottomContent: Form(
        key: _signUpFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildField(
              controller: _signUpNameController,
              label: 'Display name',
              hint: 'What should we call you?',
              icon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Name is required.' : null,
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _signUpEmailController,
              label: 'Email address',
              hint: 'you@example.com',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _signUpPasswordController,
              label: 'Password',
              obscure: _obscurePassword,
              onToggle: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              validator: _validatePassword,
            ),
            const SizedBox(height: 8),
            Text(
              'Use at least 6 characters. A longer mix of words, numbers, and symbols is stronger.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _signUpConfirmController,
              label: 'Confirm Password',
              obscure: _obscureConfirmPassword,
              onToggle: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
              validator: (v) {
                if ((v ?? '').isEmpty) return 'Confirm your password.';
                if (v != _signUpPasswordController.text) {
                  return 'Passwords do not match.';
                }
                return null;
              },
              onSubmit: (_) => _submitSignUp(),
            ),
            const SizedBox(height: 28),
            _buildPrimaryButton(
              label: 'Create Account',
              isLoading: widget.appState.isAuthenticating,
              onPressed: _submitSignUp,
            ),
            _buildErrorNotice(),
            const SizedBox(height: 20),
            _buildSwitchRow(
              prefix: 'Already have an account? ',
              linkText: 'Sign In',
              onTap: () => _setView(_AuthView.signIn),
            ),
          ],
        ),
      ),
    );
  }

  // ─── FORGOT PASSWORD ──────────────────────────────────────────────────

  Widget _buildForgotPasswordLayout() {
    final theme = Theme.of(context);
    return _FullScreenAuthLayout(
      key: const ValueKey('forgotPassword'),
      showBack: true,
      onBack: () => _setView(_AuthView.signIn),
      topContent: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Let’s get you back in.',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 34,
              letterSpacing: -1.1,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "We'll send a reset link to your inbox.",
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      bottomContent: Form(
        key: _resetFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildField(
              controller: _resetEmailController,
              label: 'Email address',
              hint: 'you@example.com',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              validator: _validateEmail,
              onSubmit: (_) => _submitPasswordReset(),
            ),
            const SizedBox(height: 28),
            _buildPrimaryButton(
              label: 'Send Reset Link',
              isLoading: widget.appState.isSendingPasswordReset,
              onPressed: _submitPasswordReset,
            ),
            if (widget.appState.authNotice != null) _buildResetConfirmation(),
            _buildErrorNotice(includeNotice: false),
            const SizedBox(height: 20),
            _buildSwitchRow(
              prefix: 'Remember your password? ',
              linkText: 'Sign In',
              onTap: () => _setView(_AuthView.signIn),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SHARED WIDGETS ───────────────────────────────────────────────────

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    void Function(String)? onSubmit,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      validator: validator,
      onFieldSubmitted: onSubmit,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.colorScheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: theme.colorScheme.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.colorScheme.error)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.colorScheme.error, width: 1.5)),
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        prefixIconColor: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
    void Function(String)? onSubmit,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      onFieldSubmitted: onSubmit,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.colorScheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: theme.colorScheme.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.colorScheme.error)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.colorScheme.error, width: 1.5)),
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
        suffixIcon: IconButton(
          tooltip: obscure ? 'Show password' : 'Hide password',
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        prefixIconColor: theme.colorScheme.onSurfaceVariant,
        suffixIconColor: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          textStyle: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: theme.colorScheme.onPrimary,
                ),
              )
            : Text(label),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String prefix,
    required String linkText,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prefix,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          onPressed: onTap,
          child: Text(linkText, style: theme.textTheme.labelLarge),
        ),
      ],
    );
  }

  Widget _buildErrorNotice({bool includeNotice = true}) {
    final theme = Theme.of(context);
    final tokens = theme.appTokens;
    final error = widget.appState.authError;
    final notice = includeNotice ? widget.appState.authNotice : null;
    if (error == null && notice == null && !_showSuccess) {
      return const SizedBox.shrink();
    }
    final isSuccess = _showSuccess || notice != null;
    final message = _showSuccess
        ? 'Success! Your account is ready.'
        : notice ?? error ?? 'Something went wrong. Please try again.';
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSuccess
              ? tokens.success.withValues(alpha: 0.12)
              : tokens.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSuccess
                ? tokens.success.withValues(alpha: 0.45)
                : tokens.danger.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              size: 16,
              color: isSuccess ? tokens.success : tokens.danger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  color: isSuccess ? tokens.success : tokens.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetConfirmation() {
    final theme = Theme.of(context);
    final tokens = theme.appTokens;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Semantics(
        liveRegion: true,
        label: 'Password reset email sent',
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tokens.success.withValues(alpha: 0.45)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.mark_email_read_outlined, color: tokens.success),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Check your inbox and spam folder for the reset link. When you are ready, return here to sign in.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    height: 1.4,
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

// ─── FULL SCREEN AUTH LAYOUT ──────────────────────────────────────────────────

class _FullScreenAuthLayout extends StatelessWidget {
  const _FullScreenAuthLayout({
    super.key,
    required this.topContent,
    required this.bottomContent,
    this.showBack = false,
    this.onBack,
  });

  final Widget topContent;
  final Widget bottomContent;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(child: LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 960;
      final form = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            if (showBack) ...[
              IconButton(
                  onPressed: onBack,
                  tooltip: 'Back to sign in',
                  icon: const Icon(Icons.arrow_back_rounded)),
              const SizedBox(width: 8),
            ],
            const Flexible(child: EntryWordmark()),
          ]),
          SizedBox(height: wide ? 64 : 28),
          if (!wide && !showBack) ...[
            const EntryArtwork(height: 148),
            const SizedBox(height: 28),
          ],
          topContent,
          const SizedBox(height: 28),
          bottomContent,
        ]),
      );
      return SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.all(wide ? 40 : 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - (wide ? 80 : 48))
                  .clamp(0, double.infinity)),
          child: Center(
              child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 1120 : 420),
            child: wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(
                        child: Container(
                            padding: const EdgeInsets.all(36),
                            decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(36),
                                border: Border.all(
                                    color: theme.colorScheme.outlineVariant)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('A SPACE FOR YOUR VOICE',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                              letterSpacing: 2,
                                              color:
                                                  theme.colorScheme.primary)),
                                  const SizedBox(height: 32),
                                  const EntryArtwork(height: 320),
                                  const SizedBox(height: 36),
                                  Text('Find your voice.\nMake it yours.',
                                      style: theme.textTheme.displaySmall
                                          ?.copyWith(
                                              fontSize: 44,
                                              height: 1.06,
                                              letterSpacing: -1.6,
                                              fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 18),
                                  Text(
                                      'Warm up. Find your rhythm. Sing something you love.',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                              color: theme
                                                  .colorScheme.onSurfaceVariant,
                                              height: 1.6)),
                                ]))),
                    const SizedBox(width: 80),
                    Flexible(child: form),
                  ])
                : form,
          )),
        ),
      );
    }));
  }
}
