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

    if (userId == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error.withAlpha((0.7 * 255).toInt()),
              ),
              const SizedBox(height: 16),
              Text(
                'Authentication Required',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Please log in to view your deliveries',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.login),
                label: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3, 
      initialIndex: _selectedTabIndex,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        bottomNavigationBar: const BottomToolbar(),
        appBar: AppBar(
          title: const Text('My Deliveries'),
          actions: [
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
              Tab(text: 'Active'),
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
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
              stream: _hasManagePermission 
                  ? deliveryService.getDeliveryRoutes()
                  : deliveryService.getAccessibleDriverRoutes(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildError(context, snapshot.error.toString());
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final routes = snapshot.data!;
                
                final activeRoutes = routes.where((r) => r.status == 'in_progress').toList();
                final upcomingRoutes = routes.where((r) => r.status == 'pending').toList();
                final completedRoutes = routes.where((r) => 
                  r.status == 'completed' || r.status == 'cancelled'
                ).toList();

                activeRoutes.sort((a, b) => a.estimatedEndTime.compareTo(b.estimatedEndTime));
                upcomingRoutes.sort((a, b) => a.startTime.compareTo(b.startTime));
                completedRoutes.sort((a, b) => 
                  (b.actualEndTime ?? b.updatedAt).compareTo(a.actualEndTime ?? a.updatedAt)
                );

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
    final isTracking = locationService.isTracking && 
                      locationService.activeDeliveryId == route.id;
    
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: route.status == 'completed' 
              ? Colors.green.withAlpha((0.3 * 255).toInt())
              : route.status == 'cancelled'
                  ? Colors.red.withAlpha((0.3 * 255).toInt())
                  : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Colored top bar based on status
          Container(
            height: 8,
            color: _getStatusColor(route.status),
          ),
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
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha((0.3 * 255).toInt()),
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
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          route.status == 'in_progress' ? 'Delivery time:' : 'Scheduled time:',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          '${DateFormat('h:mm a').format(route.startTime)} → ${DateFormat('h:mm a').format(route.estimatedEndTime)}',
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      _buildDriverInfoRow(context, route),
                      
                      // Location information
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
                
              // Active tracking indicator
              if (isTracking && route.status == 'in_progress')
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha((0.2 * 255).toInt()),
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
                  
                  // Action buttons row - Driver actions 
                  if (isActiveDriver) ...[
                    if (route.status == 'pending')
                      // Start button for active drivers with pending deliveries
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Delivery'),
                          onPressed: () => _handleStartDelivery(route),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ),
                    
                    if (route.status == 'in_progress') ...[
                      Row(
                        children: [
                          // Tracking status button
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: Icon(isTracking ? Icons.location_on : Icons.location_off),
                              label: Text(isTracking ? 'Tracking Active' : 'Resume Tracking'),
                              onPressed: isTracking
                                  ? null
                                  : () => _handleStartTracking(route),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isTracking ? Colors.green : Colors.blueGrey,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Complete button
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.check),
                              label: const Text('Complete'),
                              onPressed: () => _handleCompleteDelivery(route),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ] else ...{
                    // For non-active drivers, only show View Details button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.visibility),
                        label: const Text('View Details'),
                        onPressed: () => _handleViewDetails(route),
                      ),
                    ),
                  },
  
                  
                  // Management options - Only show Reassign and Delete
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Reassign button
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.person_add_alt),
                            label: const Text('Reassign Driver'),
                            onPressed: () => _handleReassignDialog(route),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Delete button
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.delete),
                            label: const Text('Delete'),
                            onPressed: () => _handleDeleteDialog(route),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error,
                            ),
                          ),
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
        bgColor = Theme.of(context).colorScheme.primary.withAlpha((0.1 * 255).toInt());
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
        border: Border.all(color: textColor.withAlpha((0.3 * 255).toInt())),
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

  // Get status color for the top bar
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.grey;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
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
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
            const SizedBox(height: 24),
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
      ),
    );
  }

  // Helper method to build the error UI
  Widget _buildError(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading deliveries',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                error,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                textAlign: TextAlign.center,
              ),
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