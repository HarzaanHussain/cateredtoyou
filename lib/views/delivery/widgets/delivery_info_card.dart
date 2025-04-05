import 'dart:async'; // Importing the async library for Timer functionality
import 'dart:math' as math;
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components
import 'package:intl/intl.dart'; // Importing the intl package for date formatting
import 'package:cateredtoyou/models/delivery_route_model.dart'; // Importing the delivery route model
import 'package:cateredtoyou/views/delivery/widgets/status_chip.dart'; // Importing a custom widget for status chip

class DeliveryInfoCard extends StatefulWidget {
  // Defining a stateful widget
  final DeliveryRoute route; // Delivery route data
  final VoidCallback onDriverInfoTap; // Callback for driver info tap
  final VoidCallback onContactDriverTap; // Callback for contact driver tap

  const DeliveryInfoCard({
    // Constructor for the widget
    super.key,
    required this.route,
    required this.onDriverInfoTap,
    required this.onContactDriverTap,
  });

  @override
  State<DeliveryInfoCard> createState() =>
      _DeliveryInfoCardState(); // Creating the state for the widget
}

class _DeliveryInfoCardState extends State<DeliveryInfoCard> {
  // State class for DeliveryInfoCard
  late Timer _updateTimer; // Timer to periodically update time left
  String _timeLeft = ''; // String to store time left
  bool _isDelayed = false; // Boolean to check if delivery is delayed

  @override
  void initState() {
    // Initializing state
    super.initState();
    _updateTimeLeft(); // Initial update of time left
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      // Setting up a timer to update time left every 30 seconds (more frequent updates)
      _updateTimeLeft();
    });
  }

  @override
  void dispose() {
    // Disposing the timer when widget is removed
    _updateTimer.cancel();
    super.dispose();
  }

 void _updateTimeLeft() {
    // Function to update the time left
    if (!mounted) return; // Check if the widget is still mounted

    final now = DateTime.now(); // Current time
    
    // If the delivery hasn't started yet, show time until start
    if (widget.route.status == 'pending' && now.isBefore(widget.route.startTime)) {
      final timeToStart = widget.route.startTime.difference(now);
      setState(() {
        _isDelayed = false;
        _timeLeft = 'Starts in ${_formatDuration(timeToStart)}';
      });
      return;
    }
    
    // For ongoing or future deliveries, calculate difference to estimated end time
    final difference = widget.route.estimatedEndTime.difference(now);
    
    setState(() {
      // Updating the state
      _isDelayed = difference.isNegative && widget.route.status == 'in_progress';
      
      if (widget.route.status == 'completed') {
        _timeLeft = 'Delivered';
      } else if (widget.route.status == 'cancelled') {
        _timeLeft = 'Cancelled';
      } else if (_isDelayed) {
        final delayedBy = difference.abs(); // Calculate delay duration
        _timeLeft = 'Delayed by ${_formatDuration(delayedBy)}'; // Set time left as delayed
      } else if (widget.route.status == 'pending') {
        _timeLeft = 'Scheduled'; 
      } else {
        _timeLeft = _formatDuration(difference); // Set time left
      }
    });
  }

   String _formatDuration(Duration duration) {
    // Function to format duration
    if (duration.isNegative) {
      // Handle negative durations by returning "0h 0m"
      return '0h 0m';
    }
    
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m'; // Format hours and minutes
    }
    return '${duration.inMinutes}m'; // Format minutes
  }


   String _formatTotalDistance() {
    // Function to format total distance
    final totalDistance = widget.route.metadata?['routeDetails']?['totalDistance'];
    if (totalDistance == null) {
      // Calculate from waypoints if not in metadata
      double distance = 0;
      final points = widget.route.waypoints;
      
      if (points.length >= 2) {
        for (int i = 0; i < points.length - 1; i++) {
          final p1 = points[i];
          final p2 = points[i + 1];
          // Basic distance calculation (simplified for example)
          final latDiff = p1.latitude - p2.latitude;
          final lngDiff = p1.longitude - p2.longitude;
          distance += (latDiff * latDiff + lngDiff * lngDiff);
        }
        distance = sqrt(distance) * 111000; // Rough approximation to meters
        final distanceInMiles = (distance / 1609.34).toStringAsFixed(1);
        return '$distanceInMiles mi total';
      }
      return 'Calculating...';
    }
    
    // Convert to miles and ensure it's a valid number
    final distanceMeters = totalDistance as num;
    if (!distanceMeters.isFinite || distanceMeters <= 0) {
      return 'Calculating...';
    }
    
    final distanceInMiles = (distanceMeters / 1609.34).toStringAsFixed(1);
    return '$distanceInMiles mi total';
  }

 String _formatRemainingDistance() {
    // Function to format remaining distance
    if (widget.route.status == 'completed') {
      return '0 mi left';
    }
    
    if (widget.route.status == 'pending') {
      return _formatTotalDistance(); // For pending deliveries, show total distance
    }
    
    // Try getting from metadata first
    final remainingDistance = widget.route.metadata?['routeDetails']?['remainingDistance'];
    if (remainingDistance != null && remainingDistance is num && remainingDistance.isFinite) {
      final remainingMiles = (remainingDistance / 1609.34).toStringAsFixed(1);
      return '$remainingMiles mi left';
    }
    
    // Calculate from waypoints and current location if available
    if (widget.route.currentLocation != null && widget.route.waypoints.isNotEmpty) {
      final currentLoc = widget.route.currentLocation!;
      final destination = widget.route.waypoints.last;
      
      // Basic distance calculation (simplified for example)
      final latDiff = currentLoc.latitude - destination.latitude;
      final lngDiff = currentLoc.longitude - destination.longitude;
      
      // Ensure the calculation doesn't produce NaN or Infinity
      if (latDiff.isFinite && lngDiff.isFinite) {
        final distanceSquared = latDiff * latDiff + lngDiff * lngDiff;
        if (distanceSquared.isFinite && distanceSquared >= 0) {
          final distance = math.sqrt(distanceSquared) * 111000; // Rough meters
          final distanceInMiles = (distance / 1609.34).toStringAsFixed(1);
          return '$distanceInMiles mi left';
        }
      }
    }
    
    // If we can't calculate, show total distance
    return _formatTotalDistance();
  }

 String _formatTotalDuration() {
    // Function to format total duration
    final startTime = widget.route.startTime; // Get start time
    final endTime = widget.route.estimatedEndTime; // Get end time
    
    // Check for invalid dates/times to prevent negative duration
    if (startTime.isAfter(endTime)) {
      return 'Total: 0h 0m';
    }
    
    final duration = endTime.difference(startTime); // Calculate duration
    return 'Total: ${_formatDuration(duration)}'; // Return formatted duration
  }

  String _formatElapsedTime() {
    // Function to format elapsed time
    final now = DateTime.now(); // Current time
    final startTime = widget.route.startTime; // Get start time
    
    // For pending deliveries or if now is before start time
    if (widget.route.status == 'pending' || now.isBefore(startTime)) {
      return 'Elapsed: 0h 0m';
    }
    
    final elapsed = now.difference(startTime); // Calculate elapsed time
    return 'Elapsed: ${_formatDuration(elapsed)}'; // Return formatted elapsed time
  }


  Widget _buildAddressSection(BuildContext context) {
    // Function to build address section
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
            widget.route.metadata?['pickupAddress'] ??
                'Restaurant Location', // Pickup address
            theme.colorScheme.primary, // Icon color
          ),
          const SizedBox(height: 16), // Spacing between rows
          _buildAddressRow(
            context,
            Icons.location_on, // Icon for delivery
            'Delivery', // Label for delivery
            widget.route.metadata?['deliveryAddress'] ??
                'Delivery Location', // Delivery address
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
            color: color.withAlpha(
                (0.1 * 255).toInt()), // Background color with opacity
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

  Widget _buildProgressDetails(BuildContext context) {
    // Function to build progress details
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
          
          // Add progress bar for both pending and in_progress
          if (widget.route.status == 'pending' || widget.route.status == 'in_progress') ...[
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Delivery Progress',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      '${(_getDeliveryProgress() * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: _getDeliveryProgress(),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: Colors.grey.shade300,
                ),
              ],
            ),
          ],
          
          // Add driver speed if available (for in_progress only)
          if (widget.route.status == 'in_progress' && 
              widget.route.currentLocation != null &&
              widget.route.metadata?['currentSpeed'] != null) ...[
            const SizedBox(height: 12),
            Divider(color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.speed,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Current Speed: ${_formatDriverSpeed()}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          
          // Traffic data if available
          if (widget.route.metadata?['routeDetails']?['traffic'] != null) ...[
            const SizedBox(height: 12), 
            Divider(color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.traffic_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Traffic: ${widget.route.metadata!['routeDetails']['traffic']}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          
          // Show scheduled time for pending deliveries
          if (widget.route.status == 'pending') ...[
            const SizedBox(height: 12),
            Divider(color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Scheduled: ${DateFormat('MMM d, h:mm a').format(widget.route.startTime)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
  
  // Helper to get delivery progress
 double _getDeliveryProgress() {
    // For pending deliveries, calculate progress based on time until start
    if (widget.route.status == 'pending') {
      final now = DateTime.now();
      if (now.isBefore(widget.route.startTime)) {
        // Calculate progress until start time
        final totalLeadTime = widget.route.startTime.difference(widget.route.createdAt).inSeconds;
        final remainingLeadTime = widget.route.startTime.difference(now).inSeconds;
        
        if (totalLeadTime <= 0) return 0.0;
        
        final progress = ((totalLeadTime - remainingLeadTime) / totalLeadTime);
        if (progress.isFinite && !progress.isNaN) {
          return progress.clamp(0.0, 0.99);
        }
        return 0.5; // Default to 50% if calculation failed
      }
      return 0.99; // Almost ready to start
    }
    
    // First check if there's a stored progress value
    if (widget.route.metadata?['routeDetails']?['progress'] != null) {
      final progress = widget.route.metadata!['routeDetails']['progress'];
      if (progress is num && progress.isFinite) {
        return progress.toDouble().clamp(0.0, 1.0);
      }
    }
    
    // Return a safe default value for completed and other statuses
    if (widget.route.status == 'completed') return 1.0;
    if (widget.route.status == 'cancelled') return 0.0;
    
    // Otherwise calculate based on DeliveryProgress helper
    try {
      return widget.route.calculateProgress();
    } catch (e) {
      debugPrint('Error calculating progress: $e');
      return 0.5; // Default to 50% if calculation failed
    }
  }
  
  // Format driver speed
  String _formatDriverSpeed() {
    final speed = widget.route.metadata?['currentSpeed'];
    if (speed == null || speed is! num || !speed.isFinite || speed <= 0) {
      return 'N/A';
    }
    
    // Convert m/s to mph
    final speedMph = (speed * 2.23694).toStringAsFixed(1);
    return '$speedMph mph';
  }
  double sqrt(double value) {
    if (value <= 0) return 0;
    if (!value.isFinite) return 0;
    return math.sqrt(value);
  }


  Widget _buildProgressDetail(
    BuildContext context,
    String label, // Label for the detail
    String total, // Total value
    String current, // Current value
  ) {
    final theme = Theme.of(context); // Get theme
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16), // Padding for the detail
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

  Widget _buildManifestSummary(BuildContext context) {
    final itemsData = widget.route.metadata?['loadedItems'];
    if (itemsData == null) return const SizedBox.shrink();

    final items = itemsData as List;
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final allItemsLoaded = widget.route.metadata?['vehicleHasAllItems'] ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allItemsLoaded ? Icons.check_circle : Icons.info_outline,
                color: allItemsLoaded ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Manifest Items (${items.length})',
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                allItemsLoaded
                    ? 'All items loaded'
                    : 'Some items may be missing',
                style: TextStyle(
                  color: allItemsLoaded ? Colors.green : Colors.orange,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Helper to determine status label
  String _getStatusLabel() {
    final now = DateTime.now();
    
    if (widget.route.status == 'pending') {
      return 'Scheduled';
    } else if (widget.route.status == 'completed') {
      return 'Delivered';
    } else if (widget.route.status == 'cancelled') {
      return 'Cancelled';
    } else if (_isDelayed) {
      return 'Delayed';
    } else if (widget.route.status == 'in_progress') {
      // For in-progress deliveries, check if on time
      final remaining = widget.route.estimatedEndTime.difference(now);
      if (remaining.inMinutes > 10) {
        return 'Early';
      } else {
        return 'On time';
      }
    }
    
    return 'Scheduled';
  }
  
  // Helper to get status color
  Color _getStatusColor(ThemeData theme) {
    final status = _getStatusLabel();
    
    switch (status) {
      case 'Early':
        return Colors.green;
      case 'On time':
        return theme.colorScheme.primary;
      case 'Delayed':
        return theme.colorScheme.error;
      case 'Delivered':
        return Colors.green;
      case 'Cancelled':
        return Colors.grey;
      default:
        return theme.colorScheme.tertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build method for the widget
    final theme = Theme.of(context); // Get theme
    final statusLabel = _getStatusLabel();
    final statusColor = _getStatusColor(theme);

    return Container(
      padding: const EdgeInsets.all(16), // Padding for the container
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, // Background color
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20), // Border radius
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).toInt()), // Shadow color
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
              margin:
                  const EdgeInsets.only(bottom: 16), // Margin for the handle
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant
                    .withAlpha((0.4 * 255).toInt()), // Handle color
                borderRadius: BorderRadius.circular(2), // Border radius
              ),
            ),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween, // Space between elements
              children: [
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start, // Align text to start
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
                        if (widget.route.status != 'cancelled' && widget.route.status != 'completed')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, // Horizontal padding
                              vertical: 4, // Vertical padding
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha((0.15 * 255).toInt()), // Background color
                              borderRadius:
                                  BorderRadius.circular(12), // Border radius
                              border: Border.all(color: statusColor.withAlpha((0.5 * 255).toInt())),
                            ),
                            child: Text(
                              statusLabel, // Status label
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: statusColor, // Text color
                                fontWeight: FontWeight.w600, // Text weight
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4), // Spacing
                    Text(
                      widget.route.status == 'pending' 
                        ? 'Scheduled for ${DateFormat('h:mm a').format(widget.route.startTime)}'
                        : 'Estimated arrival at ${DateFormat('h:mm a').format(widget.route.estimatedEndTime)}', // Estimated arrival time
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

            // Show progress bar for all status types
            LinearProgressIndicator(
              value: widget.route.status == 'completed' 
                ? 1.0
                : widget.route.status == 'cancelled'
                  ? 0.0 
                  : _getDeliveryProgress(), // Progress value
              backgroundColor: theme
                  .colorScheme.surfaceContainerHighest, // Background color
              valueColor: AlwaysStoppedAnimation(
                widget.route.status == 'completed'
                  ? Colors.green
                  : widget.route.status == 'cancelled'
                    ? Colors.grey
                    : _isDelayed
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary, // Progress color
              ),
            ),
            const SizedBox(height: 16), // Spacing

            // Always show address section
            _buildAddressSection(context), // Address section

            const SizedBox(height: 16), // Spacing

            // Always show progress details
            _buildProgressDetails(context), // Progress details
            
            const SizedBox(height: 16),
            _buildManifestSummary(context), // Manifest summary

            const SizedBox(height: 24), // Spacing

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        widget.onDriverInfoTap, // Driver info tap callback
                    icon: const Icon(Icons.person_outline), // Icon for button
                    label: const Text('Driver Info'), // Label for button
                  ),
                ),
                const SizedBox(width: 16), // Spacing
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget
                        .onContactDriverTap, // Contact driver tap callback
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