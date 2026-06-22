import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../dashboard/home_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSignup() async {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();

      await ref.read(authNotifierProvider.notifier).signup(
            name: _nameController.text,
            email: _emailController.text,
            phoneNumber: _phoneController.text,
            password: _passwordController.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Listen to success or error state
    ref.listen<AuthUIState>(authNotifierProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        ref.read(authNotifierProvider.notifier).clearError();
      } else if (next.isSuccess) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Let\'s Get Started',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create an account to experience smart commuting',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
              ),
              const SizedBox(height: 32),

              // Signup Card
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Full Name Field
                      CustomTextField(
                        controller: _nameController,
                        hintText: 'Enter your full name',
                        labelText: 'Full Name',
                        prefixIcon: Icons.person_outline_rounded,
                        validator: Validators.validateName,
                      ),
                      const SizedBox(height: 20),

                      // Email Field
                      CustomTextField(
                        controller: _emailController,
                        hintText: 'Enter your email address',
                        labelText: 'Email Address',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.validateEmail,
                      ),
                      const SizedBox(height: 20),

                      // Phone Number Field
                      CustomTextField(
                        controller: _phoneController,
                        hintText: 'Enter your phone number',
                        labelText: 'Phone Number',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: Validators.validatePhone,
                      ),
                      const SizedBox(height: 20),

                      // Password Field
                      CustomTextField(
                        controller: _passwordController,
                        hintText: 'Enter a secure password (6+ chars)',
                        labelText: 'Password',
                        prefixIcon: Icons.lock_outline_rounded,
                        isPassword: true,
                        validator: Validators.validatePassword,
                      ),
                      const SizedBox(height: 20),

                      // Confirm Password Field
                      CustomTextField(
                        controller: _confirmPasswordController,
                        hintText: 'Re-enter your password',
                        labelText: 'Confirm Password',
                        prefixIcon: Icons.lock_clock_outlined,
                        isPassword: true,
                        validator: (value) => Validators.validateConfirmPassword(
                          value,
                          _passwordController.text,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Create Account Button
                      CustomButton(
                        text: 'Register Account',
                        onPressed: _handleSignup,
                        isLoading: authState.isLoading,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Login back-navigation link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Already have an account? ",
                    style: TextStyle(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
