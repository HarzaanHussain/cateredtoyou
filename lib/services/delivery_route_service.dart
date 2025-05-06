import 'package:cateredtoyou/views/delivery/widgets/delivery_progress.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:cateredtoyou/services/organization_service.dart';
import 'package:cateredtoyou/models/delivery_route_model.dart';
import 'package:cateredtoyou/services/role_permissions.dart';

class DeliveryRouteService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OrganizationService _organizationService;
  final RolePermissions _rolePermissions;

  DeliveryRouteService(this._organizationService, this._rolePermissions);

  // Helper method to calculate distance between two points using Haversine formula

  // Helper math functions
  double sin(double rad) => math.sin(rad);
  double cos(double rad) => math.cos(rad);
  double asin(double value) => math.asin(value.clamp(-1.0, 1.0));
  double sqrt(double value) => value > 0 ? math.sqrt(value) : 0.0;

  // Get all delivery routes for the organization
  Stream<List<DeliveryRoute>> getDeliveryRoutes() async* {
    try {
      final organization =
          await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        yield [];
        return;
      }

      yield* _firestore
          .collection('delivery_routes')
          .where('organizationId', isEqualTo: organization.id)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => DeliveryRoute.fromMap(doc.data(), doc.id))
              .toList());
    } catch (e) {
      debugPrint('Error getting delivery routes: $e');
      yield [];
    }
  }

  // Get active deliveries for a specific driver
  Stream<List<DeliveryRoute>> getDriverRoutes(String driverId) async* {
    try {
      final organization =
          await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        yield [];
        return;
      }

      yield* _firestore
          .collection('delivery_routes')
          .where('organizationId', isEqualTo: organization.id)
          .where(Filter.or(
            Filter('driverId', isEqualTo: driverId),
            Filter('currentDriver', isEqualTo: driverId),
          ))
          .where('status', whereIn: ['pending', 'in_progress'])
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => DeliveryRoute.fromMap(doc.data(), doc.id))
              .toList());
    } catch (e) {
      debugPrint('Error getting driver routes: $e');
      yield [];
    }
  }

  // Get deliveries that the current user can access as a driver
Stream<List<DeliveryRoute>> getAccessibleDriverRoutes() async* {
  try {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      yield [];
      return;
    }

    final organization = await _organizationService.getCurrentUserOrganization();
    if (organization == null) {
      yield [];
      return;
    }

    // Permission check
    final hasViewPermission = await _rolePermissions.hasPermission('view_deliveries');

    if (hasViewPermission) {
      // Management users see all deliveries
      yield* _firestore
          .collection('delivery_routes')
          .where('organizationId', isEqualTo: organization.id)
          .where('status', whereIn: ['pending', 'in_progress'])
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => DeliveryRoute.fromMap(doc.data(), doc.id))
              .toList());
    } else {
      // Simple solution: ONLY show deliveries where currentDriver matches the user ID
      // This is the cleanest approach and avoids filter logic issues
      yield* _firestore
          .collection('delivery_routes')
          .where('organizationId', isEqualTo: organization.id)
          .where('currentDriver', isEqualTo: currentUser.uid)
          .where('status', whereIn: ['pending', 'in_progress'])
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => DeliveryRoute.fromMap(doc.data(), doc.id))
              .toList());
    }
  } catch (e) {
    debugPrint('Error getting accessible driver routes: $e');
    yield [];
  }
}

  // Initialize route metrics when creating a new route
  Future<void> initializeRouteMetrics(String routeId) async {
    try {
      final routeDoc =
          await _firestore.collection('delivery_routes').doc(routeId).get();
      if (!routeDoc.exists) return;

      final route = DeliveryRoute.fromMap(routeDoc.data()!, routeId);

      // Only initialize if metrics don't already exist
      if (route.metadata != null &&
          route.metadata!['routeDetails'] != null &&
          route.metadata!['routeDetails']['totalDistance'] != null) {
        return; // Already initialized
      }

      // Ensure we have waypoints
      if (route.waypoints.isEmpty || route.waypoints.length < 2) return;

      // Calculate total route distance
      final totalDistance =
          DeliveryProgress.calculateTotalRouteDistance(route.waypoints);

      // Estimate duration using average speed of 13.4 m/s (30 mph)
      const averageSpeed = 13.4; // m/s
      final estimatedDuration = (totalDistance / averageSpeed).round();

      // Calculate ETA based on start time and estimated duration
      final eta = route.startTime.add(Duration(seconds: estimatedDuration));

      await _firestore.collection('delivery_routes').doc(routeId).update({
        'metadata.routeDetails.totalDistance': totalDistance,
        'metadata.routeDetails.originalDuration': estimatedDuration,
        'metadata.routeDetails.progress':
            route.status == 'pending' ? 0.0 : 0.05,
        'metadata.routeDetails.calculatedAt': FieldValue.serverTimestamp(),
        'estimatedEndTime': Timestamp.fromDate(eta),
      });

      debugPrint(
          '📊 Initialized route metrics: Total distance: ${(totalDistance / 1609.344).toStringAsFixed(2)} miles, Estimated duration: ${(estimatedDuration / 60).toStringAsFixed(0)} minutes');
    } catch (e) {
      debugPrint('Error initializing route metrics: $e');
    }
  }

  // Create a new delivery route (requires manage_deliveries permission)
  Future<DeliveryRoute> createDeliveryRoute({
    required String eventId,
    required String vehicleId,
    required String driverId,
    required DateTime startTime,
    required DateTime estimatedEndTime,
    required List<GeoPoint> waypoints,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'Not authenticated';
      }

      // Check if user has permission to manage deliveries
      final hasPermission =
          await _rolePermissions.hasPermission('manage_deliveries');
      if (!hasPermission) {
        throw 'You do not have permission to create delivery routes';
      }

      final organization =
          await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found';
      }

      // Verify event exists
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) {
        throw 'Event not found';
      }

      final now = DateTime.now();
      final docRef = _firestore.collection('delivery_routes').doc();

      // Create full route data that matches security rules requirements
      final routeData = {
        'eventId': eventId,
        'vehicleId': vehicleId,
        'driverId': driverId,
        'currentDriver':
            driverId, // Initially set current driver same as original driver
        'organizationId': organization.id,
        'startTime': Timestamp.fromDate(startTime),
        'estimatedEndTime': Timestamp.fromDate(estimatedEndTime),
        'actualEndTime': null,
        'waypoints': waypoints,
        'status': 'pending',
        'createdBy': currentUser.uid,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'metadata': {
          ...?metadata,
          'createdBy': currentUser.uid,
          'eventName': eventDoc.data()?['name'],
          'updatedBy': currentUser.uid,
          'updatedAt': now,
        }
      };

      // Create route document
      await docRef.set(routeData);

      // Update vehicle status in separate operation
      await _firestore.collection('vehicles').doc(vehicleId).update({
        'status': 'in_use',
        'currentDeliveryId': docRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': currentUser.uid,
      });

      return DeliveryRoute.fromMap(routeData, docRef.id);
    } catch (e) {
      debugPrint('Error creating delivery route: $e');
      rethrow;
    }
  }

  // Update route status (can be done by any user if they're the active driver)
  Future<void> updateRouteStatus(String routeId, String newStatus) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'Not authenticated';
      }

      final routeDoc =
          await _firestore.collection('delivery_routes').doc(routeId).get();
      if (!routeDoc.exists) {
        throw 'Route not found';
      }

      final route = DeliveryRoute.fromMap(routeDoc.data()!, routeId);

      // Check if user has permission to manage_deliveries or if they are the active driver
      final hasManagePermission =
          await _rolePermissions.hasPermission('manage_deliveries');

      // Allow update if user has manage_deliveries permission OR is the active driver
      if (!hasManagePermission && !route.isActiveDriver(currentUser.uid)) {
        throw 'Only the assigned driver or managers can update this route';
      }

      final updateData = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'in_progress') {
        // If starting the delivery, record the actual start time
        updateData['actualStartTime'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'completed') {
        // If the new status is 'completed'
        updateData['actualEndTime'] = FieldValue.serverTimestamp();
        updateData['metadata.completedAt'] = FieldValue.serverTimestamp();

        // Store the completing driver's ID (might be different from original)
        updateData['metadata.completedBy'] = currentUser.uid;
      }

      await _firestore
          .collection('delivery_routes')
          .doc(routeId)
          .update(updateData);

      // If completed, update vehicle status
      if (newStatus == 'completed') {
        await _firestore.collection('vehicles').doc(route.vehicleId).update({
          'status': 'available',
          'currentDeliveryId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating route status: $e');
      rethrow;
    }
  }

  // Reassign a delivery to a different driver (requires manage_deliveries permission)
  Future<void> reassignDriver(String routeId, String newDriverId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'Not authenticated';
      }

      // Check if user has permission to manage deliveries
      final hasPermission =
          await _rolePermissions.hasPermission('manage_deliveries');
      if (!hasPermission) {
        throw 'You do not have permission to reassign deliveries';
      }

      final routeDoc =
          await _firestore.collection('delivery_routes').doc(routeId).get();
      if (!routeDoc.exists) {
        throw 'Route not found';
      }

      final now = Timestamp.now();

      await _firestore.collection('delivery_routes').doc(routeId).update({
        'currentDriver': newDriverId,
        'updatedAt': FieldValue.serverTimestamp(),
        'metadata.driverReassignments': FieldValue.arrayUnion([
          {
            'timestamp':
                now, // Use the local timestamp instead of serverTimestamp()
            'previousDriver': routeDoc.data()?['currentDriver'] ??
                routeDoc.data()?['driverId'],
            'newDriver': newDriverId,
            'reassignedBy': currentUser.uid,
          }
        ]),
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error reassigning driver: $e');
      rethrow;
    }
  }

  // Update route progress details based on current location
  Future<void> updateDriverLocation(String routeId, GeoPoint location,
      {double? heading, double? speed}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final routeDoc =
          await _firestore.collection('delivery_routes').doc(routeId).get();
      if (!routeDoc.exists) throw 'Route not found';

      final route = DeliveryRoute.fromMap(routeDoc.data()!, routeId);

      // Check if user is the active driver
      if (!route.isActiveDriver(currentUser.uid)) {
        throw 'You must be assigned to this delivery to update its location';
      }

      // Only update location if delivery is in progress
      if (route.status != 'in_progress') {
        throw 'Delivery must be in progress to update location';
      }

      // ALWAYS UPDATE - No filtering of small changes
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
        updateData['metadata.currentSpeed'] = speed;
      }

      await _firestore
          .collection('delivery_routes')
          .doc(routeId)
          .update(updateData);

      // Calculate and update route progress details in a separate operation
      _updateProgressDetails(routeId, location);

      debugPrint(
          '🚚 DRIVER LOCATION UPDATED: ${location.latitude}, ${location.longitude}');
    } catch (e) {
      debugPrint('Error updating driver location: $e');
      rethrow;
    }
  }

  // Calculate and update progress metrics
  Future<void> _updateProgressDetails(
      String routeId, GeoPoint currentLocation) async {
    try {
      final routeDoc =
          await _firestore.collection('delivery_routes').doc(routeId).get();
      if (!routeDoc.exists) return;

      final route = DeliveryRoute.fromMap(routeDoc.data()!, routeId);

      // Only calculate details if we have waypoints
      if (route.waypoints.isEmpty || route.waypoints.length < 2) return;

      final destination = route.waypoints.last;

      try {
        // Calculate total route distance if not already calculated
        double totalRouteDistance = 0;

        if (route.metadata != null &&
            route.metadata!['routeDetails'] != null &&
            route.metadata!['routeDetails']['totalDistance'] != null) {
          totalRouteDistance =
              (route.metadata!['routeDetails']['totalDistance'] as num)
                  .toDouble();
        } else {
          // Calculate from waypoints
          totalRouteDistance =
              DeliveryProgress.calculateTotalRouteDistance(route.waypoints);
        }

        // Ensure we have a valid total distance
        if (totalRouteDistance <= 0) {
          totalRouteDistance = 1000; // Default to 1km if calculation fails
        }

        // Calculate remaining distance using Haversine formula
        final remainingDistance = DeliveryProgress.calculateRemainingDistance(
            currentLocation, destination);

        // Ensure we have a non-negative remaining distance
        final safeRemainingDistance =
            remainingDistance < 0 ? 0 : remainingDistance;

        // Estimate remaining time based on current speed or average speed
        final currentSpeed =
            (route.metadata?['currentSpeed'] as num? ?? 10.0).toDouble();
        // Ensure we have a reasonable speed value (at least 0.1 m/s)
        final safeSpeed = currentSpeed < 0.1 ? 10.0 : currentSpeed;

        // Calculate estimated time safely
        double estimatedTimeInSeconds;
        if (safeRemainingDistance <= 0) {
          estimatedTimeInSeconds = 0;
        } else {
          final rawEstimatedTime = safeRemainingDistance / safeSpeed;
          // Verify result is a finite number
          if (rawEstimatedTime.isFinite && !rawEstimatedTime.isNaN) {
            estimatedTimeInSeconds = rawEstimatedTime.clamp(0.0, 3600.0);
          } else {
            estimatedTimeInSeconds =
                600.0; // Default to 10 minutes if calculation failed
          }
        }

        // Calculate progress as percentage of completion
        double progress = 0.0;
        if (totalRouteDistance > 0) {
          // Safety check for division
          if (safeRemainingDistance <= totalRouteDistance) {
            final rawProgress =
                1.0 - (safeRemainingDistance / totalRouteDistance);
            // Verify the result is valid
            progress = rawProgress.isFinite && !rawProgress.isNaN
                ? rawProgress.clamp(0.0, 1.0)
                : 0.5; // Default to 50% if calculation failed
          } else {
            progress = 0.1; // Default to 10% progress
          }
        }

        // Determine traffic conditions
        String trafficCondition = "Normal";
        if (route.metadata != null &&
            route.metadata!['routeDetails'] != null &&
            route.metadata!['routeDetails']['originalDuration'] != null) {
          final originalDuration =
              (route.metadata!['routeDetails']['originalDuration'] as num)
                  .toDouble();

          // Check for positive original duration to avoid division by zero
          if (originalDuration > 0) {
            // Safely calculate ratio
            final ratio = estimatedTimeInSeconds / originalDuration;

            // Verify the result is valid
            if (ratio.isFinite && !ratio.isNaN) {
              if (ratio > 1.5) {
                trafficCondition = "Heavy";
              } else if (ratio > 1.2) {
                trafficCondition = "Moderate";
              } else if (ratio < 0.8) {
                trafficCondition = "Light";
              }
            }
          }
        }

        // Calculate ETA
        final now = DateTime.now();
        final eta = now.add(Duration(seconds: estimatedTimeInSeconds.round()));

        // Update Firestore with the calculated values
        await _firestore.collection('delivery_routes').doc(routeId).update({
          'metadata.routeDetails.remainingDistance': safeRemainingDistance,
          'metadata.routeDetails.totalDistance': totalRouteDistance,
          'metadata.routeDetails.estimatedTimeRemaining':
              estimatedTimeInSeconds.round(),
          'metadata.routeDetails.progress': progress,
          'metadata.routeDetails.lastProgressUpdate':
              FieldValue.serverTimestamp(),
          'metadata.routeDetails.estimatedArrival': Timestamp.fromDate(eta),
          'metadata.routeDetails.traffic': trafficCondition,
          'estimatedEndTime': Timestamp.fromDate(eta),
        });

        // Log the update with detailed information
        debugPrint('📊 Updated ETA: ${DateFormat('h:mm a').format(eta)}, '
            'Distance: ${(safeRemainingDistance / 1609.344).toStringAsFixed(2)} miles, '
            'Progress: ${(progress * 100).toStringAsFixed(1)}%');
      } catch (e) {
        debugPrint('Error calculating route progress: $e');
      }
    } catch (e) {
      debugPrint('Error updating progress details: $e');
    }
  }

  // Update estimated arrival time (requires manage_deliveries permission)
  Future<void> updateEstimatedTime(
      String routeId, DateTime newEstimatedTime) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'Not authenticated';
      }

      // Check if user has permission to manage deliveries
      final hasPermission =
          await _rolePermissions.hasPermission('manage_deliveries');
      if (!hasPermission) {
        throw 'You do not have permission to update delivery times';
      }

      final routeDoc =
          await _firestore.collection('delivery_routes').doc(routeId).get();
      if (!routeDoc.exists) {
        throw 'Route not found';
      }

      await routeDoc.reference.update({
        'estimatedEndTime': Timestamp.fromDate(newEstimatedTime),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating estimated time: $e');
      rethrow;
    }
  }

  // Cancel a delivery route (requires manage_deliveries permission)
  Future<void> cancelRoute(String routeId, {String? reason}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'Not authenticated';
      }

      // Check if user has permission to manage deliveries
      final hasPermission =
          await _rolePermissions.hasPermission('manage_deliveries');
      if (!hasPermission) {
        throw 'You do not have permission to cancel deliveries';
      }

      final routeDoc =
          await _firestore.collection('delivery_routes').doc(routeId).get();
      if (!routeDoc.exists) {
        throw 'Route not found';
      }

      final route = DeliveryRoute.fromMap(routeDoc.data()!, routeId);

      await _firestore.runTransaction((transaction) async {
        // Update route status
        transaction.update(routeDoc.reference, {
          'status': 'cancelled',
          'metadata': {
            ...route.metadata ?? {},
            'cancellationReason': reason,
            'cancelledAt': FieldValue.serverTimestamp(),
            'cancelledBy': currentUser.uid,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update vehicle status
        transaction.update(
          _firestore.collection('vehicles').doc(route.vehicleId),
          {
            'status': 'available',
            'currentDeliveryId': null,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error canceling route: $e');
      rethrow;
    }
  }
}
