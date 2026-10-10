import 'dart:math';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/cotton_assets.dart';
import '../../services/storage_service.dart';
import '../../controllers/auth_controller.dart';
import '../../widgets/custom_button.dart';
import '../main_navigation_shell.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final StorageService storageService;

  const LoginScreen({super.key, required this.storageService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailOrPhoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _emailOrPhoneController.dispose();
    _passwordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.reset();
    _shakeController.forward();
  }

  Future<void> _handleLogin() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) {
      _triggerShake();
      return;
    }

    setState(() => _isLoading = true);

    final auth = AuthController(widget.storageService);
    final identifier = _emailOrPhoneController.text.trim();
    final password = _passwordController.text.trim();

    final success = await auth.login(identifier, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (context, animation, secondaryAnimation) =>
              MainNavigationShell(storageService: widget.storageService),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } else {
      _triggerShake();
      setState(() {
        _errorMessage = auth.errorMessage ??
            'Invalid credentials. Please verify your email or phone and password.';
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = AuthController(widget.storageService);
    final success = await auth.loginWithGoogle();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (context, animation, secondaryAnimation) =>
              MainNavigationShell(storageService: widget.storageService),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } else {
      if (auth.errorMessage != null &&
          !auth.errorMessage!.toLowerCase().contains('cancelled')) {
        _triggerShake();
        setState(() {
          _errorMessage = auth.errorMessage;
        });
      }
    }
  }

  Future<void> _handleGuestSignIn() async {
    setState(() => _isLoading = true);
    final auth = AuthController(widget.storageService);
    await auth.continueAsGuest();
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) =>
            MainNavigationShell(storageService: widget.storageService),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26.0, vertical: 20.0),
            child: AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                final offset = sin(_shakeAnimation.value * pi * 4) * 8 * (1 - _shakeAnimation.value);
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Logo
                    Center(
                      child: Container(
                        width: 78,
                        height: 78,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(isDark ? 50 : 15),
                              blurRadius: 18,
                              offset: const Offset(0, 5),
                            ),
                            BoxShadow(
                              color: AppColors.secondary.withAlpha(40),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          CottonAssets.logo,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Centered Welcome Heading & Subtitle
                    Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to diagnose cotton leaves & receive agronomic guidance',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Error Banner if validation or login failed
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.danger.withAlpha(120)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.danger, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Input: Email or Phone
                    TextFormField(
                      controller: _emailOrPhoneController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Email or Phone',
                        hintText: 'farmer@cottonguard.org or +91 9876543210',
                        prefixIcon: Icon(
                          Icons.mail_outline_rounded,
                          color: isDark ? AppColors.secondary : AppColors.primary,
                          size: 20,
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your email or phone number';
                        }
                        if (val.trim().length < 3) {
                          return 'Please enter a valid email or phone';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Input: Password with Visibility Icon
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(
                          Icons.lock_outline_rounded,
                          color: isDark ? AppColors.secondary : AppColors.primary,
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your password';
                        }
                        if (val.trim().length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Remember Me & Forgot Password
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                activeColor:
                                    isDark ? AppColors.secondary : AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: (val) {
                                  setState(() => _rememberMe = val ?? true);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Remember me',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ForgotPasswordScreen(
                                  storageService: widget.storageService,
                                ),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Forgot password?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.secondary : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Primary Sign In Button
                    CustomButton(
                      text: 'Sign In',
                      isLoading: _isLoading,
                      onPressed: _handleLogin,
                      width: double.infinity,
                    ),
                    const SizedBox(height: 20),

                    // Divider: or continue with
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14.0),
                          child: Text(
                            'or continue with',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textMutedDark
                                  : AppColors.textMutedLight,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Google Button (matching reference)
                    OutlinedButton(
                      onPressed: _handleGoogleSignIn,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          width: 1.2,
                        ),
                        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Clean Google G Icon
                          Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            child: const Text(
                              'G',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF4285F4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Continue with Google',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),

                    // Create Account Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Don\'t have an account?',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SignupScreen(
                                  storageService: widget.storageService,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            'Create Account',
                            style: TextStyle(
                              color: isDark ? AppColors.secondary : AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Guest Option
                    Center(
                      child: TextButton.icon(
                        onPressed: _handleGuestSignIn,
                        icon: Icon(
                          Icons.eco_outlined,
                          size: 18,
                          color: isDark ? AppColors.secondary : AppColors.primary,
                        ),
                        label: Text(
                          'Continue as Guest Farmer',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.secondary : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Terms / Privacy Text
                    Text(
                      'By continuing, you agree to Cotton Guard\'s\nTerms of Service and Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
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
  }
}
