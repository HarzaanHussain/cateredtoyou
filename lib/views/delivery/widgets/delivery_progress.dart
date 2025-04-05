import 'dart:math'; // Importing math library for mathematical functions
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore for GeoPoint

class DeliveryProgress {
  /// Calculates the progress of a delivery route based on various factors
  /// Returns a value between 0.0 and 1.0
  static double calculateProgress({
    required List<GeoPoint>
        waypoints, // List of waypoints for the delivery route
    required GeoPoint? currentLocation, // Current location of the delivery
    required DateTime startTime, // Start time of the delivery
    required DateTime estimatedEndTime, // Estimated end time of the delivery
    required String status, // Status of the delivery
    Map<String, dynamic>?
        metadata, // Optional metadata that may contain cached progress
  }) {
    // Return 1.0 if delivery is completed
    if (status.toLowerCase() == 'completed') {
      return 1.0; // Delivery is completed
    }

    // Return 0.0 if delivery is cancelled
    if (status.toLowerCase() == 'cancelled') {
      return 0.0; // Delivery is cancelled
    }

    // For pending deliveries, calculate progress based on time until start
    if (status.toLowerCase() == 'pending') {
      final now = DateTime.now();

      // If we've passed the start time but status is still pending
      if (now.isAfter(startTime)) {
        return 0.95; // Almost ready to start
      }

      // Calculate progress towards start time from creation time
      if (metadata != null && metadata['createdAt'] != null) {
        DateTime createdAt;
        if (metadata['createdAt'] is DateTime) {
          createdAt = metadata['createdAt'] as DateTime;
        } else if (metadata['createdAt'] is Timestamp) {
          createdAt = (metadata['createdAt'] as Timestamp).toDate();
        } else {
          // If we can't determine creation time, provide fallback
          return 0.5; // Default to 50% for pending without creation time
        }

        // Calculate the total lead time (from creation to start)
        final totalLeadTime = startTime.difference(createdAt).inSeconds;
        if (totalLeadTime <= 0) return 0.5; // Avoid division by zero

        // Calculate elapsed time since creation
        final elapsedLeadTime = now.difference(createdAt).inSeconds;

        // Calculate progress as a fraction of elapsed time to total lead time
        // Clamp between 0.0 and 0.95 to indicate it's not started yet
        return (elapsedLeadTime / totalLeadTime).clamp(0.0, 0.95);
      }

      return 0.5; // Default to 50% for pending
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
      return _calculateTimeProgress(
          startTime, estimatedEndTime); // Calculate progress based on time
    }

    // Calculate both distance and time progress
    final distanceProgress = _calculateDistanceProgress(
        waypoints, currentLocation, metadata); // Calculate distance progress
    final timeProgress = _calculateTimeProgress(
        startTime, estimatedEndTime); // Calculate time progress

    // Weight the progress calculation (60% distance, 40% time)
    return (distanceProgress * 0.6 + timeProgress * 0.4)
        .clamp(0.0, 1.0); // Combine distance and time progress
  }

  /// Calculates progress based on distance traveled
  static double _calculateDistanceProgress(List<GeoPoint> waypoints,
      GeoPoint currentLocation, Map<String, dynamic>? metadata) {
    if (waypoints.isEmpty || waypoints.length < 2) return 0.0;

    // First check if we have the remaining distance and total distance in metadata
    if (metadata != null &&
        metadata['routeDetails'] != null &&
        metadata['routeDetails']['remainingDistance'] != null &&
        metadata['routeDetails']['totalDistance'] != null) {
      final remainingDistance =
          metadata['routeDetails']['remainingDistance'] as num;
      final totalDistance = metadata['routeDetails']['totalDistance'] as num;

      if (totalDistance > 0) {
        // Calculate progress as (1 - remainingDistance/totalDistance)
        final progress = 1.0 - (remainingDistance / totalDistance);
        return progress.clamp(0.0, 1.0);
      }
    }

    // If we don't have the metadata, we need to calculate manually
    final origin = waypoints.first;
    final destination = waypoints.last;

    // Calculate total route distance (origin to destination)
    double totalDistance = _calculateDistance(origin.latitude, origin.longitude,
        destination.latitude, destination.longitude);

    // Ensure we have a valid total distance
    if (totalDistance <= 0.001) {
      totalDistance = 0.001; // Prevent division by zero or very small values
    }

    // Calculate distance from current location to destination
    double remainingDistance = _calculateDistance(currentLocation.latitude,
        currentLocation.longitude, destination.latitude, destination.longitude);

    // Make sure we don't divide by zero or get negative progress
    if (remainingDistance > totalDistance) {
      remainingDistance =
          totalDistance * 0.9; // Cap at 90% of total if something's wrong
    }

    // Calculate progress as (1 - remainingDistance/totalDistance)
    final progress = 1.0 - (remainingDistance / totalDistance);
    return progress.clamp(0.0, 1.0);
  }

  /// Calculates progress based on time elapsed
  static double _calculateTimeProgress(
      DateTime startTime, DateTime estimatedEndTime) {
    final now = DateTime.now(); // Current time

    // If we haven't reached start time yet
    if (now.isBefore(startTime)) {
      return 0.0; // Delivery hasn't started yet
    }

    // If we've passed the estimated end time
    if (now.isAfter(estimatedEndTime)) {
      return 1.0; // Delivery time has elapsed
    }

    final totalDuration = estimatedEndTime
        .difference(startTime)
        .inSeconds; // Total duration in seconds

    // Handle case where start and end times are the same or very close
    if (totalDuration <= 0) return 0.5;

    final elapsedDuration =
        now.difference(startTime).inSeconds; // Elapsed duration in seconds

    // Calculate and clamp between 0 and 1
    final progress = (elapsedDuration / totalDuration);
    return progress.isFinite
        ? progress.clamp(0.0, 1.0)
        : 0.5; // Return 0.5 if result is not finite
  }

  /// Calculates the distance between two points using the Haversine formula
  static double _calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    // Guard against NaN or Infinity inputs
    if (!startLat.isFinite ||
        !startLng.isFinite ||
        !endLat.isFinite ||
        !endLng.isFinite) {
      return 0.0;
    }

    const double earthRadius = 6371.0; // Earth's radius in kilometers

    // Convert latitude and longitude to radians
    final startLatRad = _degreesToRadians(startLat);
    final startLngRad = _degreesToRadians(startLng);
    final endLatRad = _degreesToRadians(endLat);
    final endLngRad = _degreesToRadians(endLng);

    // Calculate differences
    final dLat = endLatRad - startLatRad;
    final dLng = endLngRad - startLngRad;

    // Haversine formula with safety checks
    try {
      final a = _square(sin(dLat / 2)) +
          cos(startLatRad) * cos(endLatRad) * _square(sin(dLng / 2));
      // Ensure a is between 0 and 1
      final clampedA = a.clamp(0.0, 1.0);
      final c = 2 * asin(sqrt(clampedA));

      final distance = earthRadius * c;
      // Verify that the distance is finite and valid
      return distance.isFinite && distance >= 0 ? distance : 0.0;
    } catch (e) {
      // Fallback to a simpler calculation if there's an error
      return 0.0;
    }
  }

  /// Converts degrees to radians
  static double _degreesToRadians(double degrees) {
    if (!degrees.isFinite) return 0.0; // Safety check
    return degrees * (pi / 180.0); // Convert degrees to radians using math.pi
  }

  /// Helper function to calculate square of a number
  static double _square(double value) {
    if (!value.isFinite) return 0.0; // Safety check
    return value * value; // Return the square of the value
  }

  /// Helper function to calculate total route distance
  static double calculateTotalRouteDistance(List<GeoPoint> waypoints) {
    if (waypoints.length < 2) return 0.0;

    double totalDistance = 0.0;

    // Sum the distances between each consecutive waypoint
    for (int i = 0; i < waypoints.length - 1; i++) {
      final pointA = waypoints[i];
      final pointB = waypoints[i + 1];

      totalDistance += _calculateDistance(
          pointA.latitude, pointA.longitude, pointB.latitude, pointB.longitude);
    }

    // Convert kilometers to meters for consistency with the API
    return totalDistance * 1000;
  }

  /// Helper function to calculate remaining distance
  static double calculateRemainingDistance(
      GeoPoint currentLocation, GeoPoint destination) {
    // Calculate direct distance from current location to destination
    final distance = _calculateDistance(currentLocation.latitude,
        currentLocation.longitude, destination.latitude, destination.longitude);

    // Convert kilometers to meters for consistency with the API
    return distance * 1000;
  }

  // Additional helper functions for trigonometry with safety checks
  static double sin(double rad) {
    if (!rad.isFinite) return 0.0;
    return math.sin(rad);
  }

  static double cos(double rad) {
    if (!rad.isFinite) return 1.0;
    return math.cos(rad);
  }

  static double asin(double value) {
    // Clamp value between -1 and 1 to avoid domain errors
    final clampedValue = value.clamp(-1.0, 1.0);
    return math.asin(clampedValue);
  }

  static double sqrt(double value) {
    if (value <= 0) return 0.0;
    if (!value.isFinite) return 0.0;
    return math.sqrt(value);
  }
}
