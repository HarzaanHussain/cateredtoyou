import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/models/vehicle_model.dart';
import 'package:cateredtoyou/services/manifest_service.dart';
import 'package:cateredtoyou/services/vehicle_service.dart';
import 'package:cateredtoyou/services/event_service.dart';

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
  final Map<String, dynamic> _eventDetails = {};

  @override
  void initState() {
    super.initState();
    _loadVehicleDetails();
  }

  Future<void> _loadVehicleDetails() async {
    try {
      final vehicleService = Provider.of<VehicleService>(context, listen: false);
      
      // Get all vehicles and find the one we're looking for
      final vehicles = await vehicleService.getVehicles().first;
      
      if (!mounted) return;
      
      setState(() {
        _vehicle = vehicles.firstWhere(
          (v) => v.id == widget.vehicleId,
          orElse: () => throw Exception('Vehicle not found'), // Throw an exception if not found
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

  Future<Map<String, dynamic>> _getEventDetails(String eventId) async {
    // Check cache first
    if (_eventDetails.containsKey(eventId)) {
      return _eventDetails[eventId];
    }
    
    try {
      final eventService = Provider.of<EventService>(context, listen: false);
      final event = await eventService.getEventById(eventId);
      
      if (event != null) {
        final details = {
          'name': event.name,
          'date': DateFormat('MMM d, yyyy').format(event.startDate),
        };
        
        // Cache for future use
        _eventDetails[eventId] = details;
        return details;
      }
      
      return {
        'name': 'Unknown Event',
        'date': 'Unknown date',
      };
    } catch (e) {
      return {
        'name': 'Error loading event',
        'date': '',
      };
    }
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
            icon: const Icon(Icons.print),
            tooltip: 'Print Loading List',
            onPressed: () {
              // Would implement printing functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Printing not implemented')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More options',
            onPressed: () {
              // Show more options
            },
          ),
        ],
      ),
      body: Column(
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
                        color: theme.primaryColor.withAlpha((0.1 * 255).toInt()),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.local_shipping,
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
            child: Row(
              children: [
                _buildTab(true, 'All Items', Icons.list),
                const SizedBox(width: 8),
                _buildTab(false, 'Pending', Icons.pending_actions),
                const SizedBox(width: 8),
                _buildTab(false, 'Loaded', Icons.check_circle_outline),
                const Spacer(),
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
          
          // Items list grouped by event
          Expanded(
            child: Consumer<ManifestService>(
              builder: (context, manifestService, child) {
                return StreamBuilder<List<ManifestItem>>(
                  stream: manifestService.getManifestItemsByVehicleId(widget.vehicleId),
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
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
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

                    // Group items by manifest/event
                    final groupedItems = <String, List<ManifestItem>>{};
                    for (final item in items) {
                      final manifestId = item.id.split('_').first;
                      if (!groupedItems.containsKey(manifestId)) {
                        groupedItems[manifestId] = [];
                      }
                      groupedItems[manifestId]!.add(item);
                    }

                    // Convert to list for ListView
                    final groupedList = groupedItems.entries.toList();
                    
                    // Build list with headers for each event
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: groupedList.length,
                      itemBuilder: (context, index) {
                        final entry = groupedList[index];
                        final manifestItems = entry.value;
                        
                        // Calculate loading statistics
                        final totalItems = manifestItems.length;
                        final loadedCount = manifestItems
                            .where((item) => item.loadingStatus == LoadingStatus.loaded)
                            .length;
                        final loadedPercentage = (loadedCount / totalItems * 100).toInt();
                        
                        return FutureBuilder<Map<String, dynamic>>(
                          future: _getEventDetails(manifestItems.first.id.split('_').first),
                          builder: (context, eventSnapshot) {
                            final eventName = eventSnapshot.data?['name'] ?? 'Loading...';
                            final eventDate = eventSnapshot.data?['date'] ?? '';
                            
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
                                
                                // Items for this event
                                ...manifestItems.map((item) => _buildItemTile(item)),
                                
                                if (index < groupedList.length - 1)
                                  Divider(color: Colors.grey[300], height: 32),
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
        ],
      ),
    );
  }
  
  Widget _buildTab(bool isSelected, String label, IconData icon) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: () {
        // Would implement tab selection
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor
              : theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? theme.primaryColor
                : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : Colors.grey[700],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.grey[700],
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
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
        onTap: () {
          // Would implement item details view
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
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