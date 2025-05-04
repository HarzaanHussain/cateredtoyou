import 'package:cateredtoyou/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cateredtoyou/models/auth_model.dart';
import 'package:cateredtoyou/widgets/custom_button.dart';
import 'package:cateredtoyou/widgets/custom_text_field.dart';
import 'package:cateredtoyou/utils/validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isForgotPasswordLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _sanitizeInput(String input) {
    return input.trim().replaceAll(RegExp(r'[^a-zA-Z0-9@._-]'), '');
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        final email = _sanitizeInput(_emailController.text);
        final password = _passwordController.text.trim();

        if (email.isEmpty || password.isEmpty) {
          throw Exception('Email and password cannot be empty.');
        }

        final authModel = context.read<AuthModel>();
        final success = await authModel.signIn(email, password);

        if (success && mounted) {
          context.go('/home');
        } else {
          throw Exception('Invalid email or password.');
        }
      } catch (e) {
        if (mounted) {
          showSnackBar(e.toString(), Colors.red);
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  Future<void> _handleForgotPassword() async {
    final email = _sanitizeInput(_emailController.text);
    if (email.isEmpty) {
      showSnackBar('Please enter a valid email address.', Colors.red);
      return;
    }

    setState(() => _isForgotPasswordLoading = true);
    try {
      final authService = AuthService();
      final result = await authService.resetPassword(email);

      if (result.success) {
        showSnackBar('Password reset email sent.', Colors.green);
      } else {
        throw Exception(result.error ?? 'Failed to send reset email.');
      }
    } catch (e) {
      showSnackBar(e.toString(), Colors.red);
    } finally {
      setState(() => _isForgotPasswordLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
           FractionallySizedBox(
              alignment: Alignment.center,   // 🆕 keep it in the middle
                      widthFactor: 0.5,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 170),
                        child: Image.asset(
                          'assets/Adobefile.png',
                          fit: BoxFit.contain,
                           alignment: const Alignment(-1.5, 0),   //  shift ~15 % to the left
                        ),
                      ),
                    ),
           const SizedBox(height: 16),
               /* const Text('Welcome Back',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center), */
                const SizedBox(height: 24),  
                CustomTextField(
                  controller: _emailController,
                  label: 'Email',
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                 controller: _passwordController,
                  label: 'Password',
                  prefixIcon: Icons.lock,
                  obscureText: !_isPasswordVisible,
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    }),
                  ),
                  validator: Validators.validatePassword,
                  onFieldSubmitted: (_) => _handleLogin(), // Trigger login on enter key
                ),

                const SizedBox(height: 16),
                CustomButton(
                  label: 'Login',
                  onPressed: _isLoading ? null : _handleLogin,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isForgotPasswordLoading ? null : _handleForgotPassword,
                  child: _isForgotPasswordLoading
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      
                      :Text ('Forgot Password?',   style: TextStyle(
                      color: Colors.black,   // brighter, higher‑contrast
                      fontWeight: FontWeight.w600,
                    ),), 
                                        
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.push('/register'),
                  child:Text("Don't have an account? Register",   style: TextStyle(
                  color: Colors.black,   // brighter, higher‑contrast
                  fontWeight: FontWeight.w600,
                ),),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}