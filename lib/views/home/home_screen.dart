import 'package:flutter/material.dart'; // Importing Flutter material package for UI components.
import 'package:go_router/go_router.dart'; // Importing go_router package for navigation.
import 'package:provider/provider.dart'; // Importing provider package for state management.
import 'package:cateredtoyou/models/auth_model.dart'; // Importing AuthModel for authentication state.
import 'package:cateredtoyou/models/user.dart'; // Importing UserModel for user data.
import 'package:cateredtoyou/widgets/permission_widget.dart'; // Importing PermissionWidget for permission-based UI.

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key}); // Constructor for HomeScreen.

  @override
  Widget build(BuildContext context) {
    final authModel = context.watch<AuthModel>(); // Watching AuthModel for authentication state.
    final UserModel? user = authModel.user; // Getting the current user from AuthModel.
    final hasManagementAccess = user?.role == 'admin' || 
                               user?.role == 'client' || 
                               user?.role == 'manager'; // Checking if the user has management access.
    final canManageInventory = user?.role == 'admin' || 
                              user?.role == 'client' || 
                              user?.role == 'manager' ||
                              user?.role == 'chef'; // Checking if the user can manage inventory.

    return Scaffold(
      appBar: AppBar(
        title: const Text('CateredToYou'), // App bar title.
        actions: [
          IconButton(
            icon: const Icon(Icons.logout), // Logout icon button.
            onPressed: () => authModel.signOut(), // Sign out the user when pressed.
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Padding for the body content.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0), // Padding for the card content.
                  child: Column(
                    children: [
                      Text(
                        'Welcome, ${user?.fullName ?? 'User'}!', // Displaying the user's full name.
                        style: Theme.of(context).textTheme.headlineSmall, // Styling the text.
                      ),
                      const SizedBox(height: 8), // Spacing between texts.
                      Text(
                        'Role: ${user?.role.toUpperCase() ?? 'N/A'}', // Displaying the user's role.
                        style: Theme.of(context).textTheme.titleMedium, // Styling the text.
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24), // Spacing between sections.

              // Management Section
              if (hasManagementAccess) ...[
                Text(
                  'Management',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold, // Bold text for section title.
                  ),
                ),
                const SizedBox(height: 16), // Spacing before the card.
                Card(
                  child: Column(
                    children: [
                      PermissionWidget(
                        permissionId: 'manage_staff', // Permission ID for managing staff.
                        child: ListTile(
                          leading: const Icon(Icons.people), // Icon for staff management.
                          title: const Text('Staff Management'), // Title for staff management.
                          subtitle: const Text('Manage staff members and roles'), // Subtitle for staff management.
                          trailing: const Icon(Icons.arrow_forward_ios), // Arrow icon for navigation.
                          onTap: () => context.push('/staff'), // Navigate to staff management page.
                        ),
                      ),
                      if (canManageInventory) const Divider(), // Divider if the user can manage inventory.
                      if (canManageInventory)
                        PermissionWidget(
                          permissionId: 'manage_inventory', // Permission ID for managing inventory.
                          child: ListTile(
                            leading: const Icon(Icons.inventory_2), // Icon for inventory management.
                            title: const Text('Inventory Management'), // Title for inventory management.
                            subtitle: const Text('Track and manage inventory items'), // Subtitle for inventory management.
                            trailing: const Icon(Icons.arrow_forward_ios), // Arrow icon for navigation.
                            onTap: () => context.push('/inventory'), // Navigate to inventory management page.
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              // Operations Section
              const SizedBox(height: 24), // Spacing between sections.
              Text(
                'Operations',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold, // Bold text for section title.
                ),
              ),
              const SizedBox(height: 16), // Spacing before the card.
              Card(
                child: Column(
                  children: [
                    PermissionWidget(
                      permissionId: 'view_events', // Permission ID for viewing events.
                      child: ListTile(
                        leading: const Icon(Icons.event), // Icon for events.
                        title: const Text('Events'), // Title for events.
                        subtitle: const Text('View and manage events'), // Subtitle for events.
                        trailing: const Icon(Icons.arrow_forward_ios), // Arrow icon for navigation.
                        onTap: () {
                          // TODO: Implement events navigation
                        },
                      ),
                    ),
                    const Divider(), // Divider between list tiles.
                    PermissionWidget(
                      permissionId: 'view_inventory', // Permission ID for viewing inventory.
                      child: ListTile(
                        leading: const Icon(Icons.inventory), // Icon for viewing inventory.
                        title: const Text('View Inventory'), // Title for viewing inventory.
                        subtitle: const Text('Check current inventory levels'), // Subtitle for viewing inventory.
                        trailing: const Icon(Icons.arrow_forward_ios), // Arrow icon for navigation.
                        onTap: () => context.push('/inventory'), // Navigate to inventory page.
                      ),
                    ),
                  ],
                ),
              ),

              // Tasks Section
              const SizedBox(height: 24), // Spacing between sections.
              Text(
                'Tasks',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold, // Bold text for section title.
                ),
              ),
              const SizedBox(height: 16), // Spacing before the card.
              Card(
                child: Column(
                  children: [
                    PermissionWidget(
                      permissionId: 'view_tasks', // Permission ID for viewing tasks.
                      child: ListTile(
                        leading: const Icon(Icons.task), // Icon for viewing tasks.
                        title: const Text('View Tasks'), // Title for viewing tasks.
                        subtitle: const Text('Check assigned tasks'), // Subtitle for viewing tasks.
                        trailing: const Icon(Icons.arrow_forward_ios), // Arrow icon for navigation.
                        onTap: () {
                          // TODO: Implement tasks navigation
                        },
                      ),
                    ),
                    if (user?.role == 'chef') ...[
                      const Divider(), // Divider if the user is a chef.
                      PermissionWidget(
                        permissionId: 'manage_kitchen_tasks', // Permission ID for managing kitchen tasks.
                        child: ListTile(
                          leading: const Icon(Icons.restaurant), // Icon for kitchen tasks.
                          title: const Text('Kitchen Tasks'), // Title for kitchen tasks.
                          subtitle: const Text('Manage kitchen operations'), // Subtitle for kitchen tasks.
                          trailing: const Icon(Icons.arrow_forward_ios), // Arrow icon for navigation.
                          onTap: () {
                            // TODO: Implement kitchen tasks navigation
                          },
                        ),
                      ),
                    ],
                    if (user?.role == 'server') ...[
                      const Divider(), // Divider if the user is a server.
                      PermissionWidget(
                        permissionId: 'update_service_tasks', // Permission ID for updating service tasks.
                        child: ListTile(
                          leading: const Icon(Icons.room_service), // Icon for service tasks.
                          title: const Text('Service Tasks'), // Title for service tasks.
                          subtitle: const Text('Update service status'), // Subtitle for service tasks.
                          trailing: const Icon(Icons.arrow_forward_ios), // Arrow icon for navigation.
                          onTap: () {
                            // TODO: Implement service tasks navigation
                          },
                        ),
                      ),
                    ],
                    if (user?.role == 'driver') ...[
                      const Divider(), // Divider if the user is a driver.
                      PermissionWidget(
                        permissionId: 'update_delivery_tasks', // Permission ID for updating delivery tasks.
                        child: ListTile(
                          leading: const Icon(Icons.delivery_dining), // Icon for delivery tasks.
                          title: const Text('Delivery Tasks'), // Title for delivery tasks.
                          subtitle: const Text('Manage deliveries'), // Subtitle for delivery tasks.
                          trailing: const Icon(Icons.arrow_forward_ios), // Arrow icon for navigation.
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