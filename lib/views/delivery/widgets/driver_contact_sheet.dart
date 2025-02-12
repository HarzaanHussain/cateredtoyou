import 'package:flutter/material.dart'; // Importing Flutter material package for UI components
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore package for database operations

class DriverContactSheet extends StatelessWidget { // Defining a stateless widget for the driver contact sheet
  final String driverId; // Driver ID to fetch driver details from Firestore
  final Function(String, String) onContactMethod; // Callback function to handle contact actions

  const DriverContactSheet({ // Constructor for the widget
    super.key, // Key for the widget
    required this.driverId, // Required driver ID parameter
    required this.onContactMethod, // Required callback function parameter
  });

  @override
  Widget build(BuildContext context) { // Build method to construct the UI
    return FutureBuilder<DocumentSnapshot>( // Using FutureBuilder to fetch driver data from Firestore
      future: FirebaseFirestore.instance // Firestore instance
          .collection('users') // Accessing 'users' collection
          .doc(driverId) // Accessing document with driverId
          .get(), // Fetching the document
      builder: (context, snapshot) { // Builder to handle different states of the Future
        if (snapshot.connectionState == ConnectionState.waiting) { // If the data is still being fetched
          return const Center( // Show a loading indicator
            child: Padding(
              padding: EdgeInsets.all(24.0), // Padding around the indicator
              child: CircularProgressIndicator(), // Circular loading indicator
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) { // If no data is found or document doesn't exist
          return const Center( // Show a message indicating no data
            child: Padding(
              padding: EdgeInsets.all(24.0), // Padding around the message
              child: Text('Driver information not available'), // Message text
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>; // Extracting data from the snapshot
        final phone = data['phoneNumber'] ?? data['phone']; // Getting phone number from data
        final theme = Theme.of(context); // Getting the current theme

        return Container( // Container for the contact sheet
          padding: const EdgeInsets.all(24), // Padding inside the container
          decoration: BoxDecoration( // Decoration for the container
            color: theme.colorScheme.surface, // Background color from theme
            borderRadius: const BorderRadius.vertical( // Rounded top corners
              top: Radius.circular(20),
            ),
          ),
          child: Column( // Column to arrange child widgets vertically
            mainAxisSize: MainAxisSize.min, // Minimize the column size
            children: [
              Container( // Container for the drag handle
                width: 40, // Width of the handle
                height: 4, // Height of the handle
                margin: const EdgeInsets.only(bottom: 24), // Margin below the handle
                decoration: BoxDecoration( // Decoration for the handle
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4), // Color with opacity
                  borderRadius: BorderRadius.circular(2), // Rounded corners
                ),
              ),
              CircleAvatar( // Circle avatar for driver's initials
                radius: 40, // Radius of the avatar
                backgroundColor: theme.colorScheme.primary, // Background color from theme
                child: Text( // Text inside the avatar
                  '${data['firstName'][0]}${data['lastName'][0]}', // Initials of the driver
                  style: theme.textTheme.headlineMedium?.copyWith( // Text style from theme
                    color: theme.colorScheme.onPrimary, // Text color from theme
                  ),
                ),
              ),
              const SizedBox(height: 16), // Spacing between avatar and name
              Text( // Text widget for driver's full name
                '${data['firstName']} ${data['lastName']}', // Full name of the driver
                style: theme.textTheme.titleLarge, // Text style from theme
              ),
              if (phone != null) ...[ // If phone number is available
                const SizedBox(height: 8), // Spacing before phone number
                Text( // Text widget for phone number
                  phone, // Phone number
                  style: theme.textTheme.bodyLarge?.copyWith( // Text style from theme
                    color: theme.colorScheme.primary, // Text color from theme
                  ),
                ),
                const SizedBox(height: 24), // Spacing before buttons
                Row( // Row to arrange buttons horizontally
                  children: [
                    Expanded( // Expanded widget to take available space
                      child: OutlinedButton.icon( // Outlined button for messaging
                        onPressed: () => onContactMethod(phone, 'sms'), // Callback for messaging
                        icon: const Icon(Icons.message), // Icon for messaging
                        label: const Text('Message'), // Label for messaging
                      ),
                    ),
                    const SizedBox(width: 16), // Spacing between buttons
                    Expanded( // Expanded widget to take available space
                      child: FilledButton.icon( // Filled button for calling
                        onPressed: () => onContactMethod(phone, 'tel'), // Callback for calling
                        icon: const Icon(Icons.phone), // Icon for calling
                        label: const Text('Call'), // Label for calling
                      ),
                    ),
                  ],
                ),
              ] else // If phone number is not available
                Padding( // Padding around the message
                  padding: const EdgeInsets.only(top: 8), // Padding at the top
                  child: Text( // Text widget for no contact information
                    'No contact information available', // Message text
                    style: theme.textTheme.bodyMedium?.copyWith( // Text style from theme
                      color: theme.colorScheme.error, // Text color for error
                    ),
                  ),
                ),
              const SizedBox(height: 8), // Spacing at the bottom
            ],
          ),
        );
      },
    );
  }
}