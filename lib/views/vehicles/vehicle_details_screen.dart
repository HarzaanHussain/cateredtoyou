
import 'package:cateredtoyou/models/vehicle_model.dart'; // Import the Vehicle model.
import 'package:cateredtoyou/widgets/bottom_toolbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore for database interactions.
import 'package:flutter/material.dart'; // Import Flutter material design components.
import 'package:go_router/go_router.dart'; // Import GoRouter for navigation.
import 'package:intl/intl.dart'; // Import intl for date formatting.
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher for launching URLs.
import 'package:cateredtoyou/widgets/main_scaffold.dart';

/// A stateless widget that displays detailed information about a vehicle.
class VehicleDetailsScreen extends StatelessWidget {
  /// The vehicle to display details for.
  final Vehicle vehicle; // The vehicle object to display details for.

  /// Constructor for `VehicleDetailsScreen` which requires a `Vehicle` object.
  const VehicleDetailsScreen({
    super.key, // Pass the key to the superclass constructor.
    required this.vehicle, // Initialize the vehicle property.
  });
 //class VehicleDetailsScreen extends StatelessWidget {
 // final VehicleModel vehicle;
  //const VehicleDetailsScreen({super.key, required this.vehicle});

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: color ?? cs.onSurface),
        const SizedBox(width: 8),
        Text('$label: ', style: Theme.of(context).textTheme.bodyLarge),
        Text(value, style: TextStyle(color: color ?? cs.onSurface)),
      ],
    );
  }

  Widget _buildTelematicsInfo(BuildContext context, Map<String, dynamic> data) {
    // your existing telematics widget…
    return Text(data.toString());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MainScaffold(
      title: '${vehicle.make} ${vehicle.model}',

      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),

      actions: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => context.push(
            '/edit-vehicle',
            extra: vehicle,
          ),
        ),
      ],

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vehicle Information',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  _buildInfoRow(context, 'License Plate',
                      vehicle.licensePlate, Icons.confirmation_number),
                  const SizedBox(height: 12),
                  _buildInfoRow(context, 'Type',
                      vehicle.type.toString().split('.').last, Icons.category),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                      context, 'Year', vehicle.year, Icons.calendar_today),
                  const SizedBox(height: 12),
                  _buildInfoRow(context, 'Status',
                      vehicle.status.toString().split('.').last, Icons.info),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Maintenance Schedule',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    context,
                    'Last Maintenance',
                    DateFormat('MM/dd/yyyy')
                        .format(vehicle.lastMaintenanceDate),
                    Icons.build,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    context,
                    'Next Maintenance',
                    DateFormat('MM/dd/yyyy')
                        .format(vehicle.nextMaintenanceDate),
                    Icons.event,
                    color: DateTime.now()
                            .isAfter(vehicle.nextMaintenanceDate)
                        ? cs.error
                        : null,
                  ),
                ],
              ),
            ),
          ),
          if (vehicle.telematicsData != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Telematics Data',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    _buildTelematicsInfo(context, vehicle.telematicsData!),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (vehicle.assignedDriverId != null)
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(vehicle.assignedDriverId)
                  .get(),
              builder: (context, snap) {
                if (!snap.hasData || !snap.data!.exists) {
                  return const SizedBox.shrink();
                }
                final driver = snap.data!.data()! as Map<String, dynamic>;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Assigned Driver',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: cs.primary,
                            child: Text(
                              '${driver['firstName'][0]}${driver['lastName'][0]}',
                              style: TextStyle(color: cs.onPrimary),
                            ),
                          ),
                          title: Text(
                              '${driver['firstName']} ${driver['lastName']}'),
                          subtitle: Text(driver['phoneNumber']),
                          trailing: IconButton(
                            icon: const Icon(Icons.phone),
                            onPressed: () => launchUrl(
                              Uri.parse('tel:${driver['phoneNumber']}'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
  /// Helper method to build a row displaying a label, value, and icon.
  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? color, // Optional color parameter.
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color), // Display icon with optional color.
        const SizedBox(width: 8), // Add horizontal spacing.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Align children to the start.
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant, // Set text color.
                    ),
              ),
              const SizedBox(height: 4), // Add vertical spacing.
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color, // Set text color if provided.
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Helper method to build a column displaying telematics data.
  Widget _buildTelematicsInfo(
    BuildContext context,
    Map<String, dynamic> telematicsData, // Telematics data map.
  ) {
    return Column(
      children: [
        _buildTelematicsRow(
          context,
          'Current Location',
          '${telematicsData['location']['address']}', // Display current location.
          Icons.location_on, // Location icon.
        ),
        const SizedBox(height: 12), // Add vertical spacing.
        _buildTelematicsRow(
          context,
          'Speed',
          '${telematicsData['speed']} km/h', // Display speed.
          Icons.speed, // Speed icon.
        ),
        const SizedBox(height: 12), // Add vertical spacing.
        _buildTelematicsRow(
          context,
          'Fuel Level',
          '${telematicsData['fuelLevel']}%', // Display fuel level.
          Icons.local_gas_station, // Fuel icon.
        ),
        const SizedBox(height: 12), // Add vertical spacing.
        _buildTelematicsRow(
          context,
          'Engine Status',
          telematicsData['engineStatus'], // Display engine status.
          Icons.settings, // Settings icon.
        ),
      ],
    );
  }

  Widget _buildTelematicsRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20), // Display icon.
        const SizedBox(width: 8), // Add horizontal spacing.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Align children to the start.
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant, // Set text color.
                    ),
              ),
              const SizedBox(height: 4), // Add vertical spacing.
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium, // Set text style.
              ),
            ],
          ),
        ),
      ],
    );
  }
