import re

path = 'g:/cockatiel/mobile/vocal_coach_app/lib/features/authentication/presentation/authentication_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Add glass_card import
code = code.replace(
    "import '../../../shared/animations/page_transitions.dart';",
    "import '../../../shared/animations/page_transitions.dart';\nimport '../../../shared/widgets/glass_card.dart';"
)

# 2. Update the Scaffold Stack to include the image
scaffold_old = """    return Scaffold(
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
          ),"""

scaffold_new = """    return Scaffold(
      backgroundColor: const Color(0xFF09090F),
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Image.asset(
              'assets/images/auth_3d_elements.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF09090F).withOpacity(0.3),
                    const Color(0xFF09090F).withOpacity(0.8),
                    const Color(0xFF09090F),
                  ],
                  stops: const [0.0, 0.35, 0.5],
                ),
              ),
            ),
          ),"""
code = code.replace(scaffold_old, scaffold_new)

# 3. Update SignIn padding and wrap Form in GlassCard
signin_old = """  Widget _buildSignInPage(ThemeData theme) {
    return SingleChildScrollView(
      key: const ValueKey('signIn'),
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Form("""

signin_new = """  Widget _buildSignInPage(ThemeData theme) {
    return SingleChildScrollView(
      key: const ValueKey('signIn'),
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).size.height * 0.25, 24, 24),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Form("""
code = code.replace(signin_old, signin_new)

# 4. Close the GlassCard for SignIn
signin_end_old = """            // Switch to register
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
  }"""

signin_end_new = """            // Switch to register
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
                      color: const Color(0xFF00FF7F),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }"""
code = code.replace(signin_end_old, signin_end_new)


# 5. Update SignUp padding and wrap Form in GlassCard
signup_old = """  Widget _buildSignUpPage(ThemeData theme) {
    return SingleChildScrollView(
      key: const ValueKey('signUp'),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Form("""

signup_new = """  Widget _buildSignUpPage(ThemeData theme) {
    return SingleChildScrollView(
      key: const ValueKey('signUp'),
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).size.height * 0.15, 24, 24),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Form("""
code = code.replace(signup_old, signup_new)

# 6. Close the GlassCard for SignUp
signup_end_old = """            Row(
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
  }"""

signup_end_new = """            Row(
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
                      color: const Color(0xFF00FF7F),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }"""
code = code.replace(signup_end_old, signup_end_new)

# 7. Update ForgotPassword padding and wrap Form in GlassCard
forgot_old = """  Widget _buildForgotPasswordPage(ThemeData theme) {
    return SingleChildScrollView(
      key: const ValueKey('forgotPassword'),
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Form("""

forgot_new = """  Widget _buildForgotPasswordPage(ThemeData theme) {
    return SingleChildScrollView(
      key: const ValueKey('forgotPassword'),
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).size.height * 0.25, 24, 24),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Form("""
code = code.replace(forgot_old, forgot_new)

# 8. Close the GlassCard for ForgotPassword
forgot_end_old = """            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Remember your password? ',
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
  }"""

forgot_end_new = """            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Remember your password? ',
                  style: theme.textTheme.bodyMedium,
                ),
                GestureDetector(
                  onTap: widget.appState.isAuthenticating
                      ? null
                      : () => _setView(_AuthView.signIn),
                  child: Text(
                    'Sign In',
                    style: TextStyle(
                      color: const Color(0xFF00FF7F),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }"""
code = code.replace(forgot_end_old, forgot_end_new)


# 9. Update _PrimaryActionButton style to be Vibrant Green
btn_old = """      child: FilledButton(
        onPressed: onPressed,
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : showSuccess
                ? const Icon(Icons.check_circle_outline_rounded)
                : Text(label),
      ),"""

btn_new = """      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF00FF7F),
          foregroundColor: const Color(0xFF09090F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF09090F)),
              )
            : showSuccess
                ? const Icon(Icons.check_circle_outline_rounded)
                : Text(
                    label + ' ➔',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
      ),"""
code = code.replace(btn_old, btn_new)


with open(path, 'w', encoding='utf-8') as f:
    f.write(code)

print("SUCCESS")
