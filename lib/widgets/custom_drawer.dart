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
              color: const Color(0xFFFBC72B),
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
                  _buildDrawerItem(
                    context,
                    permissionId: 'view_customers',
                    icon: Icons.handshake,
                    label: 'Customer Management',
                    route: '/customers',
                  ),
                  _buildDrawerItem(
                    context,
                    permissionId: 'manage_inventory',
                    icon: Icons.inventory,
                    label: 'Inventory',
                    route: '/inventory',
                  ),
                  _buildDrawerItem(
                    context,
                    permissionId: 'manage_staff',
                    icon: Icons.people,
                    label: 'Staff',
                    route: '/staff',
                  ),
                  _buildDrawerItem(
                    context,
                    permissionId: 'view_tasks',
                    icon: Icons.task,
                    label: 'Tasks',
                    route: '/tasks',
                  ),
                  _buildDrawerItem(
                    context,
                    permissionId: 'manage_manifest',
                    icon: Icons.local_shipping,
                    label: 'Vehicle Loading',
                    route: '/manifest',
                  ),
                  _buildDrawerItem(
                    context,
                    permissionId: 'manage_vehicles',
                    icon: Icons.local_shipping,
                    label: 'Fleet Management',
                    route: '/vehicles',
                  ),
                  _buildDrawerItem(
                    context,
                    permissionId: 'manage_deliveries',
                    icon: Icons.map,
                    label: 'Delivery Routes',
                    route: '/deliveries',
                  ),
                  _buildDrawerItem(
                    context,
                    permissionId: 'manage_menu',
                    icon: Icons.restaurant_menu,
                    label: 'Menu Management',
                    route: '/menu-items',
                  ),
                ],
              ),
            ),

            // Settings at the bottom
            _buildDrawerItem(
              context,
              permissionId: 'view_tasks',
              icon: Icons.settings,
              label: 'Settings',
              route: '/settings',
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build a drawer item with smaller trailing arrow and custom padding
  Widget _buildDrawerItem(
      BuildContext context, {
        required String permissionId,
        required IconData icon,
        required String label,
        required String route,
      }) {
    return PermissionWidget(
      permissionId: permissionId,
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 16, right: 0),
        leading: Icon(icon),
        title: Text(label),
        trailing: const Padding(
          padding: EdgeInsets.only(right: 12.0), // Move arrow closer to edge
          child: SizedBox(
            height: 24,
            width: 24,
            child: Icon(
              Icons.arrow_forward_ios,
              size: 14, // Make it smaller
            ),
          ),
        ),
        onTap: () => context.push(route),
      ),
    );
  }
}