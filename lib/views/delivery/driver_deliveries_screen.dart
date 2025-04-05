import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/delivery_route_model.dart';
import 'package:cateredtoyou/services/delivery_route_service.dart';
import 'package:cateredtoyou/services/location_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cateredtoyou/views/delivery/track_delivery_screen.dart';
import 'package:cateredtoyou/widgets/bottom_toolbar.dart';
import 'package:cateredtoyou/utils/permission_helpers.dart';
import 'package:cateredtoyou/views/delivery/widgets/reassign_driver_dialog.dart';
import 'package:intl/intl.dart';

// Stateless widget for the Driver Deliveries Screen - works for any user
class DriverDeliveriesScreen extends StatelessWidget {
  const DriverDeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance;
    final userId = auth.currentUser?.uid;

    // If the user is not logged in, show a message prompting them to log in
    if (userId == null) {
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
          title: const Text('My Deliveries'),
          actions: [
            // Add action button for managers to create new deliveries
            FutureBuilder<bool>(
              future: isManagementUser(context),
              builder: (context, snapshot) {
                final canManage = snapshot.data ?? false;
                
                return Visibility(
                  visible: canManage,
                  child: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => Navigator.pushNamed(context, '/add-delivery'),
                    tooltip: 'Create New Delivery',
                  ),
                );
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'), // Tab for active deliveries
              Tab(text: 'Upcoming'), // Tab for upcoming deliveries
              Tab(text: 'Completed'), // Tab for completed deliveries
            ],
          ),
        ),
        body: FutureBuilder<bool>(
          // Check if the user has manage_deliveries permission
          future: isManagementUser(context),
          builder: (context, permissionSnapshot) {
            final hasManagePermission = permissionSnapshot.data ?? false;
            
            return Consumer<DeliveryRouteService>(
              builder: (context, deliveryService, child) {
                return StreamBuilder<List<DeliveryRoute>>(
                  // Use the appropriate stream based on permissions
                  stream: hasManagePermission 
                      ? deliveryService.getDeliveryRoutes() // Managers see all deliveries
                      : deliveryService.getAccessibleDriverRoutes(), // Others see only their own
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _buildError(context, snapshot.error.toString());
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final routes = snapshot.data!;
                    
                    // Filter routes by status
                    final activeRoutes = routes.where((r) => r.status == 'in_progress').toList();
                    final upcomingRoutes = routes.where((r) => r.status == 'pending').toList();
                    final completedRoutes = routes.where((r) => r.status == 'completed').toList();

                    // Use Consumer for LocationService to ensure it's available in deeper widgets
                    return Consumer<LocationService>(
                      builder: (context, locationService, child) {
                        return TabBarView(
                          children: [
                            _buildDeliveryList(context, activeRoutes, 'active', hasManagePermission, locationService),
                            _buildDeliveryList(context, upcomingRoutes, 'upcoming', hasManagePermission, locationService),
                            _buildDeliveryList(context, completedRoutes, 'completed', hasManagePermission, locationService),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // Helper method to build the delivery list for a specific type
  Widget _buildDeliveryList(
    BuildContext context, 
    List<DeliveryRoute> routes, 
    String type, 
    bool hasManagePermission,
    LocationService locationService
  ) {
    if (routes.isEmpty) {
      return _buildEmptyState(context, type, hasManagePermission);
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;

    return RefreshIndicator(
      onRefresh: () async {
        // Add refresh logic if needed
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: routes.length,
        itemBuilder: (context, index) {
          final route = routes[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildDeliveryCard(
              context, 
              route, 
              type, 
              hasManagePermission,
              locationService,
              isActiveDriver: route.isActiveDriver(userId ?? ''),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildDeliveryCard(
    BuildContext context, 
    DeliveryRoute route, 
    String type, 
    bool hasManagePermission,
    LocationService locationService,
    {bool isActiveDriver = false}
  ) {
    // Check if this is the currently tracked delivery
    // LocationService is now passed directly as a parameter
    final isTracking = locationService.isTracking && 
                      locationService.activeDeliveryId == route.id;
    
    return Card(
      elevation: 2,
      child: Column(
        children: [
          Stack(
            children: [
              InkWell(
                onTap: () => _viewDeliveryDetails(context, route),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              route.metadata?['eventName'] ?? 'Delivery #${route.id.substring(0, 8)}',
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusChip(context, route.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_formatDateTime(route.startTime)} → ${_formatDateTime(route.estimatedEndTime)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildDriverInfoRow(context, route),
                      if (route.metadata?['deliveryAddress'] != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                route.metadata!['deliveryAddress'],
                                style: Theme.of(context).textTheme.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (route.metadata?['loadedItems'] != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(route.metadata!['loadedItems'] as List).length} items',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: route.metadata!['vehicleHasAllItems'] == true
                                    ? Colors.green.withAlpha((0.1 * 255).toInt())
                                    : Colors.orange.withAlpha((0.1 * 255).toInt()),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                route.metadata!['vehicleHasAllItems'] == true
                                    ? 'All items loaded'
                                    : 'Items missing',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: route.metadata!['vehicleHasAllItems'] == true
                                      ? Colors.green
                                      : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              // Show a badge if this delivery was reassigned
              if (route.isReassigned)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Tooltip(
                    message: "This delivery was reassigned",
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha((0.2 * 255).toInt()),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Text(
                        "Reassigned",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          
          if (type == 'active' || type == 'upcoming') ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  // Show driver info if this user is not the active driver
                  if (!isActiveDriver && route.activeDriverId.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FutureBuilder(
                        future: _fetchDriverName(route.activeDriverId),
                        builder: (context, snapshot) {
                          final driverName = snapshot.data ?? 'Loading...';
                          return Row(
                            children: [
                              const Icon(Icons.person, size: 16, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Current Driver: $driverName',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  
                  Row(
                    children: [
                      if (route.status == 'pending') ...[
                        // Any user can take over a pending delivery
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label: isActiveDriver
                                ? const Text('Start Delivery')
                                : const Text('Take & Start'),
                            onPressed: () => isActiveDriver
                                ? _startDelivery(context, route)
                                : _takeAndStartDelivery(context, route),
                          ),
                        )
                      ] else if (route.status == 'in_progress') ...[
                        // Show tracking status and button
                        if (isActiveDriver) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: Icon(
                                isTracking ? Icons.location_on : Icons.location_off,
                                color: isTracking ? Colors.green : Colors.grey,
                              ),
                              label: Text(isTracking ? 'Tracking Active' : 'Resume Tracking'),
                              onPressed: isTracking
                                  ? null
                                  : () => _startTracking(context, route),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.check),
                              label: const Text('Complete'),
                              onPressed: () => _completeDelivery(context, route),
                            ),
                          ),
                        ] else ...[
                          // For non-active drivers, show Take Over button
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.person_add),
                              label: const Text('Take Over Delivery'),
                              onPressed: () => _takeOverDelivery(context, route),
                            ),
                          ),
                        ],
                      ],
                      
                      // View details button
                      if ((route.status == 'pending' && !isActiveDriver) || 
                          (route.status == 'in_progress' && !isActiveDriver)) ...[
                        if (route.status == 'in_progress' && !isActiveDriver)
                          const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.visibility),
                            label: const Text('View Details'),
                            onPressed: () => _viewDeliveryDetails(context, route),
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  // Show management options for users with proper permissions
                  if (hasManagePermission && (type == 'active' || type == 'upcoming')) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Management Options',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildManagementAction(
                          context,
                          Icons.person_add_alt,
                          'Reassign',
                          Colors.orange,
                          () => _showReassignDialog(context, route),
                        ),
                        _buildManagementAction(
                          context,
                          Icons.edit,
                          'Edit',
                          Theme.of(context).colorScheme.primary,
                          () => _showEditDialog(context, route),
                        ),
                        _buildManagementAction(
                          context,
                          Icons.delete,
                          'Delete',
                          Theme.of(context).colorScheme.error,
                          () => _showDeleteDialog(context, route),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper method to build a management action button
  Widget _buildManagementAction(
    BuildContext context, 
    IconData icon, 
    String label, 
    Color color, 
    VoidCallback onTap
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build driver info row
  Widget _buildDriverInfoRow(BuildContext context, DeliveryRoute route) {
    final driverId = route.currentDriver?.isNotEmpty == true 
        ? route.currentDriver 
        : route.driverId;
    
    if (driverId == null || driverId.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return FutureBuilder<String>(
      future: _fetchDriverName(driverId),
      builder: (context, snapshot) {
        final driverName = snapshot.data ?? 'Loading driver...';
        
        return Row(
          children: [
            Icon(
              Icons.person, 
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              'Driver: $driverName',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (route.isReassigned) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.swap_horiz,
                size: 12,
                color: Colors.orange,
              ),
            ],
          ],
        );
      },
    );
  }

  // Helper method to build the status chip
  Widget _buildStatusChip(BuildContext context, String status) {
    Color bgColor;
    Color textColor;
    
    switch (status.toLowerCase()) {
      case 'pending':
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        break;
      case 'in_progress':
        bgColor = Theme.of(context).colorScheme.primary.withAlpha((0.1 * 255).toInt());
        textColor = Theme.of(context).colorScheme.primary;
        break;
      case 'completed':
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade700;
        break;
      case 'cancelled':
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade700;
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Helper method to build the empty state UI for a specific type
  Widget _buildEmptyState(BuildContext context, String type, bool canManage) {
    final theme = Theme.of(context);
    
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
            color: theme.colorScheme.onSurfaceVariant.withAlpha((0.5 * 255).toInt()),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          // Only show this button for managers who can create deliveries
          if (canManage) ...[
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create Delivery'),
              onPressed: () => Navigator.pushNamed(context, '/add-delivery'),
            ),
          ],
        ],
      ),
    );
  }

  // Helper method to build the error UI
  Widget _buildError(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading deliveries',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                // Add refresh logic
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
  
  // Handler to start a delivery
  Future<void> _startDelivery(BuildContext context, DeliveryRoute route) async {
    try {
      final deliveryService = Provider.of<DeliveryRouteService>(context, listen: false);
      final locationService = Provider.of<LocationService>(context, listen: false);
      
      // Update status in Firestore
      await deliveryService.updateRouteStatus(route.id, 'in_progress');
      
      // Start location tracking
      await locationService.startTrackingDelivery(route.id);
      
      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery started successfully')),
        );
        
        // Navigate to details screen
        _viewDeliveryDetails(context, route);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting delivery: $e')),
        );
      }
    }
  }
  
  // Handler to take over and start a delivery
  Future<void> _takeAndStartDelivery(BuildContext context, DeliveryRoute route) async {
    try {
      final deliveryService = Provider.of<DeliveryRouteService>(context, listen: false);
      final locationService = Provider.of<LocationService>(context, listen: false);
      
      // First, take over the delivery
      await deliveryService.takeOverDelivery(route.id);
      
      // Then update status in Firestore
      await deliveryService.updateRouteStatus(route.id, 'in_progress');
      
      // Start location tracking
      await locationService.startTrackingDelivery(route.id);
      
      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery taken over and started successfully')),
        );
        
        // Navigate to details screen
        _viewDeliveryDetails(context, route);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking over delivery: $e')),
        );
      }
    }
  }
  
  // Handler to take over an active delivery
  Future<void> _takeOverDelivery(BuildContext context, DeliveryRoute route) async {
    try {
      final deliveryService = Provider.of<DeliveryRouteService>(context, listen: false);
      final locationService = Provider.of<LocationService>(context, listen: false);
      
      // Take over the delivery
      await deliveryService.takeOverDelivery(route.id);
      
      // Start location tracking
      await locationService.startTrackingDelivery(route.id);
      
      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery taken over successfully')),
        );
        
        // Navigate to details screen
        _viewDeliveryDetails(context, route);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking over delivery: $e')),
        );
      }
    }
  }
  
  // Handler to resume tracking for an active delivery
  Future<void> _startTracking(BuildContext context, DeliveryRoute route) async {
    try {
      final locationService = Provider.of<LocationService>(context, listen: false);
      
      // Start tracking
      await locationService.startTrackingDelivery(route.id);
      
      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location tracking resumed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting tracking: $e')),
        );
      }
    }
  }
  
  // Handler to complete a delivery
  Future<void> _completeDelivery(BuildContext context, DeliveryRoute route) async {
    try {
      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Complete Delivery'),
          content: const Text('Are you sure you want to mark this delivery as completed?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Complete'),
            ),
          ],
        ),
      );
      
      if (confirm != true || !context.mounted) return;
      
      final deliveryService = Provider.of<DeliveryRouteService>(context, listen: false);
      final locationService = Provider.of<LocationService>(context, listen: false);
      
      // Update status in Firestore
      await deliveryService.updateRouteStatus(route.id, 'completed');
      
      // Stop location tracking
      if (locationService.activeDeliveryId == route.id) {
        await locationService.stopTrackingDelivery(completed: true);
      }
      
      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery completed successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing delivery: $e')),
        );
      }
    }
  }
  
  // Navigate to delivery details screen
  void _viewDeliveryDetails(BuildContext context, DeliveryRoute route) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackDeliveryScreen(route: route),
      ),
    );
  }
  
  // Show dialog to reassign a delivery to a different driver
  Future<void> _showReassignDialog(BuildContext context, DeliveryRoute route) async {
    await showDialog(
      context: context,
      builder: (context) => ReassignDriverDialog(route: route),
    );
  }
  
  // Show dialog to edit a delivery
  Future<void> _showEditDialog(BuildContext context, DeliveryRoute route) async {
    final startTimeController = TimeOfDay.fromDateTime(route.startTime);
    final endTimeController = TimeOfDay.fromDateTime(route.estimatedEndTime);
    
    var selectedStartTime = startTimeController;
    var selectedEndTime = endTimeController;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Delivery Times'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Start Time'),
                  subtitle: Text(_formatTimeOfDay(selectedStartTime)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: selectedStartTime,
                    );
                    if (pickedTime != null) {
                      setState(() {
                        selectedStartTime = pickedTime;
                      });
                    }
                  },
                ),
                ListTile(
                  title: const Text('Estimated End Time'),
                  subtitle: Text(_formatTimeOfDay(selectedEndTime)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: selectedEndTime,
                    );
                    if (pickedTime != null) {
                      setState(() {
                        selectedEndTime = pickedTime;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
    
    if (result != true || !context.mounted) return;
    
    try {
      final now = DateTime.now();
      
      // Create new DateTime objects with the selected times
      final newStartDateTime = DateTime(
        route.startTime.year,
        route.startTime.month,
        route.startTime.day,
        selectedStartTime.hour,
        selectedStartTime.minute,
      );
      
      final newEndDateTime = DateTime(
        route.estimatedEndTime.year,
        route.estimatedEndTime.month,
        route.estimatedEndTime.day,
        selectedEndTime.hour,
        selectedEndTime.minute,
      );
      
      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('delivery_routes')
          .doc(route.id)
          .update({
        'startTime': Timestamp.fromDate(newStartDateTime),
        'estimatedEndTime': Timestamp.fromDate(newEndDateTime),
        'updatedAt': Timestamp.fromDate(now),
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery times updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating delivery times: $e')),
        );
      }
    }
  }
  
  // Show dialog to delete a delivery
  Future<void> _showDeleteDialog(BuildContext context, DeliveryRoute route) async {
    final reasonController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this delivery?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed != true || !context.mounted) return;
    
    try {
      final deliveryService = Provider.of<DeliveryRouteService>(context, listen: false);
      await deliveryService.cancelRoute(route.id, reason: reasonController.text);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting delivery: $e')),
        );
      }
    }
  }
  
  // Helper method to fetch driver name from Firestore
  Future<String> _fetchDriverName(String driverId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(driverId).get();
      if (doc.exists) {
        final firstName = doc.data()?['firstName'] ?? '';
        final lastName = doc.data()?['lastName'] ?? '';
        return '$firstName $lastName'.trim().isNotEmpty ? '$firstName $lastName' : 'Unknown Driver';
      }
      return 'Unknown Driver';
    } catch (e) {
      debugPrint('Error fetching driver name: $e');
      return 'Unknown Driver';
    }
  }
  
  // Helper to format TimeOfDay to a readable string
  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }
  
  // Helper to format DateTime to a readable string
  String _formatDateTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }
}