import 'package:flutter/material.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/models/vehicle_model.dart';
import 'package:cateredtoyou/views/manifest/widgets/vehicle_item_tile.dart';
import 'package:cateredtoyou/views/manifest/vehicle_loading_screen.dart';

/// Card widget for displaying a vehicle with its assigned items
/// 
/// This widget shows a vehicle card that can accept drag-drop items
/// and displays the list of items currently assigned to it.
class VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final Manifest manifest;
  final Function(String) onDrop;
  final Function(ManifestItem) onRemoveItem;
  final Function(ManifestItem, LoadingStatus) onUpdateStatus;
  final bool isSmallScreen;

  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.manifest,
    required this.onDrop,
    required this.onRemoveItem,
    required this.onUpdateStatus,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Filter items assigned to this vehicle
    final assignedItems = manifest.items
        .where((item) => item.vehicleId == vehicle.id)
        .toList();
        
    // Calculate loading statistics
    final totalItems = assignedItems.length;
    final loadedCount = assignedItems
        .where((item) => item.loadingStatus == LoadingStatus.loaded)
        .length;
    final pendingCount = totalItems - loadedCount;
    
    // DragTarget to accept items
    return DragTarget<Map<String, dynamic>>(
      hitTestBehavior: HitTestBehavior.translucent,
      onWillAcceptWithDetails: (details) => 
          details.data.containsKey('items'),
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data.containsKey('items')) {
          onDrop(vehicle.id);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        
        // Fixed-width container to prevent layout issues
        return SizedBox(
          width: double.infinity,
          child: Card(
            elevation: isHovering ? 4 : 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isHovering
                  ? BorderSide(color: Colors.green, width: 2)
                  : BorderSide.none,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ExpansionTile(
                backgroundColor: isHovering
                    ? Colors.green.withAlpha((0.1 * 255).toInt())
                    : null,
                collapsedBackgroundColor: isHovering
                    ? Colors.green.withAlpha((0.1 * 255).toInt())
                    : null,
                title: Text(
                  '${vehicle.make} ${vehicle.model}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'License: ${vehicle.licensePlate}',
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      '$loadedCount/$totalItems items loaded',
                      style: TextStyle(
                        color: totalItems > 0 && loadedCount == totalItems
                            ? Colors.green
                            : Colors.grey[700],
                        fontWeight: totalItems > 0 && loadedCount == totalItems
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getVehicleIcon(vehicle.type),
                    color: theme.primaryColor,
                    size: 24,
                  ),
                ),
                trailing: totalItems > 0
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Loading progress indicator
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: loadedCount == totalItems
                                  ? Colors.green.withAlpha((0.2 * 255).toInt())
                                  : Colors.orange.withAlpha((0.2 * 255).toInt()),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              loadedCount == totalItems
                                  ? 'Loaded'
                                  : '$loadedCount of $totalItems',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: loadedCount == totalItems
                                    ? Colors.green
                                    : Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.expand_more),
                        ],
                      )
                    : null,
                initiallyExpanded: isHovering || totalItems > 0,
                children: [
                  // Top actions for viewing details or vehicle info
                  if (totalItems > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha((0.1 * 255).toInt()),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            // FIX: Use fixed-width buttons to avoid overflow
                            Expanded(
                              child: TextButton.icon(
                                icon: const Icon(Icons.check_circle_outline, size: 16),
                                label: const Text('Mark All Loaded'),
                                onPressed: loadedCount < totalItems ? () {
                                  // Mark all items as loaded
                                  for (final item in assignedItems) {
                                    if (item.loadingStatus != LoadingStatus.loaded) {
                                      onUpdateStatus(item, LoadingStatus.loaded);
                                    }
                                  }
                                } : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 80,
                              child: FittedBox(
                                child: TextButton.icon(
                                  icon: const Icon(Icons.visibility_outlined, size: 16),
                                  label: const Text('View'),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => VehicleLoadingScreen(
                                          vehicleId: vehicle.id,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                
                  // Hovering drop zone indicator
                  if (isHovering)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha((0.1 * 255).toInt()),
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((0.1 * 255).toInt()),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      margin: const EdgeInsets.all(16),
                      child: Column(
                        children: const [
                          Icon(Icons.add_circle, color: Colors.green, size: 32),
                          SizedBox(height: 8),
                          Text(
                            'Drop items here to load',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                  // Status counters - simplified for better UX
                  if (totalItems > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: pendingCount > 0
                                    ? Colors.orange.withAlpha((0.1 * 255).toInt())
                                    : Colors.grey.withAlpha((0.1 * 255).toInt()),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '$pendingCount',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: pendingCount > 0 ? Colors.orange : Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    'Pending',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: loadedCount > 0
                                    ? Colors.green.withAlpha((0.1 * 255).toInt())
                                    : Colors.grey.withAlpha((0.1 * 255).toInt()),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '$loadedCount',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: loadedCount > 0 ? Colors.green : Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    'Loaded',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                  // Assigned items list
                  if (totalItems > 0)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: assignedItems.length,
                      itemBuilder: (context, index) {
                        final item = assignedItems[index];
                        return VehicleItemTile(
                          item: item,
                          onRemove: () => onRemoveItem(item),
                          onStatusChanged: (status) => onUpdateStatus(item, status),
                        );
                      },
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 32,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No items loaded to this vehicle',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Drag items here or select items and tap "Load to Vehicle"',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
}