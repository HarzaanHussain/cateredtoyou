import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cateredtoyou/models/user.dart';
import 'package:cateredtoyou/services/organization_service.dart';


/// Service class for managing staff-related operations
class StaffService extends ChangeNotifier {
  /// Instance of FirebaseFirestore for database operations
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Instance of FirebaseAuth for authentication operations
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Instance of OrganizationService for organization-related operations
  final OrganizationService _organizationService;

  /// Constructor to initialize OrganizationService
  StaffService(this._organizationService);

  /// Cached organization ID to prevent multiple fetches
  String? _cachedOrgId;

  /// Stream to get staff members for the current organization
  Stream<List<UserModel>> getStaffMembers() async* {
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) {
        yield []; // Yield an empty list if no user is authenticated
        return;
      }

      String? organizationId = _cachedOrgId; // Use cached organization ID if available

      if (organizationId == null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get(); // Get the user's document from Firestore

        if (!userDoc.exists) {
          yield []; // Yield an empty list if user document does not exist
          return;
        }

        organizationId = userDoc.data()?['organizationId']; // Get organization ID from user document
        _cachedOrgId = organizationId; // Cache the organization ID
      }

      if (organizationId == null) {
        debugPrint('No organization ID found'); // Log if no organization ID is found
        yield []; // Yield an empty list if no organization ID is found
        return;
      }

      debugPrint('Getting staff for organization: $organizationId'); // Log the organization ID

      yield* _firestore
          .collection('users')
          .where('organizationId', isEqualTo: organizationId)
          .snapshots()
          .handleError((error) {
            debugPrint('Error in staff stream: $error'); // Log any errors in the stream
            return [];
          })
          .map((snapshot) {
            try {
              return snapshot.docs
                  .map((doc) => UserModel.fromMap(doc.data()))
                  .where((user) => user.role != 'client') // Exclude clients from the list
                  .toList();
            } catch (e) {
              debugPrint('Error mapping staff data: $e'); // Log any errors in mapping data
              return [];
            }
          });

    } catch (e) {
      debugPrint('Error in getStaffMembers: $e'); // Log any errors in the method
      yield []; // Yield an empty list if an error occurs
    }
  }

  /// Clear cached organization ID when needed
  void clearCache() {
    _cachedOrgId = null; // Clear the cached organization ID
    notifyListeners(); // Notify listeners of the change
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
    final currentUser = _auth.currentUser; // Get the current authenticated user
    if (currentUser == null) throw 'Not authenticated'; // Throw an error if no user is authenticated

    try {
      debugPrint('Starting staff creation process...'); // Log the start of the staff creation process

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get(); // Get the current user's document from Firestore

      if (!userDoc.exists) throw 'User data not found'; // Throw an error if user document does not exist
      final organizationId = userDoc.get('organizationId'); // Get organization ID from user document
      final userRole = userDoc.get('role'); // Get user role from user document

      if (!['admin', 'client', 'manager'].contains(userRole)) {
        throw 'Insufficient permissions to create staff members'; // Throw an error if user does not have permission
      }

      debugPrint('Creating Firebase Auth user...'); // Log the creation of Firebase Auth user
      final UserCredential authResult = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      ); // Create a new Firebase Auth user

      if (authResult.user == null) {
        throw 'Failed to create authentication account'; // Throw an error if user creation fails
      }

      final uid = authResult.user!.uid; // Get the UID of the created user
      debugPrint('Created user with UID: $uid'); // Log the UID of the created user

      await _firestore.runTransaction((transaction) async {
        final now = DateTime.now(); // Get the current date and time

        final userRef = _firestore.collection('users').doc(uid); // Reference to the new user document
        transaction.set(userRef, {
          'uid': uid,
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
          'phoneNumber': phoneNumber,
          'role': role,
          'employmentStatus': 'active',
          'organizationId': organizationId,
          'createdBy': currentUser.uid,
          'createdAt': now,
          'updatedAt': now,
        }); // Set the new user document data

        final permissionRef = _firestore.collection('permissions').doc(uid); // Reference to the new permissions document
        transaction.set(permissionRef, {
          'role': role,
          'permissions': _getDefaultPermissions(role),
          'organizationId': organizationId,
          'createdAt': now,
          'updatedAt': now,
        }); // Set the new permissions document data
      });

      debugPrint('Staff member created successfully'); // Log the successful creation of staff member
      notifyListeners(); // Notify listeners of the change
      return true;

    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code}'); // Log any Firebase Auth errors
      final user = _auth.currentUser;
      if (user != null && user.uid != currentUser.uid) {
        await user.delete(); // Delete the user if authentication was created but Firestore failed
      }

      if (e.code == 'email-already-in-use') {
        throw 'An account with this email already exists'; // Throw an error if email is already in use
      }
      throw 'Failed to create staff account: ${e.message}'; // Throw a generic error for other cases
    } catch (e) {
      debugPrint('Error creating staff member: $e'); // Log any other errors
      final user = _auth.currentUser;
      if (user != null && user.uid != currentUser.uid) {
        await user.delete(); // Delete the user if authentication was created but Firestore failed
      }
      rethrow; // Rethrow the error
    }
  }

  /// Get default permissions based on role
  List<String> _getDefaultPermissions(String role) {
    switch (role) {
      case 'manager':
        return [
          'view_staff',
          'manage_events',
          'view_events',
          'manage_inventory',
          'view_inventory',
          'manage_tasks',
          'view_tasks',
        ]; // Permissions for manager role
      case 'chef':
        return [
          'view_events',
          'view_inventory',
          'manage_inventory',
          'view_tasks',
          'manage_kitchen_tasks',
        ]; // Permissions for chef role
      case 'server':
        return [
          'view_events',
          'view_tasks',
          'update_service_tasks',
          'view_inventory',
        ]; // Permissions for server role
      case 'driver':
        return [
          'view_events',
          'view_tasks',
          'update_delivery_tasks',
          'view_inventory',
        ]; // Permissions for driver role
      case 'staff':
        return [
          'view_events',
          'view_tasks',
          'view_inventory',
          'update_assigned_tasks',
        ]; // Permissions for staff role
      default:
        return [
          'view_events',
          'view_tasks',
        ]; // Default permissions
    }
  }

  /// Update a staff member's information
  Future<void> updateStaffMember(UserModel staff) async {
    try {
      final organization = await _organizationService.getCurrentUserOrganization(); // Get the current user's organization
      if (organization == null) {
        throw 'Organization not found'; // Throw an error if organization is not found
      }

      if (staff.organizationId != organization.id) {
        throw 'Staff member belongs to a different organization'; // Throw an error if staff belongs to a different organization
      }

      final currentUser = _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) throw 'Not authenticated'; // Throw an error if no user is authenticated

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get(); // Get the current user's document from Firestore

      if (!userDoc.exists) throw 'User data not found'; // Throw an error if user document does not exist
      final userRole = userDoc.get('role'); // Get user role from user document

      if (!['admin', 'client', 'manager'].contains(userRole)) {
        throw 'Insufficient permissions to update staff members'; // Throw an error if user does not have permission
      }

      final batch = _firestore.batch(); // Start a batch write

      final userRef = _firestore.collection('users').doc(staff.uid); // Reference to the staff user document
      batch.update(userRef, {
        ...staff.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }); // Update the staff user document

      final permissionRef = _firestore.collection('permissions').doc(staff.uid); // Reference to the staff permissions document
      batch.update(permissionRef, {
        'role': staff.role,
        'permissions': _getDefaultPermissions(staff.role),
        'updatedAt': FieldValue.serverTimestamp(),
      }); // Update the staff permissions document

      await batch.commit(); // Commit the batch write
      notifyListeners(); // Notify listeners of the change
    } catch (e) {
      debugPrint('Error updating staff member: $e'); // Log any errors
      rethrow; // Rethrow the error
    }
  }

  /// Change a staff member's employment status
  Future<void> changeStaffStatus(String uid, String status) async {
    try {
      final organization = await _organizationService.getCurrentUserOrganization(); // Get the current user's organization
      if (organization == null) {
        throw 'Organization not found'; // Throw an error if organization is not found
      }

      final currentUser = _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) throw 'Not authenticated'; // Throw an error if no user is authenticated

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get(); // Get the current user's document from Firestore

      if (!userDoc.exists) throw 'User data not found'; // Throw an error if user document does not exist
      final userRole = userDoc.get('role'); // Get user role from user document

      if (!['admin', 'client', 'manager'].contains(userRole)) {
        throw 'Insufficient permissions to change staff status'; // Throw an error if user does not have permission
      }

      final staffDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get(); // Get the staff user's document from Firestore

      if (!staffDoc.exists || staffDoc.data()?['organizationId'] != organization.id) {
        throw 'Staff member not found in your organization'; // Throw an error if staff is not found in the organization
      }

      await _firestore
          .collection('users')
          .doc(uid)
          .update({
            'employmentStatus': status,
            'updatedAt': FieldValue.serverTimestamp(),
          }); // Update the staff user's employment status

      notifyListeners(); // Notify listeners of the change
    } catch (e) {
      debugPrint('Error changing staff status: $e'); // Log any errors
      rethrow; // Rethrow the error
    }
  }

  /// Reset a staff member's password
  Future<void> resetStaffPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email); // Send a password reset email
    } catch (e) {
      debugPrint('Error resetting staff password: $e'); // Log any errors
      rethrow; // Rethrow the error
    }
  }

  /// Delete a staff member
  Future<void> deleteStaffMember(String uid) async {
    try {
      final organization = await _organizationService.getCurrentUserOrganization(); // Get the current user's organization
      if (organization == null) {
        throw 'Organization not found'; // Throw an error if organization is not found
      }

      final currentUser = _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) throw 'Not authenticated'; // Throw an error if no user is authenticated

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get(); // Get the current user's document from Firestore

      if (!userDoc.exists) throw 'User data not found'; // Throw an error if user document does not exist
      final userRole = userDoc.get('role'); // Get user role from user document

      if (!['admin', 'client'].contains(userRole)) {
        throw 'Insufficient permissions to delete staff members'; // Throw an error if user does not have permission
      }

      final staffDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get(); // Get the staff user's document from Firestore

      if (!staffDoc.exists || staffDoc.data()?['organizationId'] != organization.id) {
        throw 'Staff member not found in your organization'; // Throw an error if staff is not found in the organization
      }

      final batch = _firestore.batch(); // Start a batch write

      batch.delete(_firestore.collection('users').doc(uid)); // Delete the staff user document

      batch.delete(_firestore.collection('permissions').doc(uid)); // Delete the staff permissions document

      await batch.commit(); // Commit the batch write

      await _firestore
          .collection('users')
          .doc(uid)
          .update({
            'employmentStatus': 'inactive',
            'updatedAt': FieldValue.serverTimestamp(),
          }); // Mark the user as inactive instead of deleting from Firebase Auth

      notifyListeners(); // Notify listeners of the change
    } catch (e) {
      debugPrint('Error deleting staff member: $e'); // Log any errors
      rethrow; // Rethrow the error
    }
  }
}