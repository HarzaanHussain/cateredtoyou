import 'package:cateredtoyou/views/manifest/widgets/partial_quantity_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/models/vehicle_model.dart';
import 'package:cateredtoyou/services/manifest_service.dart';
import 'package:cateredtoyou/services/event_service.dart';
import 'package:cateredtoyou/services/vehicle_service.dart';
import 'package:cateredtoyou/managers/drag_drop_manager.dart';
import 'package:cateredtoyou/views/manifest/unassigned_items_tab.dart';
import 'package:cateredtoyou/views/manifest/vehicles_tab.dart';
import 'package:cateredtoyou/views/manifest/split_view_manifest_screen.dart';
import 'package:cateredtoyou/views/manifest/widgets/drag_item_indicator.dart';

/// A professional manifest management screen with drag and drop support
///
/// This screen displays event details and allows users to:
/// - View items in a manifest
/// - Assign items to vehicles via drag-drop or selection
/// - Track loading status
/// - See vehicle assignments and status
class ManifestDetailScreen extends StatefulWidget {
  final String manifestId;

  const ManifestDetailScreen({
    super.key,
    required this.manifestId,
  });

  @override
  State<ManifestDetailScreen> createState() => _ManifestDetailScreenState();
}

class _ManifestDetailScreenState extends State<ManifestDetailScreen>
    with SingleTickerProviderStateMixin {
  // Tab controller
  late TabController _tabController;

  // Drag Drop Manager
  late DragDropManager _dragDropManager;

  // Event information
  String _eventName = 'Loading...';
  String _eventDate = '';

  // Selection and quantities
  final Map<String, bool> _selectedItems = {};
  final Map<String, int> _itemQuantities = {};

  // Search & filtering
  final String _searchQuery = '';
  String _sortOption = 'Name (A-Z)';
  bool _filterLoaded = false;

  // UI state
  bool _showVehicleSelectorOverlay = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Listen for tab changes to update UI
    _tabController.addListener(_handleTabChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize drag drop manager with current context
    _dragDropManager = DragDropManager(context);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    // When changing tabs, if items are selected, we can show a hint
    if (_tabController.indexIsChanging) {
      setState(() {
        // If we have selected items and are moving to the vehicles tab, show the selector
        final hasSelectedItems = _selectedItems.values.contains(true);
        if (hasSelectedItems && _tabController.index == 1) {
          _showVehicleSelectorOverlay = true;
        }
      });
    }
  }

  // Check for wider screens to show split view
  bool get _canShowSplitView {
    final width = MediaQuery.of(context).size.width;
    return width >= 1200; // Only for very wide screens
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

  void _showItemContextMenu(
      BuildContext context, ManifestItem item, Offset position) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(position, position),
        Rect.fromPoints(
          Offset.zero,
          overlay.size.bottomRight(Offset.zero),
        ),
      ),
      items: [
        PopupMenuItem(
          value: 'select',
          child: Row(
            children: [
              Icon(
                (_selectedItems[item.id] ?? false)
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                color: Colors.blue,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text('Select Item'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'partial',
          child: Row(
            children: const [
              Icon(
                Icons.splitscreen,
                color: Colors.green,
                size: 18,
              ),
              SizedBox(width: 8),
              Text('Partial Loading'),
            ],
          ),
        ),
      ],
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ).then((value) {
      if (value == 'select') {
        _handleItemSelected(item.id, !(_selectedItems[item.id] ?? false));
      } else if (value == 'partial') {
        _showPartialLoadingDialog(item);
      }
    });
  }

  void _showPartialLoadingDialog(ManifestItem item) {
    showDialog(
      context: context,
      builder: (context) {
        int selectedQuantity = _itemQuantities[item.id] ?? item.quantity;

        return AlertDialog(
          title: const Text('Partial Loading'),
          content: SizedBox(
            width: 400,
            child: PartialQuantitySelector(
              itemName: item.name,
              totalQuantity: item.quantity,
              currentQuantity: selectedQuantity,
              onQuantityChanged: (value) {
                selectedQuantity = value;
              },
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

                // Update the item quantity in state
                setState(() {
                  _itemQuantities[item.id] = selectedQuantity;

                  // If not already selected, select the item
                  if (!(_selectedItems[item.id] ?? false)) {
                    _selectedItems[item.id] = true;
                  }

                  // Show vehicle selector
                  _showVehicleSelectorOverlay = true;
                });
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  // Handle selecting an item
  void _handleItemSelected(String itemId, bool selected) {
    setState(() {
      _selectedItems[itemId] = selected;

      // If we selected an item and we're on the items tab,
      // show the floating action button
      if (selected && _tabController.index == 0) {
        _showVehicleSelectorOverlay = true;
      }

      // If we deselected all items, hide the selector
      if (!_selectedItems.values.contains(true)) {
        _showVehicleSelectorOverlay = false;
      }
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

      // Show vehicle selector if items are selected
      _showVehicleSelectorOverlay = selected && items.isNotEmpty;
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

    // Switch to the vehicles tab if we're not already there
    if (_tabController.index != 1) {
      _tabController.animateTo(1);
    }

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
        _showVehicleSelectorOverlay = false;
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
  Future<void> _handleUpdateStatus(
      ManifestItem item, LoadingStatus status) async {
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
                                  .map((item) =>
                                      _itemQuantities[item.id] ?? item.quantity)
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

  void _showSortAndFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Sort & Filter Items',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  // Sorting options
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Sort by:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.sort_by_alpha),
                    title: const Text('Name (A-Z)'),
                    trailing: _sortOption == 'Name (A-Z)'
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () {
                      setState(() {
                        _sortOption = 'Name (A-Z)';
                      });
                      setModalState(() {});
                    },
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.sort_by_alpha),
                    title: const Text('Name (Z-A)'),
                    trailing: _sortOption == 'Name (Z-A)'
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () {
                      setState(() {
                        _sortOption = 'Name (Z-A)';
                      });
                      setModalState(() {});
                    },
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.numbers),
                    title: const Text('Quantity (High to Low)'),
                    trailing: _sortOption == 'Quantity (High to Low)'
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () {
                      setState(() {
                        _sortOption = 'Quantity (High to Low)';
                      });
                      setModalState(() {});
                    },
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.numbers),
                    title: const Text('Quantity (Low to High)'),
                    trailing: _sortOption == 'Quantity (Low to High)'
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () {
                      setState(() {
                        _sortOption = 'Quantity (Low to High)';
                      });
                      setModalState(() {});
                    },
                  ),
                  // Filter options
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Filters:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Hide loaded items'),
                    value: _filterLoaded,
                    onChanged: (value) {
                      setState(() {
                        _filterLoaded = value;
                      });
                      setModalState(() {});
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text('Apply'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Get selected manifest items
  List<ManifestItem> _getSelectedItems(Manifest manifest) {
    return manifest.items
        .where((item) =>
            item.vehicleId == null && (_selectedItems[item.id] ?? false))
        .toList();
  }

  // Apply sort and filter
  List<ManifestItem> _applySortAndFilter(List<ManifestItem> items) {
    var filteredItems = items;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filteredItems = filteredItems
          .where((item) =>
              item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              item.menuItemId
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Filter out loaded items if enabled
    if (_filterLoaded) {
      filteredItems = filteredItems
          .where((item) => item.loadingStatus != LoadingStatus.loaded)
          .toList();
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

  // Count selected items
  int _countSelectedItems(Manifest manifest) {
    return _getSelectedItems(manifest).length;
  }

  @override
  Widget build(BuildContext context) {
    // For very wide screens, use the split view
    if (_canShowSplitView) {
      return SplitViewManifestScreen(manifestId: widget.manifestId);
    }

    final theme = Theme.of(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

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
                  color: theme.appBarTheme.foregroundColor
                      ?.withAlpha((0.8 * 255).toInt()),
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
                  color: theme.appBarTheme.foregroundColor
                      ?.withAlpha((0.7 * 255).toInt()),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        bottom: TabBar(
          labelColor: Colors.black,        // <- selected tab text color
          controller: _tabController,
          tabs:
          [
            Tab(
              text: isSmallScreen ? 'Items' : 'Items to Load',
              icon: isSmallScreen ? const Icon(Icons.inventory_2) : null,
            ),
            Tab(
              text: isSmallScreen ? 'Vehicles' : 'Vehicle Loading',
              icon: isSmallScreen ? const Icon(Icons.local_shipping) : null,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () {
              showSearch(
                context: context,
                delegate: ManifestSearchDelegate(
                  manifest: Provider.of<ManifestService>(context, listen: false)
                      .getManifestById(widget.manifestId),
                  onItemSelected: (item) {
                    setState(() {
                      _selectedItems[item.id] = true;
                      _showVehicleSelectorOverlay = true;
                    });
                    // Switch to items tab to see the selection
                    _tabController.animateTo(0);
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              _filterLoaded || _sortOption != 'Name (A-Z)'
                  ? Icons.filter_list_alt
                  : Icons.filter_list,
              color: _filterLoaded || _sortOption != 'Name (A-Z)'
                  ? Colors.blue
                  : null,
            ),
            tooltip: 'Sort & Filter',
            onPressed: _showSortAndFilterOptions,
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<Manifest?>(
            stream: Provider.of<ManifestService>(context)
                .getManifestById(widget.manifestId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
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

              // Apply sorting and filtering to manifest items
              final filteredItems = _applySortAndFilter(manifest.items);

              return Column(
                children: [
                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Unassigned items tab
                        UnassignedItemsTab(
                          manifest: manifest,
                          filteredItems: filteredItems,
                          selectedItems: _selectedItems,
                          itemQuantities: _itemQuantities,
                          onItemSelected: _handleItemSelected,
                          onSelectAll: (selected) =>
                              _handleSelectAll(selected, manifest.items),
                          onQuantityChanged: _handleQuantityChanged,
                          onDragStart: _handleDragStart,
                          onShowContextMenu: (context, item, position) =>
                              _showItemContextMenu(context, item, position),
                          isSmallScreen: isSmallScreen,
                        ),

                        // Vehicle assignments tab
                        VehiclesTab(
                          manifest: manifest,
                          onDrop: (vehicleId) =>
                              _handleDropOnVehicle(vehicleId, manifest),
                          onRemoveItem: _handleRemoveFromVehicle,
                          onUpdateStatus: _handleUpdateStatus,
                          isSmallScreen: isSmallScreen,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          // Vehicle selector overlay - now correctly inside a Stack widget
          if (_showVehicleSelectorOverlay)
            Positioned(
              right: 16,
              bottom: 76, // Above the bottom bar
              child: StreamBuilder<Manifest?>(
                stream: Provider.of<ManifestService>(context)
                    .getManifestById(widget.manifestId),
                builder: (context, snapshot) {
                  final manifest = snapshot.data;
                  if (manifest == null) return const SizedBox.shrink();

                  // Get selected count
                  final count = _countSelectedItems(manifest);
                  if (count == 0) return const SizedBox.shrink();

                  return DragItemIndicator(
                    itemCount: count,
                    onAssign: _showVehicleSelection,
                  );
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(isSmallScreen),
    );
  }

  Widget _buildBottomBar(bool isSmallScreen) {
    return BottomAppBar(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Selected items count
            Expanded(
              flex: 2,
              child: Consumer<ManifestService>(
                builder: (context, manifestService, child) {
                  return StreamBuilder<Manifest?>(
                    stream: manifestService.getManifestById(widget.manifestId),
                    builder: (context, snapshot) {
                      final manifest = snapshot.data;
                      if (manifest == null) return const SizedBox.shrink();

                      // Count selected items
                      final selectedCount = _selectedItems.entries
                          .where((entry) => entry.value)
                          .length;

                      return Text(
                        selectedCount == 0
                            ? 'No items selected'
                            : '$selectedCount items selected',
                        style: TextStyle(
                          fontWeight: selectedCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  );
                },
              ),
            ),

            // Fixed size spacer
            const SizedBox(width: 8),

            // Action buttons with fixed width
            if (_selectedItems.values.contains(true))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    child: const Text('Clear'),
                    onPressed: () {
                      setState(() {
                        _selectedItems.clear();
                        _showVehicleSelectorOverlay = false;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  // FIXED BUTTON - Specified width to avoid infinite constraints
                  SizedBox(
                    width: isSmallScreen ? 100 : 150,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      icon: Icon(
                        Icons.local_shipping,
                        size: isSmallScreen ? 14 : 18,
                      ),
                      label: Text(
                        isSmallScreen ? 'Load' : 'Load to Vehicle',
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: _showVehicleSelection,
                    ),
                  ),
                ],
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

// Search delegate for manifest items
class ManifestSearchDelegate extends SearchDelegate<ManifestItem?> {
  final Stream<Manifest?> manifest;
  final Function(ManifestItem) onItemSelected;

  ManifestSearchDelegate({
    required this.manifest,
    required this.onItemSelected,
  });

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    return StreamBuilder<Manifest?>(
      stream: manifest,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const Center(
            child: Text('Error loading items'),
          );
        }

        final manifest = snapshot.data!;
        final items = manifest.items
            .where((item) => item.vehicleId == null)
            .where((item) =>
                query.isEmpty ||
                item.name.toLowerCase().contains(query.toLowerCase()) ||
                item.menuItemId.toLowerCase().contains(query.toLowerCase()))
            .toList();

        if (items.isEmpty) {
          return const Center(
            child: Text('No matching items found'),
          );
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              title: Text(item.name),
              subtitle: Text('ID: ${item.menuItemId} • Qty: ${item.quantity}'),
              trailing: const Icon(Icons.add_circle_outline),
              onTap: () {
                onItemSelected(item);
                close(context, item);
              },
            );
          },
        );
      },
    );
  }
}
