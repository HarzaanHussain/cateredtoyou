import 'package:flutter/foundation.dart'; // Importing foundation package for ChangeNotifier
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore package for database operations
import 'package:firebase_auth/firebase_auth.dart'; // Importing Firebase Auth package for authentication
import 'package:cateredtoyou/models/user_model.dart'; // Importing UserModel for user data
import 'package:cateredtoyou/services/organization_service.dart'; // Importing OrganizationService for organization-related operations
import 'package:cateredtoyou/services/role_permissions.dart'; // Importing RolePermissions for role-based permissions
/// Service class for managing staff-related operations
class StaffService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance for database operations
  final FirebaseAuth _auth = FirebaseAuth.instance; // Firebase Auth instance for authentication
  final OrganizationService _organizationService; // OrganizationService instance for organization-related operations
  final FirebaseAuth _staffAuth = FirebaseAuth.instance; // Separate Firebase Auth instance for staff authentication
 final RolePermissions _rolePermissions = RolePermissions(); // RolePermissions instance for managing permissions

  StaffService(this._organizationService); // Constructor to initialize OrganizationService

  /// Stream to get staff members for the current organization
  Stream<List<UserModel>> getStaffMembers() async* {
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user
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

      final organizationId = userDoc.data()?['organizationId']; // Get the organization ID from user document
      final userRole = userDoc.data()?['role']; // Get the user role from user document

      if (!['client', 'admin', 'manager'].contains(userRole)) {
        yield []; // If user role is not client, admin, or manager, yield an empty list
        return;
      }

      // Query staff members using only organizationId filter
      final query = _firestore
          .collection('users')
          .where('organizationId', isEqualTo: organizationId); // Query users with the same organization ID

      yield* query.snapshots().map((snapshot) {
        try {
          return snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data())) // Map Firestore documents to UserModel
              .where((user) => 
                  // Filter in application code instead of database
                  user.employmentStatus == 'active' &&
                  !['client', 'admin'].contains(user.role)) // Filter active staff members excluding clients and admins
              .toList();
        } catch (e) {
          debugPrint('Error mapping staff data: $e'); // Print error if mapping fails
          return [];
        }
      });
    } catch (e) {
      debugPrint('Error in getStaffMembers: $e'); // Print error if any exception occurs
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
    if (!['manager', 'chef', 'server', 'driver', 'staff'].contains(role)) {
      throw 'Invalid role specified'; // Throw error if role is invalid
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) throw 'Not authenticated'; // Throw error if no user is authenticated

    try {
      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found'; // Throw error if organization is not found
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) throw 'User data not found'; // Throw error if user document is not found
      final userRole = userDoc.get('role');

      if (!['admin', 'client', 'manager'].contains(userRole)) {
        throw 'Insufficient permissions to create staff members'; // Throw error if user does not have permission
      }

      // Use the separate auth instance to create the new user
      final UserCredential newStaffCredential = await _staffAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (newStaffCredential.user == null) {
        throw 'Failed to create authentication account'; // Throw error if user creation fails
      }

      final uid = newStaffCredential.user!.uid;
      debugPrint('Created user with UID: $uid'); // Print the UID of the newly created user

      try {
        await _firestore.runTransaction((transaction) async {
          final now = DateTime.now();

          final userRef = _firestore.collection('users').doc(uid);
          transaction.set(userRef, {
            'uid': uid,
            'email': email,
            'firstName': firstName,
            'lastName': lastName,
            'phoneNumber': phoneNumber,
            'role': role,
            'employmentStatus': 'active',
            'organizationId': organization.id,
            'createdBy': currentUser.uid,
            'createdAt': now,
            'updatedAt': now,
          }); // Set user data in Firestore

         // Use RolePermissions to create permissions
          await _rolePermissions.createUserPermissions(uid, role);
        });
        

        // Sign out from the staff auth instance
        await _staffAuth.signOut();

        notifyListeners(); // Notify listeners about the change
        return true;
      } catch (e) {
        // If Firestore operations fail, clean up the auth account
        await newStaffCredential.user?.delete();
        rethrow; // Rethrow the exception
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code}'); // Print Firebase Auth error code
      if (e.code == 'email-already-in-use') {
        throw 'An account with this email already exists'; // Throw error if email is already in use
      }
      throw 'Failed to create staff account: ${e.message}'; // Throw error if user creation fails
    } catch (e) {
      debugPrint('Error creating staff member: $e'); // Print error if any exception occurs
      rethrow; // Rethrow the exception
    }
  }

  /// Update a staff member's information
  Future<void> updateStaffMember(UserModel staff) async {
    try {
      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found'; // Throw error if organization is not found
      }

      if (staff.organizationId != organization.id) {
        throw 'Staff member belongs to a different organization'; // Throw error if staff belongs to a different organization
      }

      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated'; // Throw error if no user is authenticated

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) throw 'User data not found'; // Throw error if user document is not found
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
      debugPrint('Error updating staff member: $e'); // Print error if any exception occurs
      rethrow; // Rethrow the exception
    }
  }

 

  /// Change a staff member's employment status
  Future<void> changeStaffStatus(String uid, String status) async {
    try {
      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found'; // Throw error if organization is not found
      }

      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated'; // Throw error if no user is authenticated

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) throw 'User data not found'; // Throw error if user document is not found
      final userRole = userDoc.get('role');

      if (!['admin', 'client', 'manager'].contains(userRole)) {
        throw 'Insufficient permissions to change staff status'; // Throw error if user does not have permission
      }

      final staffDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (!staffDoc.exists || staffDoc.data()?['organizationId'] != organization.id) {
        throw 'Staff member not found in your organization'; // Throw error if staff is not found in the organization
      }

      await _firestore
          .collection('users')
          .doc(uid)
          .update({
            'employmentStatus': status,
            'updatedAt': FieldValue.serverTimestamp(),
          }); // Update staff employment status in Firestore

      notifyListeners(); // Notify listeners about the change
    } catch (e) {
      debugPrint('Error changing staff status: $e'); // Print error if any exception occurs
      rethrow; // Rethrow the exception
    }
  }

  /// Reset password for a staff member
  Future<void> resetStaffPassword(String email) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated'; // Throw error if no user is authenticated

      // Verify the user has permission to reset passwords
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) throw 'User data not found'; // Throw error if user document is not found
      final userRole = userDoc.get('role');
      final organizationId = userDoc.get('organizationId');

      if (!['admin', 'client', 'manager'].contains(userRole)) {
        throw 'Insufficient permissions to reset staff password'; // Throw error if user does not have permission
      }

      // First query by email only - this is more efficient
      final staffQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (staffQuery.docs.isEmpty) {
        throw 'Staff member not found'; // Throw error if staff is not found
      }

      final staffDoc = staffQuery.docs.first;
      final staffData = staffDoc.data();

      // Then verify organization
      if (staffData['organizationId'] != organizationId) {
        throw 'Staff member not found in your organization'; // Throw error if staff is not found in the organization
      }

      // Send password reset email
      await _auth.sendPasswordResetEmail(email: email); // Send password reset email
    } catch (e) {
      debugPrint('Error resetting staff password: $e'); // Print error if any exception occurs
      rethrow; // Rethrow the exception
    }
  }
   /// Stream to get departments for the current organization
  Stream<List<String>> getDepartments() async* { 
  try {
    final currentUser = _auth.currentUser; // Get the current authenticated user
    if (currentUser == null) { // If no user is authenticated, yield an empty list
      yield [];
      return;
    }

    final userDoc = await _firestore // Get the current user's document from Firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (!userDoc.exists) {
      yield [];
      return;
    }

    final organizationId = userDoc.data()?['organizationId']; // Get the organization ID from user document

    yield* _firestore // Query departments using only organizationId filter
        .collection('users')
        .where('organizationId', isEqualTo: organizationId)
        .snapshots()
        .map((snapshot) {
          final departments = <String>{};
          for (var doc in snapshot.docs) {
            final userDepts = List<String>.from(doc.data()['departments'] ?? []); // Get departments from user document
            departments.addAll(userDepts);
          }
          return departments.toList();
        });
  } catch (e) { // Print error if any exception occurs
    debugPrint('Error getting departments: $e');
    yield [];
  }
}
}