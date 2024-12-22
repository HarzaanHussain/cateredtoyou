// lib/views/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/auth_model.dart';
import 'package:cateredtoyou/models/user.dart';
import 'package:cateredtoyou/services/role_permissions.dart';
import 'package:cateredtoyou/widgets/permission_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authModel = context.watch<AuthModel>();
    final UserModel? user = authModel.user;
    final hasManagementAccess = user?.role == 'admin' || 
                               user?.role == 'client' || 
                               user?.role == 'manager';
    final canManageInventory = user?.role == 'admin' || 
                              user?.role == 'client' || 
                              user?.role == 'manager' ||
                              user?.role == 'chef';

    return Scaffold(
      appBar: AppBar(
        title: const Text('CateredToYou'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authModel.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              if (hasManagementAccess) ...[
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
                      if (canManageInventory) const Divider(),
                      if (canManageInventory)
                        PermissionWidget(
                          permissionId: 'manage_inventory',
                          child: ListTile(
                            leading: const Icon(Icons.inventory_2),
                            title: const Text('Inventory Management'),
                            subtitle: const Text('Track and manage inventory items'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () => context.push('/inventory'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              // Operations Section
              const SizedBox(height: 24),
              Text(
                'Operations',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    PermissionWidget(
                      permissionId: 'view_events',
                      child: ListTile(
                        leading: const Icon(Icons.event),
                        title: const Text('Events'),
                        subtitle: const Text('View and manage events'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          // TODO: Implement events navigation
                        },
                      ),
                    ),
                    const Divider(),
                    PermissionWidget(
                      permissionId: 'view_inventory',
                      child: ListTile(
                        leading: const Icon(Icons.inventory),
                        title: const Text('View Inventory'),
                        subtitle: const Text('Check current inventory levels'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => context.push('/inventory'),
                      ),
                    ),
                  ],
                ),
              ),

              // Tasks Section
              const SizedBox(height: 24),
              Text(
                'Tasks',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    PermissionWidget(
                      permissionId: 'view_tasks',
                      child: ListTile(
                        leading: const Icon(Icons.task),
                        title: const Text('View Tasks'),
                        subtitle: const Text('Check assigned tasks'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          // TODO: Implement tasks navigation
                        },
                      ),
                    ),
                    if (user?.role == 'chef') ...[
                      const Divider(),
                      PermissionWidget(
                        permissionId: 'manage_kitchen_tasks',
                        child: ListTile(
                          leading: const Icon(Icons.restaurant),
                          title: const Text('Kitchen Tasks'),
                          subtitle: const Text('Manage kitchen operations'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            // TODO: Implement kitchen tasks navigation
                          },
                        ),
                      ),
                    ],
                    if (user?.role == 'server') ...[
                      const Divider(),
                      PermissionWidget(
                        permissionId: 'update_service_tasks',
                        child: ListTile(
                          leading: const Icon(Icons.room_service),
                          title: const Text('Service Tasks'),
                          subtitle: const Text('Update service status'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            // TODO: Implement service tasks navigation
                          },
                        ),
                      ),
                    ],
                    if (user?.role == 'driver') ...[
                      const Divider(),
                      PermissionWidget(
                        permissionId: 'update_delivery_tasks',
                        child: ListTile(
                          leading: const Icon(Icons.delivery_dining),
                          title: const Text('Delivery Tasks'),
                          subtitle: const Text('Manage deliveries'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            // TODO: Implement delivery tasks navigation
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}