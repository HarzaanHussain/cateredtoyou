import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cateredtoyou/models/organization.dart';

class OrganizationService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user's organization
  Future<Organization?> getCurrentUserOrganization() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return null;

      final orgId = userDoc.data()?['organizationId'];
      if (orgId == null) return null;

      final orgDoc = await _firestore
          .collection('organizations')
          .doc(orgId)
          .get();

      if (!orgDoc.exists) return null;

      return Organization.fromMap(orgDoc.data()!, orgDoc.id);
    } catch (e) {
      debugPrint('Error getting organization: $e');
      return null;
    }
  }

  // Create new organization
  Future<Organization> createOrganization({
    required String name,
    String? contactEmail,
    String? contactPhone,
    String? address,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final orgRef = _firestore.collection('organizations').doc();
      
      final now = DateTime.now();
      final organization = Organization(
        id: orgRef.id,
        name: name,
        ownerId: user.uid,
        createdAt: now,
        updatedAt: now,
        contactEmail: contactEmail,
        contactPhone: contactPhone,
        address: address,
      );

      await orgRef.set(organization.toMap());

      // Update user with organization ID
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({
            'organizationId': orgRef.id,
            'updatedAt': now,
          });

      notifyListeners();
      return organization;
    } catch (e) {
      debugPrint('Error creating organization: $e');
      rethrow;
    }
  }

  // Update organization
  Future<void> updateOrganization(Organization organization) async {
    try {
      await _firestore
          .collection('organizations')
          .doc(organization.id)
          .update(organization.toMap());

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating organization: $e');
      rethrow;
    }
  }

  // Get organization members count
  Future<int> getOrganizationMembersCount(String organizationId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('organizationId', isEqualTo: organizationId)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting members count: $e');
      return 0;
    }
  }

  // Check if user has organization access
  Future<bool> hasOrganizationAccess(String organizationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return false;

      return userDoc.data()?['organizationId'] == organizationId;
    } catch (e) {
      debugPrint('Error checking organization access: $e');
      return false;
    }
  }
}