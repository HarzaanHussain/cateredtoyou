import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import 'package:geolocator/geolocator.dart'; 

// Stateless widget for the Driver Deliveries Screen - works for any user
class DriverDeliveriesScreen extends StatefulWidget {
  const DriverDeliveriesScreen({super.key});

  @override
  State<DriverDeliveriesScreen> createState() => _DriverDeliveriesScreenState();
}

class _DriverDeliveriesScreenState extends State<DriverDeliveriesScreen> with WidgetsBindingObserver {
  bool _isRefreshing = false;
  bool _hasManagePermission = false;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkManagePermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the app resumes, refresh permission status & data
    if (state == AppLifecycleState.resumed) {
      _checkManagePermissions();
    }
  }

  Future<void> _checkManagePermissions() async {
    final hasPermission = await isManagementUser(context);
    if (mounted) {
      setState(() {
        _hasManagePermission = hasPermission;
      });
    }
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      await _checkManagePermissions();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

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
      initialIndex: _selectedTabIndex,
      child: Scaffold(
        bottomNavigationBar: const BottomToolbar(),
        appBar: AppBar(
          title: const Text('My Deliveries'),
          actions: [
            // Add action button for managers to create new deliveries
            if (_hasManagePermission)
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => context.go('/add-delivery'),
                tooltip: 'Create New Delivery',
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
              tooltip: 'Refresh',
            ),
          ],
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Active'), // Tab for active deliveries
              Tab(text: 'Upcoming'), // Tab for upcoming deliveries
              Tab(text: 'Completed'), // Tab for completed deliveries
            ],
            onTap: (index) {
              setState(() {
                _selectedTabIndex = index;
              });
            },
          ),
        ),
        body: Consumer<DeliveryRouteService>(
          builder: (context, deliveryService, child) {
            return StreamBuilder<List<DeliveryRoute>>(
              // Use the appropriate stream based on permissions
              stream: _hasManagePermission 
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
                final completedRoutes = routes.where((r) => 
                  r.status == 'completed' || r.status == 'cancelled'
                ).toList();

                // Sort routes by time
                activeRoutes.sort((a, b) => a.estimatedEndTime.compareTo(b.estimatedEndTime));
                upcomingRoutes.sort((a, b) => a.startTime.compareTo(b.startTime));
                completedRoutes.sort((a, b) => 
                  (b.actualEndTime ?? b.updatedAt).compareTo(a.actualEndTime ?? a.updatedAt)
                );

                // Use Consumer for LocationService to ensure it's available in deeper widgets
                return Consumer<LocationService>(
                  builder: (context, locationService, child) {
                    return TabBarView(
                      children: [
                        _buildDeliveryList(context, activeRoutes, 'active', _hasManagePermission, locationService),
                        _buildDeliveryList(context, upcomingRoutes, 'upcoming', _hasManagePermission, locationService),
                        _buildDeliveryList(context, completedRoutes, 'completed', _hasManagePermission, locationService),
                      ],
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
      onRefresh: _refresh,
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
    final isTracking = locationService.isTracking && 
                      locationService.activeDeliveryId == route.id;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: route.status == 'completed' 
              ? Colors.green.withAlpha(76) // Fixed: using direct value
              : route.status == 'cancelled'
                  ? Colors.red.withAlpha(76) // Fixed: using direct value
                  : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              InkWell(
                onTap: () => _handleViewDetails(route),
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
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusChip(context, route.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Delivery time information
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(76), // Fixed: using direct value
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: route.status == 'completed'
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Completed on:',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      Text(
                                        route.actualEndTime != null
                                          ? DateFormat('MMM d, yyyy • h:mm a').format(route.actualEndTime!)
                                          : 'Unknown',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  )
                                : route.status == 'cancelled'
                                  ? const Text('Cancelled', style: TextStyle(fontWeight: FontWeight.bold))
                                  : Text(
                                      '${DateFormat('h:mm a').format(route.startTime)} → ${DateFormat('h:mm a').format(route.estimatedEndTime)}',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
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
                      
                      // Item information
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
                            if (route.metadata!.containsKey('vehicleHasAllItems')) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: route.metadata!['vehicleHasAllItems'] == true
                                      ? Colors.green.withAlpha(25) // Fixed: using direct value
                                      : Colors.orange.withAlpha(25), // Fixed: using direct value
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
                        color: Colors.orange.withAlpha(51), // Fixed: using direct value
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
                
              // Active tracking indicator
              if (isTracking && route.status == 'in_progress')
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(51), // Fixed: using direct value
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          "Live Tracking",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          
          // Action buttons section
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
                  
                  // Action buttons row
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    alignment: WrapAlignment.center,
                    children: [
                      if (route.status == 'pending') ...[
                        // Any user can take over a pending delivery
                        _buildActionButton(
                          context,
                          icon: Icons.play_arrow,
                          label: isActiveDriver ? 'Start Delivery' : 'Take & Start',
                          color: Colors.green,
                          onPressed: () => isActiveDriver
                              ? _handleStartDelivery(route)
                              : _handleTakeAndStartDelivery(route),
                        ),
                      ] else if (route.status == 'in_progress') ...[
                        // Show tracking status and button
                        if (isActiveDriver) ...[
                          _buildActionButton(
                            context,
                            icon: isTracking ? Icons.location_on : Icons.location_off,
                            label: isTracking ? 'Tracking Active' : 'Resume Tracking',
                            color: isTracking ? Colors.green : Colors.blueGrey,
                            onPressed: isTracking
                                ? null
                                : () => _handleStartTracking(route),
                          ),
                          _buildActionButton(
                            context,
                            icon: Icons.check,
                            label: 'Complete',
                            color: Colors.green,
                            onPressed: () => _handleCompleteDelivery(route),
                          ),
                        ] else ...[
                          // For non-active drivers, show Take Over button
                          _buildActionButton(
                            context,
                            icon: Icons.person_add,
                            label: 'Take Over',
                            color: Colors.blue,
                            onPressed: () => _handleTakeOverDelivery(route),
                          ),
                        ],
                      ],
                      
                      // View details button
                      if ((route.status == 'pending' && !isActiveDriver) || 
                          (route.status == 'in_progress' && !isActiveDriver)) 
                        _buildActionButton(
                          context,
                          icon: Icons.visibility,
                          label: 'View Details',
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: () => _handleViewDetails(route),
                        ),
                    ],
                  ),
                  
                  // Management options for users with proper permissions
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
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildManagementAction(
                          context,
                          Icons.person_add_alt,
                          'Reassign',
                          Colors.orange,
                          () => _handleReassignDialog(route),
                        ),
                        _buildManagementAction(
                          context,
                          Icons.edit,
                          'Edit',
                          Theme.of(context).colorScheme.primary,
                          () => _handleEditDialog(route),
                        ),
                        _buildManagementAction(
                          context,
                          Icons.delete,
                          'Delete',
                          Theme.of(context).colorScheme.error,
                          () => _handleDeleteDialog(route),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          
          // Show summary section for completed deliveries
          if (type == 'completed') ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildInfoColumn(
                    context,
                    'Status',
                    route.status == 'completed' ? 'Completed' : 'Cancelled',
                    route.status == 'completed' ? Colors.green : Colors.red,
                  ),
                  _buildInfoColumn(
                    context,
                    'Completion Date',
                    route.actualEndTime != null 
                      ? DateFormat('MMM d, yyyy').format(route.actualEndTime!)
                      : 'N/A',
                    Colors.grey.shade700,
                  ),
                  _buildInfoColumn(
                    context,
                    'Completion Time',
                    route.actualEndTime != null 
                      ? DateFormat('h:mm a').format(route.actualEndTime!)
                      : 'N/A',
                    Colors.grey.shade700,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton.icon(
                onPressed: () => _handleViewDetails(route),
                icon: const Icon(Icons.info_outline),
                label: const Text('View Details'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                ),
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
    String displayText;
    IconData? iconData;
    
    switch (status.toLowerCase()) {
      case 'pending':
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        displayText = 'SCHEDULED';
        iconData = Icons.schedule;
        break;
      case 'in_progress':
        bgColor = Theme.of(context).colorScheme.primary.withAlpha(25); // Fixed
        textColor = Theme.of(context).colorScheme.primary;
        displayText = 'IN PROGRESS';
        iconData = Icons.local_shipping;
        break;
      case 'completed':
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade700;
        displayText = 'COMPLETED';
        iconData = Icons.check_circle;
        break;
      case 'cancelled':
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade700;
        displayText = 'CANCELLED';
        iconData = Icons.cancel;
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        displayText = status.toUpperCase();
        iconData = null;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withAlpha(76)), // Fixed
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconData != null) ...[
            Icon(iconData, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            displayText,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build the empty state UI for a specific type
  Widget _buildEmptyState(BuildContext context, String type, bool canManage) {
    final theme = Theme.of(context);
    
    IconData icon;
    String message;
    String description;
    
    // Set the icon and message based on the type of deliveries
    switch (type) {
      case 'active':
        icon = Icons.local_shipping;
        message = 'No active deliveries';
        description = 'You don\'t have any deliveries in progress right now';
        break;
      case 'upcoming':
        icon = Icons.schedule;
        message = 'No upcoming deliveries';
        description = 'You don\'t have any scheduled deliveries';
        break;
      case 'completed':
        icon = Icons.check_circle;
        message = 'No completed deliveries';
        description = 'Your completed deliveries will appear here';
        break;
      default:
        icon = Icons.local_shipping;
        message = 'No deliveries';
        description = 'There are no deliveries to display';
    }

    // Display the empty state UI
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withAlpha(127), // Fixed
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Only show this button for managers who can create deliveries
          if (canManage) ...[
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create Delivery'),
             onPressed: () => context.go('/add-delivery'),
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
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper to build info columns for completed deliveries
  Widget _buildInfoColumn(BuildContext context, String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
  
  // Action button for delivery operations
  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: color),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withAlpha(25), // Fixed
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withAlpha(76)), // Fixed
        ),
      ),
    );
  }

  // Helper function to show dialog without BuildContext issues
  Future<T?> _showSafeDialog<T>({
    required BuildContext Function() contextBuilder,
    required Widget Function(BuildContext) dialogBuilder,
  }) async {
    if (!mounted) return null;
    
    BuildContext currentContext = contextBuilder();
    if (!mounted) return null;
    
    return showDialog<T>(
      context: currentContext,
      builder: (dialogContext) => dialogBuilder(dialogContext),
    );
  }
  
  // Helper function to show loading dialog
  void _showLoadingDialog(String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
  
  // Helper function to close dialog
  void _closeDialog() {
    if (!mounted) return;
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (e) {
      debugPrint('Error closing dialog: $e');
    }
  }
  
  // Check if user is within required distance (1 mile) of a location
  Future<bool> _isWithinRequiredDistance(GeoPoint locationPoint) async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showSnackBar('Location services are disabled. Please enable them to continue.');
        }
        return false;
      }

      // Check for location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showSnackBar('Location permission denied. Please enable it to continue.');
          }
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showSnackBar('Location permissions are permanently denied. Please enable them in settings.');
        }
        return false;
      }
      
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );
      
      // Calculate distance in meters
      final distanceInMeters = Geolocator.distanceBetween(
        position.latitude, position.longitude,
        locationPoint.latitude, locationPoint.longitude,
      );
      
      // Convert to miles (1609.34 meters in a mile)
      final distanceInMiles = distanceInMeters / 1609.34;
      
      // Return true if within 1 mile
      return distanceInMiles <= 1.0;
    } catch (e) {
      debugPrint('Error checking distance: $e');
      if (mounted) {
        _showSnackBar('Error checking your location: $e');
      }
      return false;
    }
  }
  
  // Handler for starting a delivery
  void _handleStartDelivery(DeliveryRoute route) async {
    // Get services before async operation
    if (!mounted) return;
    final deliveryService = Provider.of<DeliveryRouteService>(context, listen: false);
    final locationService = Provider.of<LocationService>(context, listen: false);
    
    // Show loading dialog for location check
    if (!mounted) return;
    _showLoadingDialog('Checking your location...');
    
    try {
      // Check if user is within 1 mile of the pickup location
      final pickupLocation = route.waypoints.first;
      final isClose = await _isWithinRequiredDistance(pickupLocation);
      
      // Close the loading dialog
      if (!mounted) return;
      _closeDialog();
      
      if (!isClose) {
        if (!mounted) return;
        _showSnackBar('You must be within 1 mile of the pickup location to start this delivery.');
        return;
      }
      
      // Show loading dialog for starting delivery
      if (!mounted) return;
      _showLoadingDialog('Starting delivery...');
      
      // Update status in Firestore
      await deliveryService.updateRouteStatus(route.id, 'in_progress');
      
      // Start location tracking
      await locationService.startTrackingDelivery(route.id);
      
      // Close the dialog
      if (!mounted) return;
      _closeDialog();
      
      // Show success message
      if (!mounted) return;
      _showSnackBar('Delivery started successfully');
      
      // Navigate to details
      if (!mounted) return;
      _handleViewDetails(route);
    } catch (e) {
      // Close any open dialog
      if (mounted) {
        _closeDialog();
        _showSnackBar('Error starting delivery: $e', isError: true);
      }
    }
  }
  
  // Handler for taking over and starting a delivery
  void _handleTakeAndStartDelivery(DeliveryRoute route) async {
    // Get services before async operation
    if (!mounted) return;
    final deliveryService = Provider.of<DeliveryRouteService>(context, listen: false);
    final locationService = Provider.of<LocationService>(context, listen: false);
    
    // Show loading dialog for location check
    if (!mounted) return;
    _showLoadingDialog('Checking your location...');
    
    try {
      // Check if user is within 1 mile of the pickup location
      final pickupLocation = route.waypoints.first;
      final isClose = await _isWithinRequiredDistance(pickupLocation);
      
      // Close the loading dialog
      if (!mounted) return;
      _closeDialog();
      
      if (!isClose) {
        if (!mounted) return;
        _showSnackBar('You must be within 1 mile of the pickup location to start this delivery.');
        return;
      }
      
      // Show loading dialog for taking over and starting delivery
      if (!mounted) return;
      _showLoadingDialog('Taking over and starting delivery...');
      
      // First, take over the delivery
      await deliveryService.takeOverDelivery(route.id);
      
      // Then update status in Firestore
      await deliveryService.updateRouteStatus(route.id, 'in_progress');
      
      // Start location tracking
      await locationService.startTrackingDelivery(route.id);
      
      // Close the dialog
      if (!mounted) return;
      _closeDialog();
      
      // Show success message
      if (!mounted) return;
      _showSnackBar('Delivery taken over and started successfully');
      
      // Navigate to details
      if (!mounted) return;
      _handleViewDetails(route);
    } catch (e) {
      // Close any open dialog
      if (mounted) {
        _closeDialog();
        _showSnackBar('Error taking over delivery: $e', isError: true);
      }
    }
  }
  
  // Handler for taking over an active delivery
  void _handleTakeOverDelivery(DeliveryRoute route) async {
    // Get services before async operation
    if (!mounted) return;
    final deliveryService = Provider.of<DeliveryRouteService>(context, listen: false);
    final locationService = Provider.of<LocationService>(context, listen: false);
    
    // Show loading dialog
    if (!mounted) return;
    _showLoadingDialog('Taking over delivery...');
    
    try {
      // Take over the delivery
      await deliveryService.takeOverDelivery(route.id);
      
      // Start location tracking
      await locationService.startTrackingDelivery(route.id);
      
      // Close the dialog
      if (!mounted) return;
      _closeDialog();
      
      // Show success message
      if (!mounted) return;
      _showSnackBar('Delivery taken over successfully');
      
      // Navigate to details
      if (!mounted) return;
      _handleViewDetails(route);
    } catch (e) {
      // Close any open dialog
      if (mounted) {
        _closeDialog();
        _showSnackBar('Error taking over delivery: $e', isError: true);
      }
    }
  }
  
  // Handler for starting tracking on an active delivery
  void _handleStartTracking(DeliveryRoute route) async {
    // Get service before async operation
    if (!mounted) return;
    final locationService = Provider.of<LocationService>(context, listen: false);
    
    // Show loading dialog
    if (!mounted) return;
    _showLoadingDialog('Resuming tracking...');
    
    try {
      // Start tracking
      await locationService.startTrackingDelivery(route.id);
      
      // Close the dialog
      if (!mounted) return;
      _closeDialog();
      
      // Show success message and refresh UI
      if (!mounted) return;
      _showSnackBar('Location tracking resumed');
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Close any open dialog
      if (mounted) {
        _closeDialog();
        _showSnackBar('Error starting tracking: $e', isError: true);
      }
    }
  }
  
  // Handler for completing a delivery
  void _handleCompleteDelivery(DeliveryRoute route) async {
    try {
      // First check location
      if (!mounted) return;
      _showLoadingDialog('Checking your location...');
      
      // Check if user is within 1 mile of the delivery location
      final deliveryLocation = route.waypoints.last;
      final isClose = await _isWithinRequiredDistance(deliveryLocation);
      
      // Close the loading dialog
      if (!mounted) return;
      _closeDialog();
      
      if (!isClose) {
        if (!mounted) return;
        _showSnackBar('You must be within 1 mile of the delivery location to mark it as completed.');
        return;
      }
      
      // Show confirmation dialog
      final confirm = await _showSafeDialog<bool>(
        contextBuilder: () => context,
        dialogBuilder: (dialogContext) => AlertDialog(
          title: const Text('Complete Delivery'),
          content: const Text('Are you sure you want to mark this delivery as completed?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Complete'),
            ),
          ],
        ),
      );
      
      if (confirm != true || !mounted) return;
      
      // Get services
      if (!mounted) return;
      final deliveryService = Provider.of<DeliveryRouteService>(context, listen: false);
      final locationService = Provider.of<LocationService>(context, listen: false);
      
      // Show loading dialog
      if (!mounted) return;
      _showLoadingDialog('Completing delivery...');
      
      // Update status in Firestore
      await deliveryService.updateRouteStatus(route.id, 'completed');
      
      // Stop location tracking
      if (locationService.activeDeliveryId == route.id) {
        await locationService.stopTrackingDelivery(completed: true);
      }
      
      // Close the dialog
      if (!mounted) return;
      _closeDialog();
      
      // Show success message and update UI
      if (!mounted) return;
      _showSnackBar('Delivery completed successfully');
      
      if (mounted) {
        setState(() {
          _selectedTabIndex = 2; // Switch to "Completed" tab
        });
      }
    } catch (e) {
      // Close any open dialog
      if (mounted) {
        _closeDialog();
        _showSnackBar('Error completing delivery: $e', isError: true);
      }
    }
  }
  
  // Handler for viewing delivery details
  void _handleViewDetails(DeliveryRoute route) async {
    if (!mounted) return;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackDeliveryScreen(route: route),
      ),
    );
    
    // If changes were made (result == true), refresh the UI
    if (result == true && mounted) {
      _refresh();
    }
  }
  
  // Handler for showing reassign dialog
  void _handleReassignDialog(DeliveryRoute route) async {
    if (!mounted) return;
    
    final result = await _showSafeDialog<bool>(
      contextBuilder: () => context,
      dialogBuilder: (dialogContext) => ReassignDriverDialog(route: route),
    );
    
    // If changes were made (result == true), refresh the UI
    if (result == true && mounted) {
      _refresh();
    }
  }
  
  // Handler for showing edit dialog
  void _handleEditDialog(DeliveryRoute route) async {
    if (!mounted) return;
    
    final startTimeController = TimeOfDay.fromDateTime(route.startTime);
    final endTimeController = TimeOfDay.fromDateTime(route.estimatedEndTime);
    final pickupAddressController = TextEditingController(text: route.metadata?['pickupAddress'] ?? '');
    final deliveryAddressController = TextEditingController(text: route.metadata?['deliveryAddress'] ?? '');
    
    var selectedStartTime = startTimeController;
    var selectedEndTime = endTimeController;
    
    try {
      // Show the edit dialog
      final result = await _showSafeDialog<bool>(
        contextBuilder: () => context,
        dialogBuilder: (dialogContext) => StatefulBuilder(
          builder: (builderContext, setState) {
            return AlertDialog(
              title: const Text('Edit Delivery Details'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Time section
                    Text('Time Settings', 
                      style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(builderContext).colorScheme.primary)),
                    const SizedBox(height: 8),
                    ListTile(
                      title: const Text('Start Time'),
                      subtitle: Text(_formatTimeOfDay(selectedStartTime)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: builderContext,
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
                          context: builderContext,
                          initialTime: selectedEndTime,
                        );
                        if (pickedTime != null) {
                          setState(() {
                            selectedEndTime = pickedTime;
                          });
                        }
                      },
                    ),
                    
                    const Divider(height: 24),
                    
                    // Address section
                    Text('Address Settings', 
                      style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(builderContext).colorScheme.primary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: pickupAddressController,
                      decoration: const InputDecoration(
                        labelText: 'Pickup Address',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: deliveryAddressController,
                      decoration: const InputDecoration(
                        labelText: 'Delivery Address',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Update'),
                ),
              ],
            );
          },
        ),
      );
      
      if (result != true || !mounted) {
        pickupAddressController.dispose();
        deliveryAddressController.dispose();
        return;
      }
      
      // Show loading dialog
      if (!mounted) return;
      _showLoadingDialog('Updating delivery details...');
      
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
        'metadata.pickupAddress': pickupAddressController.text,
        'metadata.deliveryAddress': deliveryAddressController.text,
      });
      
      // Close the dialog
      if (!mounted) {
        pickupAddressController.dispose();
        deliveryAddressController.dispose();
        return;
      }
      
      _closeDialog();
      
      // Show success message and refresh UI
      if (!mounted) {
        pickupAddressController.dispose();
        deliveryAddressController.dispose();
        return;
      }
      
      _showSnackBar('Delivery details updated');
      
      if (mounted) {
        _refresh();
      }
    } catch (e) {
      // Close any open dialog and show error
      if (mounted) {
        _closeDialog();
        _showSnackBar('Error updating delivery details: $e', isError: true);
      }
    } finally {
      // Always dispose controllers
      pickupAddressController.dispose();
      deliveryAddressController.dispose();
    }
  }
  
  // Handler for showing delete dialog
  void _handleDeleteDialog(DeliveryRoute route) async {
    if (!mounted) return;
    
    final reasonController = TextEditingController();
    
    try {
      // Show the confirmation dialog
      final confirmed = await _showSafeDialog<bool>(
        contextBuilder: () => context,
        dialogBuilder: (dialogContext) => AlertDialog(
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
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      
      if (confirmed != true || !mounted) {
        reasonController.dispose();
        return;
      }
      
      // Get the service
      if (!mounted) {
        reasonController.dispose();
        return;
      }
      
      final deliveryService = Provider.of<DeliveryRouteService>(context, listen: false);
      
      // Show loading dialog
      if (!mounted) {
        reasonController.dispose();
        return;
      }
      
      _showLoadingDialog('Deleting delivery...');
      
      // Capture the reason before async operation
      final reason = reasonController.text;
      
      // Cancel the route
      await deliveryService.cancelRoute(route.id, reason: reason);
      
      // Close the dialog
      if (!mounted) {
        reasonController.dispose();
        return;
      }
      
      _closeDialog();
      
      // Show success message and refresh UI
      if (!mounted) {
        reasonController.dispose();
        return;
      }
      
      _showSnackBar('Delivery deleted');
      
      if (mounted) {
        _refresh();
      }
    } catch (e) {
      // Close any open dialog and show error
      if (mounted) {
        _closeDialog();
        _showSnackBar('Error deleting delivery: $e', isError: true);
      }
    } finally {
      // Always dispose controller
      reasonController.dispose();
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
  
  // Helper to show SnackBar messages
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}