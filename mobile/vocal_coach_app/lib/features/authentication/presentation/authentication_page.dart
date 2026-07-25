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
      backgroundColor: const Color(0xFF09090F),
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
    return _FullScreenAuthLayout(
      key: const ValueKey('signIn'),
      topContent: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome\nBack 👋',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to continue your vocal journey.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.6),
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
              onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
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
                        _resetEmailController.text = _signInEmailController.text;
                        _setView(_AuthView.forgotPassword);
                      },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF00FF7F),
                  padding: EdgeInsets.zero,
                ),
                child: const Text('Forgot Password?', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 24),
            _buildPrimaryButton(
              label: 'Sign In',
              isLoading: widget.appState.isAuthenticating,
              onPressed: _submitSignIn,
            ),
            _buildErrorNotice(),
            const SizedBox(height: 32),
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
    return _FullScreenAuthLayout(
      key: const ValueKey('signUp'),
      showBack: true,
      onBack: () => _setView(_AuthView.signIn),
      topContent: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create an\nAccount ✨',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start your vocal journey today.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.6),
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
              label: 'Full Name',
              hint: 'Your name',
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
              onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
              validator: _validatePassword,
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
            const SizedBox(height: 32),
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
    return _FullScreenAuthLayout(
      key: const ValueKey('forgotPassword'),
      showBack: true,
      onBack: () => _setView(_AuthView.signIn),
      topContent: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reset\nPassword 🔑',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "We'll send a reset link to your inbox.",
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.6),
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
              isLoading: widget.appState.isAuthenticating,
              onPressed: _submitPasswordReset,
            ),
            _buildErrorNotice(),
            const SizedBox(height: 32),
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
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      validator: validator,
      onFieldSubmitted: onSubmit,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A2A40), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A2A40), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF00FF7F), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF4D6D), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF4D6D), width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF888899)),
        hintStyle: const TextStyle(color: Color(0xFF444455)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        prefixIconColor: const Color(0xFF888899),
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
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      onFieldSubmitted: onSubmit,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A2A40), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A2A40), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF00FF7F), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF4D6D), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF4D6D), width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF888899)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        prefixIconColor: const Color(0xFF888899),
        suffixIconColor: const Color(0xFF888899),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF00FF7F),
          foregroundColor: const Color(0xFF09090F),
          disabledBackgroundColor: const Color(0xFF00FF7F).withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF09090F),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          prefix,
          style: const TextStyle(color: Color(0xFF888899), fontSize: 14),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            linkText,
            style: const TextStyle(
              color: Color(0xFF00FF7F),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorNotice() {
    if (widget.appState.authError == null && !_showSuccess) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _showSuccess
              ? const Color(0xFF00FF7F).withValues(alpha: 0.1)
              : const Color(0xFFFF4D6D).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _showSuccess
                ? const Color(0xFF00FF7F).withValues(alpha: 0.4)
                : const Color(0xFFFF4D6D).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _showSuccess ? Icons.check_circle_outline : Icons.error_outline,
              size: 16,
              color: _showSuccess ? const Color(0xFF00FF7F) : const Color(0xFFFF4D6D),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _showSuccess ? 'Success! Signing you in...' : widget.appState.authError!,
                style: TextStyle(
                  fontSize: 13,
                  color: _showSuccess ? const Color(0xFF00FF7F) : const Color(0xFFFF4D6D),
                ),
              ),
            ),
          ],
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
    return Stack(
      children: [
        // ① The 3D image covers the ENTIRE screen
        Positioned.fill(
          child: Image.asset(
            'assets/images/auth_3d_elements.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),

        // ② A gradient that goes from mostly-transparent at top
        //    to fully solid dark at the bottom 55% of the screen.
        //    This kills the black-void problem: the bottom is always
        //    the same #09090F as the scaffold, not "empty".
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.30, 0.50, 1.0],
                colors: [
                  const Color(0xFF09090F).withValues(alpha: 0.15),
                  const Color(0xFF09090F).withValues(alpha: 0.55),
                  const Color(0xFF09090F).withValues(alpha: 0.92),
                  const Color(0xFF09090F),
                ],
              ),
            ),
          ),
        ),

        // ③ Back button overlay
        if (showBack)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black45,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

        // ④ All content sits in a Column that fills the screen.
        //    topContent floats over the image in the upper portion.
        //    bottomContent (the form) sits below, still on the
        //    dark-gradient area — NO separate card, NO black gap.
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Heading occupies the top ~45%
              Expanded(
                flex: 45,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: topContent,
                  ),
                ),
              ),

              // Form fills the remaining space and scrolls if needed
              Expanded(
                flex: 55,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: bottomContent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
