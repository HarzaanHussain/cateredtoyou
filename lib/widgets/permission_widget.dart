import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/services/role_permissions.dart';

class PermissionWidget extends StatelessWidget {
  final String permissionId;
  final Widget child;
  final Widget? fallback;

  const PermissionWidget({
    super.key,
    required this.permissionId,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: context.read<RolePermissions>().hasPermission(permissionId),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data == true) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}

// Usage example:
// PermissionWidget(
//   permissionId: 'manage_staff',
//   child: ElevatedButton(
//     onPressed: () => context.push('/add-staff'),
//     child: const Text('Add Staff Member'),
//   ),
//   fallback: const Text('You don\'t have permission to add staff'),
// ),