
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components.
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore package for database operations.

/// A stateless widget that displays a contact sheet for a driver.
class DriverContactSheet extends StatelessWidget {
  final String driverId; // The ID of the driver whose contact information is to be fetched.
  final Function(String, String) onContactMethod; // Callback function to handle contact actions.

  /// Constructor for `DriverContactSheet`.
  const DriverContactSheet({
    super.key, // Key for the widget.
    required this.driverId, // Required driver ID.
    required this.onContactMethod, // Required callback function.
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users') // Accessing the 'users' collection in Firestore.
          .doc(driverId) // Fetching the document with the given driver ID.
          .get(), // Getting the document snapshot.
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator()); // Show a loading indicator while waiting for data.
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(
            child: Text('Driver information not available'), // Show a message if no data is found.
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>; // Extracting data from the snapshot.
        final phone = data['phoneNumber'] ?? data['phone']; // Getting the phone number from the data.

        return Container(
          padding: const EdgeInsets.all(16), // Adding padding around the container.
          child: Column(
            mainAxisSize: MainAxisSize.min, // Minimize the main axis size of the column.
            children: [
              CircleAvatar(
                radius: 40, // Setting the radius of the avatar.
                backgroundColor: Theme.of(context).colorScheme.primary, // Setting the background color of the avatar.
                child: Text(
                  '${data['firstName'][0]}${data['lastName'][0]}', // Displaying the initials of the driver's name.
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary, // Setting the text color.
                  ),
                ),
              ),
              const SizedBox(height: 16), // Adding vertical space.
              Text(
                '${data['firstName']} ${data['lastName']}', // Displaying the full name of the driver.
                style: Theme.of(context).textTheme.titleLarge, // Setting the text style.
              ),
              if (phone != null) ...[
                const SizedBox(height: 8), // Adding vertical space.
                Text(
                  phone, // Displaying the phone number.
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary, // Setting the text color.
                  ),
                ),
                const SizedBox(height: 24), // Adding vertical space.
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onContactMethod(phone, 'sms'), // Handling SMS button press.
                        icon: const Icon(Icons.message), // Icon for the SMS button.
                        label: const Text('Message'), // Label for the SMS button.
                      ),
                    ),
                    const SizedBox(width: 16), // Adding horizontal space.
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => onContactMethod(phone, 'tel'), // Handling Call button press.
                        icon: const Icon(Icons.phone), // Icon for the Call button.
                        label: const Text('Call'), // Label for the Call button.
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}