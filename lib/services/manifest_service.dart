import 'package:cateredtoyou/models/manifest_model.dart'; // Importing the manifest model
import 'package:cateredtoyou/services/organization_service.dart'; // Importing the OrganizationService
import 'package:flutter/foundation.dart'; // Importing foundation for ChangeNotifier
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore for database operations
import 'package:firebase_auth/firebase_auth.dart'; // Importing FirebaseAuth for authentication

class ManifestService extends ChangeNotifier { // Defining manifestService class that extends ChangeNotifier
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Initializing Firestore instance
  final FirebaseAuth _auth = FirebaseAuth.instance; // Initializing FirebaseAuth instance
  final OrganizationService _organizationService; // Declaring OrganizationService instance

  ManifestService(this._organizationService); // Constructor to initialize OrganizationService

  Stream<List<Manifest>> getManifests() async* { // Method to get a stream of manifests
    try {
      final currentUser = _auth.currentUser; // Getting the current authenticated user
      if (currentUser == null) { // If no user is authenticated
        yield []; // Yield an empty list
        return; // Return from the method
      }

      final organization = await _organizationService.getCurrentUserOrganization(); // Get the user's organization
      if (organization == null) { // If no organization is found
        yield []; // Yield an empty list
        return; // Return from the method
      }

      yield* _firestore // Query Firestore for manifests
          .collection('manifests') // Access the 'manifests' collection
          .where('organizationId', isEqualTo: organization.id) // Filter by organization ID
          .snapshots() // Get real-time updates
          .map((snapshot) => snapshot.docs // Map the snapshot to a list of manifests
          .map((doc) => Manifest.fromMap(doc.data(), doc.id)) // Convert each document to a Manifest object
          .toList()); // Convert the iterable to a list
    } catch (e) { // Catch any errors
      debugPrint('Error getting manifests: $e'); // Print the error
      yield []; // Yield an empty list
    }
  }

  Stream<Manifest?> getManifestByEventId(String eventId) async* {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        yield null;
        return;
      }

      yield* _firestore
          .collection('manifests')
          .where('eventId', isEqualTo: eventId)
          .limit(1)
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          // Print the snapshot data for debugging
          debugPrint('Snapshot data: ${snapshot.docs.first.data()}');
          // Print the document ID for debugging
          debugPrint('Document ID: ${snapshot.docs.first.id}');
          // Map the snapshot to a Manifest object
          return Manifest.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
        } else {
          debugPrint('No manifests found for event ID: $eventId');
          return null;
        }
      });
    } catch (e) {
      debugPrint('Error getting manifests by event ID: $e');
      yield null;
    }
  }

  Future<bool> doesManifestExist(String eventId) async {
    try {
      final querySnapshot = await _firestore
          .collection('manifests')
          .where('eventId', isEqualTo: eventId)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking manifests existence: $e');
      return false;
    }
  }


  Future<Manifest> createManifest({ // Method to create a new manifests
    required String eventId, // Required event ID parameter
    required List<ManifestItem> items, // Required items parameter
  }) async {
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) throw 'Not authenticated'; // Throw an error if not authenticated

      final organization = await _organizationService.getCurrentUserOrganization(); // Get the user's organization
      if (organization == null) throw 'Organization not found'; // Throw an error if no organization found

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get(); // Get the user document

      if (!userDoc.exists) throw 'User data not found'; // Throw an error if user data not found
      final userRole = userDoc.get('role') as String?; // Get the user's role

      if (userRole == null || !['admin', 'client', 'manager'].contains(userRole)) { // Check if the user has sufficient permissions
        throw 'Insufficient permissions to create manifests'; // Throw an error if insufficient permissions
      }

      // Check if a manifest already exists for this event
      final existingPlanQuery = await _firestore
          .collection('manifests')
          .where('eventId', isEqualTo: eventId)
          .limit(1)
          .get();

      if (existingPlanQuery.docs.isNotEmpty) { // If a manifest already exists
        throw 'A manifest already exists for this event'; // Throw an error
      }

      final now = DateTime.now(); // Get the current date and time
      final docRef = _firestore.collection('manifests').doc(); // Create a new document reference

      final manifest = Manifest( // Create a new Manifest object
        id: docRef.id, // Set the manifest ID
        eventId: eventId, // Set the event ID
        organizationId: organization.id, // Set the organization ID
        items: items, // Set the items
        createdAt: now, // Set the creation date
        updatedAt: now, // Set the update date
      );

      final Map<String, dynamic> data = manifest.toMap(); // Convert the manifest to a map
      data['organizationId'] = organization.id; // Add the organization ID
      data['createdBy'] = currentUser.uid; // Add the creator ID

      await docRef.set(data); // Save the manifest to Firestore
      notifyListeners(); // Notify listeners of the change
      return manifest; // Return the created manifest
    } catch (e) { // Catch any errors
      debugPrint('Error creating manifest: $e'); // Print the error
      rethrow; // Rethrow the error
    }
  }

  Future<void> updateManifest(Manifest manifest) async { // Method to update a manifest
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) throw 'Not authenticated'; // Throw an error if not authenticated

      final organization = await _organizationService.getCurrentUserOrganization(); // Get the user's organization
      if (organization == null) throw 'Organization not found'; // Throw an error if no organization found

      final manifestDoc = await _firestore
          .collection('manifests')
          .doc(manifest.id)
          .get(); // Get the manifest document

      if (!manifestDoc.exists) throw 'manifest not found'; // Throw an error if manifest not found

      final manifestData = manifestDoc.data()!; // Get the manifest data
      if (manifestData['organizationId'] != organization.id) { // Check if the manifest belongs to the user's organization
        throw 'manifest belongs to a different organization'; // Throw an error if manifest belongs to a different organization
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get(); // Get the user document

      if (!userDoc.exists) throw 'User data not found'; // Throw an error if user data not found
      final userRole = userDoc.get('role') as String?; // Get the user's role

      if (userRole == null || !['admin', 'client', 'manager'].contains(userRole)) { // Check if the user has sufficient permissions
        throw 'Insufficient permissions to update manifests'; // Throw an error if insufficient permissions
      }

      final Map<String, dynamic> updates = manifest.toMap(); // Convert the manifest to a map
      updates['updatedAt'] = FieldValue.serverTimestamp(); // Update the timestamp

      await _firestore
          .collection('manifests')
          .doc(manifest.id)
          .update(updates); // Update the manifest document

      notifyListeners(); // Notify listeners of the change
    } catch (e) { // Catch any errors
      debugPrint('Error updating manifest: $e'); // Print the error
      rethrow; // Rethrow the error
    }
  }

  Future<void> assignVehicleToItem({
    required String manifestId,
    required String manifestItemId,
    required String vehicleId,
  }) async {
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) throw 'Not authenticated'; // Throw an error if not authenticated

      final organization = await _organizationService.getCurrentUserOrganization(); // Get the user's organization
      if (organization == null) throw 'Organization not found'; // Throw an error if no organization found

      // Check permissions
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get(); // Get the user document
      if (!userDoc.exists) throw 'User not found'; // Throw an error if user not found

      final userRole = userDoc.get('role') as String?; // Get the user's role
      if (!['admin', 'manager', 'client'].contains(userRole)) { // Check if the user has sufficient permissions
        throw 'Insufficient permissions to assign vehicles'; // Throw an error if insufficient permissions
      }

      // Check if the vehicle exists and is available
      final vehicleDoc = await _firestore.collection('vehicles').doc(vehicleId).get(); // Get the vehicle document
      if (!vehicleDoc.exists) throw 'Vehicle not found'; // Throw an error if vehicle not found

      final vehicleData = vehicleDoc.data()!; // Get the vehicle data
      if (vehicleData['organizationId'] != organization.id) { // Check if the vehicle belongs to the user's organization
        throw 'Vehicle belongs to a different organization'; // Throw an error if vehicle belongs to a different organization
      }

      // Get the manifest
      final manifestDoc = await _firestore.collection('manifests').doc(manifestId).get(); // Get the manifest document
      if (!manifestDoc.exists) throw 'manifest not found'; // Throw an error if manifest not found

      final manifestData = manifestDoc.data()!; // Get the manifest data
      if (manifestData['organizationId'] != organization.id) { // Check if the manifest belongs to the user's organization
        throw 'manifest belongs to a different organization'; // Throw an error if manifest belongs to a different organization
      }

      // Update the manifest item with the vehicle ID
      final List<dynamic> items = manifestData['items'] as List<dynamic>; // Get the items
      bool itemFound = false; // Flag to track if the item was found

      for (int i = 0; i < items.length; i++) { // Loop through the items
        if (items[i]['id'] == manifestItemId) { // If the item is found by its ID
          items[i]['vehicleId'] = vehicleId; // Assign the vehicle
          items[i]['loadingStatus'] = 'pending'; // Update the loading status
          itemFound = true; // Set the flag
          break; // Break the loop
        }
      }

      if (!itemFound) throw 'Item not found in manifest'; // Throw an error if item not found

      // Update the manifest
      await manifestDoc.reference.update({ // Update the manifest document
        'items': items, // Update the items
        'updatedAt': FieldValue.serverTimestamp(), // Update the timestamp
      });

      notifyListeners(); // Notify listeners of the change
    } catch (e) { // Catch any errors
      debugPrint('Error assigning vehicle to item: $e'); // Print the error
      rethrow; // Rethrow the error
    }
  }


  Future<void> manifestPlan(String manifestId) async { // Method to delete a manifest
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) throw 'Not authenticated'; // Throw an error if not authenticated

      final organization = await _organizationService.getCurrentUserOrganization(); // Get the user's organization
      if (organization == null) throw 'Organization not found'; // Throw an error if no organization found

      final manifestDoc = await _firestore
          .collection('manifests')
          .doc(manifestId)
          .get(); // Get the manifest document

      if (!manifestDoc.exists) throw 'manifest not found'; // Throw an error if manifest not found

      final manifestData = manifestDoc.data()!; // Get the manifest data
      if (manifestData['organizationId'] != organization.id) { // Check if the manifest belongs to the user's organization
        throw 'manifest belongs to a different organization'; // Throw an error if manifest belongs to a different organization
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get(); // Get the user document

      if (!userDoc.exists) throw 'User data not found'; // Throw an error if user data not found
      final userRole = userDoc.get('role') as String?; // Get the user's role

      if (userRole == null || !['admin', 'client'].contains(userRole)) { // Check if the user has sufficient permissions (note: only admin and client can delete)
        throw 'Insufficient permissions to delete manifests'; // Throw an error if insufficient permissions
      }

      await _firestore
          .collection('manifests')
          .doc(manifestId)
          .delete(); // Delete the manifest document

      notifyListeners(); // Notify listeners of the change
    } catch (e) { // Catch any errors
      debugPrint('Error deleting manifest: $e'); // Print the error
      rethrow; // Rethrow the error
    }
  }

  Stream<List<ManifestItem>> getManifestItemsByVehicleId(String vehicleId) async* {
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

      yield* _firestore
          .collection('manifests')
          .where('organizationId', isEqualTo: organization.id)
          .snapshots()
          .map((snapshot) {
        final items = <ManifestItem>[];
        for (final doc in snapshot.docs) {
          final plan = Manifest.fromMap(doc.data(), doc.id);
          final vehicleItems = plan.items.where((item) => item.vehicleId == vehicleId).toList();
          items.addAll(vehicleItems);
        }
        return items;
      });
    } catch (e) {
      debugPrint('Error getting manifests by vehicle ID: $e');
      yield [];
    }
  }
}