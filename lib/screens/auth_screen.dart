import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/user_preferences.dart';
import '../utils/colors.dart';

enum _AuthIntent { signIn, signUp, google }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  late final StreamSubscription<AuthState> _authSubscription;

  _AuthIntent? _pendingIntent;
  String? _pendingDisplayName;

  bool _isSignUp = false;
  bool _loading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _allowAuthNavigation = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();

    _authSubscription = _authService.authStateChanges.listen((event) {
      if (!_allowAuthNavigation || event.session == null) {
        return;
      }

      unawaited(
        _finishAuthenticatedSession(
          event.session!,
          isNewAccount: _pendingIntent == _AuthIntent.signUp,
        ),
      );
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedEmail() async {
    final savedEmail = await UserPreferences.getSavedEmail();

    if (!mounted || savedEmail == null || savedEmail.isEmpty) {
      return;
    }

    emailController.text = savedEmail;
    final savedDisplayName = await UserPreferences.getSavedDisplayNameForEmail(
      savedEmail,
    );

    if (!mounted || savedDisplayName == null || savedDisplayName.isEmpty) {
      return;
    }

    fullNameController.text = savedDisplayName;
  }

  Future<void> _submitEmailPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _allowAuthNavigation = true;
      _pendingIntent = _isSignUp ? _AuthIntent.signUp : _AuthIntent.signIn;
    });

    final email = emailController.text.trim();
    final password = passwordController.text;
    final fullName = fullNameController.text.trim();

    try {
      if (_isSignUp) {
        await _createAccount(email, password, fullName);
      } else {
        await _signIn(email, password);
      }
    } on AuthException catch (error) {
      _showAuthError(error);
    } on AuthFlowException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createAccount(
    String email,
    String password,
    String fullName,
  ) async {
    await UserPreferences.saveEmail(email);
    await UserPreferences.saveDisplayNameForEmail(email, fullName);

    _pendingDisplayName = fullName;

    final response = await _authService.signUpWithEmail(
      email: email,
      password: password,
      fullName: fullName,
    );

    TextInput.finishAutofillContext(shouldSave: true);

    if (response.session != null) {
      await _finishAuthenticatedSession(
        response.session!,
        isNewAccount: true,
      );
      return;
    }

    final session = await _trySignInAfterSignUp(email, password);

    if (session != null) {
      await _finishAuthenticatedSession(
        session,
        isNewAccount: true,
      );
      return;
    }

    _showMessage('Account created successfully.');
  }

  Future<void> _signIn(String email, String password) async {
    final response = await _authService.signInWithEmail(
      email: email,
      password: password,
    );

    if (response.session != null) {
      TextInput.finishAutofillContext(shouldSave: true);

      await UserPreferences.saveEmail(email);

      await _finishAuthenticatedSession(
        response.session!,
        isNewAccount: false,
      );
    }
  }

  Future<Session?> _trySignInAfterSignUp(
    String email,
    String password,
  ) async {
    try {
      final response = await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      return response.session;
    } on AuthException {
      return null;
    }
  }

  Future<void> _continueWithGoogle() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _allowAuthNavigation = true;
      _pendingIntent = _AuthIntent.google;
    });

    try {
      await _authService.signInWithGoogle();

      final session = _authService.currentSession;

      if (session != null) {
        await _finishAuthenticatedSession(
          session,
          isNewAccount: false,
        );
      } else {
        _showMessage('Complete Google sign-in to continue.');
      }
    } on AuthException catch (error) {
      _showAuthError(error);
    } on AuthFlowException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _finishAuthenticatedSession(
    Session session, {
    required bool isNewAccount,
  }) async {
    if (_navigating) {
      return;
    }

    final email = session.user.email ?? emailController.text.trim();

    await UserPreferences.saveEmail(email);
    await _saveAuthenticatedProfile(session, email);

    if (isNewAccount) {
      await UserPreferences.setOnboardingComplete(false);
      _goToOnboarding();
      return;
    }

    final onboardingComplete =
        await UserPreferences.isOnboardingComplete();

    if (onboardingComplete) {
      _goHome();
    } else {
      _goToOnboarding();
    }
  }

  Future<void> _saveAuthenticatedProfile(
    Session session,
    String email,
  ) async {
    final metadataName =
        UserPreferences.metadataDisplayNameForUser(
      session.user,
    );

    final savedName =
        await UserPreferences.getSavedDisplayNameForEmail(
      email,
    );

    final submittedName = _pendingDisplayName?.trim();

    final displayName =
        submittedName != null && submittedName.isNotEmpty
            ? submittedName
            : metadataName ?? savedName;

    if (displayName == null || displayName.trim().isEmpty) {
      await UserPreferences.cacheProfileFromUser(session.user);
      return;
    }

    await UserPreferences.saveDisplayNameForEmail(
      email,
      displayName,
    );

    if (!UserPreferences.hasMetadataDisplayName(session.user)) {
      try {
        await _authService.updateDisplayName(displayName);
      } catch (error) {
        debugPrint(
          'Display name metadata update skipped: $error',
        );
      }
    }
  }

  void _goHome() {
    if (!mounted || _navigating) {
      return;
    }

    _navigating = true;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
    );
  }

  void _goToOnboarding() {
    if (!mounted || _navigating) {
      return;
    }

    _navigating = true;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/onboarding1',
      (route) => false,
    );
  }

  void _showAuthError(AuthException error) {
    final message = error.message.toLowerCase();

    if (message.contains('invalid login credentials')) {
      _showMessage(
        'No account found with these details. Please sign up first.',
      );
      return;
    }

    _showMessage(error.message);
  }

  void _showMessage(String message) {
  if (!mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: const Color(0xFF1B2A41),
      behavior: SnackBarBehavior.floating,
      elevation: 10,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
  );
}

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Enter your email address';
    }

    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email address';
    }

    return null;
  }

  String? _validateFullName(String? value) {
    if (!_isSignUp) {
      return null;
    }

    final fullName =
        value?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';

    if (fullName.isEmpty) {
      return 'Enter your full name';
    }

    if (fullName.length < 2) {
      return 'Enter a valid name';
    }

    if (!RegExp(r'[A-Za-z]').hasMatch(fullName)) {
      return 'Name must include letters';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Enter your password';
    }

    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (!_isSignUp) {
      return null;
    }

    if ((value ?? '').isEmpty) {
      return 'Confirm your password';
    }

    if (value != passwordController.text) {
      return 'Passwords do not match';
    }

    return null;
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _passwordVisible = false;
      _confirmPasswordVisible = false;
      confirmPasswordController.clear();
      _pendingDisplayName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 28,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 56,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 420,
                    ),
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            _buildLogo(),
                            const SizedBox(height: 38),

                            Text(
                              _isSignUp
                                  ? 'Sign up'
                                  : 'Sign in',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textWhite,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 34),

                            if (_isSignUp) ...[
                              TextFormField(
                                controller: fullNameController,
                                textCapitalization:
                                    TextCapitalization.words,
                                textInputAction:
                                    TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.name,
                                ],
                                style: const TextStyle(
                                  color:
                                      AppColors.textWhite,
                                ),
                                validator:
                                    _validateFullName,
                                decoration:
                                    _inputDecoration(
                                  label: 'Full name',
                                  icon: Icons
                                      .badge_outlined,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            TextFormField(
                              controller: emailController,
                              keyboardType:
                                  TextInputType
                                      .emailAddress,
                              textInputAction:
                                  TextInputAction.next,
                              autofillHints: const [
                                AutofillHints.email,
                                AutofillHints.username,
                              ],
                              autocorrect: false,
                              style: const TextStyle(
                                color:
                                    AppColors.textWhite,
                              ),
                              validator: _validateEmail,
                              decoration:
                                  _inputDecoration(
                                label: 'Email',
                                icon:
                                    Icons.mail_outline,
                              ),
                            ),

                            const SizedBox(height: 16),

                            TextFormField(
                              controller:
                                  passwordController,
                              obscureText:
                                  !_passwordVisible,
                              enableSuggestions: false,
                              textInputAction:
                                  _isSignUp
                                      ? TextInputAction
                                          .next
                                      : TextInputAction
                                          .done,
                              autofillHints: _isSignUp
                                  ? const [
                                      AutofillHints
                                          .newPassword,
                                    ]
                                  : const [
                                      AutofillHints
                                          .password,
                                    ],
                              style: const TextStyle(
                                color:
                                    AppColors.textWhite,
                              ),
                              validator:
                                  _validatePassword,
                              onFieldSubmitted: (_) {
                                if (!_isSignUp) {
                                  _submitEmailPassword();
                                }
                              },
                              decoration:
                                  _inputDecoration(
                                label: 'Password',
                                icon:
                                    Icons.lock_outline,
                                suffixIcon:
                                    _passwordToggle(
                                  visible:
                                      _passwordVisible,
                                  onPressed: () {
                                    setState(() {
                                      _passwordVisible =
                                          !_passwordVisible;
                                    });
                                  },
                                ),
                              ),
                            ),

                            if (_isSignUp) ...[
                              const SizedBox(height: 16),

                              TextFormField(
                                controller:
                                    confirmPasswordController,
                                obscureText:
                                    !_confirmPasswordVisible,
                                enableSuggestions:
                                    false,
                                textInputAction:
                                    TextInputAction
                                        .done,
                                autofillHints: const [
                                  AutofillHints
                                      .newPassword,
                                ],
                                style: const TextStyle(
                                  color:
                                      AppColors.textWhite,
                                ),
                                validator:
                                    _validateConfirmPassword,
                                onFieldSubmitted: (_) =>
                                    _submitEmailPassword(),
                                decoration:
                                    _inputDecoration(
                                  label:
                                      'Confirm Password',
                                  icon: Icons
                                      .lock_reset_outlined,
                                  suffixIcon:
                                      _passwordToggle(
                                    visible:
                                        _confirmPasswordVisible,
                                    onPressed: () {
                                      setState(() {
                                        _confirmPasswordVisible =
                                            !_confirmPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 28),

                            SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _loading
                                    ? null
                                    : _submitEmailPassword,
                                style:
                                    ElevatedButton
                                        .styleFrom(
                                  backgroundColor:
                                      AppColors.primary,
                                  foregroundColor:
                                      Colors.black,
                                  disabledBackgroundColor:
                                      AppColors
                                          .primary
                                          .withValues(
                                    alpha: 0.5,
                                  ),
                                  elevation: 8,
                                  shadowColor:
                                      AppColors
                                          .primary
                                          .withValues(
                                    alpha: 0.24,
                                  ),
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      12,
                                    ),
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child:
                                            CircularProgressIndicator(
                                          color:
                                              Colors.black,
                                          strokeWidth:
                                              2.4,
                                        ),
                                      )
                                    : Text(
                                        _isSignUp
                                            ? 'Sign up'
                                            : 'Sign in',
                                        style:
                                            const TextStyle(
                                          fontSize: 17,
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 34),

                            _buildDivider(),

                            const SizedBox(height: 18),

                            SizedBox(
                              height: 54,
                              child:
                                  OutlinedButton.icon(
                                onPressed: _loading
                                    ? null
                                    : _continueWithGoogle,
                                style:
                                    OutlinedButton
                                        .styleFrom(
                                  foregroundColor:
                                      AppColors
                                          .textWhite,
                                  backgroundColor:
                                      AppColors.surface,
                                  side:
                                      const BorderSide(
                                    color:
                                        Colors.white24,
                                  ),
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      12,
                                    ),
                                  ),
                                ),
                                icon:
                                    const _GoogleLogo(
                                  size: 22,
                                ),
                                label: const Text(
                                  'Continue with Google',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 26),

                            TextButton(
                              onPressed:
                                  _loading
                                      ? null
                                      : _toggleMode,
                              child: Text.rich(
                                TextSpan(
                                  text: _isSignUp
                                      ? 'Already have an account? '
                                      : 'Do not have an account? ',
                                  children: [
                                    TextSpan(
                                      text: _isSignUp
                                          ? 'Sign in'
                                          : 'Sign up',
                                      style:
                                          const TextStyle(
                                        color:
                                            AppColors
                                                .primary,
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),
                                  ],
                                ),
                                style: const TextStyle(
                                  color:
                                      Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 92,
        height: 92,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.42,
              ),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: AppColors.primary.withValues(
                alpha: 0.18,
              ),
              blurRadius: 34,
              spreadRadius: 4,
            ),
            BoxShadow(
              color: Colors.white.withValues(
                alpha: 0.08,
              ),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Image.asset(
          'assets/images/museum_logo.png',
        ),
      ),
    );
  }

  Widget _passwordToggle({
    required bool visible,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip:
          visible
              ? 'Hide password'
              : 'Show password',
      onPressed: onPressed,
      icon: Icon(
        visible
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        color: Colors.white70,
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: Colors.white24),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          child: Text(
            _isSignUp
                ? 'Or sign up with'
                : 'Or sign in with',
            style: const TextStyle(
              color: Colors.white54,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: Colors.white24),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Colors.white54,
      ),
      prefixIcon: Icon(
        icon,
        color: Colors.white70,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surface,
      errorMaxLines: 2,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.2,
        ),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.2,
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.18;

    final rect =
        Offset(
          strokeWidth / 2,
          strokeWidth / 2,
        ) &
        Size(
          size.width - strokeWidth,
          size.height - strokeWidth,
        );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    void drawArc(
      Color color,
      double start,
      double sweep,
    ) {
      paint.color = color;

      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        paint,
      );
    }

    drawArc(
      const Color(0xFF4285F4),
      -0.06 * math.pi,
      0.42 * math.pi,
    );

    drawArc(
      const Color(0xFF34A853),
      0.36 * math.pi,
      0.45 * math.pi,
    );

    drawArc(
      const Color(0xFFFBBC05),
      0.81 * math.pi,
      0.44 * math.pi,
    );

    drawArc(
      const Color(0xFFEA4335),
      1.25 * math.pi,
      0.58 * math.pi,
    );

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square;

    final center = Offset(
      size.width * 0.52,
      size.height * 0.5,
    );

    canvas.drawLine(
      center,
      Offset(
        size.width * 0.92,
        size.height * 0.5,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}