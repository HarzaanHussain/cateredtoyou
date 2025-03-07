import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/vehicle_model.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/services/manifest_service.dart';
import 'package:cateredtoyou/managers/drag_drop_manager.dart';
import 'package:cateredtoyou/views/manifest/widgets/vehicle_content.dart';

class VehicleContentContainer extends StatelessWidget {
  final Vehicle vehicle;
  final DragDropManager dragDropManager;

  const VehicleContentContainer({
    super.key,
    required this.vehicle,
    required this.dragDropManager,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ManifestService>(
      builder: (context, manifestService, child) {
        return StreamBuilder<List<DeliveryManifest>>(
          stream: manifestService.getDeliveryManifestsByVehicle(vehicle.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            // Group manifests by event ID
            final manifestGroups = _groupManifestsByEvent(snapshot.data ?? []);

            return DragTarget<Map<String, dynamic>>(
              onWillAcceptWithDetails: (details) {
                return details.data.containsKey('items');
              },
              onAcceptWithDetails: (data) {
                dragDropManager.handleItemDropOnVehicle(vehicle.id);
              },
              builder: (context, candidateData, rejectedData) {
                return VehicleContent(
                  vehicle: vehicle,
                  manifestGroups: manifestGroups,
                  onItemRemoved: (item) {
                    dragDropManager.removeItemFromVehicle(item);
                  },
                  onItemStatusChanged: (item, newReadiness) {
                    dragDropManager.updateItemReadiness(item, newReadiness);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // Helper method to group manifests by event
  Map<String, List<DeliveryManifestItem>> _groupManifestsByEvent(List<DeliveryManifest> manifests) {
    final Map<String, List<DeliveryManifestItem>> groupedManifests = {};

    for (var manifest in manifests) {
      if (!groupedManifests.containsKey(manifest.eventId)) {
        groupedManifests[manifest.eventId] = [];
      }
      groupedManifests[manifest.eventId]!.addAll(manifest.items);
    }

    return groupedManifests;
  }
}