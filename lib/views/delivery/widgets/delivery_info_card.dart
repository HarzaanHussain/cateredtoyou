import 'package:cateredtoyou/models/delivery_route_model.dart'; // Importing the DeliveryRoute model
import 'package:cateredtoyou/views/delivery/widgets/delivery_progress.dart'; // Importing the DeliveryProgress widget
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components
import 'package:intl/intl.dart'; // Importing intl package for date formatting
import 'package:cateredtoyou/views/delivery/widgets/status_chip.dart'; // Importing the StatusChip widget

class DeliveryInfoCard extends StatelessWidget { // Defining a stateless widget called DeliveryInfoCard
  final DeliveryRoute route; // Delivery route information
  final VoidCallback onDriverInfoTap; // Callback for when driver info is tapped
  final VoidCallback onContactDriverTap; // Callback for when contact driver is tapped

  const DeliveryInfoCard({ // Constructor for the DeliveryInfoCard widget
    super.key, // Key for the widget
    required this.route, // Required delivery route
    required this.onDriverInfoTap, // Required callback for driver info tap
    required this.onContactDriverTap, // Required callback for contact driver tap
  });

  String _formatTimeLeft() { // Private method to format the time left for delivery
    final now = DateTime.now(); // Current time
    final difference = route.estimatedEndTime.difference(now); // Difference between estimated end time and current time
    
    if (difference.isNegative) { // If the difference is negative, the delivery is delayed
      return 'Delayed';
    }
    
    if (difference.inHours > 0) { // If the difference is more than an hour, format as hours and minutes
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    }
    return '${difference.inMinutes}m'; // Otherwise, format as minutes
  }

  Widget _buildStatusIndicator(BuildContext context) { // Private method to build the status indicator widget
    return Row( // Row to contain the status indicator
      children: [
        Container( // Container for the current status dot
          width: 10, // Width of the dot
          height: 10, // Height of the dot
          decoration: BoxDecoration( // Decoration for the dot
            color: Theme.of(context).colorScheme.primary, // Primary color from the theme
            shape: BoxShape.circle, // Circular shape
          ),
        ),
        const SizedBox(width: 8), // Spacing between the dot and the text
        Expanded( // Expanded widget to take up remaining space
          child: Column( // Column to contain the status message and delivery address
            crossAxisAlignment: CrossAxisAlignment.start, // Align children to the start
            children: [
              Text( // Text widget for the status message
                _getStatusMessage(), // Get the status message
                style: Theme.of(context).textTheme.bodyLarge?.copyWith( // Style for the text
                  fontWeight: FontWeight.w600, // Bold font weight
                ),
              ),
              const SizedBox(height: 4), // Spacing between the status message and the address
              Text( // Text widget for the delivery address
                route.metadata?['deliveryAddress'] ?? 'Delivery Location', // Delivery address or default text
                style: Theme.of(context).textTheme.bodyMedium?.copyWith( // Style for the text
                  color: Theme.of(context).colorScheme.onSurfaceVariant, // Color from the theme
                ),
                maxLines: 1, // Maximum number of lines
                overflow: TextOverflow.ellipsis, // Ellipsis for overflow
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getStatusMessage() { // Private method to get the status message based on the route status
    switch (route.status.toLowerCase()) { // Switch on the route status
      case 'in_progress': // If the status is in progress
        return 'On the way to delivery'; // Return the corresponding message
      case 'completed': // If the status is completed
        return 'Delivered'; // Return the corresponding message
      case 'cancelled': // If the status is cancelled
        return 'Delivery cancelled'; // Return the corresponding message
      default: // Default case
        return 'Preparing for delivery'; // Return the default message
    }
  }

  @override
  Widget build(BuildContext context) { // Build method to construct the widget tree
    final theme = Theme.of(context); // Get the current theme

    return Container( // Container for the delivery info card
      padding: const EdgeInsets.all(16), // Padding for the container
      decoration: BoxDecoration( // Decoration for the container
        color: theme.colorScheme.surface, // Surface color from the theme
        borderRadius: const BorderRadius.vertical( // Rounded corners at the top
          top: Radius.circular(20),
        ),
        boxShadow: [ // Box shadow for the container
          BoxShadow(
            color: Colors.black.withOpacity(0.1), // Shadow color with opacity
            blurRadius: 10, // Blur radius for the shadow
            offset: const Offset(0, -5), // Offset for the shadow
          ),
        ],
      ),
      child: SafeArea( // SafeArea to avoid system UI intrusions
        child: Column( // Column to arrange children vertically
          mainAxisSize: MainAxisSize.min, // Minimum size for the column
          children: [
            Container( // Container for the drag handle
              width: 40, // Width of the drag handle
              height: 4, // Height of the drag handle
              margin: const EdgeInsets.only(bottom: 16), // Margin below the drag handle
              decoration: BoxDecoration( // Decoration for the drag handle
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4), // Color with opacity
                borderRadius: BorderRadius.circular(2), // Rounded corners
              ),
            ),
            
            Row( // Row for the time and status
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between the children
              children: [
                Column( // Column for the time and status text
                  crossAxisAlignment: CrossAxisAlignment.start, // Align children to the start
                  children: [
                    Row( // Row for the time left and on time status
                      children: [
                        Text( // Text widget for the formatted time left
                          _formatTimeLeft(), // Format the time left
                          style: theme.textTheme.headlineSmall?.copyWith( // Style for the text
                            fontWeight: FontWeight.bold, // Bold font weight
                          ),
                        ),
                        const SizedBox(width: 8), // Spacing between the time left and on time status
                        if (route.status == 'in_progress') // If the route status is in progress
                          Container( // Container for the on time status
                            padding: const EdgeInsets.symmetric( // Padding for the container
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration( // Decoration for the container
                              color: theme.colorScheme.primaryContainer, // Primary container color from the theme
                              borderRadius: BorderRadius.circular(12), // Rounded corners
                            ),
                            child: Text( // Text widget for the on time status
                              'On time', // On time text
                              style: theme.textTheme.labelSmall?.copyWith( // Style for the text
                                color: theme.colorScheme.onPrimaryContainer, // Color from the theme
                                fontWeight: FontWeight.w600, // Bold font weight
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4), // Spacing between the time left and estimated arrival
                    Text( // Text widget for the estimated arrival time
                      'Estimated arrival at ${DateFormat('h:mm a').format(route.estimatedEndTime)}', // Format the estimated end time
                      style: theme.textTheme.bodyMedium?.copyWith( // Style for the text
                        color: theme.colorScheme.onSurfaceVariant, // Color from the theme
                      ),
                    ),
                  ],
                ),
                StatusChip(status: route.status), // Status chip for the route status
              ],
            ),
            
            const SizedBox(height: 24), // Spacing between the time and status and delivery progress
            
            if (route.status == 'in_progress') ...[ // If the route status is in progress
              LinearProgressIndicator( // Linear progress indicator for the delivery progress
                value: route.calculateProgress(), // Calculate the progress
                backgroundColor: theme.colorScheme.surfaceContainerHighest, // Background color from the theme
                valueColor: AlwaysStoppedAnimation( // Value color for the progress indicator
                  theme.colorScheme.primary, // Primary color from the theme
                ),
              ),
              const SizedBox(height: 16), // Spacing between the progress indicator and status indicator
              
              _buildStatusIndicator(context), // Build the status indicator
              
              const SizedBox(height: 16), // Spacing between the status indicator and traffic info
              
              if (route.metadata?['trafficDuration'] != null) // If traffic duration is available
                Container( // Container for the traffic info
                  padding: const EdgeInsets.all(12), // Padding for the container
                  decoration: BoxDecoration( // Decoration for the container
                    color: theme.colorScheme.surfaceContainerLowest, // Surface container lowest color from the theme
                    borderRadius: BorderRadius.circular(12), // Rounded corners
                  ),
                  child: Row( // Row for the traffic info
                    children: [
                      Icon( // Icon for the traffic info
                        Icons.traffic_rounded, // Traffic icon
                        color: theme.colorScheme.primary, // Primary color from the theme
                        size: 20, // Size of the icon
                      ),
                      const SizedBox(width: 12), // Spacing between the icon and text
                      Expanded( // Expanded widget to take up remaining space
                        child: Column( // Column for the traffic info text
                          crossAxisAlignment: CrossAxisAlignment.start, // Align children to the start
                          children: [
                            Text( // Text widget for the traffic conditions
                              'Current traffic conditions', // Traffic conditions text
                              style: theme.textTheme.bodyMedium?.copyWith( // Style for the text
                                fontWeight: FontWeight.w600, // Bold font weight
                              ),
                            ),
                            Text( // Text widget for the travel time
                              'Travel time: ${route.metadata?['trafficDuration']}', // Travel time text
                              style: theme.textTheme.bodySmall?.copyWith( // Style for the text
                                color: theme.colorScheme.onSurfaceVariant, // Color from the theme
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            
            const SizedBox(height: 24), // Spacing between the delivery progress and driver actions
            
            Row( // Row for the driver actions
              children: [
                Expanded( // Expanded widget for the driver info button
                  child: OutlinedButton.icon( // Outlined button with icon for driver info
                    onPressed: onDriverInfoTap, // Callback for when the button is pressed
                    icon: const Icon(Icons.person_outline), // Icon for the button
                    label: const Text('Driver Info'), // Label for the button
                  ),
                ),
                const SizedBox(width: 16), // Spacing between the buttons
                Expanded( // Expanded widget for the contact driver button
                  child: FilledButton.icon( // Filled button with icon for contact driver
                    onPressed: onContactDriverTap, // Callback for when the button is pressed
                    icon: const Icon(Icons.phone), // Icon for the button
                    label: const Text('Contact'), // Label for the button
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
