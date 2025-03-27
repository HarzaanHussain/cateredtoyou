import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/models/vehicle_model.dart';
import 'package:cateredtoyou/services/vehicle_service.dart';
import 'package:cateredtoyou/views/manifest/widgets/vehicle_card.dart';

/// Tab for displaying and managing vehicle assignments
///
/// This widget displays all vehicles and their assigned items, allowing users
/// to drop items onto vehicles, update loading status, and remove items.
class VehiclesTab extends StatelessWidget {
  final Manifest manifest;
  final Function(String) onDrop;
  final Function(ManifestItem) onRemoveItem;
  final Function(ManifestItem, LoadingStatus) onUpdateStatus;
  final bool isSmallScreen;

  const VehiclesTab({
    super.key,
    required this.manifest,
    required this.onDrop,
    required this.onRemoveItem,
    required this.onUpdateStatus,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<VehicleService>(
      builder: (context, vehicleService, child) {
        return StreamBuilder<List<Vehicle>>(
          stream: vehicleService.getVehicles(),
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
                  ],
                ),
              );
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: () {
                        // Would open vehicle creation screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Add vehicle functionality would go here'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            }

            // Calculate loading progress
            final totalAssignedItems = manifest.items
                .where((item) => item.vehicleId != null)
                .length;
                
            final totalLoadedItems = manifest.items
                .where((item) => 
                  item.vehicleId != null && 
                  item.loadingStatus == LoadingStatus.loaded)
                .length;
                
            final overallProgress = totalAssignedItems > 0
                ? (totalLoadedItems / totalAssignedItems * 100).toInt()
                : 0;

            return Column(
              children: [
                // Overall progress at top
                if (totalAssignedItems > 0)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey[100],
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Overall Loading Progress',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: overallProgress == 100 
                                    ? Colors.green.withAlpha((0.2 * 255).toInt())
                                    : Colors.orange.withAlpha((0.2 * 255).toInt()),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$totalLoadedItems of $totalAssignedItems items loaded',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: overallProgress == 100 ? Colors.green : Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: overallProgress / 100,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              overallProgress == 100 ? Colors.green : Colors.orange,
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (overallProgress == 100)
                              const Text(
                                'All items loaded',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            else
                              Text(
                                '${100 - overallProgress}% remaining',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                
                // Vehicle header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${vehicles.length} Available Vehicles',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        totalAssignedItems > 0
                            ? '$totalLoadedItems of $totalAssignedItems items loaded'
                            : 'No items assigned yet',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Hint for drag-drop
                if (totalAssignedItems == 0)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha((0.1 * 255).toInt()),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withAlpha((0.3 * 255).toInt()),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Select items from the Items tab and drag them here, or use the "Load to Vehicle" button',
                            style: TextStyle(
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Vehicles list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: vehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = vehicles[index];
                      return VehicleCard(
                        vehicle: vehicle,
                        manifest: manifest,
                        onDrop: onDrop,
                        onRemoveItem: onRemoveItem,
                        onUpdateStatus: onUpdateStatus,
                        isSmallScreen: isSmallScreen,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}