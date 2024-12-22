import 'package:flutter/material.dart'; // Importing Flutter material package for UI components.
import 'package:provider/provider.dart'; // Importing Provider package for state management.
import 'package:go_router/go_router.dart'; // Importing GoRouter package for navigation.
import 'package:cateredtoyou/models/auth_model.dart'; // Importing AuthModel for authentication logic.
import 'package:cateredtoyou/widgets/custom_button.dart'; // Importing custom button widget.
import 'package:cateredtoyou/widgets/custom_text_field.dart'; // Importing custom text field widget.
import 'package:cateredtoyou/utils/validators.dart'; // Importing validators for form validation.

class LoginScreen extends StatefulWidget { // Defining a stateful widget for the login screen.
  const LoginScreen({super.key}); // Constructor for the LoginScreen widget.

  @override
  State<LoginScreen> createState() => _LoginScreenState(); // Creating the state for the LoginScreen widget.
}

class _LoginScreenState extends State<LoginScreen> { // Defining the state class for LoginScreen.
  final _formKey = GlobalKey<FormState>(); // Key to identify the form and validate it.
  final _emailController = TextEditingController(); // Controller for the email text field.
  final _passwordController = TextEditingController(); // Controller for the password text field.
  bool _isPasswordVisible = false; // Boolean to toggle password visibility.

  @override
  void dispose() { // Overriding dispose method to clean up controllers.
    _emailController.dispose(); // Disposing email controller.
    _passwordController.dispose(); // Disposing password controller.
    super.dispose(); // Calling super dispose method.
  }

  Future<void> _handleLogin() async { // Method to handle login logic.
    if (_formKey.currentState?.validate() ?? false) { // Validating the form.
      final authModel = context.read<AuthModel>(); // Reading the AuthModel from the context.
      final success = await authModel.signIn( // Attempting to sign in with email and password.
        _emailController.text.trim(), // Trimming the email input.
        _passwordController.text, // Getting the password input.
      );

      if (success && mounted) { // If login is successful and widget is still mounted.
        context.go('/home'); // Navigate to the home screen.
      }
    }
  }

  @override
  Widget build(BuildContext context) { // Building the UI.
    final authModel = context.watch<AuthModel>(); // Watching the AuthModel for changes.

    return Scaffold( // Returning a Scaffold widget.
      body: Center( // Centering the content.
        child: SingleChildScrollView( // Making the content scrollable.
          padding: const EdgeInsets.all(24.0), // Adding padding around the content.
          child: Form( // Creating a form widget.
            key: _formKey, // Assigning the form key.
            child: Column( // Using a column to arrange widgets vertically.
              mainAxisAlignment: MainAxisAlignment.center, // Centering the column content vertically.
              crossAxisAlignment: CrossAxisAlignment.stretch, // Stretching the column content horizontally.
              children: [
                const Text( // Displaying a welcome text.
                  'Welcome Back', // Text content.
                  style: TextStyle( // Styling the text.
                    fontSize: 28, // Font size.
                    fontWeight: FontWeight.bold, // Font weight.
                  ),
                  textAlign: TextAlign.center, // Center aligning the text.
                ),
                const SizedBox(height: 32), // Adding vertical space.
                CustomTextField( // Custom text field for email input.
                  controller: _emailController, // Assigning the email controller.
                  label: 'Email', // Label for the text field.
                  prefixIcon: Icons.email, // Prefix icon for the text field.
                  keyboardType: TextInputType.emailAddress, // Setting keyboard type to email address.
                  validator: Validators.validateEmail, // Validator for email input.
                ),
                const SizedBox(height: 16), // Adding vertical space.
                CustomTextField( // Custom text field for password input.
                  controller: _passwordController, // Assigning the password controller.
                  label: 'Password', // Label for the text field.
                  prefixIcon: Icons.lock, // Prefix icon for the text field.
                  obscureText: !_isPasswordVisible, // Toggling password visibility.
                  suffixIcon: IconButton( // Icon button to toggle password visibility.
                    icon: Icon( // Icon for the button.
                      _isPasswordVisible ? Icons.visibility_off : Icons.visibility, // Changing icon based on visibility state.
                    ),
                    onPressed: () { // On press handler for the button.
                      setState(() { // Updating the state.
                        _isPasswordVisible = !_isPasswordVisible; // Toggling the password visibility.
                      });
                    },
                  ),
                  validator: Validators.validatePassword, // Validator for password input.
                ),
                const SizedBox(height: 24), // Adding vertical space.
                if (authModel.error != null) // Checking if there is an error.
                  Padding( // Adding padding around the error message.
                    padding: const EdgeInsets.only(bottom: 16), // Padding value.
                    child: Text( // Displaying the error message.
                      authModel.error!, // Error message content.
                      style: const TextStyle( // Styling the error message.
                        color: Colors.red, // Text color.
                        fontSize: 14, // Font size.
                      ),
                      textAlign: TextAlign.center, // Center aligning the text.
                    ),
                  ),
                CustomButton( // Custom button for login.
                  label: 'Login', // Button label.
                  onPressed: authModel.isLoading ? null : _handleLogin, // Disabling button if loading, otherwise handling login.
                  isLoading: authModel.isLoading, // Showing loading indicator if loading.
                ),
                const SizedBox(height: 16), // Adding vertical space.
                TextButton( // Text button for navigation to register screen.
                  onPressed: () { // On press handler for the button.
                    context.push('/register'); // Navigating to the register screen.
                  },
                  child: const Text('Don\'t have an account? Register'), // Button label.
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}