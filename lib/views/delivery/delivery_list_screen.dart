import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase authentication package.
import 'package:flutter/material.dart'; // Import Flutter material design package.
import 'package:provider/provider.dart'; // Import Provider package for state management.
import 'package:cateredtoyou/models/delivery_route_model.dart'; // Import DeliveryRoute model.
import 'package:cateredtoyou/services/delivery_route_service.dart'; // Import DeliveryRouteService for fetching delivery routes.
import 'package:go_router/go_router.dart'; // Import GoRouter for navigation.
import 'package:intl/intl.dart'; // Import Intl package for date formatting.
import 'package:cateredtoyou/widgets/bottom_toolbar.dart';

/// A stateless widget that displays a list of delivery routes.
class DeliveryListScreen extends StatelessWidget {
  const DeliveryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const BottomToolbar(),
      appBar: AppBar(
        title: const Text('Deliveries'), // AppBar title.
        actions: [
          IconButton(
            icon: const Icon(Icons.add), // Icon for adding a new delivery.
            onPressed: () => context
                .push('/add-delivery'), // Navigate to add delivery screen.
          ),
        ],
      ),
      body: Consumer<DeliveryRouteService>(
        builder: (context, deliveryService, child) {
          return StreamBuilder<List<DeliveryRoute>>(
            stream: deliveryService
                .getDeliveryRoutes(), // Stream of delivery routes.
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}', // Display error message if any.
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                    child:
                        CircularProgressIndicator()); // Show loading indicator while data is being fetched.
              }

              final routes = snapshot.data!;
              if (routes.isEmpty) {
                return const EmptyDeliveryState(); // Show empty state if no routes are available.
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: routes.length, // Number of delivery routes.
                itemBuilder: (context, index) {
                  final route = routes[index];
                  return DeliveryRouteCard(
                    route: route,
                    onTap: () => context.push('/track-delivery',
                        extra: route), // Navigate to track delivery screen.
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// A card widget that displays information about a delivery route.
class DeliveryRouteCard extends StatelessWidget {
  final DeliveryRoute route; // The delivery route to display.
  final VoidCallback? onTap; // Callback when the card is tapped.
  final bool showActions; // Whether to show action buttons.

  const DeliveryRouteCard({
    super.key,
    required this.route,
    this.onTap,
    this.showActions = false, // Default to false.
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap, // Handle tap event.
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Delivery #${route.id.substring(0, 8)}', // Display delivery ID.
                    style: theme.textTheme.titleMedium,
                  ),
                  _buildStatusChip(
                      context, route.status), // Display status chip.
                ],
              ),
              const SizedBox(height: 12),
              _buildTimeRow(context), // Display start and estimated end times.
              _buildLoadedItemsInfo(), // Display loaded items information.
              if (route.metadata?['notes'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  route.metadata![
                      'notes'], // Display delivery notes if available.
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (route.metadata?['loadedItems'] != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(route.metadata?['loadedItems'] as List?)?.length ?? 0} items for delivery',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
              if (showActions) ...[
                const SizedBox(height: 16),
                _buildActions(
                    context), // Display action buttons if showActions is true.
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the action buttons for the delivery route card.
  Widget _buildActions(BuildContext context) {
    if (!showActions) {
      return const SizedBox
          .shrink(); // Return empty widget if showActions is false.
    }

    final userId =
        FirebaseAuth.instance.currentUser?.uid; // Get current user ID.
    if (userId != route.driverId) {
      return const SizedBox
          .shrink(); // Return empty widget if user is not the driver.
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (route.status == 'pending')
          TextButton.icon(
            onPressed: () =>
                _updateStatus(context, 'in_progress'), // Start delivery.
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Delivery'),
          ),
        if (route.status == 'in_progress')
          TextButton.icon(
            onPressed: () =>
                _updateStatus(context, 'completed'), // Complete delivery.
            icon: const Icon(Icons.check),
            label: const Text('Complete'),
          ),
      ],
    );
  }

  /// Updates the status of the delivery route.
  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    try {
      await Provider.of<DeliveryRouteService>(context, listen: false)
          .updateRouteStatus(route.id, newStatus); // Update route status.
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error updating delivery status: ${e.toString()}'), // Show error message.
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Builds the row displaying start and estimated end times.
  Widget _buildTimeRow(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isDelayed = route.status != 'completed' &&
        now.isAfter(route.estimatedEndTime); // Check if delivery is delayed.

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start Time',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                _formatTime(route.startTime), // Display start time.
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        ),
        const Icon(Icons.arrow_forward, size: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Est. Arrival',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                _formatTime(
                    route.estimatedEndTime), // Display estimated end time.
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isDelayed
                      ? theme.colorScheme.error
                      : null, // Highlight if delayed.
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Formats the given time to a readable string.
  String _formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time); // Format time using Intl package.
  }

  /// Builds a status chip for the delivery route.
  Widget _buildStatusChip(BuildContext context, String status) {
    final theme = Theme.of(context);

    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'pending':
        backgroundColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        break;
      case 'in_progress':
        backgroundColor =
            theme.colorScheme.primary.withAlpha((0.1 * 255).toInt());
        textColor = theme.colorScheme.primary;
        break;
      case 'completed':
        backgroundColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        break;
      case 'cancelled':
        backgroundColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(), // Display status text.
        style: theme.textTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLoadedItemsInfo() {
    // Check if we have manifest data in the metadata
    if (route.metadata == null ||
        !route.metadata!.containsKey('loadedItems') ||
        route.metadata!['loadedItems'] == null) {
      return const SizedBox.shrink();
    }

    final loadedItems = route.metadata!['loadedItems'] as List;
    final hasAllItems = route.metadata!['vehicleHasAllItems'] ?? false;
    final itemCount = loadedItems.length;

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Icon(
            Icons.inventory_2,
            size: 16,
            color: hasAllItems ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            '$itemCount item${itemCount != 1 ? 's' : ''} loaded',
            style: TextStyle(
              color: hasAllItems ? Colors.green : Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (hasAllItems)
            const Padding(
              padding: EdgeInsets.only(left: 4.0),
              child: Icon(Icons.check_circle, size: 16, color: Colors.green),
            ),
        ],
      ),
    );
  }
}

/// A widget that displays an empty state when there are no deliveries.
class EmptyDeliveryState extends StatelessWidget {
  const EmptyDeliveryState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 64,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No Deliveries', // Display no deliveries message.
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new delivery to get started', // Prompt to create a new delivery.
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context
                .push('/add-delivery'), // Navigate to add delivery screen.
            icon: const Icon(Icons.add),
            label: const Text('Create Delivery'),
          ),
        ],
      ),
    );
  }
}
