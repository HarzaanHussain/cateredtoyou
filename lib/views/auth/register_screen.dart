import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cateredtoyou/models/auth_model.dart';
import 'package:cateredtoyou/widgets/custom_button.dart';
import 'package:cateredtoyou/widgets/custom_text_field.dart';
import 'package:cateredtoyou/utils/validators.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final authModel = context.read<AuthModel>();

    try {
      final success = await authModel.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );

      if (success && mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authModel = context.watch<AuthModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create Account',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // First Name
                CustomTextField(
                  controller: _firstNameController,
                  label: 'First Name',
                  prefixIcon: Icons.person,
                  validator: (value) =>
                      Validators.validateName(value?.trim()),
                ),
                const SizedBox(height: 16),

                // Last Name
                CustomTextField(
                  controller: _lastNameController,
                  label: 'Last Name',
                  prefixIcon: Icons.person,
                  validator: (value) =>
                      Validators.validateName(value?.trim()),
                ),
                const SizedBox(height: 16),

                // Email
                CustomTextField(
                  controller: _emailController,
                  label: 'Email',
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                      Validators.validateEmail(value?.trim()),
                ),
                const SizedBox(height: 16),

                // Phone Number
                CustomTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) =>
                      Validators.validatePhone(value?.trim()),
                ),
                const SizedBox(height: 16),

                // Password
                CustomTextField(
                  controller: _passwordController,
                  label: 'Password',
                  prefixIcon: Icons.lock,
                  obscureText: !_isPasswordVisible,
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    }),
                  ),
                  validator: Validators.validatePassword,
                ),
                const SizedBox(height: 16),

                // Confirm Password
                CustomTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  prefixIcon: Icons.lock,
                  obscureText: !_isConfirmPasswordVisible,
                  suffixIcon: IconButton(
                    icon: Icon(_isConfirmPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    }),
                  ),
                  validator: (value) => Validators.validateConfirmPassword(
                    value,
                    _passwordController.text,
                  ),
                ),
                const SizedBox(height: 24),

                // Error Message
                if (authModel.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      authModel.error!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Register Button
                CustomButton(
                  label: 'Register',
                  onPressed: authModel.isLoading ? null : _handleRegister,
                  isLoading: authModel.isLoading,
                ),
                const SizedBox(height: 16),

                // Navigate to Login
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
