import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/auth_model.dart';
import 'package:cateredtoyou/models/user_model.dart';
import 'package:cateredtoyou/services/role_permissions.dart';
import 'package:cateredtoyou/widgets/permission_widget.dart';
import 'package:cateredtoyou/widgets/bottom_toolbar.dart';
import 'package:cateredtoyou/widgets/custom_app_bar.dart';
import 'package:cateredtoyou/widgets/custom_drawer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authModel = context.watch<AuthModel>();
    final UserModel? user = authModel.user;
    final rolePermissions = context.read<RolePermissions>();

    return Scaffold(
      backgroundColor: Color(0xFFFFC533), // Set background color to orange
      appBar: const CustomAppBar(title: 'CateredToYou'),
      drawer: const CustomDrawer(),
      bottomNavigationBar: const BottomToolbar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Welcome, ${user?.fullName ?? 'User'}!',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Role: ${user?.role.toUpperCase() ?? 'N/A'}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Management Section
              FutureBuilder<bool>(
                future: Future.wait([
                  rolePermissions.hasPermission('manage_staff'),
                  rolePermissions.hasPermission('view_customers'),
                  rolePermissions.hasPermission('manage_menu'),
                  rolePermissions.hasPermission('manage_manifest'),
                ]).then((permissions) => permissions.any((p) => p)),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Management',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Column(
                          children: [
                            PermissionWidget(
                              permissionId: 'manage_staff',
                              child: ListTile(
                                leading: const Icon(Icons.people),
                                title: const Text('Staff Management'),
                                subtitle: const Text('Manage staff members and roles'),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () => context.push('/staff'),
                              ),
                            ),
                            const Divider(),
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
                            const Divider(),
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
                            const Divider(),
                            PermissionWidget(
                              permissionId: 'manage_menu',
                              child: ListTile(
                                leading: const Icon(Icons.notifications),
                                title: const Text('Notifications'),
                                subtitle: const Text('See all past notifications'),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () => context.push('/notifications'),
                              ),
                            ),
                            const Divider(),
                            PermissionWidget(
                              permissionId: 'manage_menu',
                              child: ListTile(
                                leading: const Icon(Icons.list_alt),
                                title: const Text('Manifest Management'),
                                subtitle: const Text('Create and manage load manifests'),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () => context.push('/manifest'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              // Vehicle and Delivery Section
              FutureBuilder<bool>(
                future: Future.wait([
                  rolePermissions.hasPermission('manage_vehicles'),
                  rolePermissions.hasPermission('view_deliveries')
                ]).then((permissions) => permissions.any((p) => p)),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        'Vehicles & Deliveries',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Column(
                          children: [
                            PermissionWidget(
                              permissionId: 'manage_vehicles',
                              child: ListTile(
                                leading: const Icon(Icons.local_shipping),
                                title: const Text('Fleet Management'),
                                subtitle: const Text('Manage vehicles and assignments'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () => context.push('/add-vehicle'),
                                    ),
                                    const Icon(Icons.arrow_forward_ios),
                                  ],
                                ),
                                onTap: () => context.push('/vehicles'),
                              ),
                            ),
                            const Divider(),
                            PermissionWidget(
                              permissionId: 'view_deliveries',
                              child: ListTile(
                                leading: const Icon(Icons.route),
                                title: const Text('My Deliveries'),
                                subtitle: const Text('View assigned routes and deliveries'),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () => context.push('/driver-deliveries'),
                              ),
                            ),
                            const Divider(),
                            PermissionWidget(
                              permissionId: 'manage_deliveries',
                              child: ListTile(
                                leading: const Icon(Icons.map),
                                title: const Text('Delivery Routes'),
                                subtitle: const Text('Manage and track delivery routes'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () => context.push('/add-delivery'),
                                    ),
                                    const Icon(Icons.arrow_forward_ios),
                                  ],
                                ),
                                onTap: () => context.push('/deliveries'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}