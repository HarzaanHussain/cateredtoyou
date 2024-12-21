// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cateredtoyou/models/user.dart';
import 'package:flutter/foundation.dart';

class AuthResult {
  final bool success;
  final String? error;
  final UserModel? user;

  AuthResult({
    required this.success,
    this.error,
    this.user,
  });
}

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<AuthResult> signIn(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (result.user != null) {
        final userData = await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .get();

        if (!userData.exists) {
          await _auth.signOut();
          return AuthResult(
            success: false,
            error: 'User data not found',
          );
        }

        final user = UserModel.fromMap(userData.data()!);

        // Check if user is deactivated
        if (user.employmentStatus == 'inactive' && 
            user.role != 'client' && 
            user.role != 'admin') {
          await _auth.signOut();
          return AuthResult(
            success: false,
            error: 'Your account has been deactivated',
          );
        }

        return AuthResult(
          success: true,
          user: user,
        );
      }
      
      return AuthResult(
        success: false,
        error: 'Failed to sign in',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        error: _getReadableError(e.code),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  // Register with email and password
  Future<AuthResult> register({
  required String email,
  required String password,
  required String firstName,
  required String lastName,
  required String phoneNumber,
}) async {
  try {
    debugPrint('Starting registration process...');
    
    final UserCredential result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (result.user != null) {
      // Create organization first
      final orgRef = _firestore.collection('organizations').doc();
      final now = DateTime.now();
      
      // Use a batch to ensure all writes succeed or fail together
      final batch = _firestore.batch();
      
      debugPrint('Creating organization...');
      batch.set(orgRef, {
        'name': '$firstName $lastName\'s Organization',
        'ownerId': result.user!.uid,
        'createdAt': now,
        'updatedAt': now,
        'contactEmail': email,
        'contactPhone': phoneNumber,
      });

      // Create user document
      debugPrint('Creating user document...');
      final userRef = _firestore.collection('users').doc(result.user!.uid);
      final UserModel newUser = UserModel(
        uid: result.user!.uid,
        email: email,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        role: 'client',
        employmentStatus: 'active',
        organizationId: orgRef.id,
        createdBy: result.user!.uid,
        createdAt: now,
        updatedAt: now,
      );
      batch.set(userRef, newUser.toMap());

      // Create initial permissions - THIS IS THE KEY FIX
      debugPrint('Creating permissions...');
      final permissionRef = _firestore.collection('permissions').doc(result.user!.uid);
      batch.set(permissionRef, {
        'role': 'client',
        'permissions': [
          'manage_staff',
          'view_staff',
          'manage_events',
          'view_events',
          'manage_inventory',
          'view_inventory',
          'manage_tasks',
          'view_tasks',
        ],
        'organizationId': orgRef.id,
        'createdAt': now,
        'updatedAt': now,
      });

      // Commit all changes
      await batch.commit();
      debugPrint('Registration completed successfully');

      return AuthResult(
        success: true,
        user: newUser,
      );
    }

    return AuthResult(
      success: false,
      error: 'Failed to create account',
    );
  } catch (e) {
    debugPrint('Error during registration: $e');
    rethrow;
  }
}
  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Password reset
  Future<AuthResult> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        error: _getReadableError(e.code),
      );
    }
  }

  // Convert Firebase error codes to readable messages
  String _getReadableError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'weak-password':
        return 'Password should be at least 6 characters';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      default:
        return 'An error occurred. Please try again';
    }
  }
}