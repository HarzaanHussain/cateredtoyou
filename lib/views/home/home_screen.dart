import 'package:flutter/material.dart'; // Importing Flutter's material design package for UI components.
import 'package:go_router/go_router.dart'; // Importing GoRouter package for navigation.
import 'package:provider/provider.dart'; // Importing Provider package for state management.
import 'package:cateredtoyou/models/auth_model.dart'; // Importing AuthModel for authentication-related data.
import 'package:cateredtoyou/models/user_model.dart'; // Importing UserModel for user-related data.
import 'package:cateredtoyou/services/role_permissions.dart'; // Importing RolePermissions for role-based permissions.
import 'package:cateredtoyou/widgets/permission_widget.dart'; // Importing PermissionWidget for permission-based UI components.

class HomeScreen extends StatelessWidget {
  // Defining a stateless widget for the home screen.
  const HomeScreen({super.key}); // Constructor for the HomeScreen widget.

  @override
  Widget build(BuildContext context) {
    // Build method to describe the part of the UI represented by this widget.
    final authModel = context.watch<
        AuthModel>(); // Watching the AuthModel for changes.
    final UserModel? user = authModel
        .user; // Getting the current user from the AuthModel.
    final rolePermissions = context.read<
        RolePermissions>(); // Reading the RolePermissions service.

    return Scaffold( // Returning a Scaffold widget which provides the basic material design visual layout structure.
      appBar: AppBar( // AppBar widget for the top app bar.
        title: const Text('CateredToYou'), // Title of the app bar.
        actions: [ // Actions in the app bar.
          IconButton( // IconButton for logout.
            icon: const Icon(Icons.logout), // Logout icon.
            onPressed: () =>
                authModel.signOut(), // Sign out the user when pressed.
          ),
        ],
      ),
      body: SingleChildScrollView( // Body of the Scaffold wrapped in a SingleChildScrollView to make it scrollable.
        child: Padding( // Padding around the body content.
          padding: const EdgeInsets.all(16.0), // Padding value.
          child: Column( // Column widget to arrange children vertically.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            // Stretch children to fill the cross axis.
            children: [
              // Welcome Card
              Card( // Card widget for the welcome message.
                child: Padding( // Padding inside the card.
                  padding: const EdgeInsets.all(16.0), // Padding value.
                  child: Column( // Column widget to arrange text vertically.
                    children: [
                      Text( // Text widget for the welcome message.
                        'Welcome, ${user?.fullName ?? 'User'}!',
                        // Display user's full name or 'User' if null.
                        style: Theme
                            .of(context)
                            .textTheme
                            .headlineSmall, // Text style.
                      ),
                      const SizedBox(height: 8), // SizedBox for spacing.
                      Text( // Text widget for the user's role.
                        'Role: ${user?.role.toUpperCase() ?? 'N/A'}',
                        // Display user's role or 'N/A' if null.
                        style: Theme
                            .of(context)
                            .textTheme
                            .titleMedium, // Text style.
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24), // SizedBox for spacing.

              // Management Section
              FutureBuilder<
                  bool>( // FutureBuilder to handle asynchronous permission check.
                future: rolePermissions.hasPermission('manage_staff'),
                // Checking if the user has 'manage_staff' permission.
                builder: (context,
                    snapshot) { // Builder to build the UI based on the snapshot.
                  if (!snapshot.hasData || !snapshot.data!) {
                    return const SizedBox
                        .shrink(); // If no data or permission denied, return an empty widget.
                  }

                  return Column( // Column widget to arrange management section vertically.
                    crossAxisAlignment: CrossAxisAlignment.start,
                    // Align children to the start.
                    children: [
                      Text( // Text widget for the section title.
                        'Management', // Section title.
                        style: Theme
                            .of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith( // Text style.
                          fontWeight: FontWeight.bold, // Bold font weight.
                        ),
                      ),
                      const SizedBox(height: 16), // SizedBox for spacing.
                      Card( // Card widget for management options.
                        child: Column( // Column widget to arrange options vertically.
                          children: [
                            PermissionWidget( // PermissionWidget to check 'manage_staff' permission.
                              permissionId: 'manage_staff', // Permission ID.
                              child: ListTile( // ListTile for staff management.
                                leading: const Icon(Icons.people),
                                // Leading icon.
                                title: const Text('Staff Management'),
                                // Title.
                                subtitle: const Text(
                                    'Manage staff members and roles'),
                                // Subtitle.
                                trailing: const Icon(Icons.arrow_forward_ios),
                                // Trailing icon.
                                onTap: () =>
                                    context.push(
                                        '/staff'), // Navigate to staff management screen.
                              ),
                            ),
                            PermissionWidget(
                                permissionId: 'view_customers',
                                child: ListTile(
                                  leading: const Icon(Icons.handshake),
                                  title: const Text('Customer Management'),
                                  subtitle: const Text(
                                      'View and edit customer information'),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                  onTap: () => context.push('/customers'),
                                )
                            ),
                            const Divider(), // Divider between options.
                            PermissionWidget( // PermissionWidget to check 'manage_events' permission.
                              permissionId: 'manage_events', // Permission ID.
                              child: ListTile( // ListTile for event management.
                                leading: const Icon(Icons.event_available),
                                // Leading icon.
                                title: const Text('Event Management'),
                                // Title.
                                subtitle: const Text(
                                    'Create and manage events'),
                                // Subtitle.
                                trailing: const Icon(Icons.arrow_forward_ios),
                                // Trailing icon.
                                onTap: () =>
                                    context.push(
                                        '/events'), // Navigate to event management screen.
                              ),
                            ),
                            PermissionWidget( // PermissionWidget to check 'manage_inventory' permission.
                              permissionId: 'manage_inventory',
                              // Permission ID.
                              child: ListTile( // ListTile for inventory management.
                                leading: const Icon(Icons.inventory_2),
                                // Leading icon.
                                title: const Text('Inventory Management'),
                                // Title.
                                subtitle: const Text(
                                    'Track and manage inventory items'),
                                // Subtitle.
                                trailing: const Icon(Icons.arrow_forward_ios),
                                // Trailing icon.
                                onTap: () =>
                                    context.push(
                                        '/inventory'), // Navigate to inventory management screen.
                              ),
                            ),
                            PermissionWidget( // PermissionWidget to check 'manage_menu' permission.
                              permissionId: 'manage_menu', // Permission ID.
                              child: ListTile( // ListTile for menu management.
                                leading: const Icon(Icons.restaurant_menu),
                                // Leading icon.
                                title: const Text('Menu Management'),
                                // Title.
                                subtitle: const Text(
                                    'Manage menu items and recipes'),
                                // Subtitle.
                                trailing: const Icon(Icons.arrow_forward_ios),
                                // Trailing icon.
                                onTap: () =>
                                    context.push(
                                        '/menu-items'), // Navigate to menu management screen.
                              ),
                            ),
                          ],
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
                  );
                },
              ),

              // Operations Section
              const SizedBox(height: 24), // SizedBox for spacing.
              Text( // Text widget for the section title.
                'Operations', // Section title.
                style: Theme
                    .of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith( // Text style.
                  fontWeight: FontWeight.bold, // Bold font weight.
                ),
              ),
              const SizedBox(height: 16), // SizedBox for spacing.
              Card( // Card widget for operations options.
                child: Column( // Column widget to arrange options vertically.
                  children: [
                    PermissionWidget( // PermissionWidget to check 'view_tasks' permission.
                      permissionId: 'view_tasks', // Permission ID.
                      child: ListTile( // ListTile for viewing tasks.
                        leading: const Icon(Icons.task),
                        // Leading icon.
                        title: const Text('View Tasks'),
                        // Title.
                        subtitle: const Text('Check assigned tasks'),
                        // Subtitle.
                        trailing: const Icon(Icons.arrow_forward_ios),
                        // Trailing arrow icon.
                        onTap: () =>
                            context.push('/tasks'), // Navigate to tasks screen.
                      ),
                    ),
                    PermissionWidget( // PermissionWidget to check 'view_events' permission.
                      permissionId: 'view_events', // Permission ID.
                      child: ListTile( // ListTile for viewing events.
                        leading: const Icon(Icons.event),
                        // Leading icon.
                        title: const Text('Events'),
                        // Title.
                        subtitle: const Text('View upcoming events'),
                        // Subtitle.
                        trailing: Row( // Row widget for trailing icons.
                          mainAxisSize: MainAxisSize.min,
                          // Minimize the main axis size.
                          children: [
                            FutureBuilder<
                                bool>( // FutureBuilder to handle asynchronous permission check.
                              future: rolePermissions.hasPermission(
                                  'manage_events'),
                              // Checking if the user has 'manage_events' permission.
                              builder: (context,
                                  snapshot) { // Builder to build the UI based on the snapshot.
                                if (!snapshot.hasData || !snapshot
                                    .data!) { // If no data or permission denied.
                                  return const SizedBox
                                      .shrink(); // Return an empty widget.
                                }
                                return IconButton( // IconButton for adding events.
                                  icon: const Icon(Icons.add), // Add icon.
                                  onPressed: () =>
                                      context.push(
                                          '/add-event'), // Navigate to add event screen.
                                );
                              },
                            ),
                            const Icon(Icons.arrow_forward_ios),
                            // Trailing arrow icon.
                          ],
                        ),
                        onTap: () =>
                            context.push(
                                '/events'), // Navigate to events screen.
                      ),
                    ),
                    const Divider(), // Divider between options.
                    PermissionWidget( // PermissionWidget to check 'view_inventory' permission.
                      permissionId: 'view_inventory', // Permission ID.
                      child: ListTile( // ListTile for viewing inventory.
                        leading: const Icon(Icons.inventory),
                        // Leading icon.
                        title: const Text('View Inventory'),
                        // Title.
                        subtitle: const Text('Check current inventory levels'),
                        // Subtitle.
                        trailing: const Icon(Icons.arrow_forward_ios),
                        // Trailing arrow icon.
                        onTap: () =>
                            context.push(
                                '/inventory'), // Navigate to inventory screen.
                      ),
                    ),
                  ],
                ),
              ),


              // Vehicle and Delivery Section
              FutureBuilder<
                  bool>( // FutureBuilder to handle asynchronous permission check.
                future: Future.wait([
                  // Waiting for multiple permission checks.
                  rolePermissions.hasPermission('manage_vehicles'),
                  // Checking if the user has 'manage_vehicles' permission.
                  rolePermissions.hasPermission('view_deliveries')
                  // Checking if the user has 'view_deliveries' permission.
                ]).then((permissions) => permissions.any((p) => p)),
                // If any permission is granted, return true.
                builder: (context,
                    snapshot) { // Builder to build the UI based on the snapshot.
                  if (!snapshot.hasData ||
                      !snapshot.data!) { // If no data or permission denied.
                    return const SizedBox.shrink(); // Return an empty widget.
                  }

                  return Column( // Column widget to arrange vehicle and delivery section vertically.
                    crossAxisAlignment: CrossAxisAlignment.start,
                    // Align children to the start.
                    children: [
                      const SizedBox(height: 24), // SizedBox for spacing.
                      Text( // Text widget for the section title.
                        'Vehicles & Deliveries', // Section title.
                        style: Theme
                            .of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith( // Text style.
                          fontWeight: FontWeight.bold, // Bold font weight.
                        ),
                      ),
                      const SizedBox(height: 16), // SizedBox for spacing.
                      Card( // Card widget for vehicle and delivery options.
                        child: Column( // Column widget to arrange options vertically.
                          children: [
                            PermissionWidget( // PermissionWidget to check 'manage_vehicles' permission.
                              permissionId: 'manage_vehicles', // Permission ID.
                              child: ListTile( // ListTile for fleet management.
                                leading: const Icon(Icons.local_shipping),
                                // Leading icon.
                                title: const Text('Fleet Management'),
                                // Title.
                                subtitle: const Text(
                                    'Manage vehicles and assignments'),
                                // Subtitle.
                                trailing: Row( // Row widget for trailing icons.
                                  mainAxisSize: MainAxisSize.min,
                                  // Minimize the main axis size.
                                  children: [
                                    IconButton( // IconButton for adding vehicles.
                                      icon: const Icon(Icons.add), // Add icon.
                                      onPressed: () =>
                                          context.push(
                                              '/add-vehicle'), // Navigate to add vehicle screen.
                                    ),
                                    const Icon(Icons.arrow_forward_ios),
                                    // Trailing arrow icon.
                                  ],
                                ),
                                onTap: () =>
                                    context.push(
                                        '/vehicles'), // Navigate to vehicles screen.
                              ),
                            ),
                            PermissionWidget( // PermissionWidget to check 'view_deliveries' permission.
                              permissionId: 'view_deliveries', // Permission ID.
                              child: ListTile( // ListTile for viewing deliveries.
                                leading: const Icon(Icons.route),
                                // Leading icon.
                                title: const Text('My Deliveries'),
                                // Title.
                                subtitle: const Text(
                                    'View assigned routes and deliveries'),
                                // Subtitle.
                                trailing: const Icon(Icons.arrow_forward_ios),
                                // Trailing arrow icon.
                                onTap: () =>
                                    context.push(
                                        '/driver-deliveries'), // Navigate to driver deliveries screen.
                              ),
                            ),
                            PermissionWidget( // PermissionWidget to check 'manage_deliveries' permission.
                              permissionId: 'manage_deliveries',
                              // Permission ID.
                              child: ListTile( // ListTile for managing deliveries.
                                leading: const Icon(Icons.map),
                                // Leading icon.
                                title: const Text('Delivery Routes'),
                                // Title.
                                subtitle: const Text(
                                    'Manage and track delivery routes'),
                                // Subtitle.
                                trailing: Row( // Row widget for trailing icons.
                                  mainAxisSize: MainAxisSize.min,
                                  // Minimize the main axis size.
                                  children: [
                                    IconButton( // IconButton for adding deliveries.
                                      icon: const Icon(Icons.add), // Add icon.
                                      onPressed: () =>
                                          context.push(
                                              '/add-delivery'), // Navigate to add delivery screen.
                                    ),
                                    const Icon(Icons.arrow_forward_ios),
                                    // Trailing arrow icon.
                                  ],
                                ),
                                onTap: () =>
                                    context.push(
                                        '/deliveries'), // Navigate to deliveries screen.
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