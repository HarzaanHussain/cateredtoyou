import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/models/vehicle_model.dart';
import 'package:cateredtoyou/services/manifest_service.dart';
import 'package:cateredtoyou/services/event_service.dart';
import 'package:cateredtoyou/services/vehicle_service.dart';
import 'package:cateredtoyou/managers/drag_drop_manager.dart';
import 'package:cateredtoyou/views/manifest/widgets/manifest_item_card.dart';
import 'package:cateredtoyou/views/manifest/widgets/vehicle_card.dart';
import 'package:cateredtoyou/views/manifest/widgets/drag_item_indicator.dart';

/// A split view manifest screen showing unassigned items and vehicles side by side
///
/// This screen shows both unassigned items and vehicles side by side 
/// for better drag and drop functionality, especially on larger screens.
class SplitViewManifestScreen extends StatefulWidget {
  final String manifestId;

  const SplitViewManifestScreen({
    super.key,
    required this.manifestId,
  });

  @override
  State<SplitViewManifestScreen> createState() => _SplitViewManifestScreenState();
}

class _SplitViewManifestScreenState extends State<SplitViewManifestScreen> {
  // Drag Drop Manager
  late DragDropManager _dragDropManager;
  
  // Event information
  String _eventName = 'Loading...';
  String _eventDate = '';
  
  // Selection and quantities
  final Map<String, bool> _selectedItems = {};
  final Map<String, int> _itemQuantities = {};
  
  // Search & filtering
  String _searchQuery = '';
  String _sortOption = 'Name (A-Z)';
  bool _filterLoadedItems = false;
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize drag drop manager with current context
    _dragDropManager = DragDropManager(context);
  }

  // Load event details
  Future<void> _loadEventDetails(String eventId) async {
    try {
      final eventService = Provider.of<EventService>(context, listen: false);
      final event = await eventService.getEventById(eventId);

      if (!mounted) return;
      
      setState(() {
        _eventName = event?.name ?? 'Unknown Event';
        _eventDate = event?.startDate != null
            ? DateFormat('MMM d, yyyy').format(event!.startDate)
            : '';
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _eventName = 'Error loading event';
        _eventDate = '';
      });
    }
  }
  
  // Handle selecting an item
  void _handleItemSelected(String itemId, bool selected) {
    setState(() {
      _selectedItems[itemId] = selected;
    });
  }

  // Handle select all items
  void _handleSelectAll(bool selected, List<ManifestItem> items) {
    setState(() {
      for (var item in items) {
        if (item.vehicleId == null) {
          _selectedItems[item.id] = selected;
        }
      }
    });
  }

  // Handle quantity changes
  void _handleQuantityChanged(String itemId, int quantity) {
    setState(() {
      _itemQuantities[itemId] = quantity;
    });
  }
  
  // Handle drag start for selected items
  void _handleDragStart(List<ManifestItem> items, List<int> quantities) {
    // Use drag drop manager to start the drag
    _dragDropManager.startDrag(items, quantities, widget.manifestId);
    
    // Force UI update
    setState(() {});
  }
  
  // Handle drop on a vehicle
  Future<void> _handleDropOnVehicle(String vehicleId, Manifest manifest) async {
    // Use drag drop manager to handle the drop
    final success = await _dragDropManager.dropOnVehicle(vehicleId);
    
    if (success && mounted) {
      // Update UI state
      setState(() {
        _selectedItems.clear();
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Items loaded to vehicle'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  // Remove an item from a vehicle
  Future<void> _handleRemoveFromVehicle(ManifestItem item) async {
    await _dragDropManager.removeFromVehicle(item);
    
    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item removed from vehicle'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  // Update item loading status
  Future<void> _handleUpdateStatus(ManifestItem item, LoadingStatus status) async {
    await _dragDropManager.updateItemStatus(item, status);
    
    // Show feedback when item is loaded
    if (status == LoadingStatus.loaded && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item marked as loaded'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  // Show vehicle selection dialog
  void _showVehicleSelection() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Vehicle to Load Items'),
          content: SizedBox(
            width: 400,
            height: 300,
            child: Consumer<VehicleService>(
              builder: (context, vehicleService, child) {
                return StreamBuilder<List<Vehicle>>(
                  stream: vehicleService.getVehicles(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final vehicles = snapshot.data ?? [];
                    
                    if (vehicles.isEmpty) {
                      return const Center(
                        child: Text('No vehicles available'),
                      );
                    }

                    return ListView.builder(
                      itemCount: vehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = vehicles[index];
                        return ListTile(
                          leading: Icon(_getVehicleIcon(vehicle.type)),
                          title: Text('${vehicle.make} ${vehicle.model}'),
                          subtitle: Text(vehicle.licensePlate),
                          trailing: Text(
                            _getStatusLabel(vehicle.status),
                            style: TextStyle(
                              color: _getStatusColor(vehicle.status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            
                            // Get the manifest and handle assignment
                            Provider.of<ManifestService>(context, listen: false)
                                .getManifestById(widget.manifestId)
                                .first
                                .then((manifest) {
                                  if (!mounted || manifest == null) return;
                                  
                                  // Get the selected items
                                  final selectedItems = _getSelectedItems(manifest);
                                  final quantities = selectedItems
                                      .map((item) => _itemQuantities[item.id] ?? item.quantity)
                                      .toList();
                                  
                                  // Handle drag and drop
                                  _handleDragStart(selectedItems, quantities);
                                  _handleDropOnVehicle(vehicle.id, manifest);
                                });
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

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Sort Items By',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.sort_by_alpha),
                  title: const Text('Name (A-Z)'),
                  trailing: _sortOption == 'Name (A-Z)' 
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    setState(() {
                      _sortOption = 'Name (A-Z)';
                    });
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.sort_by_alpha),
                  title: const Text('Name (Z-A)'),
                  trailing: _sortOption == 'Name (Z-A)' 
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    setState(() {
                      _sortOption = 'Name (Z-A)';
                    });
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.numbers),
                  title: const Text('Quantity (High to Low)'),
                  trailing: _sortOption == 'Quantity (High to Low)' 
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    setState(() {
                      _sortOption = 'Quantity (High to Low)';
                    });
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.numbers),
                  title: const Text('Quantity (Low to High)'),
                  trailing: _sortOption == 'Quantity (Low to High)' 
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    setState(() {
                      _sortOption = 'Quantity (Low to High)';
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Get selected manifest items
  List<ManifestItem> _getSelectedItems(Manifest manifest) {
    return manifest.items
        .where((item) => item.vehicleId == null && (_selectedItems[item.id] ?? false))
        .toList();
  }

  // Sort and filter items
  List<ManifestItem> _applySortAndFilter(List<ManifestItem> items) {
    // Apply search filter
    var filteredItems = _searchQuery.isEmpty 
        ? items 
        : items.where((item) => 
            item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            item.menuItemId.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();
    
    // Apply loading status filter if enabled
    if (_filterLoadedItems) {
      filteredItems = filteredItems.where((item) => 
        item.loadingStatus != LoadingStatus.loaded
      ).toList();
    }
    
    // Apply sorting
    switch (_sortOption) {
      case 'Name (A-Z)':
        filteredItems.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Name (Z-A)':
        filteredItems.sort((a, b) => b.name.compareTo(a.name));
        break;
      case 'Quantity (High to Low)':
        filteredItems.sort((a, b) => b.quantity.compareTo(a.quantity));
        break;
      case 'Quantity (Low to High)':
        filteredItems.sort((a, b) => a.quantity.compareTo(b.quantity));
        break;
    }
    
    return filteredItems;
  }

  bool _areAllItemsSelected(List<ManifestItem> items) {
    if (items.isEmpty) {
      return false;
    }

    return items.every((item) => _selectedItems[item.id] == true);
  }
  
  int _countSelectedItems(List<ManifestItem> items) {
    return items.where((item) => _selectedItems[item.id] ?? false).length;
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 800;
    
    // If screen is too small, redirect to the tabbed view
    if (isSmallScreen) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Manifest Details'),
        ),
        body: const Center(
          child: Text('This view requires a larger screen'),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Loading Manifest'),
            if (_eventName.isNotEmpty && _eventName != 'Loading...')
              Text(
                _eventName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: theme.appBarTheme.foregroundColor?.withAlpha((0.8 * 255).toInt()),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (_eventDate.isNotEmpty)
              Text(
                _eventDate,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: theme.appBarTheme.foregroundColor?.withAlpha((0.7 * 255).toInt()),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort items',
            onPressed: _showSortOptions,
          ),
          IconButton(
            icon: Icon(
              _filterLoadedItems ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _filterLoadedItems ? Colors.blue : null,
            ),
            tooltip: _filterLoadedItems ? 'Show all items' : 'Hide loaded items',
            onPressed: () {
              setState(() {
                _filterLoadedItems = !_filterLoadedItems;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search items...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              
              // Main content - split view
              Expanded(
                child: StreamBuilder<Manifest?>(
                  stream: Provider.of<ManifestService>(context).getManifestById(widget.manifestId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error: ${snapshot.error}'),
                            TextButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              onPressed: () {
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    }

                    final manifest = snapshot.data;
                    if (manifest == null) {
                      return const Center(
                        child: Text('Manifest not found'),
                      );
                    }

                    // Load event details if needed
                    if (_eventName == 'Loading...') {
                      _loadEventDetails(manifest.eventId);
                    }

                    // Initialize quantities
                    for (var item in manifest.items) {
                      if (!_itemQuantities.containsKey(item.id)) {
                        _itemQuantities[item.id] = item.quantity;
                      }
                    }

                    // Get unassigned items
                    final unassignedItems = manifest.items
                        .where((item) => item.vehicleId == null)
                        .toList();
                        
                    // Apply sort and filter
                    final filteredUnassignedItems = _applySortAndFilter(unassignedItems);

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left panel - Unassigned items
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              // Header with actions
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                color: theme.cardColor,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${filteredUnassignedItems.length} Items to Load',
                                        style: theme.textTheme.titleMedium,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        _areAllItemsSelected(filteredUnassignedItems)
                                            ? Icons.select_all
                                            : Icons.check_box_outline_blank,
                                        color: theme.primaryColor,
                                      ),
                                      tooltip: _areAllItemsSelected(filteredUnassignedItems)
                                          ? 'Deselect All'
                                          : 'Select All',
                                      onPressed: () {
                                        _handleSelectAll(!_areAllItemsSelected(filteredUnassignedItems), manifest.items);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Items list
                              Expanded(
                                child: filteredUnassignedItems.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.check_circle_outline,
                                              size: 64,
                                              color: Colors.green[300],
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              'All items loaded',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              _searchQuery.isNotEmpty || _filterLoadedItems
                                                  ? 'Try changing your search or filters'
                                                  : 'No items need to be loaded',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      )
                                    : _buildDraggableItemsList(filteredUnassignedItems),
                              ),
                              
                              // Bottom bar with actions for items
                              if (filteredUnassignedItems.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  color: theme.cardColor,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _countSelectedItems(filteredUnassignedItems) == 0
                                              ? 'No items selected'
                                              : '${_countSelectedItems(filteredUnassignedItems)} items selected',
                                          style: TextStyle(
                                            fontWeight: _countSelectedItems(filteredUnassignedItems) > 0
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      if (_countSelectedItems(filteredUnassignedItems) > 0)
                                        TextButton(
                                          child: const Text('Clear'),
                                          onPressed: () {
                                            setState(() {
                                              _selectedItems.clear();
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        // Divider
                        Container(
                          width: 1,
                          color: Colors.grey[300],
                        ),
                        
                        // Right panel - Vehicles
                        Expanded(
                          flex: 1,
                          child: Consumer<VehicleService>(
                            builder: (context, vehicleService, child) {
                              return StreamBuilder<List<Vehicle>>(
                                stream: vehicleService.getVehicles(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator());
                                  }

                                  final vehicles = snapshot.data ?? [];
                                  
                                  if (vehicles.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey[400]),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No vehicles available',
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 8),
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.add),
                                            label: const Text('Add Vehicle'),
                                            onPressed: () {
                                              // Would open vehicle creation screen
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        color: theme.cardColor,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${vehicles.length} Vehicles',
                                                style: theme.textTheme.titleMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: ListView.builder(
                                          padding: const EdgeInsets.all(16),
                                          itemCount: vehicles.length,
                                          itemBuilder: (context, index) {
                                            final vehicle = vehicles[index];
                                            return VehicleCard(
                                              vehicle: vehicle,
                                              manifest: manifest,
                                              onDrop: (vehicleId) => _handleDropOnVehicle(vehicleId, manifest),
                                              onRemoveItem: _handleRemoveFromVehicle,
                                              onUpdateStatus: _handleUpdateStatus,
                                              isSmallScreen: false,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          
          // Floating indicator for selected items - Now correctly in a Stack
          Consumer<ManifestService>(
            builder: (context, manifestService, _) {
              return StreamBuilder<Manifest?>(
                stream: manifestService.getManifestById(widget.manifestId),
                builder: (context, snapshot) {
                  // Only show if we have data and selected items
                  if (!snapshot.hasData || !_selectedItems.values.contains(true)) {
                    return const SizedBox.shrink();
                  }
                  
                  final manifest = snapshot.data!;
                  final selectedCount = _countSelectedItems(
                    manifest.items.where((item) => item.vehicleId == null).toList()
                  );
                  
                  if (selectedCount == 0) {
                    return const SizedBox.shrink();
                  }
                  
                  return Positioned(
                    bottom: 16,
                    right: 16,
                    child: DragItemIndicator(
                      itemCount: selectedCount,
                      onAssign: _showVehicleSelection,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableItemsList(List<ManifestItem> items) {
    final itemsListView = ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _selectedItems[item.id] ?? false;
        final quantity = _itemQuantities[item.id] ?? item.quantity;
        
        return ManifestItemCard(
          item: item,
          isSelected: isSelected,
          quantity: quantity,
          onSelected: (selected) => _handleItemSelected(item.id, selected),
          onQuantityChanged: (newQuantity) => _handleQuantityChanged(item.id, newQuantity),
          isSmallScreen: false,
        );
      },
    );
    
    // If no items are selected, return the basic list
    if (!_selectedItems.values.contains(true)) {
      return itemsListView;
    }
    
    // When items are selected, use draggable
    return Draggable<Map<String, dynamic>>(
      data: {
        'items': items
            .where((item) => _selectedItems[item.id] == true)
            .toList(),
        'quantities': items
            .where((item) => _selectedItems[item.id] == true)
            .map((item) => _itemQuantities[item.id] ?? item.quantity)
            .toList(),
      },
      onDragStarted: () {
        // Notify parent about drag start
        final selectedItems = items
            .where((item) => _selectedItems[item.id] == true)
            .toList();
            
        final quantities = selectedItems
            .map((item) => _itemQuantities[item.id] ?? item.quantity)
            .toList();
            
        _handleDragStart(selectedItems, quantities);
      },
      feedback: _buildDragFeedback(items),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: itemsListView,
      ),
      child: itemsListView,
    );
  }
  
  Widget _buildDragFeedback(List<ManifestItem> items) {
    final selectedItems = items
        .where((item) => _selectedItems[item.id] == true)
        .toList();
        
    if (selectedItems.isEmpty) return const SizedBox.shrink();
    
    return Material(
      elevation: 4.0,
      borderRadius: BorderRadius.circular(8),
      color: Colors.transparent,
      child: Container(
        width: 120, // Fixed width
        height: 80,  // Fixed height
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${selectedItems.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const Text(
              'items',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper methods for vehicle display
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
}