import 'package:cateredtoyou/views/delivery/widgets/delivery_progress.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore package to use Firestore related classes like Timestamp and GeoPoint
import 'dart:math' as math;

class DeliveryRoute {
  final String id; // Unique identifier for the delivery route
  final String eventId; // Identifier for the associated event
  final String vehicleId; // Identifier for the vehicle used in the delivery
  final String driverId; // Identifier for the originally assigned driver
  final String? currentDriver; // Identifier for the current active driver (may be different from original)
  final String organizationId; // Identifier for the organization managing the delivery
  final DateTime startTime; // Start time of the delivery route
  final DateTime estimatedEndTime; // Estimated end time of the delivery route
  final DateTime? actualEndTime; // Actual end time of the delivery route, nullable
  final List<GeoPoint> waypoints; // List of waypoints (geographical points) for the route
  final String status; // Current status of the delivery route
  final GeoPoint? currentLocation; // Current location of the delivery vehicle, nullable
  final double? currentHeading; // Current heading (direction) of the delivery vehicle, nullable
  final Map<String, dynamic>? dropoffInstructions; // Instructions for drop-off points, nullable
  final String? assignedZone; // Zone assigned to the delivery route, nullable
  final Map<String, dynamic>? routeOptimizationData; // Data related to route optimization, nullable
  final Map<String, dynamic>? metadata; // Additional metadata for the delivery route, nullable
  final DateTime createdAt; // Timestamp when the delivery route was created
  final DateTime updatedAt; // Timestamp when the delivery route was last updated

  DeliveryRoute({
    required this.id, // Constructor parameter for id
    required this.eventId, // Constructor parameter for eventId
    required this.vehicleId, // Constructor parameter for vehicleId
    required this.driverId, // Constructor parameter for driverId
    this.currentDriver, // Constructor parameter for currentDriver
    required this.organizationId, // Constructor parameter for organizationId
    required this.startTime, // Constructor parameter for startTime
    required this.estimatedEndTime, // Constructor parameter for estimatedEndTime
    this.actualEndTime, // Constructor parameter for actualEndTime, nullable
    required this.waypoints, // Constructor parameter for waypoints
    required this.status, // Constructor parameter for status
    this.currentLocation, // Constructor parameter for currentLocation, nullable
    this.currentHeading, // Constructor parameter for currentHeading, nullable
    this.dropoffInstructions, // Constructor parameter for dropoffInstructions, nullable
    this.assignedZone, // Constructor parameter for assignedZone, nullable
    this.routeOptimizationData, // Constructor parameter for routeOptimizationData, nullable
    this.metadata, // Constructor parameter for metadata, nullable
    required this.createdAt, // Constructor parameter for createdAt
    required this.updatedAt, // Constructor parameter for updatedAt
  });

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId, // Mapping eventId to a key-value pair
      'vehicleId': vehicleId, // Mapping vehicleId to a key-value pair
      'driverId': driverId, // Mapping driverId to a key-value pair
      'currentDriver': currentDriver ?? driverId, // Use currentDriver if available, otherwise fall back to original driverId
      'organizationId': organizationId, // Mapping organizationId to a key-value pair
      'startTime': Timestamp.fromDate(startTime), // Converting startTime to Firestore Timestamp
      'estimatedEndTime': Timestamp.fromDate(estimatedEndTime), // Converting estimatedEndTime to Firestore Timestamp
      'actualEndTime': actualEndTime != null ? Timestamp.fromDate(actualEndTime!) : null, // Converting actualEndTime to Firestore Timestamp if not null
      'waypoints': waypoints, // Mapping waypoints to a key-value pair
      'status': status, // Mapping status to a key-value pair
      'currentLocation': currentLocation, // Mapping currentLocation to a key-value pair
      'currentHeading': currentHeading, // Mapping currentHeading to a key-value pair
      'dropoffInstructions': dropoffInstructions, // Mapping dropoffInstructions to a key-value pair
      'assignedZone': assignedZone, // Mapping assignedZone to a key-value pair
      'routeOptimizationData': routeOptimizationData, // Mapping routeOptimizationData to a key-value pair
      'metadata': metadata ?? {}, // Mapping metadata to a key-value pair, defaulting to an empty map if null
      'createdAt': Timestamp.fromDate(createdAt), // Converting createdAt to Firestore Timestamp
      'updatedAt': Timestamp.fromDate(updatedAt), // Converting updatedAt to Firestore Timestamp
    };
  }

  factory DeliveryRoute.fromMap(Map<String, dynamic> map, String docId) {
    // Safely handle Timestamp conversions with null checks
    DateTime? getDateTimeFromTimestamp(dynamic timestamp) {
      if (timestamp == null) return DateTime.now();
      if (timestamp is Timestamp) return timestamp.toDate();
      return DateTime.now();
    }
    
    return DeliveryRoute(
      id: docId, // Setting id from the document ID
      eventId: map['eventId'] ?? '', // Extracting eventId from the map, defaulting to an empty string if null
      vehicleId: map['vehicleId'] ?? '', // Extracting vehicleId from the map, defaulting to an empty string if null
      driverId: map['driverId'] ?? '', // Extracting driverId from the map, defaulting to an empty string if null
      currentDriver: map['currentDriver'], // Extracting currentDriver from the map
      organizationId: map['organizationId'] ?? '', // Extracting organizationId from the map, defaulting to an empty string if null
      startTime: getDateTimeFromTimestamp(map['startTime']) ?? DateTime.now(), // Safely convert Timestamp or use current time as default
      estimatedEndTime: getDateTimeFromTimestamp(map['estimatedEndTime']) ?? DateTime.now(), // Safely convert Timestamp or use current time as default
      actualEndTime: map['actualEndTime'] != null 
          ? getDateTimeFromTimestamp(map['actualEndTime']) // Safely convert Timestamp
          : null,
      waypoints: List<GeoPoint>.from(map['waypoints'] ?? []), // Extracting waypoints from the map, defaulting to an empty list if null
      status: map['status'] ?? 'pending', // Extracting status from the map, defaulting to 'pending' if null
      currentLocation: map['currentLocation'] as GeoPoint?, // Extracting currentLocation from the map, nullable
      currentHeading: map['currentHeading']?.toDouble(), // Extracting currentHeading from the map and converting to double, nullable
      dropoffInstructions: map['dropoffInstructions'] as Map<String, dynamic>?, // Extracting dropoffInstructions from the map, nullable
      assignedZone: map['assignedZone'] as String?, // Extracting assignedZone from the map, nullable
      routeOptimizationData: map['routeOptimizationData'] as Map<String, dynamic>?, // Extracting routeOptimizationData from the map, nullable
      metadata: map['metadata'] as Map<String, dynamic>?, // Extracting metadata from the map, nullable
      createdAt: getDateTimeFromTimestamp(map['createdAt']) ?? DateTime.now(), // Safely convert Timestamp or use current time as default
      updatedAt: getDateTimeFromTimestamp(map['updatedAt']) ?? DateTime.now(), // Safely convert Timestamp or use current time as default
    );
  }

 DeliveryRoute copyWith({
    String? eventId, // Optional parameter for eventId
    String? vehicleId, // Optional parameter for vehicleId
    String? driverId, // Optional parameter for driverId
    String? currentDriver, // Optional parameter for currentDriver
    DateTime? startTime, // Optional parameter for startTime
    DateTime? estimatedEndTime, // Optional parameter for estimatedEndTime
    DateTime? actualEndTime, // Optional parameter for actualEndTime
    List<GeoPoint>? waypoints, // Optional parameter for waypoints
    String? status, // Optional parameter for status
    GeoPoint? currentLocation, // Optional parameter for currentLocation
    double? currentHeading, // Optional parameter for currentHeading
    double? currentSpeed, // Optional parameter for current speed
    Map<String, dynamic>? dropoffInstructions, // Optional parameter for dropoffInstructions
    String? assignedZone, // Optional parameter for assignedZone
    Map<String, dynamic>? routeOptimizationData, // Optional parameter for routeOptimizationData
    Map<String, dynamic>? metadata, // Optional parameter for metadata
  }) {
    return DeliveryRoute(
      id: id, // Keeping the same id
      eventId: eventId ?? this.eventId, // Using the new eventId if provided, otherwise keeping the existing one
      vehicleId: vehicleId ?? this.vehicleId, // Using the new vehicleId if provided, otherwise keeping the existing one
      driverId: driverId ?? this.driverId, // Using the new driverId if provided, otherwise keeping the existing one
      currentDriver: currentDriver ?? this.currentDriver, // Using the new currentDriver if provided, otherwise keeping the existing one
      organizationId: organizationId, // Keeping the same organizationId
      startTime: startTime ?? this.startTime, // Using the new startTime if provided, otherwise keeping the existing one
      estimatedEndTime: estimatedEndTime ?? this.estimatedEndTime, // Using the new estimatedEndTime if provided, otherwise keeping the existing one
      actualEndTime: actualEndTime ?? this.actualEndTime, // Using the new actualEndTime if provided, otherwise keeping the existing one
      waypoints: waypoints ?? this.waypoints, // Using the new waypoints if provided, otherwise keeping the existing ones
      status: status ?? this.status, // Using the new status if provided, otherwise keeping the existing one
      currentLocation: currentLocation ?? this.currentLocation, // Using the new currentLocation if provided, otherwise keeping the existing one
      currentHeading: currentHeading ?? this.currentHeading, // Using the new currentHeading if provided, otherwise keeping the existing one
      dropoffInstructions: dropoffInstructions ?? this.dropoffInstructions, // Using the new dropoffInstructions if provided, otherwise keeping the existing ones
      assignedZone: assignedZone ?? this.assignedZone, // Using the new assignedZone if provided, otherwise keeping the existing one
      routeOptimizationData: routeOptimizationData ?? this.routeOptimizationData, // Using the new routeOptimizationData if provided, otherwise keeping the existing one
      metadata: metadata ?? this.metadata, // Using the new metadata if provided, otherwise keeping the existing one
      createdAt: createdAt, // Keeping the same createdAt
      updatedAt: DateTime.now(), // Setting updatedAt to the current time
    );
  }
   // Get the active driver for this delivery (either current driver or original driver)
  String get activeDriverId => currentDriver ?? driverId;
  
  // Check if the given user is the active driver
  bool isActiveDriver(String userId){
      return currentDriver == userId;

  } 
  
  // Check if this is a reassigned delivery (current driver differs from original)
  bool get isReassigned => currentDriver != null && currentDriver != driverId;
  
  // Other methods remain the same...
  double calculateProgress() {
    return DeliveryProgress.calculateProgress(
      waypoints: waypoints,
      currentLocation: currentLocation,
      startTime: startTime,
      estimatedEndTime: estimatedEndTime,
      status: status,
      metadata: metadata,
    );
  }
  // Get the estimated time remaining in minutes
  int get estimatedTimeRemainingMinutes {
    // Implementation remains the same
    // If delivery is completed or cancelled, return 0
    if (status == 'completed' || status == 'cancelled') return 0;
    
    // Check if we have a pre-calculated value
    if (metadata != null && 
        metadata!['routeDetails'] != null && 
        metadata!['routeDetails']['estimatedTimeRemaining'] != null) {
      final seconds = metadata!['routeDetails']['estimatedTimeRemaining'];
      if (seconds is num) {
        return (seconds / 60).round();
      }
    }
    
    // Fallback to simple calculation
    final now = DateTime.now();
    
    // For pending deliveries, calculate time until start
    if (status == 'pending') {
      if (now.isAfter(startTime)) return 0; // If past start time but still pending
      return startTime.difference(now).inMinutes;
    }
    
    // For in_progress deliveries, calculate time until estimated end
    if (now.isAfter(estimatedEndTime)) return 0; // Don't show negative times
    
    return estimatedEndTime.difference(now).inMinutes;
  }
  
  // Get the remaining distance in meters
  double get remainingDistanceMeters {
    // If delivery is completed or cancelled, return 0
    if (status == 'completed' || status == 'cancelled') return 0;
    
    // Check if we have a pre-calculated value
    if (metadata != null && 
        metadata!['routeDetails'] != null && 
        metadata!['routeDetails']['remainingDistance'] != null) {
      final distance = metadata!['routeDetails']['remainingDistance'];
      if (distance is num) {
        return distance.toDouble();
      }
    }
    
    // If no pre-calculated value available, estimate from waypoints
    if (currentLocation != null && waypoints.isNotEmpty) {
      final destination = waypoints.last;
      
      // Calculate simple straight-line distance (Haversine formula)
      const double earthRadius = 6371000; // Earth radius in meters
      final lat1 = _degreesToRadians(currentLocation!.latitude);
      final lon1 = _degreesToRadians(currentLocation!.longitude);
      final lat2 = _degreesToRadians(destination.latitude);
      final lon2 = _degreesToRadians(destination.longitude);
      
      final dLat = lat2 - lat1;
      final dLon = lon2 - lon1;
      
      final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
                math.cos(lat1) * math.cos(lat2) *
                math.sin(dLon / 2) * math.sin(dLon / 2);
      final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      
      return earthRadius * c; // Distance in meters
    }
    
    // For pending status, calculate total route distance
    if (status == 'pending' && waypoints.length >= 2) {
      double totalDistance = 0;
      for (int i = 0; i < waypoints.length - 1; i++) {
        final point1 = waypoints[i];
        final point2 = waypoints[i + 1];
        
        const double earthRadius = 6371000; // Earth radius in meters
        final lat1 = _degreesToRadians(point1.latitude);
        final lon1 = _degreesToRadians(point1.longitude);
        final lat2 = _degreesToRadians(point2.latitude);
        final lon2 = _degreesToRadians(point2.longitude);
        
        final dLat = lat2 - lat1;
        final dLon = lon2 - lon1;
        
        final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
                  math.cos(lat1) * math.cos(lat2) *
                  math.sin(dLon / 2) * math.sin(dLon / 2);
        final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
        
        totalDistance += earthRadius * c;
      }
      
      return totalDistance;
    }
    
    return 0;
  }
  
  // Helper method to convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
  
  // Get the remaining distance in miles
  double get remainingDistanceMiles {
    return remainingDistanceMeters / 1609.344;
  }
  
  // Get the current speed in mph
  double get currentSpeedMph {
    final speed = metadata?['currentSpeed'];
    if (speed == null) return 0;
    
    // Convert m/s to mph
    return (speed * 2.23694);
  }
  
  // Format the remaining distance for display
  String get formattedRemainingDistance {
    if (status == 'completed') return 'Delivered';
    if (status == 'cancelled') return 'Cancelled';
    
    final miles = remainingDistanceMiles;
    if (miles <= 0) return 'Calculating...';
    
    return '${miles.toStringAsFixed(1)} miles';
  }
  
  // Format the estimated time remaining for display
  String get formattedTimeRemaining {
    if (status == 'completed') return 'Delivered';
    if (status == 'cancelled') return 'Cancelled';
    
    final minutes = estimatedTimeRemainingMinutes;
    if (minutes <= 0) {
      if (status == 'in_progress') return 'Arriving soon';
      return 'N/A';
    }
    
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours h ${remainingMinutes > 0 ? '$remainingMinutes min' : ''}';
    }
  }
  
  // Format current speed for display
  String get formattedSpeed {
    final speed = currentSpeedMph;
    if (speed <= 0) return 'N/A';
    return '${speed.toStringAsFixed(1)} mph';
  }

  // Get the total distance of the route in meters (for display purposes)
  double get totalDistanceMeters {
    // Check if we have a pre-calculated value
    if (metadata != null && 
        metadata!['routeDetails'] != null && 
        metadata!['routeDetails']['totalDistance'] != null) {
      final distance = metadata!['routeDetails']['totalDistance'];
      if (distance is num) {
        return distance.toDouble();
      }
    }
    
    // Calculate from waypoints if not in metadata
    if (waypoints.length >= 2) {
      double totalDistance = 0;
      for (int i = 0; i < waypoints.length - 1; i++) {
        final point1 = waypoints[i];
        final point2 = waypoints[i + 1];
        
        const double earthRadius = 6371000; // Earth radius in meters
        final lat1 = _degreesToRadians(point1.latitude);
        final lon1 = _degreesToRadians(point1.longitude);
        final lat2 = _degreesToRadians(point2.latitude);
        final lon2 = _degreesToRadians(point2.longitude);
        
        final dLat = lat2 - lat1;
        final dLon = lon2 - lon1;
        
        final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
                  math.cos(lat1) * math.cos(lat2) *
                  math.sin(dLon / 2) * math.sin(dLon / 2);
        final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
        
        totalDistance += earthRadius * c;
      }
      
      return totalDistance;
    }
    
    return 0;
  }
  
  // Get the total distance in miles
  double get totalDistanceMiles {
    return totalDistanceMeters / 1609.344;
  }
  
  // Format the total distance for display
  String get formattedTotalDistance {
    final miles = totalDistanceMiles;
    if (miles <= 0) return 'Calculating...';
    return '${miles.toStringAsFixed(1)} miles';
  }
}