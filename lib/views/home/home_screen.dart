import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/auth_model.dart';
import 'package:cateredtoyou/models/user_model.dart';
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
                          subtitle:
                              const Text('Manage staff members and roles'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () => context.push('/staff'),
                        ),
                      ),
                      const Divider(),
                      PermissionWidget(
                        permissionId: 'manage_events',
                        child: ListTile(
                          leading: const Icon(Icons.event_available),
                          title: const Text('Event Management'),
                          subtitle: const Text('Create and manage events'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () => context.push('/events'),
                        ),
                      ),
                      if (canManageInventory) const Divider(),
                      if (canManageInventory)
                        PermissionWidget(
                          permissionId: 'manage_inventory',
                          child: ListTile(
                            leading: const Icon(Icons.inventory_2),
                            title: const Text('Inventory Management'),
                            subtitle:
                                const Text('Track and manage inventory items'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () => context.push('/inventory'),
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

                      if (hasManagementAccess || user?.role == 'client') ...[
                        const Divider(),
                        PermissionWidget(
                          permissionId: 'manage_tasks',
                          child: ListTile(
                            leading: const Icon(Icons.add_task),
                            title: const Text('Manage Tasks'),
                            subtitle: const Text('Create and assign tasks'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () => context.push('/manage-tasks'),
                          ),
                        ),
                      ],
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
                        subtitle: const Text('View upcoming events'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasManagementAccess)
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () => context.push('/add-event'),
                              ),
                            const Icon(Icons.arrow_forward_ios),
                          ],
                        ),
                        onTap: () => context.push('/events'),
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
                    PermissionWidget(
                      permissionId: 'view_menu',
                      child: ListTile(
                        leading: const Icon(Icons.menu_book),
                        title: const Text('Menu Items'),
                        subtitle: const Text('View menu items and recipes'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasManagementAccess || user?.role == 'chef')
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () => context.push('/add-menu-item'),
                              ),
                            const Icon(Icons.arrow_forward_ios),
                          ],
                        ),
                        onTap: () => context.push('/menu-items'),
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
                        onTap: () => context.push('/tasks'),
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
                          onTap: () => context.push('/kitchen-tasks'),
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
                          onTap: () => context.push('/service-tasks'),
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
                          onTap: () => context.push('/delivery-tasks'),
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