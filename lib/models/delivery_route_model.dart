import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore package to use Firestore related classes like Timestamp and GeoPoint

class DeliveryRoute {
  final String id; // Unique identifier for the delivery route
  final String eventId; // Identifier for the associated event
  final String vehicleId; // Identifier for the vehicle used in the delivery
  final String driverId; // Identifier for the driver assigned to the delivery
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
    return DeliveryRoute(
      id: docId, // Setting id from the document ID
      eventId: map['eventId'] ?? '', // Extracting eventId from the map, defaulting to an empty string if null
      vehicleId: map['vehicleId'] ?? '', // Extracting vehicleId from the map, defaulting to an empty string if null
      driverId: map['driverId'] ?? '', // Extracting driverId from the map, defaulting to an empty string if null
      organizationId: map['organizationId'] ?? '', // Extracting organizationId from the map, defaulting to an empty string if null
      startTime: (map['startTime'] as Timestamp).toDate(), // Converting Firestore Timestamp to DateTime for startTime
      estimatedEndTime: (map['estimatedEndTime'] as Timestamp).toDate(), // Converting Firestore Timestamp to DateTime for estimatedEndTime
      actualEndTime: map['actualEndTime'] != null 
          ? (map['actualEndTime'] as Timestamp).toDate() // Converting Firestore Timestamp to DateTime for actualEndTime if not null
          : null,
      waypoints: List<GeoPoint>.from(map['waypoints'] ?? []), // Extracting waypoints from the map, defaulting to an empty list if null
      status: map['status'] ?? 'pending', // Extracting status from the map, defaulting to 'pending' if null
      currentLocation: map['currentLocation'] as GeoPoint?, // Extracting currentLocation from the map, nullable
      currentHeading: map['currentHeading']?.toDouble(), // Extracting currentHeading from the map and converting to double, nullable
      dropoffInstructions: map['dropoffInstructions'] as Map<String, dynamic>?, // Extracting dropoffInstructions from the map, nullable
      assignedZone: map['assignedZone'] as String?, // Extracting assignedZone from the map, nullable
      routeOptimizationData: map['routeOptimizationData'] as Map<String, dynamic>?, // Extracting routeOptimizationData from the map, nullable
      metadata: map['metadata'] as Map<String, dynamic>?, // Extracting metadata from the map, nullable
      createdAt: (map['createdAt'] as Timestamp).toDate(), // Converting Firestore Timestamp to DateTime for createdAt
      updatedAt: (map['updatedAt'] as Timestamp).toDate(), // Converting Firestore Timestamp to DateTime for updatedAt
    );
  }

  DeliveryRoute copyWith({
    String? eventId, // Optional parameter for eventId
    String? vehicleId, // Optional parameter for vehicleId
    String? driverId, // Optional parameter for driverId
    DateTime? startTime, // Optional parameter for startTime
    DateTime? estimatedEndTime, // Optional parameter for estimatedEndTime
    DateTime? actualEndTime, // Optional parameter for actualEndTime
    List<GeoPoint>? waypoints, // Optional parameter for waypoints
    String? status, // Optional parameter for status
    GeoPoint? currentLocation, // Optional parameter for currentLocation
    double? currentHeading, // Optional parameter for currentHeading
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
}