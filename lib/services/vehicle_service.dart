import 'package:cateredtoyou/models/vehicle_model.dart'; // Importing the Vehicle model.
import 'package:cateredtoyou/services/organization_service.dart'; // Importing the OrganizationService.
import 'package:flutter/foundation.dart'; // Importing foundation for ChangeNotifier.
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore for database operations.
import 'package:firebase_auth/firebase_auth.dart'; // Importing FirebaseAuth for authentication.

class VehicleService extends ChangeNotifier { // Defining VehicleService class that extends ChangeNotifier.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Initializing Firestore instance.
  final FirebaseAuth _auth = FirebaseAuth.instance; // Initializing FirebaseAuth instance.
  final OrganizationService _organizationService; // Declaring OrganizationService instance.

  VehicleService(this._organizationService); // Constructor to initialize OrganizationService.

  Stream<List<Vehicle>> getVehicles() async* { // Method to get a stream of vehicles.
    try {
      final currentUser = _auth.currentUser; // Getting the current authenticated user.
      if (currentUser == null) { // If no user is authenticated.
        yield []; // Yield an empty list.
        return; // Return from the method.
      }

      final organization = await _organizationService.getCurrentUserOrganization(); // Get the user's organization.
      if (organization == null) { // If no organization is found.
        yield []; // Yield an empty list.
        return; // Return from the method.
      }

      yield* _firestore // Query Firestore for vehicles.
          .collection('vehicles') // Access the 'vehicles' collection.
          .where('organizationId', isEqualTo: organization.id) // Filter by organization ID.
          .snapshots() // Get real-time updates.
          .map((snapshot) => snapshot.docs // Map the snapshot to a list of vehicles.
              .map((doc) => Vehicle.fromMap(doc.data(), doc.id)) // Convert each document to a Vehicle object.
              .toList()); // Convert the iterable to a list.
    } catch (e) { // Catch any errors.
      debugPrint('Error getting vehicles: $e'); // Print the error.
      yield []; // Yield an empty list.
    }
  }

  Future<void> updateVehicleStatus(String vehicleId, VehicleStatus newStatus) async { // Method to update vehicle status.
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user.
      if (currentUser == null) throw 'Not authenticated'; // Throw an error if not authenticated.

      final vehicleDoc = await _firestore.collection('vehicles').doc(vehicleId).get(); // Get the vehicle document.
      if (!vehicleDoc.exists) throw 'Vehicle not found'; // Throw an error if vehicle not found.

      final Map<String, dynamic> updates = { // Create a map of updates.
        'status': newStatus.toString().split('.').last, // Update the status.
        'updatedAt': FieldValue.serverTimestamp(), // Update the timestamp.
      };

      // If marking as available, maintenance, or out of service, remove assigned driver
      if (newStatus == VehicleStatus.available || 
          newStatus == VehicleStatus.maintenance || 
          newStatus == VehicleStatus.outOfService) {
        updates['assignedDriverId'] = null; // Remove the assigned driver.
      }

      await vehicleDoc.reference.update(updates); // Update the vehicle document.
      notifyListeners(); // Notify listeners of the change.
    } catch (e) { // Catch any errors.
      debugPrint('Error updating vehicle status: $e'); // Print the error.
      rethrow; // Rethrow the error.
    }
  }

  Future<void> assignDriver(String vehicleId, String driverId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      // Check permissions
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) throw 'User not found';
      
      final userRole = userDoc.get('role') as String?;
      if (!['admin', 'manager', 'client'].contains(userRole)) {
        throw 'Insufficient permissions to assign driver';
      }

      // Check if the driver exists and belongs to the organization
      final driverDoc = await _firestore.collection('users').doc(driverId).get();
      if (!driverDoc.exists) throw 'Driver not found';

      final driverData = driverDoc.data();
      if (driverData == null || 
          driverData['organizationId'] != organization.id || 
          driverData['role'] != 'driver') {
        throw 'Invalid driver selected';
      }

      // Get the vehicle first to check its status
      final vehicleDoc = await _firestore.collection('vehicles').doc(vehicleId).get();
      if (!vehicleDoc.exists) throw 'Vehicle not found';
      
      final vehicleData = vehicleDoc.data()!;
      final currentStatus = vehicleData['status'] as String;

      // Only allow assigning driver if vehicle is available
      if (currentStatus != 'available') {
        throw 'Can only assign driver to available vehicles';
      }

      // Update vehicle with driver assignment
      final updates = {
        'assignedDriverId': driverId,
        'status': 'inUse',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('vehicles').doc(vehicleId).update(updates);

      notifyListeners();
    } catch (e) {
      debugPrint('Error assigning driver: $e');
      rethrow;
    }
  }

  Future<Vehicle> createVehicle({ // Method to create a new vehicle.
    required String model, // Required model parameter.
    required String make, // Required make parameter.
    required String year, // Required year parameter.
    required String licensePlate, // Required license plate parameter.
    required VehicleType type, // Required vehicle type parameter.
    String? assignedDriverId, // Optional assigned driver ID parameter.
  }) async {
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user.
      if (currentUser == null) throw 'Not authenticated'; // Throw an error if not authenticated.

      final organization = await _organizationService.getCurrentUserOrganization(); // Get the user's organization.
      if (organization == null) throw 'Organization not found'; // Throw an error if no organization found.

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get(); // Get the user document.

      if (!userDoc.exists) throw 'User data not found'; // Throw an error if user data not found.
      final userRole = userDoc.get('role') as String?; // Get the user's role.

      if (userRole == null || !['admin', 'client', 'manager'].contains(userRole)) { // Check if the user has sufficient permissions.
        throw 'Insufficient permissions to create vehicles'; // Throw an error if insufficient permissions.
      }

      final now = DateTime.now(); // Get the current date and time.
      final docRef = _firestore.collection('vehicles').doc(); // Create a new document reference.

      final vehicle = Vehicle( // Create a new Vehicle object.
        id: docRef.id, // Set the vehicle ID.
        organizationId: organization.id, // Set the organization ID.
        model: model.trim(), // Set the model.
        make: make.trim(), // Set the make.
        year: year.trim(), // Set the year.
        licensePlate: licensePlate.trim(), // Set the license plate.
        type: type, // Set the vehicle type.
        status: VehicleStatus.available, // Set the status to available.
        assignedDriverId: assignedDriverId, // Set the assigned driver ID.
        lastMaintenanceDate: now, // Set the last maintenance date.
        nextMaintenanceDate: now.add(const Duration(days: 90)), // Set the next maintenance date.
        createdAt: now, // Set the creation date.
        updatedAt: now, // Set the update date.
        createdBy: currentUser.uid, // Set the creator ID.
      );

      await docRef.set(vehicle.toMap()); // Save the vehicle to Firestore.
      notifyListeners(); // Notify listeners of the change.
      return vehicle; // Return the created vehicle.
    } catch (e) { // Catch any errors.
      debugPrint('Error creating vehicle: $e'); // Print the error.
      rethrow; // Rethrow the error.
    }
  }

  Future<void> updateVehicle(Vehicle vehicle) async { // Method to update a vehicle.
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user.
      if (currentUser == null) throw 'Not authenticated'; // Throw an error if not authenticated.

      final organization = await _organizationService.getCurrentUserOrganization(); // Get the user's organization.
      if (organization == null) throw 'Organization not found'; // Throw an error if no organization found.

      if (vehicle.organizationId != organization.id) { // Check if the vehicle belongs to the user's organization.
        throw 'Vehicle belongs to a different organization'; // Throw an error if vehicle belongs to a different organization.
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get(); // Get the user document.

      if (!userDoc.exists) throw 'User data not found'; // Throw an error if user data not found.
      final userRole = userDoc.get('role') as String?; // Get the user's role.

      if (userRole == null || !['admin', 'client', 'manager'].contains(userRole)) { // Check if the user has sufficient permissions.
        throw 'Insufficient permissions to update vehicles'; // Throw an error if insufficient permissions.
      }

      await _firestore
          .collection('vehicles')
          .doc(vehicle.id)
          .update(vehicle.toMap()); // Update the vehicle document.

      notifyListeners(); // Notify listeners of the change.
    } catch (e) { // Catch any errors.
      debugPrint('Error updating vehicle: $e'); // Print the error.
      rethrow; // Rethrow the error.
    }
  }

  Future<void> updateTelematicsData(String vehicleId, Map<String, dynamic> data) async { // Method to update telematics data.
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user.
      if (currentUser == null) throw 'Not authenticated'; // Throw an error if not authenticated.

      final vehicleDoc = await _firestore
          .collection('vehicles')
          .doc(vehicleId)
          .get(); // Get the vehicle document.

      if (!vehicleDoc.exists) throw 'Vehicle not found'; // Throw an error if vehicle not found.

      await vehicleDoc.reference.update({ // Update the vehicle document.
        'telematicsData': data, // Update the telematics data.
        'updatedAt': FieldValue.serverTimestamp(), // Update the timestamp.
      });

      notifyListeners(); // Notify listeners of the change.
    } catch (e) { // Catch any errors.
      debugPrint('Error updating telematics data: $e'); // Print the error.
      rethrow; // Rethrow the error.
    }
  }
}