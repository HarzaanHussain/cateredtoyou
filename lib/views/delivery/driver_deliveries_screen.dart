
import 'package:cateredtoyou/views/delivery/delivery_list_screen.dart'; // Importing the delivery list screen
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components
import 'package:provider/provider.dart'; // Importing Provider package for state management
import 'package:cateredtoyou/models/delivery_route_model.dart'; // Importing the delivery route model
import 'package:cateredtoyou/services/delivery_route_service.dart'; // Importing the delivery route service
import 'package:firebase_auth/firebase_auth.dart'; // Importing Firebase authentication package
import 'package:cateredtoyou/widgets/bottom_toolbar.dart'; // Imports bottom toolbar class


// Stateless widget for the Driver Deliveries Screen
class DriverDeliveriesScreen extends StatelessWidget {
  const DriverDeliveriesScreen({super.key}); // Constructor with a key parameter

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance; // Getting the instance of FirebaseAuth
    final driverId = auth.currentUser?.uid; // Getting the current user's UID

    // If the driver is not logged in, show a message prompting them to log in
    if (driverId == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in to view your deliveries'),
        ),
      );
    }

    // Main UI structure with a TabController for different delivery statuses
    return DefaultTabController(
      length: 3, // Number of tabs
      child: Scaffold(
        bottomNavigationBar: const BottomToolbar(),
        appBar: AppBar(
          title: const Text('My Deliveries'), // App bar title
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'), // Tab for active deliveries
              Tab(text: 'Upcoming'), // Tab for upcoming deliveries
              Tab(text: 'Completed'), // Tab for completed deliveries
            ],
          ),
        ),
        body: Consumer<DeliveryRouteService>(
          builder: (context, deliveryService, child) {
            return StreamBuilder<List<DeliveryRoute>>(
              stream: deliveryService.getDriverRoutes(driverId), // Stream of delivery routes for the driver
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildError(context, snapshot.error.toString()); // Show error message if there's an error
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator()); // Show loading indicator while data is being fetched
                }

                final routes = snapshot.data!; // List of delivery routes
                
                // Filter routes by status
                final activeRoutes = routes.where((r) => r.status == 'in_progress').toList(); // Active deliveries
                final upcomingRoutes = routes.where((r) => r.status == 'pending').toList(); // Upcoming deliveries
                final completedRoutes = routes.where((r) => r.status == 'completed').toList(); // Completed deliveries

                // Display the delivery lists in different tabs
                return TabBarView(
                  children: [
                    _buildDeliveryList(context, activeRoutes, 'active'), // Active deliveries tab
                    _buildDeliveryList(context, upcomingRoutes, 'upcoming'), // Upcoming deliveries tab
                    _buildDeliveryList(context, completedRoutes, 'completed'), // Completed deliveries tab
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  // Helper method to build the delivery list for a specific type
  Widget _buildDeliveryList(BuildContext context, List<DeliveryRoute> routes, String type) {
    if (routes.isEmpty) {
      return _buildEmptyState(context, type); // Show empty state if there are no deliveries
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Add refresh logic if needed
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16), // Padding for the list
        itemCount: routes.length, // Number of items in the list
        itemBuilder: (context, index) {
          final route = routes[index]; // Get the delivery route at the current index
          return Padding(
            padding: const EdgeInsets.only(bottom: 16), // Padding between list items
            child: DeliveryRouteCard(
              route: route, // Delivery route data
              showActions: true, // Show action buttons on the card
            ),
          );
        },
      ),
    );
  }

  // Helper method to build the empty state UI for a specific type
  Widget _buildEmptyState(BuildContext context, String type) {
    final theme = Theme.of(context); // Get the current theme
    
    IconData icon;
    String message;
    
    // Set the icon and message based on the type of deliveries
    switch (type) {
      case 'active':
        icon = Icons.local_shipping;
        message = 'No active deliveries';
        break;
      case 'upcoming':
        icon = Icons.schedule;
        message = 'No upcoming deliveries';
        break;
      case 'completed':
        icon = Icons.check_circle;
        message = 'No completed deliveries';
        break;
      default:
        icon = Icons.local_shipping;
        message = 'No deliveries';
    }

    // Display the empty state UI
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withAlpha((0.5 * 255).toInt()), // Icon color with opacity
          ),
          const SizedBox(height: 16), // Spacing
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant, // Text color
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build the error UI
  Widget _buildError(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16), // Padding for the error message
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error, // Error icon color
            ),
            const SizedBox(height: 16), // Spacing
            Text(
              'Error loading deliveries',
              style: Theme.of(context).textTheme.titleMedium, // Error message style
            ),
            const SizedBox(height: 8), // Spacing
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error, // Error text color
              ),
              textAlign: TextAlign.center, // Center align the text
            ),
            const SizedBox(height: 24), // Spacing
            FilledButton.icon(
              onPressed: () {
                // Add refresh logic
              },
              icon: const Icon(Icons.refresh), // Refresh icon
              label: const Text('Retry'), // Retry button label
            ),
          ],
        ),
      ),
    );
  }
}