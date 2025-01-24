import 'package:cateredtoyou/services/auth_service.dart'; // Importing the authentication service
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components
import 'package:provider/provider.dart'; // Importing provider for state management
import 'package:go_router/go_router.dart'; // Importing go_router for navigation
import 'package:cateredtoyou/models/auth_model.dart'; // Importing the authentication model
import 'package:cateredtoyou/widgets/custom_button.dart'; // Importing custom button widget
import 'package:cateredtoyou/widgets/custom_text_field.dart'; // Importing custom text field widget
import 'package:cateredtoyou/utils/validators.dart'; // Importing validators for form validation

/// LoginScreen is a stateful widget that represents the login screen.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key}); // Constructor for LoginScreen

  @override
  State<LoginScreen> createState() => _LoginScreenState(); // Creates the mutable state for this widget
}

/// _LoginScreenState is the state class for LoginScreen.
class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>(); // Key to identify the form
  final _emailController = TextEditingController(); // Controller for email input
  final _passwordController = TextEditingController(); // Controller for password input
  bool _isPasswordVisible = false; // State to manage password visibility
  bool _isLoading = false; // State to manage loading indicator for login
  bool _isForgotPasswordLoading = false; // State to manage loading indicator for forgot password

  @override
  void dispose() {
    _emailController.dispose(); // Dispose email controller when widget is removed
    _passwordController.dispose(); // Dispose password controller when widget is removed
    super.dispose(); // Call the dispose method of the superclass
  }

  /// Handles the login process.
  Future<void> _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) { // Validate the form
      setState(() {
        _isLoading = true; // Show loading indicator
      });

      try {
        final authModel = context.read<AuthModel>(); // Read the authentication model from the context
        final success = await authModel.signIn(
          _emailController.text.trim(), // Get the trimmed email
          _passwordController.text, // Get the password
        );

        if (success && mounted) {
          context.go('/home'); // Navigate to home screen on successful login
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('An error occurred during login. Please try again.'), // Show error message
              duration: Duration(seconds: 4), // Duration of the snackbar
              backgroundColor: Colors.red, // Background color of the snackbar
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false; // Hide loading indicator
          });
        }
      }
    }
  }

  /// Shows a snackbar with a given message and background color.
  void showSnackBar(String message, Color backgroundColor,
      {Duration duration = const Duration(seconds: 4)}) {
    debugPrint('Showing SnackBar: $message'); // Debug print for showing snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), // Message to be shown in the snackbar
        duration: duration, // Duration of the snackbar
        backgroundColor: backgroundColor, // Background color of the snackbar
      ),
    );
  }

  /// Handles the forgot password process.
  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim(); // Get the trimmed email
    if (email.isEmpty) {
      showSnackBar(
        'Please enter the email address associated with your client account', // Show error if email is empty
        Colors.red,
      );
      return;
    }

    setState(() => _isForgotPasswordLoading = true); // Show loading indicator

    try {
      final authService = AuthService(); // Create an instance of AuthService
      final result = await authService.resetPassword(email); // Call resetPassword method

      if (result.success) {
        showSnackBar(
          'Password Reset Email Sent to $email\n\n'
          'Please check your email inbox and click the link to reset your password. '
          'If you don\'t see the email, please check your spam folder.', // Show success message
          Colors.green,
          duration: const Duration(seconds: 8), // Duration of the snackbar
        );
      } else {
        showSnackBar(
          result.error ?? 'Failed to send reset email. Please try again later.', // Show error message
          Colors.red,
        );
      }
    } catch (e) {
      showSnackBar(
        'An unexpected error occurred. Please try again or contact support if the problem continues.', // Show unexpected error message
        Colors.red,
      );
    } finally {
      setState(() => _isForgotPasswordLoading = false); // Hide loading indicator
    }
  }

  @override
  Widget build(BuildContext context) {
    final authModel = context.watch<AuthModel>(); // Watch the authentication model for changes

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0), // Padding for the scroll view
          child: Form(
            key: _formKey, // Assign the form key
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Center the column vertically
              crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch the column horizontally
              children: [
                const Text(
                  'Welcome Back', // Welcome message
                  style: TextStyle(
                    fontSize: 28, // Font size
                    fontWeight: FontWeight.bold, // Font weight
                  ),
                  textAlign: TextAlign.center, // Center align the text
                ),
                const SizedBox(height: 32), // Spacing
                CustomTextField(
                  controller: _emailController, // Controller for email input
                  label: 'Email', // Label for the text field
                  prefixIcon: Icons.email, // Prefix icon for the text field
                  keyboardType: TextInputType.emailAddress, // Keyboard type for email input
                  validator: Validators.validateEmail, // Validator for email input
                ),
                const SizedBox(height: 16), // Spacing
                CustomTextField(
                  controller: _passwordController, // Controller for password input
                  label: 'Password', // Label for the text field
                  prefixIcon: Icons.lock, // Prefix icon for the text field
                  obscureText: !_isPasswordVisible, // Obscure text for password input
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility, // Toggle visibility icon
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible; // Toggle password visibility
                      });
                    },
                  ),
                  validator: Validators.validatePassword, // Validator for password input
                ),
                const SizedBox(height: 24), // Spacing
                if (authModel.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16), // Padding for error message
                    child: Text(
                      authModel.error!, // Display error message
                      style: const TextStyle(
                        color: Colors.red, // Text color
                        fontSize: 14, // Font size
                      ),
                      textAlign: TextAlign.center, // Center align the text
                    ),
                  ),
                CustomButton(
                  label: 'Login', // Label for the button
                  onPressed: _isLoading ? null : _handleLogin, // Disable button if loading
                  isLoading: _isLoading, // Show loading indicator if loading
                ),
                const SizedBox(height: 16), // Spacing
                TextButton(
                  onPressed:
                      _isForgotPasswordLoading ? null : _handleForgotPassword, // Disable button if loading
                  child: _isForgotPasswordLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2), // Show loading indicator
                        )
                      : const Text('Forgot Password?'), // Forgot password text
                ),
                const SizedBox(height: 16), // Spacing
                TextButton(
                  onPressed: () {
                    context.push('/register'); // Navigate to register screen
                  },
                  child: const Text('Don\'t have an account? Register'), // Register text
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
  