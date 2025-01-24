import 'package:cateredtoyou/main.dart';
import 'package:flutter/foundation.dart'; // Importing foundation package for ChangeNotifier
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore package for database operations
import 'package:firebase_auth/firebase_auth.dart'; // Importing Firebase Auth package for authentication
import 'package:cateredtoyou/models/user_model.dart'; // Importing UserModel for user data
import 'package:cateredtoyou/services/organization_service.dart'; // Importing OrganizationService for organization-related operations
import 'package:cateredtoyou/services/role_permissions.dart'; // Importing RolePermissions for role-based permissions

/// Service class for managing staff-related operations
class StaffService extends ChangeNotifier {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Firestore instance for database operations
  final FirebaseAuth _auth =
      FirebaseAuth.instance; // Firebase Auth instance for authentication
  final OrganizationService
      _organizationService; // OrganizationService instance for organization-related operations
  
  final RolePermissions _rolePermissions =
      RolePermissions(); // RolePermissions instance for managing permissions

  StaffService(
      this._organizationService); // Constructor to initialize OrganizationService

  /// Stream to get staff members for the current organization
  Stream<List<UserModel>> getStaffMembers() async* {
    try {
      final currentUser =
          _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) {
        yield []; // If no user is authenticated, yield an empty list
        return;
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get(); // Get the current user's document from Firestore

      if (!userDoc.exists) {
        yield []; // If user document does not exist, yield an empty list
        return;
      }

      final organizationId = userDoc.data()?[
          'organizationId']; // Get the organization ID from user document
      final userRole =
          userDoc.data()?['role']; // Get the user role from user document

      if (!['client', 'admin', 'manager'].contains(userRole)) {
        yield []; // If user role is not client, admin, or manager, yield an empty list
        return;
      }

      // Query staff members using only organizationId filter
      final query = _firestore.collection('users').where('organizationId',
          isEqualTo:
              organizationId); // Query users with the same organization ID

      yield* query.snapshots().map((snapshot) {
        try {
          return snapshot.docs
              .map((doc) => UserModel.fromMap(
                  doc.data())) // Map Firestore documents to UserModel
              .where((user) =>
                  // Filter in application code instead of database
                  user.employmentStatus == 'active' &&
                  !['client', 'admin'].contains(user
                      .role)) // Filter active staff members excluding clients and admins
              .toList();
        } catch (e) {
          debugPrint(
              'Error mapping staff data: $e'); // Print error if mapping fails
          return [];
        }
      });
    } catch (e) {
      debugPrint(
          'Error in getStaffMembers: $e'); // Print error if any exception occurs
      yield [];
    }
  }

  /// Create a new staff member
  Future<bool> createStaffMember({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String role,
  }) async {
    debugPrint('Starting staff member creation process...'); // Debug logging

    // Input validation
    if (email.trim().isEmpty ||
        password.trim().isEmpty ||
        firstName.trim().isEmpty ||
        lastName.trim().isEmpty ||
        phoneNumber.trim().isEmpty ||
        role.trim().isEmpty) {
      debugPrint('Validation failed: Empty fields detected');
      throw 'All fields are required'; // Throw error if any field is empty
    }

    if (!['manager', 'chef', 'server', 'driver', 'staff'].contains(role)) {
      debugPrint('Validation failed: Invalid role - $role');
      throw 'Invalid role specified'; // Throw error if role is invalid
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('Error: No authenticated user found');
      throw 'Not authenticated'; // Throw error if no user is authenticated
    }

    try {
      debugPrint('Fetching organization details...');
      final organization =
          await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        debugPrint('Error: Organization not found');
        throw 'Organization not found'; // Throw error if organization is not found
      }

      // Verify permissions
      debugPrint('Verifying user permissions...');
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (!userDoc.exists) {
        debugPrint('Error: Current user document not found');
        throw 'User data not found'; // Throw error if user document is not found
      }

      final userRole = userDoc.get('role');
      debugPrint('Current user role: $userRole');

      if (!['admin', 'client', 'manager'].contains(userRole)) {
        debugPrint('Error: Insufficient permissions for role - $userRole');
        throw 'Insufficient permissions to create staff members'; // Throw error if user does not have permission
      }

      // Create auth account first
      debugPrint('Creating Firebase Auth account...');
      final credential =
          await FirebaseSecondary.secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user == null) {
        debugPrint('Error: Failed to create Firebase Auth account');
        throw 'Failed to create authentication account'; // Throw error if user creation fails
      }

      final newUserId = credential.user!.uid;
      debugPrint('Created auth account with UID: $newUserId');

      // Then create Firestore records
      try {
        debugPrint('Creating Firestore records...');
        await _firestore.runTransaction((transaction) async {
          final now = DateTime.now();

          // Create user document using the auth UID
          debugPrint('Creating user document...');
          final userRef = _firestore.collection('users').doc(newUserId);
          final userData = {
            'uid': newUserId,
            'email': email.trim(),
            'firstName': firstName.trim(),
            'lastName': lastName.trim(),
            'phoneNumber': phoneNumber.trim(),
            'role': role,
            'employmentStatus': 'active',
            'organizationId': organization.id,
            'createdBy': currentUser.uid,
            'createdAt': now,
            'updatedAt': now,
          };

          transaction.set(userRef, userData);
          debugPrint('User document created successfully');

          // Create permissions
          debugPrint('Creating permissions document...');
          final permissionRef =
              _firestore.collection('permissions').doc(newUserId);
          final permissions = _rolePermissions.getPermissionsForRole(role);

          transaction.set(permissionRef, {
            'role': role,
            'permissions': permissions,
            'organizationId': organization.id,
            'createdAt': now,
            'updatedAt': now,
          });
          debugPrint('Permissions document created successfully');
          debugPrint('Assigned permissions: ${permissions.join(", ")}');
        });

        debugPrint('Staff member creation completed successfully');
        notifyListeners(); // Notify listeners about the change
        return true;
      } catch (e) {
        // Rollback auth account if Firestore fails
        debugPrint('Error during Firestore operations, attempting rollback...');
        try {
          await credential.user?.delete();
          debugPrint('Auth account rolled back successfully');
        } catch (deleteError) {
          debugPrint('Error during auth account rollback: $deleteError');
        }
        debugPrint('Firestore error: $e');
        rethrow; // Rethrow the exception
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'email-already-in-use':
          throw 'An account with this email already exists'; // Throw error if email is already in use
        case 'invalid-email':
          throw 'Invalid email format'; // Throw error if email format is invalid
        case 'operation-not-allowed':
          throw 'Email/password accounts are not enabled'; // Throw error if email/password accounts are not enabled
        case 'weak-password':
          throw 'The password provided is too weak'; // Throw error if password is too weak
        default:
          throw 'Authentication error: ${e.message}'; // Throw error for other authentication issues
      }
    } catch (e) {
      debugPrint('Unexpected error during staff creation: $e');
      rethrow; // Rethrow the exception
    }
  }

  /// Update a staff member's information
  Future<void> updateStaffMember(UserModel staff) async {
    try {
      final organization =
          await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found'; // Throw error if organization is not found
      }

      if (staff.organizationId != organization.id) {
        throw 'Staff member belongs to a different organization'; // Throw error if staff belongs to a different organization
      }

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'Not authenticated'; // Throw error if no user is authenticated
      }

      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (!userDoc.exists) {
        throw 'User data not found'; // Throw error if user document is not found
      }
      final userRole = userDoc.get('role');

      if (!['admin', 'client', 'manager'].contains(userRole)) {
        throw 'Insufficient permissions to update staff members'; // Throw error if user does not have permission
      }

      final batch = _firestore.batch();

      final userRef = _firestore.collection('users').doc(staff.uid);
      batch.update(userRef, {
        ...staff.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }); // Update user data in Firestore

      // Use RolePermissions to update permissions
      await _rolePermissions.updateUserPermissions(staff.uid, staff.role);

      await batch.commit(); // Commit the batch update
      notifyListeners(); // Notify listeners about the change
    } catch (e) {
      debugPrint(
          'Error updating staff member: $e'); // Print error if any exception occurs
      rethrow; // Rethrow the exception
    }
  }

  /// Change a staff member's employment status
  Future<void> changeStaffStatus(String uid, String status) async {
    try {
      final organization =
          await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found'; // Throw error if organization is not found
      }

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'Not authenticated'; // Throw error if no user is authenticated
      }

      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (!userDoc.exists) {
        throw 'User data not found'; // Throw error if user document is not found
      }
      final userRole = userDoc.get('role');

      if (!['admin', 'client', 'manager'].contains(userRole)) {
        throw 'Insufficient permissions to change staff status'; // Throw error if user does not have permission
      }

      final staffDoc = await _firestore.collection('users').doc(uid).get();

      if (!staffDoc.exists ||
          staffDoc.data()?['organizationId'] != organization.id) {
        throw 'Staff member not found in your organization'; // Throw error if staff is not found in the organization
      }

      await _firestore.collection('users').doc(uid).update({
        'employmentStatus': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }); // Update staff employment status in Firestore

      notifyListeners(); // Notify listeners about the change
    } catch (e) {
      debugPrint(
          'Error changing staff status: $e'); // Print error if any exception occurs
      rethrow; // Rethrow the exception
    }
  }

  /// Reset password for a staff member
  Future<void> resetStaffPassword(String email) async {
    debugPrint(
        'Starting password reset process for email: $email'); // Debug logging

    try {
      final currentUser =
          _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) {
        debugPrint('Error: No authenticated user found');
        throw 'Not authenticated'; // Throw error if no user is authenticated
      }

      // Verify the user has permission to reset passwords
      debugPrint('Verifying user permissions...');
      final currentUserDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get(); // Get the current user's document from Firestore

      if (!currentUserDoc.exists) {
        debugPrint('Error: Current user document not found');
        throw 'User data not found'; // Throw error if user document is not found
      }

      final userRole =
          currentUserDoc.get('role'); // Get the user role from user document
      final organizationId = currentUserDoc
          .get('organizationId'); // Get the organization ID from user document
      debugPrint('Current user role: $userRole');

      if (!['admin', 'client', 'manager'].contains(userRole)) {
        debugPrint('Error: Insufficient permissions for role - $userRole');
        throw 'Insufficient permissions to reset staff password'; // Throw error if user does not have permission
      }

      // Use direct document query instead of where clause
      debugPrint('Querying staff member document...');
      final staffQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .where('organizationId', isEqualTo: organizationId)
          .limit(1)
          .get(); // Query staff member document by email and organization ID

      if (staffQuery.docs.isEmpty) {
        debugPrint('Error: Staff member not found');
        throw 'Staff member not found'; // Throw error if staff member is not found
      }

      final staffData =
          staffQuery.docs.first.data(); // Get the staff member data

      // Additional check for staff role
      if (!['manager', 'chef', 'server', 'driver', 'staff']
          .contains(staffData['role'])) {
        debugPrint('Error: Cannot reset password for non-staff user');
        throw 'Invalid user role for password reset'; // Throw error if user role is invalid for password reset
      }

      // Send password reset email using the main auth instance
      debugPrint('Sending password reset email...');
      await _auth.sendPasswordResetEmail(
          email: email); // Send password reset email

      debugPrint('Password reset email sent successfully'); // Debug logging
    } catch (e) {
      debugPrint(
          'Error resetting staff password: $e'); // Print error if any exception occurs
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            throw 'No user found with this email'; // Throw error if no user is found with the email
          case 'invalid-email':
            throw 'Invalid email address'; // Throw error if email address is invalid
          default:
            throw 'Failed to send password reset email: ${e.message}'; // Throw error for other authentication issues
        }
      }
      rethrow; // Rethrow the exception
    }
  }

  /// Stream to get departments for the current organization
  Stream<List<String>> getDepartments() async* {
    try {
      final currentUser =
          _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) {
        // If no user is authenticated, yield an empty list
        yield [];
        return;
      }

      final userDoc =
          await _firestore // Get the current user's document from Firestore
              .collection('users')
              .doc(currentUser.uid)
              .get();

      if (!userDoc.exists) {
        yield [];
        return;
      }

      final organizationId = userDoc.data()?[
          'organizationId']; // Get the organization ID from user document

      yield* _firestore // Query departments using only organizationId filter
          .collection('users')
          .where('organizationId', isEqualTo: organizationId)
          .snapshots()
          .map((snapshot) {
        final departments = <String>{};
        for (var doc in snapshot.docs) {
          final userDepts = List<String>.from(doc.data()['departments'] ??
              []); // Get departments from user document
          departments.addAll(userDepts);
        }
        return departments.toList();
      });
    } catch (e) {
      // Print error if any exception occurs
      debugPrint('Error getting departments: $e');
      yield [];
    }
  }
}
