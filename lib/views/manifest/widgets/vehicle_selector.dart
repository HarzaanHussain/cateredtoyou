import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/vehicle_model.dart';
import 'package:cateredtoyou/services/vehicle_service.dart';

/// A mini-selector for vehicles that appears when items are selected
///
/// This widget shows when items are selected and provides a quick way to
/// select a vehicle without having to switch tabs or use a full-screen dialog.
class VehicleSelector extends StatelessWidget {
  final String title;
  final Function(String) onVehicleSelected;
  final VoidCallback onCancel;
  
  const VehicleSelector({
    super.key,
    this.title = 'Select a vehicle',
    required this.onVehicleSelected,
    required this.onCancel,
  });
  
  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha((0.1 * 255).toInt()),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_shipping,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      padding: EdgeInsets.zero,
                      onPressed: onCancel,
                    ),
                  ),
                ],
              ),
            ),
            
            // Vehicle list
            SizedBox(
              height: 240,
              child: Consumer<VehicleService>(
                builder: (context, vehicleService, child) {
                  return StreamBuilder<List<Vehicle>>(
                    stream: vehicleService.getVehicles(),
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
                              const Icon(
                                Icons.error_outline,
                                size: 32,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Error loading vehicles',
                                style: TextStyle(fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
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
                              Icon(
                                Icons.no_transfer,
                                size: 32,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'No available vehicles',
                                style: TextStyle(fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 8),
                        itemCount: vehicles.length,
                        itemBuilder: (context, index) {
                          final vehicle = vehicles[index];
                          final isAvailable = vehicle.status == VehicleStatus.available;
                          
                          return InkWell(
                            onTap: isAvailable
                                ? () => onVehicleSelected(vehicle.id)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isAvailable
                                          ? Colors.green.withAlpha((0.1 * 255).toInt())
                                          : (Colors.grey[200] ?? Colors.grey),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _getVehicleIcon(vehicle.type),
                                      color: isAvailable
                                          ? Colors.green
                                          : Colors.grey[500],
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${vehicle.make} ${vehicle.model}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isAvailable
                                                ? null
                                                : Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          vehicle.licensePlate,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
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
                                      color: _getStatusColor(vehicle.status).withAlpha((0.2 * 255).toInt()),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getStatusLabel(vehicle.status),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _getStatusColor(vehicle.status),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
      ),
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