import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cateredtoyou/models/delivery_route_model.dart';
import 'package:cateredtoyou/views/delivery/widgets/status_chip.dart';
import 'package:cateredtoyou/views/delivery/widgets/loaded_items_section.dart';

class DeliveryInfoCard extends StatefulWidget {
  final DeliveryRoute route;
  final VoidCallback onDriverInfoTap;
  final VoidCallback onContactDriverTap;

  const DeliveryInfoCard({
    super.key,
    required this.route,
    required this.onDriverInfoTap,
    required this.onContactDriverTap,
  });

  @override
  State<DeliveryInfoCard> createState() => _DeliveryInfoCardState();
}

class _DeliveryInfoCardState extends State<DeliveryInfoCard> {
  late Timer _updateTimer;
  String _timeLeft = '';
  bool _isDelayed = false;

  @override
  void initState() {
    super.initState();
    _updateTimeLeft();
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateTimeLeft();
    });
  }

  @override
  void dispose() {
    _updateTimer.cancel();
    super.dispose();
  }

  void _updateTimeLeft() {
    if (!mounted) return;

    final now = DateTime.now();
    
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
      _isDelayed = difference.isNegative && widget.route.status == 'in_progress';
      
      if (widget.route.status == 'completed') {
        _timeLeft = 'Delivered';
      } else if (widget.route.status == 'cancelled') {
        _timeLeft = 'Cancelled';
      } else if (_isDelayed) {
        final delayedBy = difference.abs();
        _timeLeft = 'Delayed by ${_formatDuration(delayedBy)}';
      } else if (widget.route.status == 'pending') {
        _timeLeft = 'Scheduled'; 
      } else {
        _timeLeft = _formatDuration(difference);
      }
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) {
      return '0h 0m';
    }
    
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    return '${duration.inMinutes}m';
  }

  String _formatTotalDistance() {
    final totalDistance = widget.route.metadata?['routeDetails']?['totalDistance'];
    if (totalDistance == null) {
      // Calculate from waypoints if not in metadata
      double distance = 0;
      final points = widget.route.waypoints;
      
      if (points.length >= 2) {
        for (int i = 0; i < points.length - 1; i++) {
          final p1 = points[i];
          final p2 = points[i + 1];
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
    if (widget.route.status == 'completed') {
      return '0 mi left';
    }
    
    if (widget.route.status == 'pending') {
      return _formatTotalDistance();
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
      
      final latDiff = currentLoc.latitude - destination.latitude;
      final lngDiff = currentLoc.longitude - destination.longitude;
      
      if (latDiff.isFinite && lngDiff.isFinite) {
        final distanceSquared = latDiff * latDiff + lngDiff * lngDiff;
        if (distanceSquared.isFinite && distanceSquared >= 0) {
          final distance = math.sqrt(distanceSquared) * 111000; // Rough meters
          final distanceInMiles = (distance / 1609.34).toStringAsFixed(1);
          return '$distanceInMiles mi left';
        }
      }
    }
    
    return _formatTotalDistance();
  }

  String _formatTotalDuration() {
  // Use the route's actual start and end times for accurate calculation
  final startTime = widget.route.startTime; 
  final endTime = widget.route.estimatedEndTime;
  
  // Ensure we're not calculating a negative duration
  if (startTime.isAfter(endTime)) {
    return 'Est. time: 0h 0m';
  }
  
  // Calculate the duration between start and estimated end time
  final duration = endTime.difference(startTime);
  
  // Format the duration - make sure we're getting proper values
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  
  // Debug the calculated values
  debugPrint('Total duration - Hours: $hours, Minutes: $minutes');
  debugPrint('StartTime: ${startTime.toString()}, EndTime: ${endTime.toString()}');
  
  // If both hours and minutes are 0, try getting the total minutes directly
  if (hours == 0 && minutes == 0) {
    final totalMinutes = duration.inMinutes;
    if (totalMinutes > 0) {
      return 'Est. time: ${totalMinutes}m';
    }
    
    // If we still have zero, check for seconds
    final totalSeconds = duration.inSeconds;
    if (totalSeconds > 0) {
      return 'Est. time: <1m';
    }
    
    // Fall back to using the metadata if available
    if (widget.route.metadata != null && 
        widget.route.metadata!['routeDetails'] != null && 
        widget.route.metadata!['routeDetails']['originalDuration'] != null) {
      final seconds = widget.route.metadata!['routeDetails']['originalDuration'] as num;
      final durationMinutes = (seconds / 60).round();
      final durationHours = durationMinutes ~/ 60;
      final remainingMinutes = durationMinutes % 60;
      
      if (durationHours > 0) {
        return 'Est. time: ${durationHours}h ${remainingMinutes}m';
      } else {
        return 'Est. time: ${durationMinutes}m';
      }
    }
  }
  
  // Normal formatting with hours and minutes
  if (hours > 0) {
    return 'Est. time: ${hours}h ${minutes}m';
  } else {
    return 'Est. time: ${minutes}m';
  }
}


 String _formatElapsedTime() {
  final now = DateTime.now();
  final startTime = widget.route.startTime;
  
  // For pending deliveries or if now is before start time
  if (widget.route.status == 'pending' || now.isBefore(startTime)) {
    return 'Elapsed: 0h 0m';
  }
  
  // For completed deliveries, use actual end time if available
  if (widget.route.status == 'completed' && widget.route.actualEndTime != null) {
    final elapsed = widget.route.actualEndTime!.difference(startTime);
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);
    
    if (hours > 0) {
      return 'Actual: ${hours}h ${minutes}m';
    } else {
      return 'Actual: ${elapsed.inMinutes}m';
    }
  }
  
  // For in-progress, calculate elapsed time from now
  final elapsed = now.difference(startTime);
  final hours = elapsed.inHours;
  final minutes = elapsed.inMinutes.remainder(60);
  
  // Debug the calculated values
  debugPrint('Elapsed time - Hours: $hours, Minutes: $minutes');
  debugPrint('Now: ${now.toString()}, StartTime: ${startTime.toString()}');
  
  // If in-progress but showing 0 time, check for timestamps in metadata
  if (hours == 0 && minutes == 0 && widget.route.status == 'in_progress') {
    // Check if there's an actualStartTime in the document
    if (widget.route.metadata != null && 
        widget.route.metadata!['actualStartTime'] != null) {
      final actualStartTimestamp = widget.route.metadata!['actualStartTime'];
      if (actualStartTimestamp is Timestamp) {
        // Convert the Firestore Timestamp to a Dart DateTime object
        final actualStartTime = actualStartTimestamp.toDate(); 
        // This is necessary because Firestore stores timestamps in its own format,
        // and we need a Dart DateTime object to perform time calculations.
        final actualElapsed = now.difference(actualStartTime);
        final actualHours = actualElapsed.inHours;
        final actualMinutes = actualElapsed.inMinutes.remainder(60);
        
        if (actualHours > 0) {
          return 'Elapsed: ${actualHours}h ${actualMinutes}m';
        } else if (actualMinutes > 0) {
          return 'Elapsed: ${actualMinutes}m';
        }
      }
    }
    
    // If we still have no time, show a minimum value rather than 0
    return 'Elapsed: <1m';
  }
  
  // Normal formatting with hours and minutes
  if (hours > 0) {
    return 'Elapsed: ${hours}h ${minutes}m';
  } else {
    return 'Elapsed: ${minutes}m';
  }
}

  Widget _buildAddressSection(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildAddressRow(
            context,
            Icons.store,
            'Pickup',
            widget.route.metadata?['pickupAddress'] ??
                'Restaurant Location',
            theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          _buildAddressRow(
            context,
            Icons.location_on,
            'Delivery',
            widget.route.metadata?['deliveryAddress'] ??
                'Delivery Location',
            theme.colorScheme.error,
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(
    BuildContext context,
    IconData icon,
    String label,
    String address,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha((0.1 * 255).toInt()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                address,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressDetails(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildProgressDetail(
                  context,
                  'Distance',
                  _formatTotalDistance(),
                  _formatRemainingDistance(),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: theme.colorScheme.outlineVariant,
              ),
              Expanded(
                child: _buildProgressDetail(
                  context,
                  'Time',
                  _formatTotalDuration(),
                  _formatElapsedTime(),
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
                    overflow: TextOverflow.ellipsis,
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
  
  double sqrt(double value) {
    if (value <= 0) return 0;
    if (!value.isFinite) return 0;
    return math.sqrt(value);
  }

  Widget _buildProgressDetail(
    BuildContext context,
    String label,
    String total,
    String current,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            total,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            current,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
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
    final theme = Theme.of(context);
    final statusLabel = _getStatusLabel();
    final statusColor = _getStatusColor(theme);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).toInt()),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant
                    .withAlpha((0.4 * 255).toInt()),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // FIX: Row that was causing overflow
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _timeLeft,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _isDelayed
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (widget.route.status != 'cancelled' && widget.route.status != 'completed')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha((0.15 * 255).toInt()),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: statusColor.withAlpha((0.5 * 255).toInt())),
                              ),
                              child: Text(
                                statusLabel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.route.status == 'pending' 
                          ? 'Scheduled for ${DateFormat('h:mm a').format(widget.route.startTime)}'
                          : 'Estimated arrival at ${DateFormat('h:mm a').format(widget.route.estimatedEndTime)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                StatusChip(status: widget.route.status),
              ],
            ),

            const SizedBox(height: 24),

            // Show progress bar for all status types
            LinearProgressIndicator(
              value: widget.route.status == 'completed' 
                ? 1.0
                : widget.route.status == 'cancelled'
                  ? 0.0 
                  : _getDeliveryProgress(),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                widget.route.status == 'completed'
                  ? Colors.green
                  : widget.route.status == 'cancelled'
                    ? Colors.grey
                    : _isDelayed
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
              ),
            ),
            
            const SizedBox(height: 16),

            // Address section
            _buildAddressSection(context),

            const SizedBox(height: 16),

            // Progress details
            _buildProgressDetails(context),
            
            const SizedBox(height: 16),
            
            // LoadedItemsSection integrated into info card
            if (widget.route.metadata != null && 
                widget.route.metadata!['loadedItems'] != null)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: LoadedItemsSection(
                  items: List<Map<String, dynamic>>.from(
                      widget.route.metadata!['loadedItems']),
                  allItemsLoaded: widget.route.metadata!['vehicleHasAllItems'] ?? false,
                ),
              ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onDriverInfoTap,
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Driver Info'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onContactDriverTap,
                    icon: const Icon(Icons.phone),
                    label: const Text('Contact'),
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