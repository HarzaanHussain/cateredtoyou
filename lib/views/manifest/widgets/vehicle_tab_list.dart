import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/vehicle_model.dart';
import 'package:cateredtoyou/services/vehicle_service.dart';
import 'package:cateredtoyou/managers/drag_drop_manager.dart';
import 'package:cateredtoyou/views/manifest/widgets/vehicle_tab_container.dart';
import 'package:cateredtoyou/views/manifest/widgets/vehicle_content_container.dart';

/// Displays the list of vehicle tabs.
/// Tapping a tab opens its content in a dialog.
class VehicleTabList extends StatelessWidget {
  final DragDropManager dragDropManager;

  const VehicleTabList({
    super.key,
    required this.dragDropManager,
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
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final vehicles = snapshot.data ?? [];

            if (vehicles.isEmpty) {
              return const Center(child: Text('No vehicles available'));
            }

            return ListView.builder(
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];

                return VehicleTabContainer(
                  vehicle: vehicle,
                  onVehicleSelected: (vehicle) => _showVehicleContentDialog(context, vehicle),
                  onItemsDropped: (items, quantities) {
                    dragDropManager.handleItemDropOnVehicle(vehicle.id);
                  },
                  dragDropManager: dragDropManager,
                );
              },
            );
          },
        );
      },
    );
  }

  void _showVehicleContentDialog(BuildContext context, Vehicle vehicle) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: 600,
          height: 400,
          child: VehicleContentContainer(
            vehicle: vehicle,
            dragDropManager: dragDropManager,
          ),
        ),
      ),
    );
  }
}