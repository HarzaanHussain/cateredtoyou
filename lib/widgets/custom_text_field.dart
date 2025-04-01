import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int? maxLines;  // Added maxLines parameter
  final bool readOnly;
  final VoidCallback? onTap;
    final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted; //add this for allowind enter on login screen

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,  // Default to 1 line
    this.readOnly = false,
    this.onTap,
     this.onChanged,
    this.onFieldSubmitted, // include in the constructor
    
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,  // Use maxLines parameter
      readOnly: readOnly,
      onTap: onTap,
       onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted, // pass the callback along
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon,
        border: const OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
    );
  }
}