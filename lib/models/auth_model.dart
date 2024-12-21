import 'package:cateredtoyou/services/firebase_service.dart'; // Importing Firebase service
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore for database operations
import 'package:flutter/foundation.dart'; // Importing foundation for ChangeNotifier
import 'package:firebase_auth/firebase_auth.dart'; // Importing Firebase Auth for authentication
import 'package:cateredtoyou/services/auth_service.dart'; // Importing custom AuthService
import 'user.dart'; // Importing UserModel

class AuthModel extends ChangeNotifier { // AuthModel class extending ChangeNotifier for state management
  final AuthService _authService = AuthService(); // Instance of AuthService for authentication operations
  UserModel? _user; // UserModel instance to hold user data
  bool _isLoading = false; // Boolean to indicate loading state
  String? _error; // String to hold error messages

  UserModel? get user => _user; // Getter for _user
  bool get isLoading => _isLoading; // Getter for _isLoading
  String? get error => _error; // Getter for _error
  bool get isAuthenticated => _user != null; // Getter to check if user is authenticated

  AuthModel() { // Constructor
    _initializeAuthState(); // Initialize authentication state
  }

  void _initializeAuthState() { // Method to initialize authentication state
    _authService.authStateChanges.listen((User? firebaseUser) async { // Listen to auth state changes
      if (firebaseUser == null) { // If no user is signed in
        _user = null; // Set _user to null
      } else { // If user is signed in
        // Get user data from Firestore
        final userData = await FirebaseFirestore.instance
            .collection(Collections.users) // Access users collection
            .doc(firebaseUser.uid) // Get document with user ID
            .get(); // Fetch document
        
        if (userData.exists) { // If user data exists
          _user = UserModel.fromMap(userData.data()!); // Map Firestore data to UserModel
        }
      }
      notifyListeners(); // Notify listeners about state change
    });
  }

  Future<bool> signIn(String email, String password) async { // Method to sign in user
    _setLoading(true); // Set loading state to true
    _clearError(); // Clear any previous errors

    try {
      final result = await _authService.signIn(email, password); // Attempt to sign in
      if (result.success && result.user != null) { // If sign in is successful
        _user = result.user; // Set _user to signed in user
        _setLoading(false); // Set loading state to false
        notifyListeners(); // Notify listeners about state change
        return true; // Return true for success
      } else {
        _setError(result.error ?? 'Sign in failed'); // Set error message
        _setLoading(false); // Set loading state to false
        return false; // Return false for failure
      }
    } catch (e) {
      _setError('An unexpected error occurred'); // Set error message for exception
      _setLoading(false); // Set loading state to false
      return false; // Return false for failure
    }
  }

  Future<bool> register({ // Method to register user
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
  }) async {
    _setLoading(true); // Set loading state to true
    _clearError(); // Clear any previous errors

    try {
      final result = await _authService.register( // Attempt to register
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
      );

      if (result.success && result.user != null) { // If registration is successful
        _user = result.user; // Set _user to registered user
        _setLoading(false); // Set loading state to false
        notifyListeners(); // Notify listeners about state change
        return true; // Return true for success
      } else {
        _setError(result.error ?? 'Registration failed'); // Set error message
        _setLoading(false); // Set loading state to false
        return false; // Return false for failure
      }
    } catch (e) {
      _setError('An unexpected error occurred'); // Set error message for exception
      _setLoading(false); // Set loading state to false
      return false; // Return false for failure
    }
  }

  Future<void> signOut() async { // Method to sign out user
    _setLoading(true); // Set loading state to true
    _clearError(); // Clear any previous errors

    try {
      await _authService.signOut(); // Attempt to sign out
      _user = null; // Set _user to null
    } catch (e) {
      _setError('Failed to sign out'); // Set error message for exception
    }

    _setLoading(false); // Set loading state to false
    notifyListeners(); // Notify listeners about state change
  }

  Future<bool> resetPassword(String email) async { // Method to reset password
    _setLoading(true); // Set loading state to true
    _clearError(); // Clear any previous errors

    try {
      final result = await _authService.resetPassword(email); // Attempt to reset password
      if (result.success) { // If password reset is successful
        _setLoading(false); // Set loading state to false
        return true; // Return true for success
      } else {
        _setError(result.error ?? 'Password reset failed'); // Set error message
        _setLoading(false); // Set loading state to false
        return false; // Return false for failure
      }
    } catch (e) {
      _setError('An unexpected error occurred'); // Set error message for exception
      _setLoading(false); // Set loading state to false
      return false; // Return false for failure
    }
  }

  void _setLoading(bool value) { // Method to set loading state
    _isLoading = value; // Set _isLoading to value
    notifyListeners(); // Notify listeners about state change
  }

  void _setError(String error) { // Method to set error message
    _error = error; // Set _error to error message
    notifyListeners(); // Notify listeners about state change
  }

  void _clearError() { // Method to clear error message
    _error = null; // Set _error to null
    notifyListeners(); // Notify listeners about state change
  }
}
