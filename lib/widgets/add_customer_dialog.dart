
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components.
import 'package:provider/provider.dart'; // Importing Provider package for state management.
import 'package:cateredtoyou/services/customer_service.dart'; // Importing customer service for creating customers.
import 'package:cateredtoyou/widgets/custom_text_field.dart'; // Importing custom text field widget.

/// A dialog widget for adding a new customer.
class AddCustomerDialog extends StatefulWidget {
  const AddCustomerDialog({super.key}); // Constructor with optional key.

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState(); // Creates the mutable state for this widget.
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>(); // Key to identify the form and validate it.
  final _firstNameController = TextEditingController(); // Controller for first name input field.
  final _lastNameController = TextEditingController(); // Controller for last name input field.
  final _emailController = TextEditingController(); // Controller for email input field.
  final _phoneController = TextEditingController(); // Controller for phone number input field.
  bool _isLoading = false; // State to manage loading indicator.
  String? _error; // State to manage error messages.

  @override
  void dispose() {
    _firstNameController.dispose(); // Disposing first name controller to free resources.
    _lastNameController.dispose(); // Disposing last name controller to free resources.
    _emailController.dispose(); // Disposing email controller to free resources.
    _phoneController.dispose(); // Disposing phone controller to free resources.
    super.dispose(); // Calling super dispose method.
  }

  /// Handles form submission and customer creation.
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return; // Validates the form and returns if invalid.

    setState(() {
      _isLoading = true; // Sets loading state to true.
      _error = null; // Resets error state.
    });

    try {
      final customer = await context.read<CustomerService>().createCustomer(
        firstName: _firstNameController.text.trim(), // Trims and gets first name.
        lastName: _lastNameController.text.trim(), // Trims and gets last name.
        email: _emailController.text.trim(), // Trims and gets email.
        phoneNumber: _phoneController.text.trim(), // Trims and gets phone number.
      );

      if (mounted) {
        Navigator.of(context).pop(customer); // Pops the dialog and returns the created customer.
      }
    } catch (e) {
      setState(() {
        _error = e.toString(); // Sets error message.
        _isLoading = false; // Sets loading state to false.
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Customer'), // Dialog title.
      content: Form(
        key: _formKey, // Assigns form key to the form.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min, // Sets the main axis size to minimum.
            children: [
              CustomTextField(
                controller: _firstNameController, // Assigns controller to first name field.
                label: 'First Name', // Label for first name field.
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter first name'; // Validation message for empty first name.
                  }
                  return null; // Returns null if validation passes.
                },
              ),
              const SizedBox(height: 16), // Adds vertical spacing.
              CustomTextField(
                controller: _lastNameController, // Assigns controller to last name field.
                label: 'Last Name', // Label for last name field.
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter last name'; // Validation message for empty last name.
                  }
                  return null; // Returns null if validation passes.
                },
              ),
              const SizedBox(height: 16), // Adds vertical spacing.
              CustomTextField(
                controller: _emailController, // Assigns controller to email field.
                label: 'Email', // Label for email field.
                keyboardType: TextInputType.emailAddress, // Sets keyboard type to email address.
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter email'; // Validation message for empty email.
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email'; // Validation message for invalid email.
                  }
                  return null; // Returns null if validation passes.
                },
              ),
              const SizedBox(height: 16), // Adds vertical spacing.
              CustomTextField(
                controller: _phoneController, // Assigns controller to phone number field.
                label: 'Phone Number', // Label for phone number field.
                keyboardType: TextInputType.phone, // Sets keyboard type to phone.
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number'; // Validation message for empty phone number.
                  }
                  return null; // Returns null if validation passes.
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 16), // Adds vertical spacing.
                Text(
                  _error!, // Displays error message.
                  style: const TextStyle(color: Colors.red), // Sets text color to red.
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(), // Closes the dialog if not loading.
          child: const Text('Cancel'), // Cancel button text.
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit, // Submits the form if not loading.
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2), // Loading indicator.
                )
              : const Text('Add Customer'), // Add Customer button text.
        ),
      ],
    );
  }
}