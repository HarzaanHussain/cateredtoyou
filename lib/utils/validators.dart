class Validators { // Class to hold validation methods

  static String? validateEmail(String? value) { // Method to validate email
    if (value == null || value.isEmpty) { // Check if email is null or empty
      return 'Email is required'; // Return error message if email is null or empty
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$'); // Regular expression for email validation
    if (!emailRegex.hasMatch(value)) { // Check if email matches the regex
      return 'Enter a valid email address'; // Return error message if email is invalid
    }
    return null; // Return null if email is valid
  }

  static String? validatePassword(String? value) { // Method to validate password
    if (value == null || value.isEmpty) { // Check if password is null or empty
      return 'Password is required'; // Return error message if password is null or empty
    }
    if (value.length < 6) { // Check if password length is less than 6 characters
      return 'Password must be at least 6 characters'; // Return error message if password is too short
    }
    return null; // Return null if password is valid
  }

  static String? validateConfirmPassword(String? value, String password) { // Method to validate confirm password
    if (value == null || value.isEmpty) { // Check if confirm password is null or empty
      return 'Confirm password is required'; // Return error message if confirm password is null or empty
    }
    if (value != password) { // Check if confirm password matches the original password
      return 'Passwords do not match'; // Return error message if passwords do not match
    }
    return null; // Return null if confirm password is valid
  }

  static String? validateName(String? value) { // Method to validate name
    if (value == null || value.isEmpty) { // Check if name is null or empty
      return 'This field is required'; // Return error message if name is null or empty
    }
    if (value.length < 2) { // Check if name length is less than 2 characters
      return 'Name must be at least 2 characters'; // Return error message if name is too short
    }
    return null; // Return null if name is valid
  }

  static String? validatePhone(String? value) { // Method to validate phone number
    if (value == null || value.isEmpty) { // Check if phone number is null or empty
      return 'Phone number is required'; // Return error message if phone number is null or empty
    }
    final phoneRegex = RegExp(r'^\+?[\d\s-]{10,}$'); // Regular expression for phone number validation
    if (!phoneRegex.hasMatch(value)) { // Check if phone number matches the regex
      return 'Enter a valid phone number'; // Return error message if phone number is invalid
    }
    return null; // Return null if phone number is valid
  }
}
