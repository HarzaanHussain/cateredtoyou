import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:cateredtoyou/models/user.dart';

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
      
      // 1. Create Firebase Auth user
      final UserCredential authResult = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (authResult.user == null) {
        throw 'Failed to create user account';
      }

      final uid = authResult.user!.uid;
      debugPrint('Created auth user with ID: $uid');

      try {
        final now = DateTime.now();

        // 2. Create organization
        debugPrint('Creating organization...');
        final orgRef = _firestore.collection('organizations').doc();
        final orgId = orgRef.id;
        await orgRef.set({
          'name': '$firstName $lastName\'s Organization',
          'ownerId': uid,
          'createdAt': now,
          'updatedAt': now,
          'contactEmail': email,
          'contactPhone': phoneNumber,
        });

        // 3. Create user document
        debugPrint('Creating user document...');
        final userRef = _firestore.collection('users').doc(uid);
        final UserModel newUser = UserModel(
          uid: uid,
          email: email,
          firstName: firstName,
          lastName: lastName,
          phoneNumber: phoneNumber,
          role: 'client',
          employmentStatus: 'active',
          organizationId: orgId,
          createdBy: uid,
          createdAt: now,
          updatedAt: now,
        );
        await userRef.set(newUser.toMap());

        // 4. Create permissions document
        debugPrint('Creating permissions...');
        final permissionRef = _firestore.collection('permissions').doc(uid);
        await permissionRef.set({
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
          'organizationId': orgId,
          'createdAt': now,
          'updatedAt': now,
        });

        debugPrint('Registration completed successfully');
        return AuthResult(
          success: true,
          user: newUser,
        );
      } catch (e) {
        // If Firestore operations fail, clean up the auth user
        debugPrint('Error during Firestore operations, cleaning up auth user...');
        await authResult.user?.delete();
        rethrow;
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code}');
      return AuthResult(
        success: false,
        error: _getReadableError(e.code),
      );
    } catch (e) {
      debugPrint('Error during registration: $e');
      return AuthResult(
        success: false,
        error: 'Registration failed: ${e.toString()}',
      );
    }
  }

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
      case 'requires-recent-login':
        return 'Please sign out and sign in again to perform this action';
      default:
        return 'An error occurred. Please try again';
    }
  }
}