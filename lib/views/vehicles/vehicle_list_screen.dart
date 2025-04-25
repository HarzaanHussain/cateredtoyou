import 'package:cateredtoyou/models/vehicle_model.dart'; // Model for vehicle data.
import 'package:cateredtoyou/services/vehicle_service.dart'; // Service for fetching and updating vehicle data.
import 'package:cateredtoyou/views/vehicles/widgets/assign_driver_dialog.dart'; // Widget for assigning a driver to a vehicle.
import 'package:flutter/material.dart'; // Flutter framework for building UI.
import 'package:go_router/go_router.dart'; // Package for navigation.
import 'package:intl/intl.dart'; // Package for date formatting.
import 'package:provider/provider.dart'; // Package for state management.
import 'package:cateredtoyou/widgets/bottom_toolbar.dart'; // Imports bottom toolbar class
import 'package:cateredtoyou/widgets/main_scaffold.dart'; 

/// A stateless widget that displays a list of vehicles.
class VehicleListScreen extends StatelessWidget {
  const VehicleListScreen({super.key});
 @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Fleet Management',

      // ➕ your “add vehicle” button lives here now
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => context.push('/add-vehicle'),
        ),
      ],

      body: Consumer<VehicleService>(
        builder: (context, vehicleService, _) {
          return StreamBuilder<List<Vehicle>>(
            stream: vehicleService.getVehicles(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final vehicles = snapshot.data!;
              if (vehicles.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.directions_car_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No vehicles found',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Vehicle'),
                        onPressed: () => context.push('/add-vehicle'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: vehicles.length,
                itemBuilder: (context, index) {
                  return VehicleCard(vehicle: vehicles[index]);
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// A stateless widget that displays details of a single vehicle in a card format.
class VehicleCard extends StatelessWidget {
  final Vehicle vehicle;

  const VehicleCard({
    super.key,
    required this.vehicle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color statusColor;
    switch (vehicle.status) {
      case VehicleStatus.available:
        statusColor = Colors.green; // Color for available status.
        break;
      case VehicleStatus.inUse:
        statusColor = Colors.blue; // Color for in-use status.
        break;
      case VehicleStatus.maintenance:
        statusColor = Colors.orange; // Color for maintenance status.
        break;
      case VehicleStatus.outOfService:
        statusColor = Colors.red; // Color for out-of-service status.
        break;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/vehicle-details', extra: vehicle), // Navigates to vehicle details screen.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: statusColor,
                    width: 4, // Colored border indicating vehicle status.
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${vehicle.make} ${vehicle.model}', // Displays vehicle make and model.
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              vehicle.licensePlate, // Displays vehicle license plate.
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
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
                          color: statusColor.withAlpha((0.1 * 255).toInt()),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          vehicle.status.toString().split('.').last, // Displays vehicle status.
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (vehicle.assignedDriverId != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Assigned Driver', // Displays assigned driver if available.
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Next Maintenance: ${DateFormat('MM/dd/yyyy').format(vehicle.nextMaintenanceDate)}', // Displays next maintenance date.
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showVehicleOptions(context), // Shows options for the vehicle.
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a bottom sheet with options for the vehicle.
  void _showVehicleOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Vehicle'), // Option to edit the vehicle.
              onTap: () {
                Navigator.pop(context);
                context.push('/edit-vehicle', extra: vehicle); // Navigates to edit vehicle screen.
              },
            ),
            // Show Assign Driver option only if vehicle is available
            if (vehicle.status == VehicleStatus.available)
              ListTile(
                leading: const Icon(Icons.person_add),
                title: const Text('Assign Driver'), // Option to assign a driver.
                onTap: () {
                  Navigator.pop(context);
                  _showAssignDriverDialog(context); // Shows dialog to assign a driver.
                },
              ),
            // Show Mark Available option if vehicle is in maintenance or out of service
            if (vehicle.status == VehicleStatus.maintenance || 
                vehicle.status == VehicleStatus.outOfService)
              ListTile(
                leading: const Icon(Icons.check_circle),
                title: const Text('Mark as Available'), // Option to mark vehicle as available.
                onTap: () {
                  Navigator.pop(context);
                  _updateVehicleStatus(context, VehicleStatus.available); // Updates vehicle status to available.
                },
              ),
            // Show Mark for Maintenance option if not in maintenance
            if (vehicle.status != VehicleStatus.maintenance)
              ListTile(
                leading: const Icon(Icons.build),
                title: const Text('Mark for Maintenance'), // Option to mark vehicle for maintenance.
                onTap: () {
                  Navigator.pop(context);
                  _updateVehicleStatus(context, VehicleStatus.maintenance); // Updates vehicle status to maintenance.
                },
              ),
            // Show Mark Out of Service option if not out of service
            if (vehicle.status != VehicleStatus.outOfService)
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Mark Out of Service'), // Option to mark vehicle out of service.
                onTap: () {
                  Navigator.pop(context);
                  _updateVehicleStatus(context, VehicleStatus.outOfService); // Updates vehicle status to out of service.
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Shows a dialog to assign a driver to the vehicle.
  void _showAssignDriverDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AssignDriverDialog(vehicle: vehicle),
    );
  }

  /// Updates the status of the vehicle.
  Future<void> _updateVehicleStatus(
    BuildContext context,
    VehicleStatus status,
  ) async {
    try {
      final vehicleService = context.read<VehicleService>();
      await vehicleService.updateVehicleStatus(vehicle.id, status); // Calls service to update vehicle status.
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle status updated successfully'), // Shows success message.
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating vehicle status: $e'), // Shows error message.
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
