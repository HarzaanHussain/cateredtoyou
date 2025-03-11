import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Authentication package
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore package
import 'package:flutter/foundation.dart'; // Import Flutter foundation package for debugging
import 'package:cateredtoyou/models/user_model.dart'; // Import UserModel class

class AuthResult {
  final bool success; // Indicates if the operation was successful
  final String? error; // Stores error message if any
  final UserModel? user; // Stores user data if operation was successful

  AuthResult({
    required this.success, // Constructor to initialize success
    this.error, // Constructor to initialize error
    this.user, // Constructor to initialize user
  });
}

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance
  final FirebaseAuth _auth = FirebaseAuth.instance; // FirebaseAuth instance

  Stream<User?> get authStateChanges => _auth.authStateChanges(); // Stream to listen to auth state changes
  User? get currentUser => _auth.currentUser; // Get current authenticated user

  // Register with email and password
  Future<AuthResult> register({
    required String email, // User email
    required String password, // User password
    required String firstName, // User first name
    required String lastName, // User last name
    required String phoneNumber, // User phone number
  }) async {
    try {
      debugPrint('Starting registration process...'); // Debug print for registration start
      
      // 1. Create Firebase Auth user
      final UserCredential authResult = await _auth.createUserWithEmailAndPassword(
        email: email, // Email for registration
        password: password, // Password for registration
      );

      if (authResult.user == null) {
        throw 'Failed to create user account'; // Throw error if user creation failed
      }

      final uid = authResult.user!.uid; // Get user ID
      debugPrint('Created auth user with ID: $uid'); // Debug print for user ID

      try {
        final now = DateTime.now(); // Get current time

        // 2. Create organization
        debugPrint('Creating organization...'); // Debug print for organization creation
        final orgRef = _firestore.collection('organizations').doc(); // Reference to organization document
        final orgId = orgRef.id; // Get organization ID
        await orgRef.set({
          'name': '$firstName $lastName\'s Organization', // Organization name
          'ownerId': uid, // Owner ID
          'createdAt': now, // Creation time
          'updatedAt': now, // Update time
          'contactEmail': email, // Contact email
          'contactPhone': phoneNumber, // Contact phone number
        });

        // 3. Create user document
        debugPrint('Creating user document...'); // Debug print for user document creation
        final userRef = _firestore.collection('users').doc(uid); // Reference to user document
        final UserModel newUser = UserModel(
          uid: uid, // User ID
          email: email, // User email
          firstName: firstName, // User first name
          lastName: lastName, // User last name
          phoneNumber: phoneNumber, // User phone number
          role: 'client', // User role
          employmentStatus: 'active', // Employment status
          organizationId: orgId, // Organization ID
          createdBy: uid, // Created by user ID
          createdAt: now, // Creation time
          updatedAt: now, // Update time
        );
        await userRef.set(newUser.toMap()); // Save user document

        // 4. Create permissions document
        debugPrint('Creating permissions...'); // Debug print for permissions creation
        final permissionRef = _firestore.collection('permissions').doc(uid); // Reference to permissions document
        await permissionRef.set({
          'role': 'client', // User role
          'permissions': [
               'manage_staff',
    'view_customers',
    'view_staff',
    'manage_events',
    'view_events',
    'view_inventory',
    'manage_tasks',
    'view_tasks',
    'manage_menu',
    'view_menu',
    'manage_vehicles',
    'view_vehicles',
    'manage_deliveries',
    'view_deliveries',
            
          ],
          'organizationId': orgId, // Organization ID
          'createdAt': now, // Creation time
          'updatedAt': now, // Update time
        });
        

        debugPrint('Registration completed successfully'); // Debug print for successful registration
        return AuthResult(
          success: true, // Indicate success
          user: newUser, // Return new user data
        );
      } catch (e) {
        // If Firestore operations fail, clean up the auth user
        debugPrint('Error during Firestore operations, cleaning up auth user...'); // Debug print for cleanup
        await authResult.user?.delete(); // Delete auth user
        rethrow; // Rethrow exception
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code}'); // Debug print for Firebase Auth error
      return AuthResult(
        success: false, // Indicate failure
        error: _getReadableError(e.code), // Return readable error message
      );
    } catch (e) {
      debugPrint('Error during registration: $e'); // Debug print for general error
      return AuthResult(
        success: false, // Indicate failure
        error: 'Registration failed: ${e.toString()}', // Return error message
      );
    }
  }

  // Sign in with email and password
  Future<AuthResult> signIn(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, // Email for sign in
        password: password, // Password for sign in
      );
      
      if (result.user != null) {
        final userData = await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .get(); // Get user data from Firestore

        if (!userData.exists) {
          await _auth.signOut(); // Sign out if user data not found
          return AuthResult(
            success: false, // Indicate failure
            error: 'User data not found', // Return error message
          );
        }

        final user = UserModel.fromMap(userData.data()!); // Convert Firestore data to UserModel

        // Check if user is deactivated
        if (user.employmentStatus == 'inactive' && 
            user.role != 'client' && 
            user.role != 'admin') {
          await _auth.signOut(); // Sign out if user is deactivated
          return AuthResult(
            success: false, // Indicate failure
            error: 'Your account has been deactivated', // Return error message
          );
        }

        return AuthResult(
          success: true, // Indicate success
          user: user, // Return user data
        );
      }
      
      return AuthResult(
        success: false, // Indicate failure
        error: 'Failed to sign in', // Return error message
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false, // Indicate failure
        error: _getReadableError(e.code), // Return readable error message
      );
    } catch (e) {
      return AuthResult(
        success: false, // Indicate failure
        error: 'An unexpected error occurred', // Return error message
      );
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut(); // Sign out user
  }

  // Password reset
  Future<AuthResult> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email); // Send password reset email
      return AuthResult(success: true); // Indicate success
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false, // Indicate failure
        error: _getReadableError(e.code), // Return readable error message
      );
    }
  }

  // Convert Firebase error codes to readable messages
  String _getReadableError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email'; // Error message for user not found
      case 'wrong-password':
        return 'Incorrect password'; // Error message for wrong password
      case 'email-already-in-use':
        return 'An account already exists with this email'; // Error message for email already in use
      case 'invalid-email':
        return 'Please enter a valid email address'; // Error message for invalid email
      case 'weak-password':
        return 'Password should be at least 6 characters'; // Error message for weak password
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled. Please contact support.'; // Error message for operation not allowed
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.'; // Error message for too many requests
      case 'requires-recent-login':
        return 'Please sign out and sign in again to perform this action'; // Error message for recent login required
      default:
        return 'An error occurred. Please try again'; // Default error message
    }
  }
}