// lib/services/staff_service.dart

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

      // First, get the user's organization ID
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

      // Now listen to users collection filtered by organizationId
      yield* _firestore
          .collection('users')
          .where('organizationId', isEqualTo: organizationId)
          .snapshots()
          .map((snapshot) {
            debugPrint('Got ${snapshot.docs.length} staff members');
            return snapshot.docs
                .map((doc) {
                  final data = doc.data();
                  debugPrint('Processing staff member: ${data['email']}');
                  return UserModel.fromMap(data);
                })
                .where((user) => user.role != 'client') // Exclude clients from the list
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
  final authInstance = FirebaseAuth.instance;
  final currentUser = authInstance.currentUser;
  
  if (currentUser == null) throw 'Not authenticated';
  
  try {
    debugPrint('Starting staff creation process...');
    
    // 1. Get organization ID from current user
    final orgDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (!orgDoc.exists) throw 'Organization data not found';
    final organizationId = orgDoc.get('organizationId');
    
    // 2. Create the staff account using admin SDK
    debugPrint('Creating staff authentication...');
    await _firestore.runTransaction((transaction) async {
      // Create user document first
      final userRef = _firestore.collection('users').doc();
      final now = DateTime.now();
      
      // Create user document
      transaction.set(userRef, {
        'uid': userRef.id,
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
      final permissionRef = _firestore.collection('permissions').doc(userRef.id);
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

  } catch (e) {
    debugPrint('Error creating staff member: $e');
    rethrow;
  }
}

  List<String> _getDefaultPermissions(String role) {
    switch (role) {
      case 'manager':
        return [
          'view_events',
          'manage_events',
          'view_inventory',
          'manage_inventory',
          'view_tasks',
          'manage_tasks',
        ];
      case 'chef':
        return [
          'view_events',
          'view_inventory',
          'manage_inventory',
          'view_tasks',
        ];
      case 'server':
        return [
          'view_events',
          'view_tasks',
          'update_tasks',
        ];
      case 'driver':
        return [
          'view_events',
          'view_tasks',
          'update_tasks',
        ];
        case 'staff':
        return [
          'view_events',
          'view_tasks',
          'update_tasks',
          'view_inventory',
          
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

    // Start a batch write
    final batch = _firestore.batch();

    // Update user document
    batch.update(
      _firestore.collection('users').doc(staff.uid),
      staff.toMap()
    );

    // Update permissions
    batch.update(
      _firestore.collection('permissions').doc(staff.uid),
      {
        'role': staff.role,
        'permissions': _getDefaultPermissions(staff.role),
        'updatedAt': DateTime.now(),
      }
    );

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

      final staffDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (!staffDoc.exists || staffDoc.data()?['organizationId'] != organization.id) {
        throw 'Staff member not found in your organization';
      }

      await _firestore
          .collection('users')
          .doc(uid)
          .update({
            'employmentStatus': status,
            'updatedAt': DateTime.now(),
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
}