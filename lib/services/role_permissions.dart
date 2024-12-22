import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Represents a permission with an ID, name, description, and category
class Permission {
  final String id; // Unique identifier for the permission
  final String name; // Name of the permission
  final String description; // Description of what the permission allows
  final String category; // Category to which the permission belongs

  const Permission({
    required this.id, // Constructor parameter for the permission ID
    required this.name, // Constructor parameter for the permission name
    required this.description, // Constructor parameter for the permission description
    required this.category, // Constructor parameter for the permission category
  });
}

// Manages role-based permissions and notifies listeners of changes
class RolePermissions extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance for database operations
  final FirebaseAuth _auth = FirebaseAuth.instance; // FirebaseAuth instance for authentication operations

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
      final user = _auth.currentUser; // Get the current authenticated user
      if (user == null) return false; // If no user is authenticated, return false

      final doc = await _firestore
          .collection('permissions')
          .doc(user.uid)
          .get(); // Get the permissions document for the current user

      if (!doc.exists) return false; // If the document does not exist, return false

      final permissions = List<String>.from(doc.data()?['permissions'] ?? []); // Get the list of permissions from the document
      return permissions.contains(permissionId); // Check if the specified permission is in the list
    } catch (e) {
      debugPrint('Error checking permission: $e'); // Print an error message if an exception occurs
      return false; // Return false if an exception occurs
    }
  }

  // Get all permissions for a role
  List<String> getPermissionsForRole(String role) {
    return defaultRolePermissions[role] ?? []; // Return the list of permissions for the specified role, or an empty list if the role is not found
  }

  // Create permissions document for a user
  Future<void> createUserPermissions(String uid, String role) async {
    try {
      final permissions = getPermissionsForRole(role); // Get the list of permissions for the specified role
      await _firestore.collection('permissions').doc(uid).set({
        'permissions': permissions, // Set the permissions field in the document
        'role': role, // Set the role field in the document
        'updatedAt': FieldValue.serverTimestamp(), // Set the updatedAt field to the current server timestamp
      });
    } catch (e) {
      debugPrint('Error creating user permissions: $e'); // Print an error message if an exception occurs
      rethrow; // Rethrow the exception to be handled by the caller
    }
  }

  // Update user permissions
  Future<void> updateUserPermissions(
    String uid,
    String newRole, {
    List<String>? customPermissions,
  }) async {
    try {
      final permissions = customPermissions ?? getPermissionsForRole(newRole); // Use custom permissions if provided, otherwise get the permissions for the new role
      await _firestore.collection('permissions').doc(uid).update({
        'permissions': permissions, // Update the permissions field in the document
        'role': newRole, // Update the role field in the document
        'updatedAt': FieldValue.serverTimestamp(), // Update the updatedAt field to the current server timestamp
      });
    } catch (e) {
      debugPrint('Error updating user permissions: $e'); // Print an error message if an exception occurs
      rethrow; // Rethrow the exception to be handled by the caller
    }
  }

  // Get permissions for a specific user
  Future<List<String>> getUserPermissions(String uid) async {
    try {
      final doc = await _firestore
          .collection('permissions')
          .doc(uid)
          .get(); // Get the permissions document for the specified user

      if (!doc.exists) return []; // If the document does not exist, return an empty list

      return List<String>.from(doc.data()?['permissions'] ?? []); // Return the list of permissions from the document
    } catch (e) {
      debugPrint('Error getting user permissions: $e'); // Print an error message if an exception occurs
      return []; // Return an empty list if an exception occurs
    }
  }
}