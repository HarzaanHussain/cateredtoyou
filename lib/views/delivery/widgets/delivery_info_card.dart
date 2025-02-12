import 'dart:async'; // Importing the async library for Timer functionality
import 'package:cateredtoyou/views/delivery/widgets/delivery_progress.dart'; // Importing a custom widget for delivery progress
import 'package:flutter/material.dart'; // Importing Flutter's material design library
import 'package:intl/intl.dart'; // Importing the intl package for date formatting
import 'package:cateredtoyou/models/delivery_route_model.dart'; // Importing the delivery route model
import 'package:cateredtoyou/views/delivery/widgets/status_chip.dart'; // Importing a custom widget for status chip

class DeliveryInfoCard extends StatefulWidget { // Defining a stateful widget
  final DeliveryRoute route; // Delivery route data
  final VoidCallback onDriverInfoTap; // Callback for driver info tap
  final VoidCallback onContactDriverTap; // Callback for contact driver tap

  const DeliveryInfoCard({ // Constructor for the widget
    super.key,
    required this.route,
    required this.onDriverInfoTap,
    required this.onContactDriverTap,
  });

  @override
  State<DeliveryInfoCard> createState() => _DeliveryInfoCardState(); // Creating the state for the widget
}

class _DeliveryInfoCardState extends State<DeliveryInfoCard> { // State class for DeliveryInfoCard
  late Timer _updateTimer; // Timer to periodically update time left
  String _timeLeft = ''; // String to store time left
  bool _isDelayed = false; // Boolean to check if delivery is delayed

  @override
  void initState() { // Initializing state
    super.initState();
    _updateTimeLeft(); // Initial update of time left
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (_) { // Setting up a timer to update time left every minute
      _updateTimeLeft();
    });
  }

  @override
  void dispose() { // Disposing the timer when widget is removed
    _updateTimer.cancel();
    super.dispose();
  }

  void _updateTimeLeft() { // Function to update the time left
    if (!mounted) return; // Check if the widget is still mounted
    
    final now = DateTime.now(); // Current time
    final difference = widget.route.estimatedEndTime.difference(now); // Difference between estimated end time and now
    
    setState(() { // Updating the state
      _isDelayed = difference.isNegative; // Check if the delivery is delayed
      if (_isDelayed) {
        final delayedBy = difference.abs(); // Calculate delay duration
        _timeLeft = 'Delayed by ${_formatDuration(delayedBy)}'; // Set time left as delayed
      } else {
        _timeLeft = _formatDuration(difference); // Set time left
      }
    });
  }

  String _formatDuration(Duration duration) { // Function to format duration
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m'; // Format hours and minutes
    }
    return '${duration.inMinutes}m'; // Format minutes
  }

  String _formatTotalDistance() { // Function to format total distance
    final distance = widget.route.metadata?['routeDetails']?['totalDistance']; // Get total distance from metadata
    if (distance == null) return 'Calculating...'; // Return if distance is null
    final distanceInMiles = (distance / 1609.34).toStringAsFixed(1); // Convert distance to miles
    return '$distanceInMiles mi total'; // Return formatted distance
  }

  String _formatRemainingDistance() { // Function to format remaining distance
    final totalDistance = widget.route.metadata?['routeDetails']?['totalDistance'] ?? 0.0; // Get total distance from metadata
    final progress = widget.route.calculateProgress(); // Calculate progress
    final remainingDistance = totalDistance * (1 - progress); // Calculate remaining distance
    final remainingMiles = (remainingDistance / 1609.34).toStringAsFixed(1); // Convert remaining distance to miles
    return '$remainingMiles mi left'; // Return formatted remaining distance
  }

  String _formatTotalDuration() { // Function to format total duration
    final startTime = widget.route.startTime; // Get start time
    final endTime = widget.route.estimatedEndTime; // Get end time
    final duration = endTime.difference(startTime); // Calculate duration
    return 'Total: ${_formatDuration(duration)}'; // Return formatted duration
  }

  String _formatElapsedTime() { // Function to format elapsed time
    final now = DateTime.now(); // Current time
    final startTime = widget.route.startTime; // Get start time
    final elapsed = now.difference(startTime); // Calculate elapsed time
    return 'Elapsed: ${_formatDuration(elapsed)}'; // Return formatted elapsed time
  }

  Widget _buildAddressSection(BuildContext context) { // Function to build address section
    final theme = Theme.of(context); // Get theme
    return Container(
      padding: const EdgeInsets.all(16), // Padding for the container
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest, // Background color
        borderRadius: BorderRadius.circular(12), // Border radius
      ),
      child: Column(
        children: [
          _buildAddressRow(
            context,
            Icons.store, // Icon for pickup
            'Pickup', // Label for pickup
            widget.route.metadata?['pickupAddress'] ?? 'Restaurant Location', // Pickup address
            theme.colorScheme.primary, // Icon color
          ),
          const SizedBox(height: 16), // Spacing between rows
          _buildAddressRow(
            context,
            Icons.location_on, // Icon for delivery
            'Delivery', // Label for delivery
            widget.route.metadata?['deliveryAddress'] ?? 'Delivery Location', // Delivery address
            theme.colorScheme.error, // Icon color
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(
    BuildContext context,
    IconData icon, // Icon for the row
    String label, // Label for the row
    String address, // Address for the row
    Color color, // Color for the icon
  ) {
    final theme = Theme.of(context); // Get theme
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8), // Padding for the icon container
          decoration: BoxDecoration(
            color: color.withOpacity(0.1), // Background color with opacity
            borderRadius: BorderRadius.circular(8), // Border radius
          ),
          child: Icon(icon, color: color, size: 20), // Icon
        ),
        const SizedBox(width: 12), // Spacing between icon and text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Align text to start
            children: [
              Text(
                label, // Label text
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, // Text color
                ),
              ),
              Text(
                address, // Address text
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500, // Text weight
                ),
                maxLines: 2, // Max lines for text
                overflow: TextOverflow.ellipsis, // Ellipsis for overflow
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressDetails(BuildContext context) { // Function to build progress details
    final theme = Theme.of(context); // Get theme
    return Container(
      padding: const EdgeInsets.all(16), // Padding for the container
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest, // Background color
        borderRadius: BorderRadius.circular(12), // Border radius
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildProgressDetail(
                  context,
                  'Distance', // Label for distance
                  _formatTotalDistance(), // Total distance
                  _formatRemainingDistance(), // Remaining distance
                ),
              ),
              Container(
                width: 1, // Width of the divider
                height: 40, // Height of the divider
                color: theme.colorScheme.outlineVariant, // Color of the divider
              ),
              Expanded(
                child: _buildProgressDetail(
                  context,
                  'Time', // Label for time
                  _formatTotalDuration(), // Total duration
                  _formatElapsedTime(), // Elapsed time
                ),
              ),
            ],
          ),
          if (widget.route.metadata?['routeDetails']?['traffic'] != null) ...[ // Check if traffic data is available
            const SizedBox(height: 12), // Spacing
            Divider(color: theme.colorScheme.outlineVariant), // Divider
            const SizedBox(height: 12), // Spacing
            Row(
              children: [
                Icon(
                  Icons.traffic_rounded, // Traffic icon
                  color: theme.colorScheme.primary, // Icon color
                  size: 20, // Icon size
                ),
                const SizedBox(width: 8), // Spacing
                Expanded(
                  child: Text(
                    'Traffic: ${widget.route.metadata!['routeDetails']['traffic']}', // Traffic data
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant, // Text color
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressDetail(
    BuildContext context,
    String label, // Label for the detail
    String total, // Total value
    String current, // Current value
  ) {
    final theme = Theme.of(context); // Get theme
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16), // Padding for the detail
      child: Column(
        children: [
          Text(
            label, // Label text
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant, // Text color
            ),
          ),
          const SizedBox(height: 4), // Spacing
          Text(
            total, // Total value text
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600, // Text weight
            ),
          ),
          const SizedBox(height: 2), // Spacing
          Text(
            current, // Current value text
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant, // Text color
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) { // Build method for the widget
    final theme = Theme.of(context); // Get theme

    return Container(
      padding: const EdgeInsets.all(16), // Padding for the container
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, // Background color
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20), // Border radius
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1), // Shadow color
            blurRadius: 10, // Blur radius
            offset: const Offset(0, -5), // Offset
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Minimize the main axis size
          children: [
            Container(
              width: 40, // Width of the handle
              height: 4, // Height of the handle
              margin: const EdgeInsets.only(bottom: 16), // Margin for the handle
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4), // Handle color
                borderRadius: BorderRadius.circular(2), // Border radius
              ),
            ),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between elements
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // Align text to start
                  children: [
                    Row(
                      children: [
                        Text(
                          _timeLeft, // Time left text
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold, // Text weight
                            color: _isDelayed 
                                ? theme.colorScheme.error // Color if delayed
                                : theme.colorScheme.onSurface, // Default color
                          ),
                        ),
                        const SizedBox(width: 8), // Spacing
                        if (!_isDelayed && widget.route.status == 'in_progress')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, // Horizontal padding
                              vertical: 4, // Vertical padding
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer, // Background color
                              borderRadius: BorderRadius.circular(12), // Border radius
                            ),
                            child: Text(
                              'On time', // On time text
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer, // Text color
                                fontWeight: FontWeight.w600, // Text weight
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4), // Spacing
                    Text(
                      'Estimated arrival at ${DateFormat('h:mm a').format(widget.route.estimatedEndTime)}', // Estimated arrival time
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant, // Text color
                      ),
                    ),
                  ],
                ),
                StatusChip(status: widget.route.status), // Status chip
              ],
            ),
            
            const SizedBox(height: 24), // Spacing
            
            if (widget.route.status == 'in_progress') ...[ // Check if route is in progress
              LinearProgressIndicator(
                value: widget.route.calculateProgress(), // Progress value
                backgroundColor: theme.colorScheme.surfaceContainerHighest, // Background color
                valueColor: AlwaysStoppedAnimation(
                  _isDelayed ? theme.colorScheme.error : theme.colorScheme.primary, // Progress color
                ),
              ),
              const SizedBox(height: 16), // Spacing
              
              _buildAddressSection(context), // Address section
              
              const SizedBox(height: 16), // Spacing
              
              _buildProgressDetails(context), // Progress details
            ],
            
            const SizedBox(height: 24), // Spacing
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onDriverInfoTap, // Driver info tap callback
                    icon: const Icon(Icons.person_outline), // Icon for button
                    label: const Text('Driver Info'), // Label for button
                  ),
                ),
                const SizedBox(width: 16), // Spacing
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onContactDriverTap, // Contact driver tap callback
                    icon: const Icon(Icons.phone), // Icon for button
                    label: const Text('Contact'), // Label for button
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