import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/storage_service.dart';
import '../../controllers/auth_controller.dart';
import '../../widgets/custom_button.dart';
import '../main_navigation_shell.dart';

class SignupScreen extends StatefulWidget {
  final StorageService storageService;

  const SignupScreen({super.key, required this.storageService});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedLocation = 'Warangal, Telangana';
  String _selectedRole = 'Cotton Farmer';
  bool _obscurePassword = true;
  bool _agreeTerms = false;
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _locations = [
    'Warangal, Telangana',
    'Nagpur, Maharashtra',
    'Rajkot, Gujarat',
    'Guntur, Andhra Pradesh',
    'Bhatinda, Punjab',
    'Dharwad, Karnataka',
    'Coimbatore, Tamil Nadu',
  ];

  final List<String> _roles = [
    'Cotton Farmer',
    'Agronomist / Field Officer',
    'Agriculture Researcher',
    'Student / Academic',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  int _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 6) score++;
    if (password.length >= 8) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) || RegExp(r'[!@#\$&*~]').hasMatch(password)) score++;
    return score;
  }

  void _handleSignup() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeTerms) {
      setState(() {
        _errorMessage = 'You must agree to the agricultural terms & privacy policy to continue.';
      });
      return;
    }

    setState(() => _isLoading = true);
    final auth = AuthController(widget.storageService);
    final success = await auth.signup(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      phone: _phoneController.text.trim(),
      location: _selectedLocation,
      role: _selectedRole,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => MainNavigationShell(storageService: widget.storageService),
        ),
        (route) => false,
      );
    } else {
      setState(() {
        _errorMessage = auth.errorMessage ??
            'Failed to create account. Please verify input fields.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pwStrength = _calculatePasswordStrength(_passwordController.text);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Join Cotton Guard',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Empowering cotton growers with smart AI disease intelligence',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 24),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Full Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty || !val.contains('@')) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (val.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    if (!RegExp(r'[a-zA-Z]').hasMatch(val) ||
                        !RegExp(r'[0-9]').hasMatch(val)) {
                      return 'Must include both letters and numbers';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Password Strength Indicator
                if (_passwordController.text.isNotEmpty) ...[
                  Row(
                    children: List.generate(4, (index) {
                      Color color = Colors.grey.shade300;
                      if (index < pwStrength) {
                        if (pwStrength <= 1) {
                          color = AppColors.danger;
                        } else if (pwStrength <= 2) {
                          color = AppColors.warning;
                        } else {
                          color = AppColors.success;
                        }
                      }
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      pwStrength <= 1 ? 'Weak' : (pwStrength <= 2 ? 'Moderate' : 'Strong'),
                      style: TextStyle(
                        fontSize: 11,
                        color: pwStrength <= 1
                            ? AppColors.danger
                            : (pwStrength <= 2 ? AppColors.warning : AppColors.success),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password *',
                    prefixIcon: Icon(Icons.lock_reset_outlined),
                  ),
                  validator: (val) {
                    if (val != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Phone (Optional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: '+91 98480 12345',
                  ),
                ),
                const SizedBox(height: 16),

                // Location Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedLocation,
                  decoration: const InputDecoration(
                    labelText: 'Farm Location / Region',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  items: _locations.map((loc) {
                    return DropdownMenuItem(value: loc, child: Text(loc));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedLocation = val);
                  },
                ),
                const SizedBox(height: 16),

                // Role Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Primary Role',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: _roles.map((r) {
                    return DropdownMenuItem(value: r, child: Text(r));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRole = val);
                  },
                ),
                const SizedBox(height: 16),

                // Terms Checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreeTerms,
                      activeColor: isDark ? AppColors.secondary : AppColors.primary,
                      onChanged: (val) => setState(() => _agreeTerms = val ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text(
                          'I agree to the Cotton Guard Agricultural Terms of Service and data privacy policies.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Submit Button
                CustomButton(
                  text: 'Create Account',
                  isLoading: _isLoading,
                  onPressed: _handleSignup,
                  width: double.infinity,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
