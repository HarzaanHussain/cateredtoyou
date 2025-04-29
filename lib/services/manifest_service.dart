import 'package:cateredtoyou/models/manifest_model.dart'; // Importing the manifest model
import 'package:cateredtoyou/services/organization_service.dart'; // Importing the OrganizationService
import 'package:flutter/foundation.dart'; // Importing foundation for ChangeNotifier
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore for database operations
import 'package:firebase_auth/firebase_auth.dart'; // Importing FirebaseAuth for authentication

class ManifestService extends ChangeNotifier {
  // Defining manifestService class that extends ChangeNotifier
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Initializing Firestore instance
  final FirebaseAuth _auth =
      FirebaseAuth.instance; // Initializing FirebaseAuth instance
  final OrganizationService
      _organizationService; // Declaring OrganizationService instance

  ManifestService(
      this._organizationService); // Constructor to initialize OrganizationService

  Stream<List<Manifest>> getManifests() async* {
    // Method to get a stream of manifests
    try {
      final currentUser =
          _auth.currentUser; // Getting the current authenticated user
      if (currentUser == null) {
        // If no user is authenticated
        yield []; // Yield an empty list
        return; // Return from the method
      }

      final organization = await _organizationService
          .getCurrentUserOrganization(); // Get the user's organization
      if (organization == null) {
        // If no organization is found
        yield []; // Yield an empty list
        return; // Return from the method
      }
      yield* _firestore // Query Firestore for manifests
          .collection('manifests') // Access the 'manifests' collection
          .where('organizationId',
              isEqualTo: organization.id) // Filter by organization ID
          .where('isArchived',
              isEqualTo: false) // Only get non-archived manifests
          .snapshots() // Get real-time updates
          .map((snapshot) => snapshot
              .docs // Map the snapshot to a list of manifests
              .map((doc) => Manifest.fromMap(doc.data(),
                  doc.id)) // Convert each document to a Manifest object
              .toList()); // Convert the iterable to a list
    } catch (e) {
      // Catch any errors
      debugPrint('Error getting manifests: $e'); // Print the error
      yield []; // Yield an empty list
    }
  }

  Stream<List<Manifest>> getArchivedManifests() async* {
    // Method to get a stream of archived manifests
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        yield [];
        return;
      }

      final organization =
          await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        yield [];
        return;
      }

      yield* _firestore
          .collection('manifests')
          .where('organizationId', isEqualTo: organization.id)
          .where('isArchived', isEqualTo: true) // Only get archived manifests
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Manifest.fromMap(doc.data(), doc.id))
              .toList());
    } catch (e) {
      debugPrint('Error getting archived manifests: $e');
      yield [];
    }
  }

  Stream<Manifest?> getManifestById(String manifestId) async* {
    if (manifestId.isEmpty) {
      debugPrint('Error: Empty manifest ID provided');
      yield null;
      return;
    }

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('Error: No authenticated user');
        yield null;
        return;
      }

      final organization =
          await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        debugPrint('Error: No organization found for user');
        yield null;
        return;
      }

      debugPrint('Fetching manifest with ID: $manifestId');
      yield* _firestore
          .collection('manifests')
          .doc(manifestId)
          .snapshots()
          .map((snapshot) {
        if (snapshot.exists) {
          try {
            final data = snapshot.data()!;
            // Validate that this manifest belongs to the user's organization
            if (data['organizationId'] == organization.id) {
              debugPrint('Successfully retrieved manifest: $manifestId');
              return Manifest.fromMap(data, snapshot.id);
            } else {
              debugPrint('Manifest belongs to a different organization');
              return null;
            }
          } catch (e) {
            debugPrint('Error parsing manifest: $e');
            return null;
          }
        } else {
          debugPrint('Manifest not found: $manifestId');
          return null;
        }
      });
    } catch (e) {
      debugPrint('Error in getManifestById: $e');
      yield null;
    }
  }

  Future<void> deleteManifest(String manifestId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization =
          await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      final manifestDoc =
          await _firestore.collection('manifests').doc(manifestId).get();

      if (!manifestDoc.exists) throw 'Manifest not found';

      final manifestData = manifestDoc.data()!;
      if (manifestData['organizationId'] != organization.id) {
        throw 'Manifest belongs to a different organization';
      }

      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (!userDoc.exists) throw 'User data not found';
      final userRole = userDoc.get('role') as String?;

      if (userRole == null || !['admin', 'client'].contains(userRole)) {
        throw 'Insufficient permissions to delete manifests';
      }

      await _firestore.collection('manifests').doc(manifestId).delete();

      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting manifest: $e');
      rethrow;
    }
  }

  Future<void> archiveManifest(String manifestId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization =
          await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      final manifestDoc =
          await _firestore.collection('manifests').doc(manifestId).get();

      if (!manifestDoc.exists) throw 'Manifest not found';

      final manifestData = manifestDoc.data()!;
      if (manifestData['organizationId'] != organization.id) {
        throw 'Manifest belongs to a different organization';
      }

      // Verify that all items are loaded
      final List<dynamic> items = manifestData['items'] as List<dynamic>;
      final bool allLoaded = items.every((item) =>
          item['loadingStatus'] ==
              LoadingStatus.loaded.toString().split('.').last ||
          item['vehicleId'] != null);

      if (!allLoaded) {
        throw 'Cannot archive manifest: Not all items are loaded';
      }

      await _firestore.collection('manifests').doc(manifestId).update({
        'isArchived': true,
        'archivedAt': FieldValue.serverTimestamp(),
        'archivedBy': currentUser.uid,
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error archiving manifest: $e');
      rethrow;
    }
  }

  Future<void> updateManifestItem(
    String itemId, {
    String? vehicleId,
    int? quantity,
    LoadingStatus? loadingStatus,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization =
          await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      // Find which manifest contains this item
      final manifestsQuery = await _firestore
          .collection('manifests')
          .where('organizationId', isEqualTo: organization.id)
          .get();

      // Track if we found and updated the item
      bool itemFound = false;
      String? manifestId;

      // Iterate through manifests to find the item
      for (final manifestDoc in manifestsQuery.docs) {
        final manifestData = manifestDoc.data();
        final List<dynamic> items = manifestData['items'] as List<dynamic>;

        for (int i = 0; i < items.length; i++) {
          if (items[i]['id'] == itemId) {
            // Found the item, update fields based on parameters
            if (vehicleId != null) {
              items[i]['vehicleId'] = vehicleId;
            }

            if (quantity != null) {
              items[i]['quantity'] = quantity;
            }

            if (loadingStatus != null) {
              items[i]['loadingStatus'] =
                  loadingStatus.toString().split('.').last;
            }

            // Update the manifest with modified items
            await manifestDoc.reference.update({
              'items': items,
              'updatedAt': FieldValue.serverTimestamp(),
            });

            itemFound = true;
            manifestId = manifestDoc.id;
            break;
          }
        }

        if (itemFound) break;
      }

      if (!itemFound) {
        throw 'Item not found in any manifest';
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating manifest item: $e');
      rethrow;
    }
  }

  Stream<Manifest?> getManifestByEventId(String eventId) async* {
    if (eventId.isEmpty) {
      debugPrint('Error: Empty event ID provided');
      yield null;
      return;
    }

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('Error: No authenticated user');
        yield null;
        return;
      }

      // Get user organization to add this filter
      final organization =
          await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        debugPrint('Error: No organization found for user');
        yield null;
        return;
      }

      debugPrint('Fetching manifest for event: $eventId');

      yield* _firestore
          .collection('manifests')
          .where('eventId', isEqualTo: eventId)
          // Add organization filter to ensure correct data retrieval
          .where('organizationId', isEqualTo: organization.id)
          .limit(1)
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          // Improved error handling and logging
          try {
            debugPrint('Found manifest for event: $eventId');
            return Manifest.fromMap(
                snapshot.docs.first.data(), snapshot.docs.first.id);
          } catch (e) {
            debugPrint('Error parsing manifest data: $e');
            return null;
          }
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

  Future<Manifest> createManifest({
  required String eventId,
  required List<ManifestItem> items,
}) async {
  try {
    if (eventId.isEmpty) {
      throw 'Event ID cannot be empty';
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw 'Not authenticated';
    }

    final organization = await _organizationService.getCurrentUserOrganization();
    if (organization == null) {
      throw 'Organization not found';
    }

    final userDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (!userDoc.exists) {
      throw 'User data not found';
    }
    
    final userRole = userDoc.get('role') as String?;

    if (userRole == null || !['admin', 'client', 'manager'].contains(userRole)) {
      throw 'Insufficient permissions to create manifests';
    }

    // Check if a manifest already exists for this event
    final existingManifestQuery = await _firestore
        .collection('manifests')
        .where('eventId', isEqualTo: eventId)
        .limit(1)
        .get();

    if (existingManifestQuery.docs.isNotEmpty) {
      throw 'A manifest already exists for this event';
    }

    if (items.isEmpty) {
      throw 'Cannot create a manifest with no items';
    }

    debugPrint('Creating new manifest for event: $eventId with ${items.length} items');
    
    // For debugging, check the items being provided
    for (var item in items) {
      debugPrint('Item: ${item.name}, menuItemId: ${item.menuItemId}, quantity: ${item.quantity}');
    }

    final now = DateTime.now();
    final docRef = _firestore.collection('manifests').doc();

    final manifest = Manifest(
      id: docRef.id,
      eventId: eventId,
      organizationId: organization.id,
      items: items,
      createdAt: now,
      updatedAt: now,
      isArchived: false,
    );

    final Map<String, dynamic> data = manifest.toMap();
    data['createdBy'] = currentUser.uid;

    await docRef.set(data);
    debugPrint('Successfully created manifest with ID: ${docRef.id}');
    
    notifyListeners();
    return manifest;
  } catch (e) {
    debugPrint('Error creating manifest: $e');
    rethrow;
  }
}


  Future<void> updateManifest(Manifest manifest) async {
    // Method to update a manifest
    try {
      final currentUser =
          _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) {
        throw 'Not authenticated'; // Throw an error if not authenticated
      }

      final organization = await _organizationService
          .getCurrentUserOrganization(); // Get the user's organization
      if (organization == null) {
        throw 'Organization not found'; // Throw an error if no organization found
      }

      final manifestDoc = await _firestore
          .collection('manifests')
          .doc(manifest.id)
          .get(); // Get the manifest document

      if (!manifestDoc.exists) {
        throw 'manifest not found'; // Throw an error if manifest not found
      }

      final manifestData = manifestDoc.data()!; // Get the manifest data
      if (manifestData['organizationId'] != organization.id) {
        // Check if the manifest belongs to the user's organization
        throw 'manifest belongs to a different organization'; // Throw an error if manifest belongs to a different organization
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get(); // Get the user document

      if (!userDoc.exists) {
        throw 'User data not found'; // Throw an error if user data not found
      }
      final userRole = userDoc.get('role') as String?; // Get the user's role

      if (userRole == null ||
          !['admin', 'client', 'manager'].contains(userRole)) {
        // Check if the user has sufficient permissions
        throw 'Insufficient permissions to update manifests'; // Throw an error if insufficient permissions
      }

      final Map<String, dynamic> updates =
          manifest.toMap(); // Convert the manifest to a map
      updates['updatedAt'] =
          FieldValue.serverTimestamp(); // Update the timestamp

      await _firestore
          .collection('manifests')
          .doc(manifest.id)
          .update(updates); // Update the manifest document

      notifyListeners(); // Notify listeners of the change
    } catch (e) {
      // Catch any errors
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
      final currentUser =
          _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) {
        throw 'Not authenticated'; // Throw an error if not authenticated
      }

      final organization = await _organizationService
          .getCurrentUserOrganization(); // Get the user's organization
      if (organization == null) {
        throw 'Organization not found'; // Throw an error if no organization found
      }

      // Check permissions
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get(); // Get the user document
      if (!userDoc.exists) {
        throw 'User not found'; // Throw an error if user not found
      }

      final userRole = userDoc.get('role') as String?; // Get the user's role
      if (!['admin', 'manager', 'client'].contains(userRole)) {
        // Check if the user has sufficient permissions
        throw 'Insufficient permissions to assign vehicles'; // Throw an error if insufficient permissions
      }

      // Check if the vehicle exists and is available
      final vehicleDoc = await _firestore
          .collection('vehicles')
          .doc(vehicleId)
          .get(); // Get the vehicle document
      if (!vehicleDoc.exists) {
        throw 'Vehicle not found'; // Throw an error if vehicle not found
      }

      final vehicleData = vehicleDoc.data()!; // Get the vehicle data
      if (vehicleData['organizationId'] != organization.id) {
        // Check if the vehicle belongs to the user's organization
        throw 'Vehicle belongs to a different organization'; // Throw an error if vehicle belongs to a different organization
      }

      // Get the manifest
      final manifestDoc = await _firestore
          .collection('manifests')
          .doc(manifestId)
          .get(); // Get the manifest document
      if (!manifestDoc.exists) {
        throw 'manifest not found'; // Throw an error if manifest not found
      }

      final manifestData = manifestDoc.data()!; // Get the manifest data
      if (manifestData['organizationId'] != organization.id) {
        // Check if the manifest belongs to the user's organization
        throw 'manifest belongs to a different organization'; // Throw an error if manifest belongs to a different organization
      }

      // Update the manifest item with the vehicle ID
      final List<dynamic> items =
          manifestData['items'] as List<dynamic>; // Get the items
      bool itemFound = false; // Flag to track if the item was found

      for (int i = 0; i < items.length; i++) {
        // Loop through the items
        if (items[i]['id'] == manifestItemId) {
          // If the item is found by its ID
          items[i]['vehicleId'] = vehicleId; // Assign the vehicle
          items[i]['loadingStatus'] = 'pending'; // Update the loading status
          itemFound = true; // Set the flag
          break; // Break the loop
        }
      }

      if (!itemFound) {
        throw 'Item not found in manifest'; // Throw an error if item not found
      }

      // Update the manifest
      await manifestDoc.reference.update({
        // Update the manifest document
        'items': items, // Update the items
        'updatedAt': FieldValue.serverTimestamp(), // Update the timestamp
      });

      notifyListeners(); // Notify listeners of the change
    } catch (e) {
      // Catch any errors
      debugPrint('Error assigning vehicle to item: $e'); // Print the error
      rethrow; // Rethrow the error
    }
  }

  Stream<List<ManifestItem>> getManifestItemsByVehicleId(
      String vehicleId) async* {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        yield [];
        return;
      }

      final organization =
          await _organizationService.getCurrentUserOrganization();
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
          final vehicleItems =
              plan.items.where((item) => item.vehicleId == vehicleId).toList();
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
