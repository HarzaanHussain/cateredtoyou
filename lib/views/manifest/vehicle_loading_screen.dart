import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/models/vehicle_model.dart';
import 'package:cateredtoyou/services/manifest_service.dart';
import 'package:cateredtoyou/services/vehicle_service.dart';
import 'package:cateredtoyou/services/event_service.dart';
import 'package:cateredtoyou/views/manifest/widgets/partial_loading_item_tile.dart';
import 'package:cateredtoyou/views/manifest/widgets/drag_item_indicator.dart';

/// A screen that shows all items loaded in a specific vehicle across all events
///
/// This screen displays a comprehensive view of all items assigned to a vehicle,
/// grouping them by event and showing loading status.
class VehicleLoadingScreen extends StatefulWidget {
  final String vehicleId;

  const VehicleLoadingScreen({
    super.key,
    required this.vehicleId,
  });

  @override
  State<VehicleLoadingScreen> createState() => _VehicleLoadingScreenState();
}

class _VehicleLoadingScreenState extends State<VehicleLoadingScreen> {
  Vehicle? _vehicle;
  bool _isLoading = true;
  final Map<String, Map<String, dynamic>> _eventDetails = {};
  final Set<String> _failedEventIds = {}; // Track failed event ID lookups
  String _selectedFilter = 'All Items';
  final Map<String, bool> _selectedItems = {};
  int _selectedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadVehicleDetails();
  }

  Future<void> _loadVehicleDetails() async {
    try {
      final vehicleService =
          Provider.of<VehicleService>(context, listen: false);

      // Get all vehicles and find the one we're looking for
      final vehicles = await vehicleService.getVehicles().first;

      if (!mounted) return;

      setState(() {
        _vehicle = vehicles.firstWhere(
          (v) => v.id == widget.vehicleId,
          orElse: () => throw Exception(
              'Vehicle not found'), // Throw an exception if not found
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading vehicle details: $e')),
      );
    }
  }

  Future<Map<String, dynamic>> _getEventDetails(String manifestId) async {
    // Try to extract eventId from manifestId if needed
    String eventId;
    
    // Check if this is a direct manifestId or an item id with format timestamp_menuItemId
    if (manifestId.contains('_')) {
      // Extract the first part as eventId or manifestId
      eventId = manifestId.split('_').first;
    } else {
      eventId = manifestId;
    }
    
    // Return from cache if available
    if (_eventDetails.containsKey(eventId)) {
      return _eventDetails[eventId]!;
    }

    // If we previously failed to fetch this event, don't try again
    if (_failedEventIds.contains(eventId)) {
      return {
        'name': 'Event #${eventId.substring(0, min(6, eventId.length))}',
        'date': 'Date unknown',
      };
    }

    try {
      final eventService = Provider.of<EventService>(context, listen: false);
      
      // Log attempt to fetch event
      debugPrint('Fetching event details for ID: $eventId');
      
      // First try to get by manifest id
      var event = await eventService.getEventById(manifestId);
      
      // If that failed, try with the extracted eventId
      if (event == null && eventId != manifestId) {
        event = await eventService.getEventById(eventId);
      }

      if (event != null) {
        // Safely format the date with null check
        String formattedDate;
        try {
          formattedDate = DateFormat('MMM d, yyyy').format(event.startDate);
        } catch (e) {
          formattedDate = 'Date unknown';
        }

        final details = {
          'name': event.name,
          'date': formattedDate,
          'id': event.id,
        };

        // Cache for future use
        _eventDetails[eventId] = details;
        return details;
      }
      
      // If we get here, event was null but no exception was thrown
      debugPrint('Event not found: $eventId');
      _failedEventIds.add(eventId);
      return {
        'name': 'Event #${eventId.substring(0, min(6, eventId.length))}',
        'date': 'Date unknown',
      };
    } catch (e) {
      debugPrint('Error fetching event details: $e');
      _failedEventIds.add(eventId);
      
      // Return graceful fallback
      return {
        'name': 'Event #${eventId.substring(0, min(6, eventId.length))}',
        'date': 'Unknown date',
      };
    }
  }

  // Helper function for min value
  int min(int a, int b) => a < b ? a : b;

  void _setFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  void _toggleItemSelection(ManifestItem item) {
    setState(() {
      if (_selectedItems.containsKey(item.id) && _selectedItems[item.id] == true) {
        _selectedItems[item.id] = false;
        _selectedCount--;
      } else {
        _selectedItems[item.id] = true;
        _selectedCount++;
      }
    });
  }

  void _assignSelectedItemsToVehicle() {
    // This is a placeholder - implement vehicle assignment logic
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Items'),
        content: Text('Would assign $_selectedCount selected items to another vehicle'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              
              // Clear selection after assignment
              setState(() {
                _selectedItems.clear();
                _selectedCount = 0;
              });
              
              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Items assigned successfully')),
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Vehicle Loading'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_vehicle == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Vehicle Loading'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Vehicle not found',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${_vehicle!.make} ${_vehicle!.model} Loading'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh data',
            onPressed: () {
              setState(() {
                // Clear caches to force refresh
                _eventDetails.clear();
                _failedEventIds.clear();
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Vehicle details card
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color:
                                theme.primaryColor.withAlpha((0.1 * 255).toInt()),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getVehicleIcon(_vehicle!.type),
                            color: theme.primaryColor,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_vehicle!.make} ${_vehicle!.model}',
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'License: ${_vehicle!.licensePlate}',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Type: ${_getVehicleTypeLabel(_vehicle!.type)}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(_vehicle!.status),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _getStatusLabel(_vehicle!.status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Tabs for All Items and Filter options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  height: 40,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min, // This prevents overflow
                      children: [
                        _buildTab(_selectedFilter == 'All Items', 'All Items', Icons.list, () => _setFilter('All Items')),
                        const SizedBox(width: 8),
                        _buildTab(_selectedFilter == 'Pending', 'Pending', Icons.pending_actions, () => _setFilter('Pending')),
                        const SizedBox(width: 8),
                        _buildTab(_selectedFilter == 'Loaded', 'Loaded', Icons.check_circle_outline, () => _setFilter('Loaded')),
                        const SizedBox(width: 8),
                        _buildTab(_selectedFilter == 'Partial', 'Partial', Icons.splitscreen, () => _setFilter('Partial')),
                        const SizedBox(width: 16), // Fixed width instead of Spacer
                        IconButton(
                          icon: const Icon(Icons.filter_list),
                          tooltip: 'Filter',
                          onPressed: () {
                            // Would implement filter functionality
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Items list grouped by event
              Expanded(
                child: Consumer<ManifestService>(
                  builder: (context, manifestService, child) {
                    return StreamBuilder<List<ManifestItem>>(
                      stream: manifestService
                          .getManifestItemsByVehicleId(widget.vehicleId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 48, color: Colors.red),
                                const SizedBox(height: 16),
                                Text('Error: ${snapshot.error}'),
                              ],
                            ),
                          );
                        }

                        final items = snapshot.data ?? [];

                        if (items.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No items assigned to this vehicle',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Assign Items'),
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                ),
                              ],
                            ),
                          );
                        }

                        // Filter items based on selected filter
                        var filteredItems = items;
                        if (_selectedFilter == 'Pending') {
                          filteredItems = items.where((item) => item.loadingStatus == LoadingStatus.pending).toList();
                        } else if (_selectedFilter == 'Loaded') {
                          filteredItems = items.where((item) => item.loadingStatus == LoadingStatus.loaded).toList();
                        } else if (_selectedFilter == 'Partial') {
                          // This would require us to know the total quantity across all vehicles
                          // For now, just show all items - in real implementation, you'd check partial loading
                          filteredItems = items;
                        }

                        // Group items by manifest/event
                        final groupedItems = <String, List<ManifestItem>>{};
                        for (final item in filteredItems) {
                          // Extract the manifestId from the item id format
                          String manifestId;
                          
                          // Try to identify the manifest ID from the item ID
                          if (item.id.contains('_')) {
                            manifestId = item.id.split('_').first;
                          } else {
                            // If item ID doesn't have the expected format, use menuItemId as fallback
                            manifestId = item.menuItemId;
                          }

                          // This is the fix: get the manifestId correctly
                          if (!groupedItems.containsKey(manifestId)) {
                            groupedItems[manifestId] = [];
                          }
                          groupedItems[manifestId]!.add(item);
                        }

                        // Convert to list for ListView
                        final groupedList = groupedItems.entries.toList();
                        
                        if (groupedList.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.filter_list,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No items match the selected filter',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  icon: const Icon(Icons.clear_all),
                                  label: const Text('Clear Filter'),
                                  onPressed: () {
                                    setState(() {
                                      _selectedFilter = 'All Items';
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }

                        // Build list with headers for each event
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: groupedList.length,
                          itemBuilder: (context, index) {
                            final entry = groupedList[index];
                            final eventId = entry.key;
                            final manifestItems = entry.value;

                            return FutureBuilder<Map<String, dynamic>>(
                              future: _getEventDetails(eventId),
                              builder: (context, eventSnapshot) {
                                // Default values if data isn't loaded yet
                                final eventName = eventSnapshot.data?['name'] ?? 'Loading...';
                                final eventDate = eventSnapshot.data?['date'] ?? '';

                                // Build event section
                                return _buildEventSection(
                                  context,
                                  eventName,
                                  eventDate,
                                  manifestItems,
                                  theme,
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
            ],
          ),
          
          // DragItemIndicator - Positioned at the bottom right when items are selected
          if (_selectedCount > 0)
            Positioned(
              bottom: 16,
              right: 16,
              child: DragItemIndicator(
                itemCount: _selectedCount,
                onAssign: _assignSelectedItemsToVehicle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventSection(
    BuildContext context,
    String eventName,
    String eventDate,
    List<ManifestItem> manifestItems,
    ThemeData theme,
  ) {
    // Calculate loading statistics
    final totalItems = manifestItems.length;
    final loadedCount = manifestItems
        .where((item) => item.loadingStatus == LoadingStatus.loaded)
        .length;
    final loadedPercentage = totalItems > 0 ? (loadedCount / totalItems * 100).toInt() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Event header
        Padding(
          padding: const EdgeInsets.only(
            left: 4,
            right: 4,
            top: 16,
            bottom: 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eventName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (eventDate.isNotEmpty)
                      Text(
                        eventDate,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withAlpha((0.1 * 255).toInt()),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$loadedCount/$totalItems items loaded',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  value: loadedPercentage / 100,
                  strokeWidth: 4,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    loadedPercentage == 100 ? Colors.green : theme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Group items by type for partial loading display
        ..._buildGroupedItemTiles(manifestItems, theme),

        const Divider(height: 32),
      ],
    );
  }

  List<Widget> _buildGroupedItemTiles(List<ManifestItem> items, ThemeData theme) {
    // Group by menu item ID to identify items of the same type
    final groupedByMenuItem = <String, List<ManifestItem>>{};
    
    for (final item in items) {
      if (!groupedByMenuItem.containsKey(item.menuItemId)) {
        groupedByMenuItem[item.menuItemId] = [];
      }
      groupedByMenuItem[item.menuItemId]!.add(item);
    }
    
    final itemWidgets = <Widget>[];
    
    groupedByMenuItem.forEach((menuItemId, menuItems) {
      // If there's only one item of this type, display normally
      if (menuItems.length == 1) {
        itemWidgets.add(_buildItemTile(menuItems.first));
        return;
      }
      
      // Multiple items of the same type - potential partial loading
      // Count total quantity across all instances
      final totalQuantity = menuItems.fold<int>(
        0, (sum, item) => sum + item.quantity);
      
      // Count loaded quantity
      final loadedCount = menuItems
        .where((item) => item.loadingStatus == LoadingStatus.loaded)
        .fold<int>(0, (sum, item) => sum + item.quantity);
      
      // Use the first item as reference
      final referenceItem = menuItems.first;
      
      // Create a partial loading item tile
      itemWidgets.add(
        PartialLoadingItemTile(
          item: referenceItem,
          totalQuantity: totalQuantity,
          loadedQuantity: loadedCount,
          pendingQuantity: totalQuantity - loadedCount,
          onTap: () {
            // Show details about each instance of this item
            _showItemInstances(context, menuItems, theme);
          },
        ),
      );
    });
    
    return itemWidgets;
  }

  void _showItemInstances(BuildContext context, List<ManifestItem> items, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.splitscreen,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Item Instances: ${items.first.name}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildItemTile(item);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemTile(ManifestItem item) {
    Color statusColor;
    IconData statusIcon;

    switch (item.loadingStatus) {
      case LoadingStatus.unassigned:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        break;
      case LoadingStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.pending_outlined;
        break;
      case LoadingStatus.loaded:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
    }
    
    final isSelected = _selectedItems[item.id] == true;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected 
            ? Colors.blue.withAlpha((0.8 * 255).toInt()) 
            : statusColor.withAlpha((0.3 * 255).toInt()),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _toggleItemSelection(item),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Selection indicator
              if (isSelected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                )
              else
                // Status indicator
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              const SizedBox(width: 12),

              // Item details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quantity: ${item.quantity}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Status label
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha((0.2 * 255).toInt()),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      statusIcon,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getLoadingStatusLabel(item.loadingStatus),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(bool isSelected, String label, IconData icon, VoidCallback onTap) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getVehicleTypeLabel(VehicleType type) {
    switch (type) {
      case VehicleType.van:
        return 'Van';
      case VehicleType.truck:
        return 'Truck';
      case VehicleType.car:
        return 'Car';
      default:
        return 'Unknown';
    }
  }

  IconData _getVehicleIcon(VehicleType type) {
    switch (type) {
      case VehicleType.van:
        return Icons.airport_shuttle;
      case VehicleType.truck:
        return Icons.local_shipping;
      case VehicleType.car:
        return Icons.directions_car;
      default:
        return Icons.local_shipping;
    }
  }

  String _getStatusLabel(VehicleStatus status) {
    switch (status) {
      case VehicleStatus.available:
        return 'Available';
      case VehicleStatus.inUse:
        return 'In Use';
      case VehicleStatus.maintenance:
        return 'Maintenance';
      case VehicleStatus.outOfService:
        return 'Out of Service';
    }
  }

  Color _getStatusColor(VehicleStatus status) {
    switch (status) {
      case VehicleStatus.available:
        return Colors.green;
      case VehicleStatus.inUse:
        return Colors.blue;
      case VehicleStatus.maintenance:
        return Colors.orange;
      case VehicleStatus.outOfService:
        return Colors.red;
    }
  }

  String _getLoadingStatusLabel(LoadingStatus status) {
    switch (status) {
      case LoadingStatus.unassigned:
        return 'Unassigned';
      case LoadingStatus.pending:
        return 'Pending';
      case LoadingStatus.loaded:
        return 'Loaded';
    }
  }
}