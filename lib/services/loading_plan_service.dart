import 'package:cateredtoyou/models/loading_plan_model.dart'; // Importing the LoadingPlan model
import 'package:cateredtoyou/services/organization_service.dart'; // Importing the OrganizationService
import 'package:flutter/foundation.dart'; // Importing foundation for ChangeNotifier
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore for database operations
import 'package:firebase_auth/firebase_auth.dart'; // Importing FirebaseAuth for authentication

class LoadingPlanService extends ChangeNotifier { // Defining LoadingPlanService class that extends ChangeNotifier
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Initializing Firestore instance
  final FirebaseAuth _auth = FirebaseAuth.instance; // Initializing FirebaseAuth instance
  final OrganizationService _organizationService; // Declaring OrganizationService instance

  LoadingPlanService(this._organizationService); // Constructor to initialize OrganizationService

  Stream<List<LoadingPlan>> getLoadingPlans() async* { // Method to get a stream of loading plans
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

      yield* _firestore // Query Firestore for loading plans
          .collection('loading_plans') // Access the 'loading_plans' collection
          .where('organizationId', isEqualTo: organization.id) // Filter by organization ID
          .snapshots() // Get real-time updates
          .map((snapshot) => snapshot.docs // Map the snapshot to a list of loading plans
          .map((doc) => LoadingPlan.fromMap(doc.data(), doc.id)) // Convert each document to a LoadingPlan object
          .toList()); // Convert the iterable to a list
    } catch (e) { // Catch any errors
      debugPrint('Error getting loading plans: $e'); // Print the error
      yield []; // Yield an empty list
    }
  }

  Stream<LoadingPlan?> getLoadingPlanByEventId(String eventId) async* { // Method to get a loading plan by event ID
    try {
      final currentUser = _auth.currentUser; // Getting the current authenticated user
      if (currentUser == null) { // If no user is authenticated
        yield null; // Yield null
        return; // Return from the method
      }

      yield* _firestore // Query Firestore for loading plans
          .collection('loading_plans') // Access the 'loading_plans' collection
          .where('eventId', isEqualTo: eventId) // Filter by event ID
          .limit(1) // Limit to 1 result
          .snapshots() // Get real-time updates
          .map((snapshot) => snapshot.docs.isNotEmpty // Map the snapshot to a LoadingPlan object or null
          ? LoadingPlan.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id)
          : null);
    } catch (e) { // Catch any errors
      debugPrint('Error getting loading plan by event ID: $e'); // Print the error
      yield null; // Yield null
    }
  }

  Future<LoadingPlan> createLoadingPlan({ // Method to create a new loading plan
    required String eventId, // Required event ID parameter
    required List<LoadingItem> items, // Required items parameter
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
        throw 'Insufficient permissions to create loading plans'; // Throw an error if insufficient permissions
      }

      // Check if a loading plan already exists for this event
      final existingPlanQuery = await _firestore
          .collection('loading_plans')
          .where('eventId', isEqualTo: eventId)
          .limit(1)
          .get();

      if (existingPlanQuery.docs.isNotEmpty) { // If a loading plan already exists
        throw 'A loading plan already exists for this event'; // Throw an error
      }

      final now = DateTime.now(); // Get the current date and time
      final docRef = _firestore.collection('loading_plans').doc(); // Create a new document reference

      final loadingPlan = LoadingPlan( // Create a new LoadingPlan object
        id: docRef.id, // Set the loading plan ID
        eventId: eventId, // Set the event ID
        items: items, // Set the items
        createdAt: now, // Set the creation date
        updatedAt: now, // Set the update date
      );

      final Map<String, dynamic> data = loadingPlan.toMap(); // Convert the loading plan to a map
      data['organizationId'] = organization.id; // Add the organization ID
      data['createdBy'] = currentUser.uid; // Add the creator ID

      await docRef.set(data); // Save the loading plan to Firestore
      notifyListeners(); // Notify listeners of the change
      return loadingPlan; // Return the created loading plan
    } catch (e) { // Catch any errors
      debugPrint('Error creating loading plan: $e'); // Print the error
      rethrow; // Rethrow the error
    }
  }

  Future<void> updateLoadingPlan(LoadingPlan loadingPlan) async { // Method to update a loading plan
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) throw 'Not authenticated'; // Throw an error if not authenticated

      final organization = await _organizationService.getCurrentUserOrganization(); // Get the user's organization
      if (organization == null) throw 'Organization not found'; // Throw an error if no organization found

      final loadingPlanDoc = await _firestore
          .collection('loading_plans')
          .doc(loadingPlan.id)
          .get(); // Get the loading plan document

      if (!loadingPlanDoc.exists) throw 'Loading plan not found'; // Throw an error if loading plan not found

      final loadingPlanData = loadingPlanDoc.data()!; // Get the loading plan data
      if (loadingPlanData['organizationId'] != organization.id) { // Check if the loading plan belongs to the user's organization
        throw 'Loading plan belongs to a different organization'; // Throw an error if loading plan belongs to a different organization
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get(); // Get the user document

      if (!userDoc.exists) throw 'User data not found'; // Throw an error if user data not found
      final userRole = userDoc.get('role') as String?; // Get the user's role

      if (userRole == null || !['admin', 'client', 'manager'].contains(userRole)) { // Check if the user has sufficient permissions
        throw 'Insufficient permissions to update loading plans'; // Throw an error if insufficient permissions
      }

      final Map<String, dynamic> updates = loadingPlan.toMap(); // Convert the loading plan to a map
      updates['updatedAt'] = FieldValue.serverTimestamp(); // Update the timestamp

      await _firestore
          .collection('loading_plans')
          .doc(loadingPlan.id)
          .update(updates); // Update the loading plan document

      notifyListeners(); // Notify listeners of the change
    } catch (e) { // Catch any errors
      debugPrint('Error updating loading plan: $e'); // Print the error
      rethrow; // Rethrow the error
    }
  }

  Future<void> assignVehicleToItem(String loadingPlanId, String eventMenuItemId, String vehicleId) async { // Method to assign a vehicle to an item
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

      // Get the loading plan
      final loadingPlanDoc = await _firestore.collection('loading_plans').doc(loadingPlanId).get(); // Get the loading plan document
      if (!loadingPlanDoc.exists) throw 'Loading plan not found'; // Throw an error if loading plan not found

      final loadingPlanData = loadingPlanDoc.data()!; // Get the loading plan data
      if (loadingPlanData['organizationId'] != organization.id) { // Check if the loading plan belongs to the user's organization
        throw 'Loading plan belongs to a different organization'; // Throw an error if loading plan belongs to a different organization
      }

      // Update the loading item with the vehicle ID
      final List<dynamic> items = loadingPlanData['items'] as List<dynamic>; // Get the items
      bool itemFound = false; // Flag to track if the item was found

      for (int i = 0; i < items.length; i++) { // Loop through the items
        if (items[i]['eventMenuItemId'] == eventMenuItemId) { // If the item is found
          items[i]['vehicleId'] = vehicleId; // Assign the vehicle
          itemFound = true; // Set the flag
          break; // Break the loop
        }
      }

      if (!itemFound) throw 'Item not found in loading plan'; // Throw an error if item not found

      // Update the loading plan
      await loadingPlanDoc.reference.update({ // Update the loading plan document
        'items': items, // Update the items
        'updatedAt': FieldValue.serverTimestamp(), // Update the timestamp
      });

      notifyListeners(); // Notify listeners of the change
    } catch (e) { // Catch any errors
      debugPrint('Error assigning vehicle to item: $e'); // Print the error
      rethrow; // Rethrow the error
    }
  }

  Future<void> removeVehicleFromItem(String loadingPlanId, String eventMenuItemId) async { // Method to remove a vehicle from an item
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) throw 'Not authenticated'; // Throw an error if not authenticated

      // Get the loading plan
      final loadingPlanDoc = await _firestore.collection('loading_plans').doc(loadingPlanId).get(); // Get the loading plan document
      if (!loadingPlanDoc.exists) throw 'Loading plan not found'; // Throw an error if loading plan not found

      final loadingPlanData = loadingPlanDoc.data()!; // Get the loading plan data

      // Check permissions
      final organization = await _organizationService.getCurrentUserOrganization(); // Get the user's organization
      if (organization == null) throw 'Organization not found'; // Throw an error if no organization found

      if (loadingPlanData['organizationId'] != organization.id) { // Check if the loading plan belongs to the user's organization
        throw 'Loading plan belongs to a different organization'; // Throw an error if loading plan belongs to a different organization
      }

      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get(); // Get the user document
      if (!userDoc.exists) throw 'User not found'; // Throw an error if user not found

      final userRole = userDoc.get('role') as String?; // Get the user's role
      if (!['admin', 'manager', 'client'].contains(userRole)) { // Check if the user has sufficient permissions
        throw 'Insufficient permissions to modify vehicle assignments'; // Throw an error if insufficient permissions
      }

      // Update the loading item by removing the vehicle ID
      final List<dynamic> items = loadingPlanData['items'] as List<dynamic>; // Get the items
      bool itemFound = false; // Flag to track if the item was found

      for (int i = 0; i < items.length; i++) { // Loop through the items
        if (items[i]['eventMenuItemId'] == eventMenuItemId) { // If the item is found
          items[i]['vehicleId'] = null; // Remove the vehicle assignment
          itemFound = true; // Set the flag
          break; // Break the loop
        }
      }

      if (!itemFound) throw 'Item not found in loading plan'; // Throw an error if item not found

      // Update the loading plan
      await loadingPlanDoc.reference.update({ // Update the loading plan document
        'items': items, // Update the items
        'updatedAt': FieldValue.serverTimestamp(), // Update the timestamp
      });

      notifyListeners(); // Notify listeners of the change
    } catch (e) { // Catch any errors
      debugPrint('Error removing vehicle from item: $e'); // Print the error
      rethrow; // Rethrow the error
    }
  }

  Future<void> deleteLoadingPlan(String loadingPlanId) async { // Method to delete a loading plan
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) throw 'Not authenticated'; // Throw an error if not authenticated

      final organization = await _organizationService.getCurrentUserOrganization(); // Get the user's organization
      if (organization == null) throw 'Organization not found'; // Throw an error if no organization found

      final loadingPlanDoc = await _firestore
          .collection('loading_plans')
          .doc(loadingPlanId)
          .get(); // Get the loading plan document

      if (!loadingPlanDoc.exists) throw 'Loading plan not found'; // Throw an error if loading plan not found

      final loadingPlanData = loadingPlanDoc.data()!; // Get the loading plan data
      if (loadingPlanData['organizationId'] != organization.id) { // Check if the loading plan belongs to the user's organization
        throw 'Loading plan belongs to a different organization'; // Throw an error if loading plan belongs to a different organization
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get(); // Get the user document

      if (!userDoc.exists) throw 'User data not found'; // Throw an error if user data not found
      final userRole = userDoc.get('role') as String?; // Get the user's role

      if (userRole == null || !['admin', 'client'].contains(userRole)) { // Check if the user has sufficient permissions (note: only admin and client can delete)
        throw 'Insufficient permissions to delete loading plans'; // Throw an error if insufficient permissions
      }

      await _firestore
          .collection('loading_plans')
          .doc(loadingPlanId)
          .delete(); // Delete the loading plan document

      notifyListeners(); // Notify listeners of the change
    } catch (e) { // Catch any errors
      debugPrint('Error deleting loading plan: $e'); // Print the error
      rethrow; // Rethrow the error
    }
  }
}