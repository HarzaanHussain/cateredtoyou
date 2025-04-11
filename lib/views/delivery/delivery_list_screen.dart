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
import 'package:cateredtoyou/views/delivery/widgets/status_chip.dart';

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

              // Group deliveries by status
              final inProgressRoutes = routes.where((r) => r.status == 'in_progress').toList();
              final pendingRoutes = routes.where((r) => r.status == 'pending').toList();
              final completedRoutes = routes.where((r) => r.status == 'completed').toList();
              final cancelledRoutes = routes.where((r) => r.status == 'cancelled').toList();
              
              // Sort each group by time
              inProgressRoutes.sort((a, b) => a.estimatedEndTime.compareTo(b.estimatedEndTime));
              pendingRoutes.sort((a, b) => a.startTime.compareTo(b.startTime));
              completedRoutes.sort((a, b) => b.actualEndTime?.compareTo(a.actualEndTime ?? b.estimatedEndTime) ?? -1);
              cancelledRoutes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
              
              // Combine groups in order
              final orderedRoutes = [
                ...inProgressRoutes,
                ...pendingRoutes,
                ...completedRoutes,
                ...cancelledRoutes,
              ];

              return FutureBuilder<bool>(
                future: isManagementUser(context),
                builder: (context, permissionSnapshot) {
                  final isManager = permissionSnapshot.data ?? false;
                  
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orderedRoutes.length,
                    itemBuilder: (context, index) {
                      final route = orderedRoutes[index];
                      
                      // Add section headers
                      if (index == 0 || route.status != orderedRoutes[index-1].status) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (index > 0) const SizedBox(height: 16),
                            _buildSectionHeader(context, route.status),
                            const SizedBox(height: 8),
                            DeliveryRouteCard(
                              route: route,
                              isManager: isManager,
                              onTap: () => context.push('/track-delivery', extra: route),
                            ),
                          ],
                        );
                      }
                      
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

  Widget _buildSectionHeader(BuildContext context, String status) {
    final theme = Theme.of(context);
    
    String title;
    IconData icon;
    Color color;
    
    switch (status.toLowerCase()) {
      case 'in_progress':
        title = 'In Progress';
        icon = Icons.local_shipping;
        color = theme.colorScheme.primary;
        break;
      case 'pending':
        title = 'Scheduled';
        icon = Icons.schedule;
        color = Colors.orange;
        break;
      case 'completed':
        title = 'Completed';
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'cancelled':
        title = 'Cancelled';
        icon = Icons.cancel;
        color = Colors.red;
        break;
      default:
        title = 'Other';
        icon = Icons.more_horiz;
        color = Colors.grey;
    }
    
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
    
    // Get card styling based on status
    final cardStyle = _getCardStyle(context, route.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: cardStyle.borderColor,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Optional colored status bar
          Container(
            height: 6,
            width: double.infinity,
            color: cardStyle.headerColor,
          ),
          
          // Main content
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row with title and status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event name and date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              route.metadata?['eventName'] ?? 'Delivery #${route.id.substring(0, 8)}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('MMM d, yyyy').format(route.startTime),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Status chip using the provided widget
                      StatusChip(status: route.status),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Driver and time information
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Driver info with avatar
                      Expanded(
                        flex: 3,
                        child: _buildDriverInfo(context),
                      ),
                      
                      // Vertical divider
                      Container(
                        height: 40,
                        width: 1,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      
                      // Time info
                      Expanded(
                        flex: 4,
                        child: _buildTimeInfo(context),
                      ),
                    ],
                  ),
                  
                  // Load info and address
                  const SizedBox(height: 16),
                  _buildAddressAndLoadInfo(context),
                  
                  // Notes if available
                  if (route.metadata?['notes'] != null && 
                     (route.metadata?['notes'] as String).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.notes,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            route.metadata!['notes'],
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Action buttons
          if (showActions && (isManager || isUserDriver) && 
              (route.status == 'pending' || route.status == 'in_progress')) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Driver actions
                  if (isUserDriver) ...[
                    if (route.status == 'pending')
                      TextButton.icon(
                        onPressed: () => _updateStatus(context, 'in_progress'),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Start'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green,
                        ),
                      ),
                      
                    if (route.status == 'in_progress')
                      TextButton.icon(
                        onPressed: () => _updateStatus(context, 'completed'),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Complete'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green,
                        ),
                      ),
                  ],
                  
                  // Manager actions
                  if (isManager) ...[
                    if (route.status != 'completed' && route.status != 'cancelled') ...[
                      TextButton.icon(
                        onPressed: () => _showReassignDialog(context),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Reassign'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                      ),
                      
                      TextButton.icon(
                        onPressed: () => _showDeleteDialog(context),
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Delete'),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper class for card styling
  CardStyle _getCardStyle(BuildContext context, String status) {
    final theme = Theme.of(context);
    
    switch (status.toLowerCase()) {
      case 'in_progress':
        return CardStyle(
          headerColor: theme.colorScheme.primary,
          borderColor: theme.colorScheme.primary.withAlpha((0.3 * 255).toInt()),
          backgroundColor: theme.colorScheme.surface,
        );
      case 'pending':
        return CardStyle(
          headerColor: Colors.orange,
          borderColor: Colors.orange.withAlpha((0.3 * 255).toInt()),
          backgroundColor: theme.colorScheme.surface,
        );
      case 'completed':
        return CardStyle(
          headerColor: Colors.green,
          borderColor: Colors.green.withAlpha((0.3 * 255).toInt()),
          backgroundColor: theme.colorScheme.surface,
        );
      case 'cancelled':
        return CardStyle(
          headerColor: Colors.grey,
          borderColor: Colors.grey.withAlpha((0.3 * 255).toInt()),
          backgroundColor: theme.colorScheme.surfaceContainerLowest,
        );
      default:
        return CardStyle(
          headerColor: Colors.grey,
          borderColor: theme.colorScheme.outlineVariant,
          backgroundColor: theme.colorScheme.surface,
        );
    }
  }
  
  Widget _buildAddressAndLoadInfo(BuildContext context) {
    final theme = Theme.of(context);
    
    // Get pickup and delivery addresses
    final pickupAddress = route.metadata?['pickupAddress'] ?? 'Restaurant Location';
    final deliveryAddress = route.metadata?['deliveryAddress'] ?? 'Delivery Location';
    
    // Get loaded items info
    final hasItemsInfo = route.metadata != null && 
                         route.metadata!.containsKey('loadedItems') &&
                         route.metadata!['loadedItems'] != null;
    
    final loadedItems = hasItemsInfo ? route.metadata!['loadedItems'] as List : [];
    final hasAllItems = route.metadata?['vehicleHasAllItems'] ?? false;
    final itemCount = loadedItems.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Addresses
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.store,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                Container(
                  width: 1,
                  height: 16,
                  color: theme.colorScheme.outlineVariant,
                ),
                Icon(
                  Icons.location_on,
                  size: 16, 
                  color: theme.colorScheme.error,
                ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pickupAddress,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    deliveryAddress,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        
        // Item info if available
        if (hasItemsInfo) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.inventory_2,
                size: 16,
                color: hasAllItems ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                '$itemCount item${itemCount != 1 ? 's' : ''} for delivery',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: hasAllItems ? Colors.green : Colors.orange,
                ),
              ),
              if (hasAllItems)
                const Padding(
                  padding: EdgeInsets.only(left: 4.0),
                  child: Icon(Icons.check_circle, size: 14, color: Colors.green),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDriverInfo(BuildContext context) {
    if (route.driverId.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.0),
        child: Text('No driver assigned'),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc((route.currentDriver?.isNotEmpty ?? false) ? route.currentDriver! : route.driverId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Text('Loading...');
          }
          
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Text('Driver unavailable');
          }
          
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final firstName = data['firstName'] ?? '';
          final lastName = data['lastName'] ?? '';
          final initials = firstName.isNotEmpty ? firstName[0] : '';
          final driverName = '$firstName $lastName';
          
          return Row(
            children: [
              // Driver avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.primary.withAlpha((0.2 * 255).toInt()),
                child: Text(
                  initials.toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Driver',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      driverName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeInfo(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    
    // Variables to hold time-related display text
    String timeLabel;
    String timeValue;
    Color timeColor = theme.colorScheme.onSurface;
    IconData timeIcon;
    String statusText;
    
    switch (route.status.toLowerCase()) {
      case 'pending':
        timeLabel = 'Scheduled for';
        timeValue = _formatTime(route.startTime);
        timeIcon = Icons.schedule;
        
        // Check if scheduled time is in the past
        if (now.isAfter(route.startTime)) {
          statusText = 'Overdue';
          timeColor = theme.colorScheme.error;
        } else {
          // Show time until scheduled start
          final difference = route.startTime.difference(now);
          if (difference.inDays > 0) {
            statusText = 'In ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
          } else if (difference.inHours > 0) {
            statusText = 'In ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
          } else {
            statusText = 'In ${difference.inMinutes} min';
          }
        }
        break;
        
      case 'in_progress':
        timeLabel = 'Est. arrival';
        timeValue = _formatTime(route.estimatedEndTime);
        timeIcon = Icons.delivery_dining;
        
        // Calculate if delivery is on time or delayed
        final difference = route.estimatedEndTime.difference(now);
        if (difference.isNegative) {
          statusText = 'Delayed';
          timeColor = theme.colorScheme.error;
        } else if (difference.inHours > 0) {
          statusText = '${difference.inHours}h ${difference.inMinutes.remainder(60)}m left';
        } else {
          statusText = '${difference.inMinutes}m left';
        }
        break;
        
      case 'completed':
        timeLabel = 'Delivered at';
        timeValue = _formatTime(route.actualEndTime ?? route.estimatedEndTime);
        timeIcon = Icons.check_circle;
        
        // How long ago it was completed
        final difference = now.difference(route.actualEndTime ?? route.estimatedEndTime);
        if (difference.inDays > 0) {
          statusText = '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
        } else if (difference.inHours > 0) {
          statusText = '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
        } else {
          statusText = '${difference.inMinutes} min ago';
        }
        break;
        
      case 'cancelled':
        timeLabel = 'Cancelled on';
        timeValue = _formatDateTime(route.updatedAt);
        timeIcon = Icons.cancel;
        statusText = '';
        break;
        
      default:
        timeLabel = 'Time';
        timeValue = _formatTime(route.startTime);
        timeIcon = Icons.access_time;
        statusText = '';
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Row(
        children: [
          Icon(timeIcon, size: 18, color: timeColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  timeValue,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: timeColor,
                  ),
                ),
                if (statusText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    statusText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: timeColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }
  
  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, h:mm a').format(dateTime);
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
}

/// Helper class for styling delivery cards
class CardStyle {
  final Color headerColor;
  final Color borderColor;
  final Color backgroundColor;
  
  CardStyle({
    required this.headerColor,
    required this.borderColor,
    required this.backgroundColor,
  });
}