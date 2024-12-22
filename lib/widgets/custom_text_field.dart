import 'package:flutter/material.dart'; // Importing the Flutter material package for UI components

class CustomTextField extends StatelessWidget { // Defining a stateless widget named CustomTextField
  final TextEditingController controller; // Controller to manage the text being edited
  final String label; // Label for the text field
  final IconData? prefixIcon; // Optional prefix icon for the text field
  final Widget? suffixIcon; // Optional suffix icon for the text field
  final bool obscureText; // Whether to obscure the text (for passwords)
  final TextInputType? keyboardType; // Type of keyboard to use (e.g., text, number)
  final String? Function(String?)? validator; // Optional validator function for form validation

  const CustomTextField({ // Constructor for the CustomTextField class
    super.key, // Key for the widget
    required this.controller, // Required controller for the text field
    required this.label, // Required label for the text field
    this.prefixIcon, // Optional prefix icon
    this.suffixIcon, // Optional suffix icon
    this.obscureText = false, // Default value for obscureText is false
    this.keyboardType, // Optional keyboard type
    this.validator, // Optional validator function
  });

  @override
  Widget build(BuildContext context) { // Build method to describe the part of the UI represented by this widget
    return TextFormField( // Using TextFormField widget to create a form field
      controller: controller, // Assigning the controller to the text field
      obscureText: obscureText, // Setting whether the text should be obscured
      keyboardType: keyboardType, // Setting the keyboard type
      validator: validator, // Assigning the validator function
      decoration: InputDecoration( // Setting the decoration for the text field
        labelText: label, // Setting the label text
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null, // Adding the prefix icon if provided
        suffixIcon: suffixIcon, // Adding the suffix icon if provided
        border: const OutlineInputBorder(), // Setting the border style
        floatingLabelBehavior: FloatingLabelBehavior.always, // Label always floats above the text field
      ),
    );
  }
}