// File: lib/views/manifest/widgets/vehicle_content_container.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/vehicle_model.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/services/manifest_service.dart';
import 'package:cateredtoyou/managers/drag_drop_manager.dart';
import 'package:cateredtoyou/views/manifest/widgets/vehicle_content.dart';

/// Container widget for displaying vehicle contents in a dialog
///
/// This widget encapsulates the logic for loading vehicle-specific manifest items
/// and handling drag/drop operations for the vehicle content dialog.
class VehicleContentContainer extends StatelessWidget {
  final Vehicle vehicle;
  final DragDropManager dragDropManager;

  const VehicleContentContainer({
    Key? key,
    required this.vehicle,
    required this.dragDropManager,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Consumer only listens to ManifestService changes
    return Consumer<ManifestService>(
      builder: (context, manifestService, child) {
        // Stream provides reactive updates when vehicle's assigned items change
        return StreamBuilder<List<ManifestItem>>(
          stream: manifestService.getManifestItemsByVehicleId(vehicle.id),
          builder: (context, snapshot) {
            // Handle loading state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Handle error state
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final assignedItems = snapshot.data ?? [];

            // Wrap in DragTarget to accept items being dragged to this vehicle
            return DragTarget<Map<String, dynamic>>(
              onWillAccept: (data) {
                // Only accept valid drag data with items
                return data != null && data.containsKey('items');
              },
              onAccept: (data) {
                // Handle drop operation via manager
                dragDropManager.handleItemDropOnVehicle(vehicle.id);
              },
              builder: (context, candidateData, rejectedData) {
                // Forward properties to the actual content widget
                return VehicleContent(
                  vehicle: vehicle,
                  assignedItems: assignedItems,
                  onItemRemoved: (item) {
                    // Handle item removal via manager
                    dragDropManager.removeItemFromVehicle(item);
                  },
                  onItemStatusChanged: (item, status) {
                    // Handle item status change via manager
                    dragDropManager.updateItemLoadingStatus(item, status);
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}