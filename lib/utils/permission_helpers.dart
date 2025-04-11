import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Authentication package to manage user authentication.
import 'package:flutter/material.dart'; // Import Flutter Material package for UI components.
import 'package:provider/provider.dart'; // Import Provider package for state management.
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore package to interact with the Firestore database.
import 'package:cateredtoyou/services/role_permissions.dart'; // Import custom RolePermissions service for permission handling.

/// Helper functions for checking permissions throughout the app
/// Check if the current user is authorized to manage deliveries
/// Requires both the 'manage_deliveries' permission AND a management role
Future<bool> isManagementUser(BuildContext context) async {
  try {
    // Retrieve the RolePermissions instance from the context to check user permissions.
    final rolePermissions = context.read<RolePermissions>();
    // Check if the user has the 'manage_deliveries' permission.
    final hasManagePermissions = await rolePermissions.hasPermission('manage_deliveries');
   
    // Get the currently authenticated user from FirebaseAuth.
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false; // If no user is logged in, return false.
   
    // Fetch the user's document from the Firestore 'users' collection using their UID.
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
   
    if (!userDoc.exists) return false; // If the user's document doesn't exist, return false.
   
    // Retrieve the user's role from the document data.
    final userRole = userDoc.data()?['role'];
   
    // Define management roles as 'admin', 'client', or 'manager'.
    final isManagementRole = ['admin', 'client', 'manager'].contains(userRole);
   
    // Return true only if the user has both a management role and the required permission.
    return isManagementRole && hasManagePermissions;
  } catch (e) {
    // Log any errors that occur during the process and return false.
    debugPrint('Error checking if user is management: $e');
    return false;
  }
}

/// Check if user is the active driver for a delivery
Future<bool> isActiveDeliveryDriver(String deliveryId, String? userId) async {
  if (userId == null) return false; // If no user ID is provided, return false.
 
  try {
    // Fetch the delivery route document from Firestore using the delivery ID.
    final doc = await FirebaseFirestore.instance
        .collection('delivery_routes')
        .doc(deliveryId)
        .get();
   
    if (!doc.exists) return false; // If the document doesn't exist, return false.
   
    // Retrieve the current driver ID and the original driver ID from the document data.
    final currentDriverId = doc.data()?['currentDriver'];
    final originalDriverId = doc.data()?['driverId'];
   
    // Return true if the user is either the current driver or the original driver.
    return userId == currentDriverId || userId == originalDriverId;
  } catch (e) {
    // Log any errors that occur during the process and return false.
    debugPrint('Error checking if user is active driver: $e');
    return false;
  }
}

/// Color helper for status chips
Color getStatusColor(String status) {
  // Return a specific color based on the status string.
  switch (status.toLowerCase()) {
    case 'pending':
      return Colors.grey.shade200; // Light grey for 'pending' status.
    case 'in_progress':
      return Colors.blue.shade100; // Light blue for 'in_progress' status.
    case 'completed':
      return Colors.green.shade100; // Light green for 'completed' status.
    case 'cancelled':
      return Colors.red.shade100; // Light red for 'cancelled' status.
    default:
      return Colors.grey.shade100; // Default light grey for unknown statuses.
  }
}