import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Permission {
  final String id;
  final String name;
  final String description;
  final String category;

  const Permission({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
  });
}

class RolePermissions extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Define all available permissions
  static const Map<String, Permission> allPermissions = {
    'manage_staff': Permission(
      id: 'manage_staff',
      name: 'Manage Staff',
      description: 'Create, edit, and deactivate staff members',
      category: 'Staff Management',
    ),
    'view_staff': Permission(
      id: 'view_staff',
      name: 'View Staff',
      description: 'View staff member details',
      category: 'Staff Management',
    ),
    'manage_events': Permission(
      id: 'manage_events',
      name: 'Manage Events',
      description: 'Create and edit events',
      category: 'Event Management',
    ),
    'view_events': Permission(
      id: 'view_events',
      name: 'View Events',
      description: 'View event details',
      category: 'Event Management',
    ),
    'manage_inventory': Permission(
      id: 'manage_inventory',
      name: 'Manage Inventory',
      description: 'Add, edit, and remove inventory items',
      category: 'Inventory',
    ),
    'view_inventory': Permission(
      id: 'view_inventory',
      name: 'View Inventory',
      description: 'View inventory items',
      category: 'Inventory',
    ),
    'manage_tasks': Permission(
      id: 'manage_tasks',
      name: 'Manage Tasks',
      description: 'Create and assign tasks',
      category: 'Task Management',
    ),
    'view_tasks': Permission(
      id: 'view_tasks',
      name: 'View Tasks',
      description: 'View assigned tasks',
      category: 'Task Management',
    ),
  };

  // Default role permissions
  static const Map<String, List<String>> defaultRolePermissions = {
    'admin': [
      'manage_staff',
      'view_staff',
      'manage_events',
      'view_events',
      'manage_inventory',
      'view_inventory',
      'manage_tasks',
      'view_tasks',
    ],
    'client': [
      'manage_staff',
      'view_staff',
      'manage_events',
      'view_events',
      'view_inventory',
      'manage_tasks',
      'view_tasks',
    ],
    'manager': [
      'view_staff',
      'manage_events',
      'view_events',
      'manage_inventory',
      'view_inventory',
      'manage_tasks',
      'view_tasks',
    ],
    'chef': [
      'view_events',
      'manage_inventory',
      'view_inventory',
      'view_tasks',
    ],
    'server': [
      'view_events',
      'view_inventory',
      'view_tasks',
    ],
    'driver': [
      'view_events',
      'view_tasks',
    ],
  };

  // Check if current user has a specific permission
  Future<bool> hasPermission(String permissionId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore
          .collection('permissions')
          .doc(user.uid)
          .get();

      if (!doc.exists) return false;

      final permissions = List<String>.from(doc.data()?['permissions'] ?? []);
      return permissions.contains(permissionId);
    } catch (e) {
      debugPrint('Error checking permission: $e');
      return false;
    }
  }

  // Get all permissions for a role
  List<String> getPermissionsForRole(String role) {
    return defaultRolePermissions[role] ?? [];
  }

  // Create permissions document for a user
  Future<void> createUserPermissions(String uid, String role) async {
    try {
      final permissions = getPermissionsForRole(role);
      await _firestore.collection('permissions').doc(uid).set({
        'permissions': permissions,
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating user permissions: $e');
      rethrow;
    }
  }

  // Update user permissions
  Future<void> updateUserPermissions(
    String uid,
    String newRole, {
    List<String>? customPermissions,
  }) async {
    try {
      final permissions = customPermissions ?? getPermissionsForRole(newRole);
      await _firestore.collection('permissions').doc(uid).update({
        'permissions': permissions,
        'role': newRole,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating user permissions: $e');
      rethrow;
    }
  }

  // Get permissions for a specific user
  Future<List<String>> getUserPermissions(String uid) async {
    try {
      final doc = await _firestore
          .collection('permissions')
          .doc(uid)
          .get();

      if (!doc.exists) return [];

      return List<String>.from(doc.data()?['permissions'] ?? []);
    } catch (e) {
      debugPrint('Error getting user permissions: $e');
      return [];
    }
  }
}