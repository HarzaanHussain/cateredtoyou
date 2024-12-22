
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components.
import 'package:provider/provider.dart'; // Importing provider package for state management.
import 'package:cateredtoyou/services/role_permissions.dart'; // Importing custom service for role permissions.

/// A widget that checks for a specific permission before displaying its child widget.
/// If the permission is not granted, it displays a fallback widget or nothing.
class PermissionWidget extends StatelessWidget {
  final String permissionId; // The ID of the permission to check.
  final Widget child; // The widget to display if the permission is granted.
  final Widget? fallback; // The widget to display if the permission is not granted.

  /// Constructor for PermissionWidget.
  /// 
  /// [permissionId] is required and specifies the permission to check.
  /// [child] is required and specifies the widget to display if the permission is granted.
  /// [fallback] is optional and specifies the widget to display if the permission is not granted.
  const PermissionWidget({
    super.key, // Key for the widget.
    required this.permissionId, // Required permission ID.
    required this.child, // Required child widget.
    this.fallback, // Optional fallback widget.
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: context.read<RolePermissions>().hasPermission(permissionId), // Asynchronously checks if the permission is granted.
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data == true) { // If permission is granted, display the child widget.
          return child;
        }
        return fallback ?? const SizedBox.shrink(); // If permission is not granted, display the fallback widget or an empty widget.
      },
    );
  }
}

// Usage example:
// PermissionWidget(
//   permissionId: 'manage_staff', // The permission ID to check.
//   child: ElevatedButton(
//     onPressed: () => context.push('/add-staff'), // Action to perform if permission is granted.
//     child: const Text('Add Staff Member'), // Button text.
//   ),
//   fallback: const Text('You don\'t have permission to add staff'), // Message to display if permission is not granted.
// ),