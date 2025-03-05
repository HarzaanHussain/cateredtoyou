import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/auth_model.dart';
import 'package:cateredtoyou/models/user_model.dart';
import 'package:cateredtoyou/services/role_permissions.dart';
import 'package:cateredtoyou/widgets/permission_widget.dart';

// This is the hamburger menu, to use it in views you also need the top bar :
  // import 'package:cateredtoyou/widgets/custom_app_bar.dart';
  // import 'package:cateredtoyou/widgets/custom_drawer.dart';
  // Place these two in the scaffold:
    //appBar: const CustomAppBar(title: 'CateredToYou'),
    //drawer: const CustomDrawer(),

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authModel = context.watch<AuthModel>();

    return Drawer(
      child: Column(
        children: [
          // Header Section
          SizedBox(
            height: 150,
            width: double.infinity,
            child: DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFFFFC533), // Header background color
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



          // Inventory Section
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

          // Staff Management Section
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

          // Task Management Section
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

          // Vehicle Loading System Section
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
          // Menu Management Section
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
        ],
      ),
    );
  }
}