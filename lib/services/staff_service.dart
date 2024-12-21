import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cateredtoyou/models/user.dart';
import 'package:cateredtoyou/services/organization_service.dart';

class StaffService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OrganizationService _organizationService;

  StaffService(this._organizationService);

  // Get staff members for current organization
  Stream<List<UserModel>> getStaffMembers() async* {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        yield [];
        return;
      }

      // Get the user's organization ID
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (!userDoc.exists) {
        yield [];
        return;
      }

      final organizationId = userDoc.data()?['organizationId'];
      debugPrint('Getting staff for organization: $organizationId');

      // Listen to users collection filtered by organizationId
      yield* _firestore
          .collection('users')
          .where('organizationId', isEqualTo: organizationId)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => UserModel.fromMap(doc.data()))
                .where((user) => user.role != 'client') // Exclude clients
                .toList();
          });

    } catch (e) {
      debugPrint('Error in getStaffMembers: $e');
      yield [];
    }
  }

  Future<bool> createStaffMember({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String role,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw 'Not authenticated';
    
    try {
      debugPrint('Starting staff creation process...');
      
      // 1. Check organization access
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) throw 'User data not found';
      final organizationId = userDoc.get('organizationId');
      final userRole = userDoc.get('role');

      // 2. Verify permissions
      if (!['admin', 'client', 'manager'].contains(userRole)) {
        throw 'Insufficient permissions to create staff members';
      }

      // 3. Create Firebase Auth user
      debugPrint('Creating Firebase Auth user...');
      final UserCredential authResult = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (authResult.user == null) {
        throw 'Failed to create authentication account';
      }

      final uid = authResult.user!.uid;
      debugPrint('Created user with UID: $uid');

      // 4. Create Firestore documents in a transaction
      await _firestore.runTransaction((transaction) async {
        final now = DateTime.now();

        // Create user document
        final userRef = _firestore.collection('users').doc(uid);
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
        });

        // Create permissions document
        final permissionRef = _firestore.collection('permissions').doc(uid);
        transaction.set(permissionRef, {
          'role': role,
          'permissions': _getDefaultPermissions(role),
          'organizationId': organizationId,
          'createdAt': now,
          'updatedAt': now,
        });
      });

      debugPrint('Staff member created successfully');
      notifyListeners();
      return true;

    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code}');
      // Clean up if auth was created but Firestore failed
      final user = _auth.currentUser;
      if (user != null && user.uid != currentUser.uid) {
        await user.delete();
      }
      
      if (e.code == 'email-already-in-use') {
        throw 'An account with this email already exists';
      }
      throw 'Failed to create staff account: ${e.message}';
    } catch (e) {
      debugPrint('Error creating staff member: $e');
      // Clean up if auth was created but Firestore failed
      final user = _auth.currentUser;
      if (user != null && user.uid != currentUser.uid) {
        await user.delete();
      }
      rethrow;
    }
  }

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
        ];
      case 'chef':
        return [
          'view_events',
          'view_inventory',
          'manage_inventory',
          'view_tasks',
          'manage_kitchen_tasks',
        ];
      case 'server':
        return [
          'view_events',
          'view_tasks',
          'update_service_tasks',
          'view_inventory',
        ];
      case 'driver':
        return [
          'view_events',
          'view_tasks',
          'update_delivery_tasks',
          'view_inventory',
        ];
      case 'staff':
        return [
          'view_events',
          'view_tasks',
          'view_inventory',
          'update_assigned_tasks',
        ];
      default:
        return [
          'view_events',
          'view_tasks',
        ];
    }
  }

  // Update staff member
  Future<void> updateStaffMember(UserModel staff) async {
    try {
      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found';
      }

      if (staff.organizationId != organization.id) {
        throw 'Staff member belongs to a different organization';
      }

      // Verify current user has permission
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) throw 'User data not found';
      final userRole = userDoc.get('role');

      if (!['admin', 'client', 'manager'].contains(userRole)) {
        throw 'Insufficient permissions to update staff members';
      }

      // Start a batch write
      final batch = _firestore.batch();

      // Update user document
      final userRef = _firestore.collection('users').doc(staff.uid);
      batch.update(userRef, {
        ...staff.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update permissions
      final permissionRef = _firestore.collection('permissions').doc(staff.uid);
      batch.update(permissionRef, {
        'role': staff.role,
        'permissions': _getDefaultPermissions(staff.role),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating staff member: $e');
      rethrow;
    }
  }

  // Change staff status
  Future<void> changeStaffStatus(String uid, String status) async {
    try {
      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found';
      }

      // Verify current user has permission
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) throw 'User data not found';
      final userRole = userDoc.get('role');

      if (!['admin', 'client', 'manager'].contains(userRole)) {
        throw 'Insufficient permissions to change staff status';
      }

      // Get staff document
      final staffDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (!staffDoc.exists || staffDoc.data()?['organizationId'] != organization.id) {
        throw 'Staff member not found in your organization';
      }

      // Update staff status
      await _firestore
          .collection('users')
          .doc(uid)
          .update({
            'employmentStatus': status,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      notifyListeners();
    } catch (e) {
      debugPrint('Error changing staff status: $e');
      rethrow;
    }
  }

  // Reset staff password
  Future<void> resetStaffPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Error resetting staff password: $e');
      rethrow;
    }
  }

  // Delete staff member (Additional safety checks)
  Future<void> deleteStaffMember(String uid) async {
    try {
      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found';
      }

      // Verify current user has permission
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) throw 'User data not found';
      final userRole = userDoc.get('role');

      if (!['admin', 'client'].contains(userRole)) {
        throw 'Insufficient permissions to delete staff members';
      }

      // Get staff document
      final staffDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (!staffDoc.exists || staffDoc.data()?['organizationId'] != organization.id) {
        throw 'Staff member not found in your organization';
      }

      // Start a batch write
      final batch = _firestore.batch();

      // Delete user document
      batch.delete(_firestore.collection('users').doc(uid));

      // Delete permissions document
      batch.delete(_firestore.collection('permissions').doc(uid));

      await batch.commit();

      // Note: Firebase Auth user deletion requires admin SDK
      // For client-side, we'll mark the user as inactive instead
      await _firestore
          .collection('users')
          .doc(uid)
          .update({
            'employmentStatus': 'inactive',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting staff member: $e');
      rethrow;
    }
  }
}