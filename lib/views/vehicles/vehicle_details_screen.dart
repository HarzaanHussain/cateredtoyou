
import 'package:cateredtoyou/models/vehicle_model.dart'; // Import the Vehicle model.
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore for database interactions.
import 'package:flutter/material.dart'; // Import Flutter material design components.
import 'package:go_router/go_router.dart'; // Import GoRouter for navigation.
import 'package:intl/intl.dart'; // Import intl for date formatting.
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher for launching URLs.

/// A stateless widget that displays detailed information about a vehicle.
class VehicleDetailsScreen extends StatelessWidget {
  /// The vehicle to display details for.
  final Vehicle vehicle; // The vehicle object to display details for.

  /// Constructor for `VehicleDetailsScreen` which requires a `Vehicle` object.
  const VehicleDetailsScreen({
    super.key, // Pass the key to the superclass constructor.
    required this.vehicle, // Initialize the vehicle property.
  });

  @override
  Widget build(BuildContext context) {
    /// Retrieve the current theme and color scheme for styling.
    final theme = Theme.of(context); // Get the current theme.
    final colorScheme = theme.colorScheme; // Get the current color scheme.

    return Scaffold(
      /// App bar with the vehicle's make and model as the title.
      appBar: AppBar(
        title: Text('${vehicle.make} ${vehicle.model}'), // Display vehicle's make and model in the app bar.
        actions: [
          /// Edit button that navigates to the edit vehicle screen.
          IconButton(
            icon: const Icon(Icons.edit), // Edit icon.
            onPressed: () => context.push('/edit-vehicle', extra: vehicle), // Navigate to edit vehicle screen with the vehicle object.
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16), // Add padding around the list view.
        children: [
          /// Card displaying general vehicle information.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16), // Add padding inside the card.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // Align children to the start.
                children: [
                  Text(
                    'Vehicle Information',
                    style: theme.textTheme.titleLarge, // Use large title text style.
                  ),
                  const SizedBox(height: 16), // Add vertical spacing.
                  /// Display vehicle's license plate.
                  _buildInfoRow(
                    context,
                    'License Plate',
                    vehicle.licensePlate, // Display vehicle's license plate.
                    Icons.confirmation_number, // Use confirmation number icon.
                  ),
                  const SizedBox(height: 12), // Add vertical spacing.
                  /// Display vehicle's type.
                  _buildInfoRow(
                    context,
                    'Type',
                    vehicle.type.toString().split('.').last, // Display vehicle's type.
                    Icons.category, // Use category icon.
                  ),
                  const SizedBox(height: 12), // Add vertical spacing.
                  /// Display vehicle's year.
                  _buildInfoRow(
                    context,
                    'Year',
                    vehicle.year, // Display vehicle's year.
                    Icons.calendar_today, // Use calendar icon.
                  ),
                  const SizedBox(height: 12), // Add vertical spacing.
                  /// Display vehicle's status.
                  _buildInfoRow(
                    context,
                    'Status',
                    vehicle.status.toString().split('.').last, // Display vehicle's status.
                    Icons.info, // Use info icon.
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16), // Add vertical spacing.
          /// Card displaying vehicle's maintenance schedule.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16), // Add padding inside the card.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // Align children to the start.
                children: [
                  Text(
                    'Maintenance Schedule',
                    style: theme.textTheme.titleLarge, // Use large title text style.
                  ),
                  const SizedBox(height: 16), // Add vertical spacing.
                  /// Display last maintenance date.
                  _buildInfoRow(
                    context,
                    'Last Maintenance',
                    DateFormat('MM/dd/yyyy').format(vehicle.lastMaintenanceDate), // Format and display last maintenance date.
                    Icons.build, // Use build icon.
                  ),
                  const SizedBox(height: 12), // Add vertical spacing.
                  /// Display next maintenance date with color indication if overdue.
                  _buildInfoRow(
                    context,
                    'Next Maintenance',
                    DateFormat('MM/dd/yyyy').format(vehicle.nextMaintenanceDate), // Format and display next maintenance date.
                    Icons.event, // Use event icon.
                    color: DateTime.now().isAfter(vehicle.nextMaintenanceDate) // Check if the next maintenance date is overdue.
                        ? colorScheme.error // Use error color if overdue.
                        : null, // No color if not overdue.
                  ),
                ],
              ),
            ),
          ),
          if (vehicle.telematicsData != null) ...[
            const SizedBox(height: 16), // Add vertical spacing.
            /// Card displaying vehicle's telematics data.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16), // Add padding inside the card.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // Align children to the start.
                  children: [
                    Text(
                      'Telematics Data',
                      style: theme.textTheme.titleLarge, // Use large title text style.
                    ),
                    const SizedBox(height: 16), // Add vertical spacing.
                    _buildTelematicsInfo(context, vehicle.telematicsData!), // Display telematics data.
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16), // Add vertical spacing.
          if (vehicle.assignedDriverId != null)
            /// FutureBuilder to fetch and display assigned driver's information.
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(vehicle.assignedDriverId)
                  .get(), // Fetch assigned driver's information from Firestore.
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink(); // Return an empty widget if data is not available.
                }

                final driverData = snapshot.data!.data() as Map<String, dynamic>?; // Get driver data from snapshot.
                if (driverData == null) {
                  return const SizedBox.shrink(); // Return an empty widget if driver data is null.
                }

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16), // Add padding inside the card.
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, // Align children to the start.
                      children: [
                        Text(
                          'Assigned Driver',
                          style: theme.textTheme.titleLarge, // Use large title text style.
                        ),
                        const SizedBox(height: 16), // Add vertical spacing.
                        /// Display driver's information with a call button.
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.primary, // Set background color of avatar.
                            child: Text(
                              '${driverData['firstName'][0]}${driverData['lastName'][0]}', // Display driver's initials.
                              style: TextStyle(color: colorScheme.onPrimary), // Set text color.
                            ),
                          ),
                          title: Text(
                            '${driverData['firstName']} ${driverData['lastName']}', // Display driver's full name.
                          ),
                          subtitle: Text(driverData['phoneNumber']), // Display driver's phone number.
                          trailing: IconButton(
                            icon: const Icon(Icons.phone), // Phone icon.
                            onPressed: () => launchUrl(
                              Uri.parse('tel:${driverData['phoneNumber']}'), // Launch phone dialer with driver's phone number.
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
}