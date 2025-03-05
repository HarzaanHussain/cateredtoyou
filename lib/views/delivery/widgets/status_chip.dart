import 'package:flutter/material.dart'; // Importing the Flutter material package for UI components.

class StatusChip extends StatelessWidget { // Defining a stateless widget called StatusChip.
  final String status; // Declaring a final variable to hold the status string.

  const StatusChip({ // Constructor for the StatusChip widget.
    super.key, // Passing the key to the superclass constructor.
    required this.status, // Initializing the status variable.
  });

  @override
  Widget build(BuildContext context) { // Overriding the build method to define the UI.
    final theme = Theme.of(context); // Getting the current theme from the context.
    final (backgroundColor, textColor) = _getStatusColors(status, theme); // Getting the background and text colors based on the status.

    return Container( // Returning a Container widget.
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Adding padding inside the container.
      decoration: BoxDecoration( // Defining the decoration for the container.
        color: backgroundColor, // Setting the background color.
        borderRadius: BorderRadius.circular(16), // Making the corners rounded.
        border: Border.all( // Adding a border around the container.
          color: textColor.withAlpha((0.2 * 255).toInt()), // Setting the border color with some opacity.
        ),
      ),
      child: Row( // Using a Row widget to arrange children horizontally.
        mainAxisSize: MainAxisSize.min, // Making the row take up the minimum space needed.
        children: [
          _buildStatusIcon(status, textColor), // Adding the status icon.
          const SizedBox(width: 6), // Adding some space between the icon and text.
          Text( // Adding the status text.
            _formatStatus(status), // Formatting the status text.
            style: theme.textTheme.labelLarge?.copyWith( // Applying text style from the theme.
              color: textColor, // Setting the text color.
              fontWeight: FontWeight.bold, // Making the text bold.
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String status, Color color) { // Method to build the status icon.
    IconData icon; // Declaring a variable to hold the icon data.
    switch (status.toLowerCase()) { // Checking the status value.
      case 'pending': // If status is 'pending'.
        icon = Icons.schedule; // Use the schedule icon.
        break;
      case 'in_progress': // If status is 'in_progress'.
        icon = Icons.local_shipping; // Use the local shipping icon.
        break;
      case 'completed': // If status is 'completed'.
        icon = Icons.check_circle; // Use the check circle icon.
        break;
      case 'cancelled': // If status is 'cancelled'.
        icon = Icons.cancel; // Use the cancel icon.
        break;
      default: // For any other status.
        icon = Icons.info; // Use the info icon.
    }
    return Icon(icon, size: 16, color: color); // Returning the icon widget with specified size and color.
  }

  String _formatStatus(String status) { // Method to format the status text.
    return status.toUpperCase().replaceAll('_', ' '); // Converting the status to uppercase and replacing underscores with spaces.
  }

  (Color, Color) _getStatusColors(String status, ThemeData theme) { // Method to get the background and text colors based on the status.
    switch (status.toLowerCase()) { // Checking the status value.
      case 'pending': // If status is 'pending'.
        return (
          theme.colorScheme.tertiaryContainer, // Use the tertiary container color.
          theme.colorScheme.onTertiaryContainer, // Use the on tertiary container color.
        );
      case 'in_progress': // If status is 'in_progress'.
        return (
          theme.colorScheme.primaryContainer, // Use the primary container color.
          theme.colorScheme.onPrimaryContainer, // Use the on primary container color.
        );
      case 'completed': // If status is 'completed'.
        return (
          theme.colorScheme.secondaryContainer, // Use the secondary container color.
          theme.colorScheme.onSecondaryContainer, // Use the on secondary container color.
        );
      case 'cancelled': // If status is 'cancelled'.
        return (
          theme.colorScheme.errorContainer, // Use the error container color.
          theme.colorScheme.onErrorContainer, // Use the on error container color.
        );
      default: // For any other status.
        return (
          theme.colorScheme.surfaceContainerHighest, // Use the surface container highest color.
          theme.colorScheme.onSurfaceVariant, // Use the on surface variant color.
        );
    }
  }
}