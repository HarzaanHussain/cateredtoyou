import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore package for database operations
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth package for authentication
import 'package:flutter/foundation.dart'; // Import foundation package for ChangeNotifier
import 'package:cateredtoyou/services/organization_service.dart'; // Import custom OrganizationService
import 'package:cateredtoyou/models/delivery_route_model.dart'; // Import custom DeliveryRoute model

class DeliveryRouteService extends ChangeNotifier { // Define a service class extending ChangeNotifier
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance for database operations
  final FirebaseAuth _auth = FirebaseAuth.instance; // Firebase Auth instance for authentication
  final OrganizationService _organizationService; // OrganizationService instance for organization-related operations

  DeliveryRouteService(this._organizationService); // Constructor to initialize OrganizationService

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

      if (newStatus == 'completed') { // If the new status is 'completed'
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