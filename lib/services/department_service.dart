import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './organization_service.dart';

/// Service for managing departments in an organization.
class DepartmentService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OrganizationService _organizationService;

  DepartmentService(this._organizationService);

  /// Creates a new department with a given name under the current user's organization.
  Future<void> createDepartment({required String name}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      final docRef = _firestore.collection('departments').doc();
      await docRef.set({
        'id': docRef.id,
        'name': name,
        'organizationId': organization.id,
      });
      notifyListeners();
    } catch (e) {
      debugPrint('Error creating department: $e');
      rethrow;
    }
  }

  /// Retrieves a list of departments for the current user's organization.
  Stream<List<Map<String, dynamic>>> getDepartments() async* {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        yield [];
        return;
      }

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        yield [];
        return;
      }

      yield* _firestore
          .collection('departments')
          .where('organizationId', isEqualTo: organization.id)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
    } catch (e) {
      debugPrint('Error fetching departments: $e');
      yield [];
    }
  }

  /// Deletes a department by its ID, ensuring it belongs to the current user's organization.
  Future<void> deleteDepartment(String departmentId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      final departmentDoc = await _firestore.collection('departments').doc(departmentId).get();

      if (!departmentDoc.exists || departmentDoc.data()?['organizationId'] != organization.id) {
        throw 'Department not found in your organization';
      }

      await _firestore.collection('departments').doc(departmentId).delete();
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting department: $e');
      rethrow;
    }
  }
}