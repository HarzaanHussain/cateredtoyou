import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore package for database operations
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth package for authentication
import 'package:flutter/foundation.dart'; // Import foundation package for ChangeNotifier
import 'dart:math' as math; // Import math package for trigonometric functions with alias
import 'package:cateredtoyou/services/organization_service.dart'; // Import custom OrganizationService
import 'package:cateredtoyou/models/delivery_route_model.dart'; // Import custom DeliveryRoute model

class DeliveryRouteService extends ChangeNotifier { // Define a service class extending ChangeNotifier
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance for database operations
  final FirebaseAuth _auth = FirebaseAuth.instance; // Firebase Auth instance for authentication
  final OrganizationService _organizationService; // OrganizationService instance for organization-related operations

  DeliveryRouteService(this._organizationService); // Constructor to initialize OrganizationService

  // Helper method to calculate distance between two points using Haversine formula
  double _calculateDistance(
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

  // Helper math functions
  double _square(double value) => value * value;
  double _degreesToRadians(double degrees) => degrees * (3.14159 / 180.0);
  double sin(double rad) => math.sin(rad);
  double cos(double rad) => math.cos(rad);
  double asin(double value) => math.asin(value.clamp(-1.0, 1.0));
  double sqrt(double value) => value > 0 ? math.sqrt(value) : 0.0;

  // Get all delivery routes for the organization
  Stream<List<DeliveryRoute>> getDeliveryRoutes() async* { // Method to get delivery routes as a stream
    try {
      final organization = await _organizationService.getCurrentUserOrganization(); // Get current user's organization
      if (organization == null) { // Check if organization is null
        yield []; // Yield an empty list if no organization
        return; // Return early
      }

      yield* _firestore
          .collection('delivery_routes') // Access 'delivery_routes' collection
          .where('organizationId', isEqualTo: organization.id) // Filter by organization ID
          .snapshots() // Get real-time updates
          .map((snapshot) => snapshot.docs
              .map((doc) => DeliveryRoute.fromMap(doc.data(), doc.id)) // Map documents to DeliveryRoute objects
              .toList()); // Convert to list
    } catch (e) {
      debugPrint('Error getting delivery routes: $e'); // Print error message
      yield []; // Yield an empty list on error
    }
  }

  // Get active deliveries for a specific driver
  Stream<List<DeliveryRoute>> getDriverRoutes(String driverId) async* { // Method to get driver-specific routes as a stream
    try {
      final organization = await _organizationService.getCurrentUserOrganization(); // Get current user's organization
      if (organization == null) { // Check if organization is null
        yield []; // Yield an empty list if no organization
        return; // Return early
      }

      yield* _firestore
          .collection('delivery_routes') // Access 'delivery_routes' collection
          .where('driverId', isEqualTo: driverId) // Filter by driver ID
          .where('organizationId', isEqualTo: organization.id) // Filter by organization ID
          .where('status', whereIn: ['pending', 'in_progress']) // Filter by status
          .snapshots() // Get real-time updates
          .map((snapshot) => snapshot.docs
              .map((doc) => DeliveryRoute.fromMap(doc.data(), doc.id)) // Map documents to DeliveryRoute objects
              .toList()); // Convert to list
    } catch (e) {
      debugPrint('Error getting driver routes: $e'); // Print error message
      yield []; // Yield an empty list on error
    }
  }

  // Create a new delivery route
  Future<DeliveryRoute> createDeliveryRoute({
    required String eventId, // Event ID
    required String vehicleId, // Vehicle ID
    required String driverId, // Driver ID
    required DateTime startTime, // Start time
    required DateTime estimatedEndTime, // Estimated end time
    required List<GeoPoint> waypoints, // List of waypoints
    Map<String, dynamic>? metadata, // Optional metadata
  }) async {
    try {
      final currentUser = _auth.currentUser; // Get current authenticated user
      if (currentUser == null) throw 'Not authenticated'; // Throw error if not authenticated

      final organization = await _organizationService.getCurrentUserOrganization(); // Get current user's organization
      if (organization == null) throw 'Organization not found'; // Throw error if organization not found

      // Verify event exists
      final eventDoc = await _firestore.collection('events').doc(eventId).get(); // Get event document
      if (!eventDoc.exists) throw 'Event not found'; // Throw error if event not found

      final now = DateTime.now(); // Get current time
      final docRef = _firestore.collection('delivery_routes').doc(); // Create a new document reference

      // Create full route data that matches security rules requirements
      final routeData = {
        'eventId': eventId, // Event ID
        'vehicleId': vehicleId, // Vehicle ID
        'driverId': driverId, // Driver ID
        'organizationId': organization.id, // Organization ID
        'startTime': Timestamp.fromDate(startTime), // Start time as Timestamp
        'estimatedEndTime': Timestamp.fromDate(estimatedEndTime), // Estimated end time as Timestamp
        'waypoints': waypoints, // List of waypoints
        'status': 'pending', // Initial status
        'createdBy': currentUser.uid, // Created by user ID
        'createdAt': Timestamp.fromDate(now), // Creation time
        'updatedAt': Timestamp.fromDate(now), // Update time
        'metadata': {
          ...?metadata, // Spread optional metadata
          'createdBy': currentUser.uid, // Created by user ID
          'eventName': eventDoc.data()?['name'], // Event name
          'updatedBy': currentUser.uid, // Updated by user ID
          'updatedAt': now, // Update time
        }
      };

      // Create route document
      await docRef.set(routeData); // Set document data

      // Update vehicle status in separate operation
      await _firestore.collection('vehicles').doc(vehicleId).update({
        'status': 'in_use', // Update vehicle status
        'currentDeliveryId': docRef.id, // Set current delivery ID
        'updatedAt': FieldValue.serverTimestamp(), // Update time
        'updatedBy': currentUser.uid, // Updated by user ID
      });

      return DeliveryRoute.fromMap(routeData, docRef.id); // Return created DeliveryRoute object
    } catch (e) {
      debugPrint('Error creating delivery route: $e'); // Print error message
      rethrow; // Rethrow error
    }
  }

  // Update route status
 Future<void> updateRouteStatus(String routeId, String newStatus) async { // Method to update the status of a delivery route
    try {
      final currentUser = _auth.currentUser; // Get current authenticated user
      if (currentUser == null) throw 'Not authenticated'; // Throw error if not authenticated

      final routeDoc = await _firestore.collection('delivery_routes').doc(routeId).get(); // Get route document
      if (!routeDoc.exists) throw 'Route not found'; // Throw error if route not found

      final route = DeliveryRoute.fromMap(routeDoc.data()!, routeId); // Convert document data to DeliveryRoute object

      // Check if user is the assigned driver
      if (route.driverId != currentUser.uid) {
        throw 'Only the assigned driver can update this route'; // Throw error if user is not the assigned driver
      }

      final updateData = {
        'status': newStatus, // Update status
        'updatedAt': FieldValue.serverTimestamp(), // Update time
      };

      if (newStatus == 'in_progress') {
        // If starting the delivery, record the actual start time
        updateData['actualStartTime'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'completed') { // If the new status is 'completed'
        updateData['actualEndTime'] = FieldValue.serverTimestamp(); // Set actual end time
        updateData['metadata.completedAt'] = FieldValue.serverTimestamp(); // Set completion time in metadata
      }

      await _firestore.collection('delivery_routes').doc(routeId).update(updateData); // Update route document with new data

      // If completed, update vehicle status
      if (newStatus == 'completed') {
        await _firestore.collection('vehicles').doc(route.vehicleId).update({
          'status': 'available', // Update vehicle status to available
          'currentDeliveryId': null, // Clear current delivery ID
          'updatedAt': FieldValue.serverTimestamp(), // Update time
        });
      }

      notifyListeners(); // Notify listeners of changes
    } catch (e) {
      debugPrint('Error updating route status: $e'); // Print error message
      rethrow; // Rethrow error
    }
  }
  // Update route progress details based on current location
   Future<void> updateDriverLocation(String routeId, GeoPoint location, {double? heading, double? speed}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final routeDoc = await _firestore.collection('delivery_routes').doc(routeId).get();
      if (!routeDoc.exists) throw 'Route not found';

      final route = DeliveryRoute.fromMap(routeDoc.data()!, routeId);

      // Check if user is the assigned driver
      if (route.driverId != currentUser.uid) {
        throw 'Only the assigned driver can update this route';
      }

      // Only update location if delivery is in progress
      if (route.status != 'in_progress') {
        throw 'Delivery must be in progress to update location';
      }

      final updateData = {
        'currentLocation': location,
        'updatedAt': FieldValue.serverTimestamp(),
        'metadata.lastLocationUpdate': FieldValue.serverTimestamp(),
      };

      // Add optional parameters if provided
      if (heading != null) {
        updateData['currentHeading'] = heading;
      }
      
      if (speed != null) {
        updateData['currentSpeed'] = speed;
      }

      await _firestore.collection('delivery_routes').doc(routeId).update(updateData);
      
      // Calculate and update route progress details
      await _updateProgressDetails(routeId, location);
    } catch (e) {
      debugPrint('Error updating driver location: $e');
      rethrow;
    }
  }
 // Calculate and update progress metrics for a delivery
  Future<void> _updateProgressDetails(String routeId, GeoPoint currentLocation) async {
    try {
      final routeDoc = await _firestore.collection('delivery_routes').doc(routeId).get();
      if (!routeDoc.exists) return;
      
      final route = DeliveryRoute.fromMap(routeDoc.data()!, routeId);
      
      // Calculate remaining distance to destination
      if (route.waypoints.length < 2) return;
      
      final destination = route.waypoints.last;
      
      try {
        // Simple direct distance calculation (in a real app, you would use a routing API)
        final remainingDistance = _calculateDistance(
          currentLocation.latitude,
          currentLocation.longitude,
          destination.latitude,
          destination.longitude
        ) * 1000; // Convert to meters
        
        // Estimate remaining time based on current speed or average speed
        final currentSpeed = route.metadata?['currentSpeed'] ?? 10.0; // Default to 10 m/s (~22 mph)
        final estimatedTimeInSeconds = (remainingDistance / currentSpeed).round();
        
        // Progress as percentage of completion (rough estimate)
        final totalDistance = route.metadata?['routeDetails']?['totalDistance'] as num? ?? 0;
        final progress = totalDistance > 0 
          ? 1.0 - (remainingDistance / totalDistance) 
          : 0.0;
        
        // Clamp progress to valid range
        final validProgress = progress.clamp(0.0, 1.0);
        
        await _firestore.collection('delivery_routes').doc(routeId).update({
          'metadata.routeDetails.remainingDistance': remainingDistance,
          'metadata.routeDetails.estimatedTimeRemaining': estimatedTimeInSeconds,
          'metadata.routeDetails.progress': validProgress,
          'metadata.routeDetails.lastProgressUpdate': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error calculating route progress: $e');
      }
    } catch (e) {
      debugPrint('Error updating progress details: $e');
    }
  }
  

  // Update estimated arrival time
  Future<void> updateEstimatedTime(String routeId, DateTime newEstimatedTime) async {
    try {
      final currentUser = _auth.currentUser; // Get current authenticated user
      if (currentUser == null) throw 'Not authenticated'; // Throw error if not authenticated

      final routeDoc = await _firestore.collection('delivery_routes').doc(routeId).get(); // Get route document
      if (!routeDoc.exists) throw 'Route not found'; // Throw error if route not found

      await routeDoc.reference.update({
        'estimatedEndTime': Timestamp.fromDate(newEstimatedTime), // Update estimated end time
        'updatedAt': FieldValue.serverTimestamp(), // Update time
      });

      notifyListeners(); // Notify listeners of changes
    } catch (e) {
      debugPrint('Error updating estimated time: $e'); // Print error message
      rethrow; // Rethrow error
    }
  }

  // Cancel a delivery route
  Future<void> cancelRoute(String routeId, {String? reason}) async {
    try {
      final routeDoc = await _firestore.collection('delivery_routes').doc(routeId).get(); // Get route document
      if (!routeDoc.exists) throw 'Route not found'; // Throw error if route not found

      final route = DeliveryRoute.fromMap(routeDoc.data()!, routeId); // Convert document data to DeliveryRoute object

      await _firestore.runTransaction((transaction) async {
        // Update route status
        transaction.update(routeDoc.reference, {
          'status': 'cancelled', // Update status to cancelled
          'metadata': {
            ...route.metadata ?? {}, // Spread existing metadata
            'cancellationReason': reason, // Add cancellation reason
            'cancelledAt': FieldValue.serverTimestamp(), // Cancellation time
          },
          'updatedAt': FieldValue.serverTimestamp(), // Update time
        });

        // Update vehicle status
        transaction.update(
          _firestore.collection('vehicles').doc(route.vehicleId), // Get vehicle document
          {
            'status': 'available', // Update vehicle status
            'currentDeliveryId': null, // Clear current delivery ID
            'updatedAt': FieldValue.serverTimestamp(), // Update time
          },
        );
      });

      notifyListeners(); // Notify listeners of changes
    } catch (e) {
      debugPrint('Error canceling route: $e'); // Print error message
      rethrow; // Rethrow error
    }
  }
    
}



