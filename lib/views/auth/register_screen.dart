import 'package:flutter/material.dart'; // Importing Flutter material package for UI components.
import 'package:provider/provider.dart'; // Importing provider package for state management.
import 'package:go_router/go_router.dart'; // Importing go_router package for navigation.
import 'package:cateredtoyou/models/auth_model.dart'; // Importing the AuthModel for authentication logic.
import 'package:cateredtoyou/widgets/custom_button.dart'; // Importing custom button widget.
import 'package:cateredtoyou/widgets/custom_text_field.dart'; // Importing custom text field widget.
import 'package:cateredtoyou/utils/validators.dart'; // Importing validators for form validation.

class RegisterScreen extends StatefulWidget { // Defining a stateful widget for the registration screen.
  const RegisterScreen({super.key}); // Constructor for the RegisterScreen widget.

  @override
  State<RegisterScreen> createState() => _RegisterScreenState(); // Creating the state for the RegisterScreen widget.
}

class _RegisterScreenState extends State<RegisterScreen> { // Defining the state class for RegisterScreen.
  final _formKey = GlobalKey<FormState>(); // Key to identify the form and validate it.
  final _firstNameController = TextEditingController(); // Controller for the first name input field.
  final _lastNameController = TextEditingController(); // Controller for the last name input field.
  final _emailController = TextEditingController(); // Controller for the email input field.
  final _phoneController = TextEditingController(); // Controller for the phone number input field.
  final _passwordController = TextEditingController(); // Controller for the password input field.
  final _confirmPasswordController = TextEditingController(); // Controller for the confirm password input field.
  bool _isPasswordVisible = false; // Boolean to toggle password visibility.
  bool _isConfirmPasswordVisible = false; // Boolean to toggle confirm password visibility.

  @override
  void dispose() { // Dispose method to clean up controllers when the widget is removed from the widget tree.
    _firstNameController.dispose(); // Disposing first name controller.
    _lastNameController.dispose(); // Disposing last name controller.
    _emailController.dispose(); // Disposing email controller.
    _phoneController.dispose(); // Disposing phone controller.
    _passwordController.dispose(); // Disposing password controller.
    _confirmPasswordController.dispose(); // Disposing confirm password controller.
    super.dispose(); // Calling the dispose method of the superclass.
  }

  Future<void> _handleRegister() async { // Method to handle the registration process.
    if (_formKey.currentState?.validate() ?? false) { // Checking if the form is valid.
      final authModel = context.read<AuthModel>(); // Reading the AuthModel from the context.
      final success = await authModel.register( // Calling the register method from AuthModel.
        email: _emailController.text.trim(), // Passing trimmed email.
        password: _passwordController.text, // Passing password.
        firstName: _firstNameController.text.trim(), // Passing trimmed first name.
        lastName: _lastNameController.text.trim(), // Passing trimmed last name.
        phoneNumber: _phoneController.text.trim(), // Passing trimmed phone number.
      );

      if (success && mounted) { // If registration is successful and the widget is still mounted.
        context.go('/home'); // Navigate to the home screen.
      }
    }
  }

  @override
  Widget build(BuildContext context) { // Build method to construct the UI.
    final authModel = context.watch<AuthModel>(); // Watching the AuthModel for changes.

    return Scaffold( // Returning a Scaffold widget.
      appBar: AppBar( // AppBar for the top of the screen.
        title: const Text('Register'), // Title of the AppBar.
      ),
      body: Center( // Centering the body content.
        child: SingleChildScrollView( // Making the body scrollable.
          padding: const EdgeInsets.all(24.0), // Adding padding around the content.
          child: Form( // Form widget to group form fields.
            key: _formKey, // Assigning the form key.
            child: Column( // Column to arrange widgets vertically.
              mainAxisAlignment: MainAxisAlignment.center, // Centering the content vertically.
              crossAxisAlignment: CrossAxisAlignment.stretch, // Stretching the content horizontally.
              children: [
                const Text( // Text widget for the title.
                  'Create Account', // Title text.
                  style: TextStyle( // Styling the text.
                    fontSize: 28, // Font size.
                    fontWeight: FontWeight.bold, // Font weight.
                  ),
                  textAlign: TextAlign.center, // Center aligning the text.
                ),
                const SizedBox(height: 32), // Adding vertical space.
                CustomTextField( // Custom text field for first name.
                  controller: _firstNameController, // Assigning the controller.
                  label: 'First Name', // Label for the text field.
                  prefixIcon: Icons.person, // Prefix icon.
                  validator: Validators.validateName, // Validator for the text field.
                ),
                const SizedBox(height: 16), // Adding vertical space.
                CustomTextField( // Custom text field for last name.
                  controller: _lastNameController, // Assigning the controller.
                  label: 'Last Name', // Label for the text field.
                  prefixIcon: Icons.person, // Prefix icon.
                  validator: Validators.validateName, // Validator for the text field.
                ),
                const SizedBox(height: 16), // Adding vertical space.
                CustomTextField( // Custom text field for email.
                  controller: _emailController, // Assigning the controller.
                  label: 'Email', // Label for the text field.
                  prefixIcon: Icons.email, // Prefix icon.
                  keyboardType: TextInputType.emailAddress, // Setting keyboard type to email.
                  validator: Validators.validateEmail, // Validator for the text field.
                ),
                const SizedBox(height: 16), // Adding vertical space.
                CustomTextField( // Custom text field for phone number.
                  controller: _phoneController, // Assigning the controller.
                  label: 'Phone Number', // Label for the text field.
                  prefixIcon: Icons.phone, // Prefix icon.
                  keyboardType: TextInputType.phone, // Setting keyboard type to phone.
                  validator: Validators.validatePhone, // Validator for the text field.
                ),
                const SizedBox(height: 16), // Adding vertical space.
                CustomTextField( // Custom text field for password.
                  controller: _passwordController, // Assigning the controller.
                  label: 'Password', // Label for the text field.
                  prefixIcon: Icons.lock, // Prefix icon.
                  obscureText: !_isPasswordVisible, // Obscuring text based on visibility toggle.
                  suffixIcon: IconButton( // Suffix icon button to toggle visibility.
                    icon: Icon( // Icon for the button.
                      _isPasswordVisible ? Icons.visibility_off : Icons.visibility, // Toggling icon based on visibility.
                    ),
                    onPressed: () { // On press event for the button.
                      setState(() { // Updating the state.
                        _isPasswordVisible = !_isPasswordVisible; // Toggling password visibility.
                      });
                    },
                  ),
                  validator: Validators.validatePassword, // Validator for the text field.
                ),
                const SizedBox(height: 16), // Adding vertical space.
                CustomTextField( // Custom text field for confirm password.
                  controller: _confirmPasswordController, // Assigning the controller.
                  label: 'Confirm Password', // Label for the text field.
                  prefixIcon: Icons.lock, // Prefix icon.
                  obscureText: !_isConfirmPasswordVisible, // Obscuring text based on visibility toggle.
                  suffixIcon: IconButton( // Suffix icon button to toggle visibility.
                    icon: Icon( // Icon for the button.
                      _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility, // Toggling icon based on visibility.
                    ),
                    onPressed: () { // On press event for the button.
                      setState(() { // Updating the state.
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible; // Toggling confirm password visibility.
                      });
                    },
                  ),
                  validator: (value) { // Validator for the text field.
                    return Validators.validateConfirmPassword( // Validating confirm password.
                      value, // Value of the confirm password field.
                      _passwordController.text, // Value of the password field.
                    );
                  },
                ),
                const SizedBox(height: 24), // Adding vertical space.
                if (authModel.error != null) // Checking if there is an error.
                  Padding( // Adding padding around the error message.
                    padding: const EdgeInsets.only(bottom: 16), // Padding at the bottom.
                    child: Text( // Text widget for the error message.
                      authModel.error!, // Error message from the AuthModel.
                      style: const TextStyle( // Styling the error message.
                        color: Colors.red, // Red color for the error message.
                        fontSize: 14, // Font size.
                      ),
                      textAlign: TextAlign.center, // Center aligning the text.
                    ),
                  ),
                CustomButton( // Custom button for registration.
                  label: 'Register', // Label for the button.
                  onPressed: authModel.isLoading ? null : _handleRegister, // Disabling button if loading, otherwise calling _handleRegister.
                  isLoading: authModel.isLoading, // Showing loading indicator if loading.
                ),
                const SizedBox(height: 16), // Adding vertical space.
                TextButton( // Text button for navigation to login screen.
                  onPressed: () { // On press event for the button.
                    context.pop(); // Navigating back to the previous screen.
                  },
                  child: const Text('Already have an account? Login'), // Text for the button.
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}