import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/services/staff_service.dart';
import 'package:cateredtoyou/widgets/custom_button.dart';
import 'package:cateredtoyou/widgets/custom_text_field.dart';
import 'package:cateredtoyou/utils/validators.dart';

class AddStaffScreen extends StatefulWidget {
  const AddStaffScreen({super.key}); // Constructor for the AddStaffScreen widget

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState(); // Creates the mutable state for this widget
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>(); // Key to identify the form and validate it
  final _firstNameController = TextEditingController(); // Controller for the first name input field
  final _lastNameController = TextEditingController(); // Controller for the last name input field
  final _emailController = TextEditingController(); // Controller for the email input field
  final _phoneController = TextEditingController(); // Controller for the phone number input field
  final _passwordController = TextEditingController(); // Controller for the password input field
  String _selectedRole = 'staff'; // Default role selected
  bool _isLoading = false; // Indicates if a loading process is ongoing
  String? _error; // Stores any error messages

  final List<String> _roles = [
    'staff',
    'manager',
    'admin',
    'chef',
    'server',
    'driver'
  ]; // List of roles available for selection

  @override
  void dispose() {
    _firstNameController.dispose(); // Dispose of the controller when the widget is removed from the widget tree
    _lastNameController.dispose(); // Dispose of the controller when the widget is removed from the widget tree
    _emailController.dispose(); // Dispose of the controller when the widget is removed from the widget tree
    _phoneController.dispose(); // Dispose of the controller when the widget is removed from the widget tree
    _passwordController.dispose(); // Dispose of the controller when the widget is removed from the widget tree
    super.dispose(); // Call the dispose method of the superclass
  }

  Future<void> _handleAddStaff() async {
    if (!_formKey.currentState!.validate()) return; // Validate the form and return if invalid

    setState(() {
      _isLoading = true; // Set loading state to true
      _error = null; // Clear any previous error messages
    });

    try {
      final staffService = Provider.of<StaffService>(context, listen: false); // Get the staff service from the provider

      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissing the dialog by tapping outside
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(), // Show a loading indicator
          );
        },
      );

      final success = await staffService.createStaffMember(
        email: _emailController.text.trim(), // Get the trimmed email from the controller
        password: _passwordController.text, // Get the password from the controller
        firstName: _firstNameController.text.trim(), // Get the trimmed first name from the controller
        lastName: _lastNameController.text.trim(), // Get the trimmed last name from the controller
        phoneNumber: _phoneController.text.trim(), // Get the trimmed phone number from the controller
        role: _selectedRole,  // Get the selected role
      );

      if (!mounted) return; // Check if the widget is still mounted

      Navigator.of(context).pop(); // Close the loading dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff member added successfully'), // Show success message
            backgroundColor: Colors.green, // Set background color to green
            behavior: SnackBarBehavior.floating, // Make the snackbar float
            duration: Duration(seconds: 2), // Set duration for the snackbar
          ),
        );
        context.go('/staff'); // Navigate to the staff screen
      }
    } catch (e) {
      if (!mounted) return; // Check if the widget is still mounted

      if (Navigator.canPop(context)) {
        Navigator.of(context).pop(); // Close the loading dialog if it's still shown
      }

      final errorMessage = e.toString().replaceAll(RegExp(r'^Exception: '), ''); // Format the error message

      setState(() {
        _error = errorMessage; // Set the error message
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage), // Show the error message
          backgroundColor: Colors.red, // Set background color to red
          behavior: SnackBarBehavior.floating, // Make the snackbar float
          duration: const Duration(seconds: 4), // Set duration for the snackbar
          action: SnackBarAction(
            label: 'Dismiss', // Label for the dismiss action
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Hide the current snackbar
            },
            textColor: Colors.white, // Set text color to white
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Set loading state to false
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Staff Member'), // Title for the app bar
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0), // Add padding around the content
        child: Form(
          key: _formKey, // Assign the form key to the form
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch the children to fill the column
            children: [
              CustomTextField(
                controller: _firstNameController, // Assign the controller to the text field
                label: 'First Name', // Label for the text field
                prefixIcon: Icons.person, // Icon for the text field
                validator: Validators.validateName, // Validator for the text field
              ),
              const SizedBox(height: 16), // Add vertical space
              CustomTextField(
                controller: _lastNameController, // Assign the controller to the text field
                label: 'Last Name', // Label for the text field
                prefixIcon: Icons.person, // Icon for the text field
                validator: Validators.validateName, // Validator for the text field
              ),
              const SizedBox(height: 16), // Add vertical space
              CustomTextField(
                controller: _emailController, // Assign the controller to the text field
                label: 'Email', // Label for the text field
                prefixIcon: Icons.email, // Icon for the text field
                keyboardType: TextInputType.emailAddress, // Set keyboard type to email address
                validator: Validators.validateEmail, // Validator for the text field
              ),
              const SizedBox(height: 16), // Add vertical space
              CustomTextField(
                controller: _phoneController, // Assign the controller to the text field
                label: 'Phone Number', // Label for the text field
                prefixIcon: Icons.phone, // Icon for the text field
                keyboardType: TextInputType.phone, // Set keyboard type to phone number
                validator: Validators.validatePhone, // Validator for the text field
              ),
              const SizedBox(height: 16), // Add vertical space
              CustomTextField(
                controller: _passwordController, // Assign the controller to the text field
                label: 'Password', // Label for the text field
                prefixIcon: Icons.lock, // Icon for the text field
                validator: Validators.validatePassword, // Validator for the text field
                obscureText: true, // Hide the text for password input
              ),
              const SizedBox(height: 16), // Add vertical space
              DropdownButtonFormField<String>(
                value: _selectedRole, // Set the selected role
                decoration: const InputDecoration(
                  labelText: 'Role', // Label for the dropdown
                  border: OutlineInputBorder(), // Border for the dropdown
                  prefixIcon: Icon(Icons.work), // Icon for the dropdown
                ),
                items: _roles.map((String role) {
                  return DropdownMenuItem<String>(
                    value: role, // Value for the dropdown item
                    child: Text(role.toUpperCase()), // Display text for the dropdown item
                  );
                }).toList(), // Convert the roles list to dropdown menu items
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      _selectedRole = value; // Update the selected role
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a role'; // Validator for the dropdown
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24), // Add vertical space
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16), // Add padding around the error message
                  child: Text(
                    _error!, // Display the error message
                    style: const TextStyle(
                      color: Colors.red, // Set text color to red
                      fontSize: 14, // Set font size
                    ),
                    textAlign: TextAlign.center, // Center align the text
                  ),
                ),
              CustomButton(
                label: 'Add Staff Member', // Label for the button
                onPressed: _isLoading ? null : _handleAddStaff, // Disable the button if loading, otherwise call the handler
                isLoading: _isLoading, // Show loading indicator if loading
              ),
            ],
          ),
        ),
      ),
    );
  }
}
