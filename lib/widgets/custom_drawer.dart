import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/auth_model.dart';
import 'package:cateredtoyou/widgets/permission_widget.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authModel = context.watch<AuthModel>();

    return Drawer(
      child: Column(
        children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child: DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFFFFC533),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'CateredToYou',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // New Customer Management option
          PermissionWidget(
            permissionId: 'view_customers',
            child: ListTile(
              leading: const Icon(Icons.handshake),
              title: const Text('Customer Management'),
              subtitle: const Text('View and edit customer information'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => context.push('/customers'),
            ),
          ),

          PermissionWidget(
            permissionId: 'manage_inventory',
            child: ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Inventory'),
              subtitle: const Text('Manage kitchen inventory'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => context.push('/inventory'),
            ),
          ),

          PermissionWidget(
            permissionId: 'manage_staff',
            child: ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Staff'),
              subtitle: const Text('Manage staff and roles'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => context.push('/staff'),
            ),
          ),

          PermissionWidget(
            permissionId: 'view_tasks',
            child: ListTile(
              leading: const Icon(Icons.task),
              title: const Text('Tasks'),
              subtitle: const Text('View and assign tasks'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => context.push('/tasks'),
            ),
          ),

          PermissionWidget(
            permissionId: 'manage_manifest',
            child: ListTile(
              leading: const Icon(Icons.local_shipping),
              title: const Text('Vehicle Loading'),
              subtitle: const Text('Manage vehicle loading manifests'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => context.push('/manifest'),
            ),
          ),

          PermissionWidget(
            permissionId: 'manage_menu',
            child: ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: const Text('Menu Management'),
              subtitle: const Text('Manage menu items and recipes'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => context.push('/menu-items'),
            ),
          ),

          const Spacer(),

          PermissionWidget(
            permissionId: 'view_tasks', // Ensure this permission ID is correct
            child: ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              subtitle: const Text('Configure app preferences'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => context.push('/app_settings'),
            ),
          ),
        ],
      ),
    );
  }
}