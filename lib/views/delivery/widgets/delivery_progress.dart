import 'dart:math'; // Importing math library for mathematical functions
import 'package:cateredtoyou/models/delivery_route_model.dart'; // Importing the delivery route model
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore for GeoPoint

class DeliveryProgress {
  /// Calculates the progress of a delivery route based on various factors
  /// Returns a value between 0.0 and 1.0
  static double calculateProgress({
    required List<GeoPoint> waypoints, // List of waypoints for the delivery route
    required GeoPoint? currentLocation, // Current location of the delivery
    required DateTime startTime, // Start time of the delivery
    required DateTime estimatedEndTime, // Estimated end time of the delivery
    required String status, // Status of the delivery
    Map<String, dynamic>? metadata, // Optional metadata that may contain cached progress
  }) {
    // Return 1.0 if delivery is completed
    if (status.toLowerCase() == 'completed') {
      return 1.0; // Delivery is completed
    }

    // Return 0.0 if delivery is cancelled
    if (status.toLowerCase() == 'cancelled') {
      return 0.0; // Delivery is cancelled
    }

    // If delivery hasn't started yet, return 0.0
    if (status.toLowerCase() == 'pending') {
      return 0.0; // Delivery is pending
    }
    
    // First check if we have a pre-calculated progress value in metadata
    if (metadata != null && 
        metadata['routeDetails'] != null && 
        metadata['routeDetails']['progress'] != null) {
      final progress = metadata['routeDetails']['progress'];
      if (progress is num) {
        return progress.toDouble().clamp(0.0, 1.0);
      }
    }

    // If no current location is available, calculate based on time only
    if (currentLocation == null) {
      return _calculateTimeProgress(startTime, estimatedEndTime); // Calculate progress based on time
    }

    // Calculate both distance and time progress
    final distanceProgress = _calculateDistanceProgress(waypoints, currentLocation); // Calculate distance progress
    final timeProgress = _calculateTimeProgress(startTime, estimatedEndTime); // Calculate time progress

    // Weight the progress calculation (60% distance, 40% time)
    return (distanceProgress * 0.6) + (timeProgress * 0.4); // Combine distance and time progress
  }
  /// Calculates progress based on distance traveled
  static double _calculateDistanceProgress(List<GeoPoint> waypoints, GeoPoint currentLocation) {
    if (waypoints.isEmpty || waypoints.length < 2) return 0.0; // Return 0.0 if there are not enough waypoints

    double totalDistance = 0; // Total distance of the route
    double traveledDistance = 0; // Distance traveled so far
    bool passedDriver = false; // Flag to check if the driver has passed a waypoint

    // Calculate total route distance and distance traveled
    for (int i = 0; i < waypoints.length - 1; i++) {
      final pointA = waypoints[i]; // Current waypoint
      final pointB = waypoints[i + 1]; // Next waypoint

      final segmentDistance = _calculateDistance(
        pointA.latitude, pointA.longitude,
        pointB.latitude, pointB.longitude
      ); // Distance between two waypoints

      if (!passedDriver) {
        final distToA = _calculateDistance(
          currentLocation.latitude, currentLocation.longitude,
          pointA.latitude, pointA.longitude
        ); // Distance from current location to current waypoint
        final distToB = _calculateDistance(
          currentLocation.latitude, currentLocation.longitude,
          pointB.latitude, pointB.longitude
        ); // Distance from current location to next waypoint

        if (distToA + distToB <= segmentDistance + 0.1) {
          traveledDistance += distToA; // Add distance to current waypoint
          passedDriver = true; // Mark that the driver has passed the waypoint
        } else {
          traveledDistance += segmentDistance; // Add segment distance to traveled distance
        }
      }

      totalDistance += segmentDistance; // Add segment distance to total distance
    }

    return (traveledDistance / totalDistance).clamp(0.0, 1.0); // Return the progress as a fraction of total distance
  }

  /// Calculates progress based on time elapsed
  static double _calculateTimeProgress(DateTime startTime, DateTime estimatedEndTime) {
    final now = DateTime.now(); // Current time
    
    // If we haven't reached start time yet
    if (now.isBefore(startTime)) {
      return 0.0; // Delivery hasn't started yet
    }
    
    // If we've passed the estimated end time
    if (now.isAfter(estimatedEndTime)) {
      return 1.0; // Delivery time has elapsed
    }

    final totalDuration = estimatedEndTime.difference(startTime).inSeconds; // Total duration of the delivery
    final elapsedDuration = now.difference(startTime).inSeconds; // Elapsed duration since start time

    return (elapsedDuration / totalDuration).clamp(0.0, 1.0); // Return the progress as a fraction of total duration
  }

  /// Calculates the distance between two points using the Haversine formula
  static double _calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    const double earthRadius = 6371.0; // Earth's radius in kilometers

    // Convert latitude and longitude to radians
    final startLatRad = _degreesToRadians(startLat);
    final startLngRad = _degreesToRadians(startLng);
    final endLatRad = _degreesToRadians(endLat);
    final endLngRad = _degreesToRadians(endLng);

    // Calculate differences
    final dLat = endLatRad - startLatRad;
    final dLng = endLngRad - startLngRad;

    // Haversine formula
    final a = _square(sin(dLat / 2)) +
        cos(startLatRad) * cos(endLatRad) * _square(sin(dLng / 2));
    final c = 2 * asin(sqrt(a));

    return earthRadius * c; // Return the distance in kilometers
  }

  /// Converts degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180.0); // Convert degrees to radians
  }

  /// Helper function to calculate square of a number
  static double _square(double value) {
    return value * value; // Return the square of the value
  }
}

// Extension to use the calculator with DeliveryRoute model
extension DeliveryRouteProgress on DeliveryRoute {
  double calculateProgress() {
    return DeliveryProgress.calculateProgress(
      waypoints: waypoints, // Waypoints of the delivery route
      currentLocation: currentLocation, // Current location of the delivery
      startTime: startTime, // Start time of the delivery
      estimatedEndTime: estimatedEndTime, // Estimated end time of the delivery
      status: status, // Status of the delivery
    );
  }
}