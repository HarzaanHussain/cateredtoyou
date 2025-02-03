import 'package:flutter/material.dart'; // Importing the Flutter material package for UI components.

class StatusChip extends StatelessWidget { // Defining a stateless widget called StatusChip.
  final String status; // Declaring a final variable to hold the status.

  const StatusChip({super.key, required this.status}); // Constructor for the StatusChip widget, requiring a status parameter.

  @override
  Widget build(BuildContext context) { // Overriding the build method to define the widget's UI.
    final theme = Theme.of(context); // Getting the current theme from the context.
    final (backgroundColor, textColor) = _getStatusColors(status, theme); // Getting the background and text colors based on the status.

    return Container( // Returning a Container widget.
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Adding padding inside the container.
      decoration: BoxDecoration( // Defining the container's decoration.
        color: backgroundColor, // Setting the background color.
        borderRadius: BorderRadius.circular(16), // Making the corners rounded.
        border: Border.all( // Adding a border around the container.
          color: textColor.withOpacity(0.2), // Setting the border color with some transparency.
        ),
      ),
      child: Row( // Using a Row widget to arrange children horizontally.
        mainAxisSize: MainAxisSize.min, // Making the row take up the minimum space needed.
        children: [
          _buildStatusIcon(status, textColor), // Adding an icon based on the status.
          const SizedBox(width: 6), // Adding some horizontal space between the icon and text.
          Text( // Adding a Text widget to display the status.
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

  Widget _buildStatusIcon(String status, Color color) { // Method to build an icon based on the status.
    IconData icon; // Declaring a variable to hold the icon data.
    switch (status.toLowerCase()) { // Using a switch statement to determine the icon based on the status.
      case 'pending':
        icon = Icons.schedule; // Icon for pending status.
        break;
      case 'in_progress':
        icon = Icons.local_shipping; // Icon for in-progress status.
        break;
      case 'completed':
        icon = Icons.check_circle; // Icon for completed status.
        break;
      case 'cancelled':
        icon = Icons.cancel; // Icon for cancelled status.
        break;
      default:
        icon = Icons.info; // Default icon for unknown status.
    }
    return Icon(icon, size: 16, color: color); // Returning the icon with specified size and color.
  }

  String _formatStatus(String status) { // Method to format the status text.
    return status.toUpperCase().replaceAll('_', ' '); // Converting status to uppercase and replacing underscores with spaces.
  }

  (Color, Color) _getStatusColors(String status, ThemeData theme) { // Method to get background and text colors based on the status.
    switch (status.toLowerCase()) { // Using a switch statement to determine colors based on the status.
      case 'pending':
        return (
          theme.colorScheme.tertiaryContainer, // Background color for pending status.
          theme.colorScheme.onTertiaryContainer, // Text color for pending status.
        );
      case 'in_progress':
        return (
          theme.colorScheme.primaryContainer, // Background color for in-progress status.
          theme.colorScheme.onPrimaryContainer, // Text color for in-progress status.
        );
      case 'completed':
        return (
          theme.colorScheme.secondaryContainer, // Background color for completed status.
          theme.colorScheme.onSecondaryContainer, // Text color for completed status.
        );
      case 'cancelled':
        return (
          theme.colorScheme.errorContainer, // Background color for cancelled status.
          theme.colorScheme.onErrorContainer, // Text color for cancelled status.
        );
      default:
        return (
          theme.colorScheme.surfaceContainerHighest, // Default background color for unknown status.
          theme.colorScheme.onSurfaceVariant, // Default text color for unknown status.
        );
    }
  }
}
