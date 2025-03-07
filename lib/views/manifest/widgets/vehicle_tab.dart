// File: lib/views/manifest/widgets/vehicle_tab.dart

import 'package:flutter/material.dart';
import 'package:cateredtoyou/models/vehicle_model.dart';
import 'package:cateredtoyou/models/manifest_model.dart';

/// A draggable target representing a vehicle.
/// Items can be dropped onto this vehicle, or the vehicle can be tapped to trigger an action.
class VehicleTab extends StatelessWidget {
  final Vehicle vehicle;
  final Function(List<EventManifestItem>, List<int>) onItemsDropped;

  const VehicleTab({
    super.key,
    required this.vehicle,
    required this.onItemsDropped,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Map<String, dynamic>>(
        onAcceptWithDetails: (DragTargetDetails<Map<String, dynamic>> details) {
          final data = details.data;
          debugPrint('data[items] is of type: ${data['items'].runtimeType}');
          final items = (data['items'] as List<dynamic>?)
              ?.map((item) => item as EventManifestItem)
              .toList();
          final quantities = data['quantities'] as List<int>?;

          if (items != null && quantities != null) {
            onItemsDropped(items, quantities);
          }
        },
        builder: (context, candidateData, rejectedData) {
        // Whether an item is currently being dragged over this vehicle tab.
        final bool isHovering = candidateData.isNotEmpty;

        return Container(
          width: 80,
          height: 60,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isHovering
                ? Colors.green.shade300 // Highlight when hovered
                : Colors.grey.shade300,  // Default background
            borderRadius: BorderRadius.circular(8),
            border: isHovering
                ? Border.all(color: Colors.green.shade700, width: 2)
                : null,
            boxShadow: isHovering
                ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                vehicle.model,
                style: TextStyle(
                  color: isHovering ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                vehicle.id,
                style: TextStyle(
                  color: isHovering ? Colors.white : Colors.black54,
                  fontSize: 10,
                  overflow: TextOverflow.ellipsis,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}