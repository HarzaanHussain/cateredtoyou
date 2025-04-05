import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cateredtoyou/services/role_permissions.dart';

/// Helper functions for checking permissions throughout the app
/// Check if the current user is authorized to manage deliveries
/// Requires both the 'manage_deliveries' permission AND a management role
Future<bool> isManagementUser(BuildContext context) async {
  try {
    // Check for management permissions
    final rolePermissions = context.read<RolePermissions>();
    final hasManagePermissions = await rolePermissions.hasPermission('manage_deliveries');
   
    // Get current user's role
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;
   
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
   
    if (!userDoc.exists) return false;
   
    final userRole = userDoc.data()?['role'];
   
    // Management users are admin, client, or manager
    final isManagementRole = ['admin', 'client', 'manager'].contains(userRole);
   
    // User must have both the role AND the permission
    return isManagementRole && hasManagePermissions;
  } catch (e) {
    debugPrint('Error checking if user is management: $e');
    return false;
  }
}

/// Check if user is the active driver for a delivery
Future<bool> isActiveDeliveryDriver(String deliveryId, String? userId) async {
  if (userId == null) return false;
 
  try {
    final doc = await FirebaseFirestore.instance
        .collection('delivery_routes')
        .doc(deliveryId)
        .get();
   
    if (!doc.exists) return false;
   
    final currentDriverId = doc.data()?['currentDriver'];
    final originalDriverId = doc.data()?['driverId'];
   
    // Check if user is either the current or original driver
    return userId == currentDriverId || userId == originalDriverId;
  } catch (e) {
    debugPrint('Error checking if user is active driver: $e');
    return false;
  }
}

/// Color helper for status chips
Color getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return Colors.grey.shade200;
    case 'in_progress':
      return Colors.blue.shade100;
    case 'completed':
      return Colors.green.shade100;
    case 'cancelled':
      return Colors.red.shade100;
    default:
      return Colors.grey.shade100;
  }
}