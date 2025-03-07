// File: lib/views/manifest/widgets/vehicle_tab_container.dart

import 'package:flutter/material.dart';
import 'package:cateredtoyou/models/vehicle_model.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/managers/drag_drop_manager.dart';
import 'package:cateredtoyou/views/manifest/widgets/vehicle_tab.dart';

/// Container for a single vehicle tab, acting as a drag-and-drop target.
class VehicleTabContainer extends StatelessWidget {
  final Vehicle vehicle;
  final Function(Vehicle) onVehicleSelected;
  final Function(List<EventManifestItem>, List<int>) onItemsDropped;
  final DragDropManager dragDropManager;

  const VehicleTabContainer({
    super.key,
    required this.vehicle,
    required this.onVehicleSelected,
    required this.onItemsDropped,
    required this.dragDropManager,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onVehicleSelected(vehicle),
      child: VehicleTab(
        vehicle: vehicle,
        onItemsDropped: onItemsDropped,
      ),
    );
  }
}