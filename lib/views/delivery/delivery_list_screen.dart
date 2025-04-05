import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cateredtoyou/models/delivery_route_model.dart';
import 'package:cateredtoyou/services/delivery_route_service.dart';
import 'package:cateredtoyou/widgets/bottom_toolbar.dart';
import 'package:cateredtoyou/utils/permission_helpers.dart';
import 'package:cateredtoyou/views/delivery/widgets/reassign_driver_dialog.dart';

/// A stateless widget that displays a list of delivery routes with management features.
class DeliveryListScreen extends StatelessWidget {
  const DeliveryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const BottomToolbar(),
      appBar: AppBar(
        title: const Text('Deliveries'),
        actions: [
          FutureBuilder<bool>(
            future: isManagementUser(context),
            builder: (context, snapshot) {
              final canManage = snapshot.data ?? false;
              
              return Visibility(
                visible: canManage,
                child: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => context.push('/add-delivery'),
                  tooltip: 'Add New Delivery',
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<DeliveryRouteService>(
        builder: (context, deliveryService, child) {
          return StreamBuilder<List<DeliveryRoute>>(
            stream: deliveryService.getDeliveryRoutes(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final routes = snapshot.data!;
              if (routes.isEmpty) {
                return _buildEmptyState(context);
              }

              // Sort deliveries: in_progress, pending, completed, cancelled
              routes.sort((a, b) {
                final statusOrder = {
                  'in_progress': 0,
                  'pending': 1,
                  'completed': 2,
                  'cancelled': 3,
                };
                
                final aOrder = statusOrder[a.status.toLowerCase()] ?? 4;
                final bOrder = statusOrder[b.status.toLowerCase()] ?? 4;
                
                final statusCompare = aOrder.compareTo(bOrder);
                if (statusCompare != 0) return statusCompare;
                
                // Then sort by time (start time for pending, estimated end for in_progress)
                return a.estimatedEndTime.compareTo(b.estimatedEndTime);
              });

              return FutureBuilder<bool>(
                future: isManagementUser(context),
                builder: (context, permissionSnapshot) {
                  final isManager = permissionSnapshot.data ?? false;
                  
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: routes.length,
                    itemBuilder: (context, index) {
                      final route = routes[index];
                      return DeliveryRouteCard(
                        route: route,
                        isManager: isManager,
                        onTap: () => context.push('/track-delivery', extra: route),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return FutureBuilder<bool>(
      future: isManagementUser(context),
      builder: (context, snapshot) {
        final canManage = snapshot.data ?? false;
        
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 16),
              Text(
                'No Deliveries',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                canManage 
                    ? 'Create a new delivery to get started' 
                    : 'No deliveries are currently assigned to you',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (canManage) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.push('/add-delivery'),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Delivery'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A card widget that displays information about a delivery route with management options.
class DeliveryRouteCard extends StatelessWidget {
  final DeliveryRoute route;
  final VoidCallback? onTap;
  final bool showActions;
  final bool isManager;

  const DeliveryRouteCard({
    super.key,
    required this.route,
    this.onTap,
    this.showActions = true,
    this.isManager = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final isUserDriver = userId == route.driverId || userId == route.currentDriver;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
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
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(context, route.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTimeRow(context),
                  if (route.isReassigned) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha((0.1 * 255).toInt()),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withAlpha((0.5 * 255).toInt()),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.swap_horiz,
                            size: 14,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Reassigned',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  _buildDriverInfo(context),
                  _buildLoadedItemsInfo(),
                  if (route.metadata?['notes'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      route.metadata!['notes'],
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
                ],
              ),
            ),
          ),
          
          // Management actions section
          if (showActions && (isManager || isUserDriver)) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (isUserDriver && route.status == 'pending') // Driver can start their deliveries
                    _buildActionButton(
                      context, 
                      Icons.play_arrow, 
                      'Start', 
                      () => _updateStatus(context, 'in_progress'),
                      theme.colorScheme.primary,
                    ),
                    
                  if (isUserDriver && route.status == 'in_progress') // Driver can complete their deliveries
                    _buildActionButton(
                      context, 
                      Icons.check, 
                      'Complete', 
                      () => _updateStatus(context, 'completed'),
                      Colors.green,
                    ),
                  
                  if (isManager) ...[
                    if (route.status != 'completed' && route.status != 'cancelled')
                      _buildActionButton(
                        context, 
                        Icons.edit, 
                        'Edit', 
                        () => _showEditDialog(context),
                        theme.colorScheme.primary,
                      ),
                      
                    if (route.status != 'completed' && route.status != 'cancelled')
                      _buildActionButton(
                        context, 
                        Icons.person_add, 
                        'Reassign', 
                        () => _showReassignDialog(context),
                        Colors.orange,
                      ),
                      
                    if (route.status != 'completed' && route.status != 'cancelled')
                      _buildActionButton(
                        context, 
                        Icons.delete, 
                        'Delete', 
                        () => _showDeleteDialog(context),
                        theme.colorScheme.error,
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

  Widget _buildActionButton(
    BuildContext context, 
    IconData icon, 
    String label, 
    VoidCallback onPressed,
    Color color,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverInfo(BuildContext context) {
    if (route.driverId.isEmpty) return const SizedBox();
    
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc((route.currentDriver?.isNotEmpty ?? false) ? route.currentDriver! : route.driverId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Text('Loading driver info...');
          }
          
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Text('Driver info unavailable');
          }
          
          final driverData = snapshot.data!.data() as Map<String, dynamic>;
          final driverName = '${driverData['firstName'] ?? ''} ${driverData['lastName'] ?? ''}';
          
          return Row(
            children: [
              const Icon(Icons.person, size: 16, color: Colors.blue),
              const SizedBox(width: 4),
              Text(
                'Driver: $driverName',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeRow(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isDelayed = route.status != 'completed' &&
        now.isAfter(route.estimatedEndTime);

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
                _formatTime(route.startTime),
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
                _formatTime(route.estimatedEndTime),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isDelayed ? theme.colorScheme.error : null,
                ),
              ),
            ],
          ),
        ),
      ],
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
              fontSize: 13,
            ),
          ),
          if (hasAllItems)
            const Padding(
              padding: EdgeInsets.only(left: 4.0),
              child: Icon(Icons.check_circle, size: 14, color: Colors.green),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

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
        backgroundColor = theme.colorScheme.primary.withAlpha((0.1 * 255).toInt());
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
        status.toUpperCase(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showReassignDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ReassignDriverDialog(route: route),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final reasonController = TextEditingController();
    
    showDialog(
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteDelivery(context, reasonController.text);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final startTimeController = TimeOfDay.fromDateTime(route.startTime);
    final endTimeController = TimeOfDay.fromDateTime(route.estimatedEndTime);
    
    var selectedStartTime = startTimeController;
    var selectedEndTime = endTimeController;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Delivery Times'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Start Time'),
              subtitle: Text(_formatTimeOfDay(startTimeController)),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: startTimeController,
                );
                if (pickedTime != null) {
                  selectedStartTime = pickedTime;
                }
              },
            ),
            ListTile(
              title: const Text('Estimated End Time'),
              subtitle: Text(_formatTimeOfDay(endTimeController)),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: endTimeController,
                );
                if (pickedTime != null) {
                  selectedEndTime = pickedTime;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _updateDeliveryTimes(
                context, 
                selectedStartTime, 
                selectedEndTime
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
  
  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(
      now.year, 
      now.month, 
      now.day, 
      time.hour, 
      time.minute
    );
    return DateFormat('h:mm a').format(dt);
  }

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    try {
      await Provider.of<DeliveryRouteService>(context, listen: false)
          .updateRouteStatus(route.id, newStatus);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delivery ${newStatus.replaceAll('_', ' ')}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteDelivery(BuildContext context, String reason) async {
    try {
      await Provider.of<DeliveryRouteService>(context, listen: false)
          .cancelRoute(route.id, reason: reason);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
  
  Future<void> _updateDeliveryTimes(
    BuildContext context, 
    TimeOfDay startTime, 
    TimeOfDay endTime
  ) async {
    try {
      final now = DateTime.now();
      
      // Create new DateTime objects with the selected times but same date
      final newStartDateTime = DateTime(
        route.startTime.year,
        route.startTime.month,
        route.startTime.day,
        startTime.hour,
        startTime.minute,
      );
      
      final newEndDateTime = DateTime(
        route.estimatedEndTime.year,
        route.estimatedEndTime.month,
        route.estimatedEndTime.day,
        endTime.hour,
        endTime.minute,
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
          const SnackBar(
            content: Text('Delivery times updated'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}