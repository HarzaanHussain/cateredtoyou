// Update your VehicleLoadingScreen to enhance support for partial item loading

import 'package:cateredtoyou/widgets/bottom_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/models/vehicle_model.dart';
import 'package:cateredtoyou/services/manifest_service.dart';
import 'package:cateredtoyou/services/vehicle_service.dart';
import 'package:cateredtoyou/services/event_service.dart';
import 'package:cateredtoyou/managers/drag_drop_manager.dart';
import 'package:cateredtoyou/views/manifest/widgets/partial_quantity_selector.dart';

/// A screen that shows all items loaded in a specific vehicle across all events
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
  
  // Add a drag drop manager for item transfers
  late DragDropManager _dragDropManager;

  @override
  void initState() {
    super.initState();
    _loadVehicleDetails();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize drag drop manager
    _dragDropManager = DragDropManager(context);
  }

  Future<void> _loadVehicleDetails() async {
    try {
      final vehicleService = Provider.of<VehicleService>(context, listen: false);
      final vehicles = await vehicleService.getVehicles().first;

      if (!mounted) return;

      setState(() {
        _vehicle = vehicles.firstWhere(
          (v) => v.id == widget.vehicleId,
          orElse: () => throw Exception('Vehicle not found'),
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
    // Code for event details retrieval remains the same
    // ...
    
    String eventId;
    if (manifestId.contains('_')) {
      eventId = manifestId.split('_').first;
    } else {
      eventId = manifestId;
    }
    
    if (_eventDetails.containsKey(eventId)) {
      return _eventDetails[eventId]!;
    }

    if (_failedEventIds.contains(eventId)) {
      return {
        'name': 'Event #${eventId.substring(0, min(6, eventId.length))}',
        'date': 'Date unknown',
      };
    }

    try {
      final eventService = Provider.of<EventService>(context, listen: false);
      var event = await eventService.getEventById(eventId);
      
      if (event != null) {
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

        _eventDetails[eventId] = details;
        return details;
      }
      
      _failedEventIds.add(eventId);
      return {
        'name': 'Event #${eventId.substring(0, min(6, eventId.length))}',
        'date': 'Date unknown',
      };
    } catch (e) {
      _failedEventIds.add(eventId);
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
  
  // New method to show the partial quantity transfer dialog
  void _showPartialTransferDialog(ManifestItem item, Function(int) onTransfer) {
    showDialog(
      context: context,
      builder: (context) {
        int selectedQuantity = 1;
        
        return AlertDialog(
          title: const Text('Transfer Items'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'How many ${item.name} do you want to transfer to another vehicle?',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                PartialQuantitySelector(
                  itemName: item.name,
                  totalQuantity: item.quantity,
                  currentQuantity: selectedQuantity,
                  onQuantityChanged: (value) {
                    selectedQuantity = value;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              onPressed: () {
                Navigator.pop(context);
                onTransfer(selectedQuantity);
              },
              child: const Text('Transfer'),
            ),
          ],
        );
      },
    );
  }
  
  // New method to show vehicle selection for transfer
  void _showVehicleSelectionForTransfer(ManifestItem item, int quantity) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Destination Vehicle'),
          content: SizedBox(
            width: 400,
            height: 300,
            child: Consumer<VehicleService>(
              builder: (context, vehicleService, child) {
                return FutureBuilder<List<Vehicle>>(
                  future: vehicleService.getVehicles().first,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final vehicles = snapshot.data ?? [];
                    final filteredVehicles = vehicles
                        .where((v) => v.id != widget.vehicleId)
                        .toList();
                    
                    if (filteredVehicles.isEmpty) {
                      return const Center(
                        child: Text('No other vehicles available'),
                      );
                    }

                    return ListView.builder(
                      itemCount: filteredVehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = filteredVehicles[index];
                        return ListTile(
                          leading: Icon(_getVehicleIcon(vehicle.type)),
                          title: Text('${vehicle.make} ${vehicle.model}'),
                          subtitle: Text(vehicle.licensePlate),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(vehicle.status).withAlpha((0.2 * 255).toInt()),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getStatusLabel(vehicle.status),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(vehicle.status),
                              ),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _transferItemToVehicle(item, quantity, vehicle.id);
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
  
  // Method to handle transferring items between vehicles
  Future<void> _transferItemToVehicle(ManifestItem item, int quantity, String destinationVehicleId) async {
    try {
      final manifestService = Provider.of<ManifestService>(context, listen: false);
      
      // First ensure we have the latest manifest
      String manifestId = item.id.split('_').first;
      final manifest = await manifestService.getManifestById(manifestId).first;
      
      if (manifest == null) {
        throw Exception('Manifest not found');
      }
      
      // Find the original item
      final originalItem = manifest.items.firstWhere(
        (manifestItem) => manifestItem.id == item.id,
        orElse: () => throw Exception('Item not found in manifest'),
      );
      
      // Calculate remaining quantity
      final remainingQuantity = originalItem.quantity - quantity;
      
      if (remainingQuantity < 0) {
        throw Exception('Invalid quantity');
      }
      
      // Create a copy of all items
      final updatedItems = List<ManifestItem>.from(manifest.items);
      
      // Find and update the original item
      final originalItemIndex = updatedItems.indexWhere((i) => i.id == item.id);
      if (originalItemIndex != -1) {
        if (remainingQuantity > 0) {
          // Update the quantity of the original item
          updatedItems[originalItemIndex] = ManifestItem(
            id: item.id,
            name: item.name,
            menuItemId: item.menuItemId,
            quantity: remainingQuantity,
            vehicleId: widget.vehicleId,
            loadingStatus: item.loadingStatus,
          );
        } else {
          // Remove the item if no quantity remains
          updatedItems.removeAt(originalItemIndex);
        }
      }
      
      // Add the new item with the transferred quantity to the destination vehicle
      // Generate a unique ID by appending timestamp to existing item ID
      final newItemId = '${DateTime.now().millisecondsSinceEpoch}_${item.menuItemId}';
      updatedItems.add(ManifestItem(
        id: newItemId,
        name: item.name,
        menuItemId: item.menuItemId,
        quantity: quantity,
        vehicleId: destinationVehicleId,
        loadingStatus: LoadingStatus.pending, // Reset to pending for new vehicle
      ));
      
      // Create updated manifest
      final updatedManifest = Manifest(
        id: manifest.id,
        eventId: manifest.eventId,
        organizationId: manifest.organizationId,
        items: updatedItems,
        createdAt: manifest.createdAt,
        updatedAt: DateTime.now(),
      );
      
      // Update the manifest
      await manifestService.updateManifest(updatedManifest);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transferred $quantity ${item.name} to another vehicle'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error transferring item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show item options menu
  void _showItemOptions(ManifestItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'Quantity: ${item.quantity}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                
                // Update loading status
                ListTile(
                  leading: Icon(
                    item.loadingStatus == LoadingStatus.loaded
                        ? Icons.check_circle
                        : Icons.pending_actions,
                    color: item.loadingStatus == LoadingStatus.loaded
                        ? Colors.green
                        : Colors.orange,
                  ),
                  title: Text(
                    item.loadingStatus == LoadingStatus.loaded
                        ? 'Mark as Pending'
                        : 'Mark as Loaded',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    
                    final newStatus = item.loadingStatus == LoadingStatus.loaded
                        ? LoadingStatus.pending
                        : LoadingStatus.loaded;
                    
                    _dragDropManager.updateItemStatus(item, newStatus);
                  },
                ),
                
                // Transfer to another vehicle option
                ListTile(
                  leading: const Icon(Icons.swap_horiz, color: Colors.blue),
                  title: const Text('Transfer to Another Vehicle'),
                  onTap: () {
                    Navigator.pop(context);
                    _showPartialTransferDialog(item, (quantity) {
                      _showVehicleSelectionForTransfer(item, quantity);
                    });
                  },
                ),
                
                // Remove from vehicle option
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  title: const Text('Remove from Vehicle'),
                  onTap: () {
                    Navigator.pop(context);
                    _dragDropManager.removeFromVehicle(item);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // The main build method remains largely the same
    // ...
    
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        bottomNavigationBar: const BottomToolbar(),
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
        bottomNavigationBar: const BottomToolbar(),
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
      bottomNavigationBar: const BottomToolbar(),
      appBar: AppBar(
        title: Text('${_vehicle!.make} ${_vehicle!.model} Loading'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh data',
            onPressed: () {
              setState(() {
                _eventDetails.clear();
                _failedEventIds.clear();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Vehicle details card stays the same
          // ...
          
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
                        color: theme.primaryColor.withAlpha((0.1 * 255).toInt()),
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

          // Tabs with filter options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTab(_selectedFilter == 'All Items', 'All Items', Icons.list, () => _setFilter('All Items')),
                  const SizedBox(width: 8),
                  _buildTab(_selectedFilter == 'Pending', 'Pending', Icons.pending_actions, () => _setFilter('Pending')),
                  const SizedBox(width: 8),
                  _buildTab(_selectedFilter == 'Loaded', 'Loaded', Icons.check_circle_outline, () => _setFilter('Loaded')),
                  const SizedBox(width: 8),
                  _buildTab(_selectedFilter == 'Partial', 'Partial', Icons.splitscreen, () => _setFilter('Partial')),
                  const SizedBox(width: 16),
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
                      // Find items that are partial loads
                      filteredItems = items.where((item) {
                        final totalCount = _getTotalItemCountAcrossVehicles(items, item.menuItemId);
                        return totalCount > item.quantity;
                      }).toList();
                    }

                    // Group items by manifest/event and render
                    // ...
                    
                    // Group items by manifest/event
                    final groupedItems = <String, List<ManifestItem>>{};
                    for (final item in filteredItems) {
                      // Extract the manifestId from the item id format
                      String manifestId;
                      
                      if (item.id.contains('_')) {
                        manifestId = item.id.split('_').first;
                      } else {
                        // If item ID doesn't have the expected format, use menuItemId as fallback
                        manifestId = item.menuItemId;
                      }

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
                              items, // Pass all items to calculate partials
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
    );
  }

  // Update the event section to show partial item information
  Widget _buildEventSection(
    BuildContext context,
    String eventName,
    String eventDate,
    List<ManifestItem> manifestItems,
    List<ManifestItem> allItems,
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

        // Display items with partial loading information
        ...manifestItems.map((item) => _buildEnhancedItemTile(item, allItems)),

        const Divider(height: 32),
      ],
    );
  }

  // Helper method to get total count of an item across all vehicles
  int _getTotalItemCountAcrossVehicles(List<ManifestItem> allItems, String menuItemId) {
    // Group items by menuItemId
    final itemsByType = <String, List<ManifestItem>>{};
    
    for (final item in allItems) {
      if (!itemsByType.containsKey(item.menuItemId)) {
        itemsByType[item.menuItemId] = [];
      }
      itemsByType[item.menuItemId]!.add(item);
    }
    
    // Calculate total quantity for this menu item
    if (itemsByType.containsKey(menuItemId)) {
      return itemsByType[menuItemId]!.fold(0, (sum, item) => sum + item.quantity);
    }
    
    return 0;
  }

  // Enhanced item tile with partial loading information
  Widget _buildEnhancedItemTile(ManifestItem item, List<ManifestItem> allItems) {
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
    
    // Calculate if this is a partial load
    final totalQuantity = _getTotalItemCountAcrossVehicles(allItems, item.menuItemId);
    final isPartial = totalQuantity > item.quantity;
    
    // Find items of the same type across other vehicles
    final sameTypeItems = allItems
        .where((i) => i.menuItemId == item.menuItemId && i.vehicleId != widget.vehicleId)
        .toList();
    
    final otherVehiclesCount = sameTypeItems.isNotEmpty
        ? sameTypeItems.fold(0, (sum, i) => sum + i.quantity)
        : 0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: statusColor.withAlpha((0.3 * 255).toInt()),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showItemOptions(item),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                        Row(
                          children: [
                            Text(
                              'Quantity: ${item.quantity}',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                              ),
                            ),
                            if (isPartial) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withAlpha((0.2 * 255).toInt()),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Partial: ${item.quantity}/$totalQuantity',
                                  style: const TextStyle(
                                    color: Colors.purple,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
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
              
              // Show other vehicle distribution info if this is a partial load
              if (isPartial && otherVehiclesCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Also loaded: $otherVehiclesCount in other vehicles',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
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