import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:cateredtoyou/models/delivery_route_model.dart';

class DeliveryProgress extends StatelessWidget {
  final DeliveryRoute route;
  final VoidCallback? onTap;

  const DeliveryProgress({
    super.key,
    required this.route,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Get delivery progress metrics
    final progress = _getDeliveryProgress();
    final etaText = _getFormattedETA();
    final statusText = _getStatusText();
    final statusColor = _getStatusColor();
    final totalDistance = _getFormattedDistance();
    final timeRemaining = _getTimeRemaining();
    final driverName = route.metadata?['driverName'] ?? 'Your Driver';

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: statusColor.withAlpha((0.1 * 255).toInt()),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha((0.2 * 255).toInt()),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getStatusIcon(),
                      color: statusColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            fontSize: 16,
                          ),
                        ),
                        if (route.status == 'in_progress')
                          Text(
                            'Estimated arrival at $etaText',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (route.status == 'in_progress')
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          timeRemaining,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'remaining',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Progress visualization
            if (route.status == 'in_progress')
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16, left: 16, right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Route progress bar
                    ProgressBarWithSteps(
                      progress: progress,
                      stepLabels: const ['Accepted', 'In Transit', 'Arriving', 'Delivered'],
                    ),
                    
                    // Distance and driver status
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$totalDistance remaining',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _isDriverActive() ? Colors.green : Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isDriverActive() ? '$driverName is on the way' : 'Waiting for driver update',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _isDriverActive() ? Colors.green : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Order details section
            if (route.metadata?['orderDetails'] != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha((0.5 * 255).toInt()),
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'View Order Details',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper method to determine if driver is actively updating
  bool _isDriverActive() {
    if (route.currentLocation == null) return false;

    // Check if there's a recent location update timestamp
    if (route.metadata != null && route.metadata!['lastLocationUpdate'] != null) {
      final lastUpdate = (route.metadata!['lastLocationUpdate'] as Timestamp).toDate();
      final difference = DateTime.now().difference(lastUpdate);
      return difference.inMinutes < 3; // Consider active if update within last 3 minutes
    }

    return false;
  }

  // Helper to get the delivery progress percentage
  double _getDeliveryProgress() {
    if (route.status == 'completed') return 1.0;
    if (route.status == 'pending') return 0.0;

    // If route is in progress, extract progress from metadata
    if (route.metadata != null &&
        route.metadata!['routeDetails'] != null &&
        route.metadata!['routeDetails']['progress'] != null) {
      final progress = (route.metadata!['routeDetails']['progress'] as num).toDouble();
      // Ensure progress is between 0 and 1
      return progress.clamp(0.0, 1.0);
    }

    // Default to 0.1 if no progress data (just started)
    return 0.1;
  }

  // Helper to get formatted ETA
  String _getFormattedETA() {
    return DateFormat('h:mm a').format(route.estimatedEndTime);
  }

  // Helper to get status text
  String _getStatusText() {
    switch (route.status) {
      case 'pending':
        return 'Delivery Scheduled';
      case 'in_progress':
        final progress = _getDeliveryProgress();
        if (progress < 0.1) {
          return 'Driver is preparing';
        } else if (progress < 0.7) {
          return 'Your delivery is on the way';
        } else {
          return 'Driver is almost there';
        }
      case 'completed':
        return 'Delivery Completed';
      case 'cancelled':
        return 'Delivery Cancelled';
      default:
        return 'Status Unknown';
    }
  }

  // Helper to get status color
  Color _getStatusColor() {
    switch (route.status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Helper to get status icon
  IconData _getStatusIcon() {
    switch (route.status) {
      case 'pending':
        return Icons.timelapse;
      case 'in_progress':
        return Icons.delivery_dining;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  // Helper to get formatted distance
  String _getFormattedDistance() {
    if (route.metadata == null ||
        route.metadata!['routeDetails'] == null ||
        route.metadata!['routeDetails']['remainingDistance'] == null) {
      return 'calculating...';
    }

    // Get remaining distance in meters
    final distanceMeters = (route.metadata!['routeDetails']['remainingDistance'] as num).toDouble();
    
    // Convert to miles
    final distanceMiles = distanceMeters / 1609.344;
    
    if (distanceMiles < 0.1) {
      return 'less than 0.1 miles';
    } else {
      return '${distanceMiles.toStringAsFixed(1)} miles';
    }
  }

  // Helper to get formatted time remaining
  String _getTimeRemaining() {
    if (route.metadata == null ||
        route.metadata!['routeDetails'] == null ||
        route.metadata!['routeDetails']['remainingDuration'] == null) {
      return 'calculating...';
    }

    // Get remaining duration in seconds
    final durationSeconds = (route.metadata!['routeDetails']['remainingDuration'] as num).toInt();
    
    // Format nicely
    if (durationSeconds < 60) {
      return 'Less than 1 min';
    } else if (durationSeconds < 3600) {
      final minutes = (durationSeconds / 60).ceil();
      return '$minutes min';
    } else {
      final hours = (durationSeconds / 3600).floor();
      final minutes = ((durationSeconds % 3600) / 60).ceil();
      return '$hours h ${minutes > 0 ? '$minutes min' : ''}';
    }
  }

 
  static double calculateProgress({
    required List<GeoPoint> waypoints,
    GeoPoint? currentLocation,
    required DateTime startTime,
    required DateTime estimatedEndTime,
    required String status,
    Map<String, dynamic>? metadata,
  }) {
    // If delivery is completed, return 100%
    if (status == 'completed') return 1.0;
    
    // If delivery is cancelled, return 0%
    if (status == 'cancelled') return 0.0;
    
    // If delivery is pending (not started yet), return 0%
    if (status == 'pending') return 0.0;
    
    // First, check if we have a pre-calculated progress value in metadata
    if (metadata != null && 
        metadata['routeDetails'] != null && 
        metadata['routeDetails']['progress'] != null) {
      final progress = metadata['routeDetails']['progress'];
      if (progress is num) {
        return progress.toDouble().clamp(0.0, 1.0);
      }
    }
    
    // If we have current location and waypoints, calculate based on distance
    if (currentLocation != null && waypoints.isNotEmpty) {
      // Get the total distance of the route
      double totalDistance = calculateTotalRouteDistance(waypoints);
      if (totalDistance <= 0) return 0.0;
      
      // Get the remaining distance to the destination
      double remainingDistance = calculateRemainingDistance(currentLocation, waypoints.last);
      
      // Calculate the progress as a percentage (1 - remaining/total)
      double progress = 1.0 - (remainingDistance / totalDistance);
      
      // Ensure progress is between 0 and 1
      return progress.clamp(0.0, 1.0);
    }
    
    // If we can't calculate based on location, use time-based estimation
    final now = DateTime.now();
    
    // If delivery hasn't started yet
    if (now.isBefore(startTime)) return 0.0;
    
    // If we're past the estimated end time
    if (now.isAfter(estimatedEndTime)) return 0.95; // Almost complete
    
    // Calculate progress based on time elapsed
    final totalDuration = estimatedEndTime.difference(startTime).inMilliseconds;
    if (totalDuration <= 0) return 0.5; // Default to 50% if timing is weird
    
    final elapsedDuration = now.difference(startTime).inMilliseconds;
    double progress = elapsedDuration / totalDuration;
    
    // Ensure progress is between 0 and 1
    return progress.clamp(0.0, 1.0);
  }

  // Static helper for route distance calculation (used by other classes)
  static double calculateTotalRouteDistance(List<GeoPoint> waypoints) {
    if (waypoints.length < 2) return 0;

    double totalDistance = 0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      final startPoint = waypoints[i];
      final endPoint = waypoints[i + 1];

      totalDistance += calculateStraightLineDistance(
          startPoint.latitude,
          startPoint.longitude,
          endPoint.latitude,
          endPoint.longitude);
    }

    // Convert to meters
    return totalDistance * 1000; 
  }

  // Static helper for calculating remaining distance
  static double calculateRemainingDistance(GeoPoint currentLocation, GeoPoint destination) {
    // Calculate straight-line distance
    return calculateStraightLineDistance(
      currentLocation.latitude,
      currentLocation.longitude,
      destination.latitude,
      destination.longitude,
    ) * 1000; // Convert km to meters
  }

  // Helper for straight-line distance calculation
  static double calculateStraightLineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371.0; // Earth's radius in kilometers

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  static double sin(double rad) => math.sin(rad);
  static double cos(double rad) => math.cos(rad);
  static double atan2(double y, double x) => math.atan2(y, x);
  static double sqrt(double value) => value <= 0 ? 0 : math.sqrt(value);
}

// Beautiful progress bar with steps similar to Uber Eats
class ProgressBarWithSteps extends StatelessWidget {
  final double progress;
  final List<String> stepLabels;
  final Color? activeColor;
  final Color? inactiveColor;

  const ProgressBarWithSteps({
    super.key,
    required this.progress,
    required this.stepLabels,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColorValue = activeColor ?? Theme.of(context).colorScheme.primary;
    final inactiveColorValue = inactiveColor ?? Colors.grey.shade300;
    
    // Calculate which steps are active based on progress
    final stepCount = stepLabels.length;
    final stepWidth = 1.0 / (stepCount - 1);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar with steps
        SizedBox(
          height: 36,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              
              return Stack(
                children: [
                  // Background track
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: inactiveColorValue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  
                  // Active progress
                  Positioned(
                    top: 12,
                    left: 0,
                    child: Container(
                      height: 4,
                      width: totalWidth * progress,
                      decoration: BoxDecoration(
                        color: activeColorValue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  
                  // Step circles
                  ...List.generate(stepCount, (index) {
                    final stepPosition = index * stepWidth;
                    final isActive = progress >= stepPosition;
                    final isLastStep = index == stepCount - 1;
                    
                    return Positioned(
                      top: 8,
                      left: totalWidth * stepPosition - (isLastStep ? 12 : 0),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isActive ? activeColorValue : inactiveColorValue,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }),
                  
                  // Current position animated indicator
                  if (progress > 0 && progress < 1.0)
                    Positioned(
                      top: 4,
                      left: totalWidth * progress - 10,
                      child: _buildPulsingDot(context, activeColorValue),
                    ),
                ],
              );
            },
          ),
        ),
        
        // Step labels
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              
              return Stack(
                children: List.generate(stepCount, (index) {
                  final stepPosition = index * stepWidth;
                  final isActive = progress >= stepPosition;
                  final isLastStep = index == stepCount - 1;
                  
                  return Positioned(
                    top: 0,
                    left: totalWidth * stepPosition - (isLastStep ? 60 : 0),
                    right: isLastStep ? 0 : null,
                    width: isLastStep ? 60 : 60,
                    child: Text(
                      stepLabels[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? activeColorValue : Colors.grey.shade600,
                      ),
                      textAlign: isLastStep ? TextAlign.right : (index == 0 ? TextAlign.left : TextAlign.center),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
  
  // Pulsing dot animation for current position
  Widget _buildPulsingDot(BuildContext context, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.8, end: 1.2),
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 20 * value,
          height: 20 * value,
          decoration: BoxDecoration(
            color: color.withAlpha((0.3 * 255).toInt()),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
        );
      },
      onEnd: () {
        // Rebuild to restart animation
        if (context.findRenderObject()?.attached ?? false) {
          (context as Element).markNeedsBuild();
        }
      },
    );
  }
}