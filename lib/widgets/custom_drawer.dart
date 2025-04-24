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
      child: SafeArea(
        child: Column(
          children: [
            // Fixed height drawer header
            Container(
              height: 100,
              width: double.infinity,
              color: Color(0xFFFBC72B),
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
              child: Text(
                'CateredToYou',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Scrollable list of menu items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // New Customer Management option
                  PermissionWidget(
                    permissionId: 'view_customers',
                    child: ListTile(
                      leading: const Icon(Icons.handshake),
                      title: const Text('Customer Management'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => context.push('/customers'),
                    ),
                  ),

                  PermissionWidget(
                    permissionId: 'manage_inventory',
                    child: ListTile(
                      leading: const Icon(Icons.inventory),
                      title: const Text('Inventory'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => context.push('/inventory'),
                    ),
                  ),

                  PermissionWidget(
                    permissionId: 'manage_staff',
                    child: ListTile(
                      leading: const Icon(Icons.people),
                      title: const Text('Staff'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => context.push('/staff'),
                    ),
                  ),

                  PermissionWidget(
                    permissionId: 'view_tasks',
                    child: ListTile(
                      leading: const Icon(Icons.task),
                      title: const Text('Tasks'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => context.push('/tasks'),
                    ),
                  ),

                  PermissionWidget(
                    permissionId: 'manage_manifest',
                    child: ListTile(
                      leading: const Icon(Icons.local_shipping),
                      title: const Text('Vehicle Loading'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => context.push('/manifest'),
                    ),
                  ),

                  PermissionWidget(
                    permissionId: 'manage_vehicles',
                    child: ListTile(
                      leading: const Icon(Icons.local_shipping),
                      title: const Text('Fleet Management'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => context.push('/vehicles'),
                    ),
                  ),

                  PermissionWidget(
                    permissionId: 'manage_deliveries',
                    child: ListTile(
                      leading: const Icon(Icons.map),
                      title: const Text('Delivery Routes'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => context.push('/deliveries'),
                    ),
                  ),

                  PermissionWidget(
                    permissionId: 'manage_menu',
                    child: ListTile(
                      leading: const Icon(Icons.restaurant_menu),
                      title: const Text('Menu Management'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => context.push('/menu-items'),
                    ),
                  ),
                ],
              ),
            ),

            // Settings at the bottom
            PermissionWidget(
              permissionId: 'view_tasks', 
              child: ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => context.push('/settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}