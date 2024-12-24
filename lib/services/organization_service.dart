import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cateredtoyou/models/organization_model.dart';

/// Service class for managing organizations and user-organization relationships.
class OrganizationService extends ChangeNotifier {
  /// Instance of FirebaseFirestore for database operations.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Instance of FirebaseAuth for authentication operations.
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Retrieves the current user's organization.
  /// 
  /// Returns an [Organization] object if the user is authenticated and belongs to an organization,
  /// otherwise returns null.
  Future<Organization?> getCurrentUserOrganization() async {
    try {
      final user = _auth.currentUser; // Get the currently authenticated user.
      if (user == null) return null; // Return null if no user is authenticated.

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get(); // Get the user's document from Firestore.

      if (!userDoc.exists) return null; // Return null if the user document does not exist.

      final orgId = userDoc.data()?['organizationId']; // Get the organization ID from the user document.
      if (orgId == null) return null; // Return null if the organization ID is not found.

      final orgDoc = await _firestore
          .collection('organizations')
          .doc(orgId)
          .get(); // Get the organization document from Firestore.

      if (!orgDoc.exists) return null; // Return null if the organization document does not exist.

      return Organization.fromMap(orgDoc.data()!, orgDoc.id); // Return the organization object.
    } catch (e) {
      debugPrint('Error getting organization: $e'); // Print error message if an exception occurs.
      return null; // Return null in case of an error.
    }
  }

  /// Creates a new organization.
  /// 
  /// Takes the organization's name, contact email, contact phone, and address as parameters.
  /// Returns the created [Organization] object.
  Future<Organization> createOrganization({
    required String name,
    String? contactEmail,
    String? contactPhone,
    String? address,
  }) async {
    try {
      final user = _auth.currentUser; // Get the currently authenticated user.
      if (user == null) throw 'User not authenticated'; // Throw an error if no user is authenticated.

      final orgRef = _firestore.collection('organizations').doc(); // Create a new document reference for the organization.
      
      final now = DateTime.now(); // Get the current date and time.
      final organization = Organization(
        id: orgRef.id,
        name: name,
        ownerId: user.uid,
        createdAt: now,
        updatedAt: now,
        contactEmail: contactEmail,
        contactPhone: contactPhone,
        address: address,
      ); // Create a new organization object.

      await orgRef.set(organization.toMap()); // Save the organization object to Firestore.

      // Update the user document with the organization ID.
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({
            'organizationId': orgRef.id,
            'updatedAt': now,
          });

      notifyListeners(); // Notify listeners about the change.
      return organization; // Return the created organization object.
    } catch (e) {
      debugPrint('Error creating organization: $e'); // Print error message if an exception occurs.
      rethrow; // Rethrow the exception.
    }
  }

  /// Updates an existing organization.
  /// 
  /// Takes an [Organization] object as a parameter and updates the corresponding document in Firestore.
  Future<void> updateOrganization(Organization organization) async {
    try {
      await _firestore
          .collection('organizations')
          .doc(organization.id)
          .update(organization.toMap()); // Update the organization document in Firestore.

      notifyListeners(); // Notify listeners about the change.
    } catch (e) {
      debugPrint('Error updating organization: $e'); // Print error message if an exception occurs.
      rethrow; // Rethrow the exception.
    }
  }

  /// Retrieves the count of members in an organization.
  /// 
  /// Takes the organization ID as a parameter.
  /// Returns the count of members in the organization.
  Future<int> getOrganizationMembersCount(String organizationId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('organizationId', isEqualTo: organizationId)
          .count()
          .get(); // Get the count of users belonging to the organization.

      return snapshot.count ?? 0; // Return the count of members, or 0 if the count is null.
    } catch (e) {
      debugPrint('Error getting members count: $e'); // Print error message if an exception occurs.
      return 0; // Return 0 in case of an error.
    }
  }

  /// Checks if the current user has access to a specific organization.
  /// 
  /// Takes the organization ID as a parameter.
  /// Returns true if the user has access, otherwise returns false.
  Future<bool> hasOrganizationAccess(String organizationId) async {
    try {
      final user = _auth.currentUser; // Get the currently authenticated user.
      if (user == null) return false; // Return false if no user is authenticated.

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get(); // Get the user's document from Firestore.

      if (!userDoc.exists) return false; // Return false if the user document does not exist.

      return userDoc.data()?['organizationId'] == organizationId; // Return true if the user belongs to the organization.
    } catch (e) {
      debugPrint('Error checking organization access: $e'); // Print error message if an exception occurs.
      return false; // Return false in case of an error.
    }
  }
}