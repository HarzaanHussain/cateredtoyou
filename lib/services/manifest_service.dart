import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/services/organization_service.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManifestService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OrganizationService _organizationService;

  ManifestService(this._organizationService);

  Stream<List<Manifest>> getManifests() async* {
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
          .map((snapshot) => snapshot.docs
          .map((doc) => _manifestFromMap(doc.data(), doc.id))
          .toList());
    } catch (e) {
      debugPrint('Error getting manifests: $e');
      yield [];
    }
  }

  Stream<Manifest?> getEventManifestByEventId(String eventId) async* {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        yield null;
        return;
      }

      yield* _firestore
          .collection('manifests')
          .where('eventId', isEqualTo: eventId)
          .where('manifestType', isEqualTo: 'event')
          .limit(1)
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          debugPrint('Snapshot data: ${snapshot.docs.first.data()}');
          debugPrint('Document ID: ${snapshot.docs.first.id}');
          return _manifestFromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
        } else {
          debugPrint('No event manifests found for event ID: $eventId');
          return null;
        }
      });
    } catch (e) {
      debugPrint('Error getting event manifests by event ID: $e');
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
    required String manifestType,
    String? vehicleId, // New optional parameter
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) throw 'User data not found';
      final userRole = userDoc.get('role') as String?;

      if (userRole == null || !['admin', 'client', 'manager'].contains(userRole)) {
        throw 'Insufficient permissions to create manifests';
      }

      // Check if a manifest already exists for this event
      final existingPlanQuery = await _firestore
          .collection('manifests')
          .where('eventId', isEqualTo: eventId)
          .limit(1)
          .get();

      if (existingPlanQuery.docs.isNotEmpty) {
        throw 'A manifest already exists for this event';
      }

      final now = DateTime.now();
      final docRef = _firestore.collection('manifests').doc();

      // Create the appropriate manifest type based on the parameter
      Manifest manifest;
      if (manifestType == 'event') {
        manifest = EventManifest(
          id: docRef.id,
          eventId: eventId,
          organizationId: organization.id,
          items: _convertToEventManifestItems(items),
          createdAt: now,
          updatedAt: now,
        );
      } else if (manifestType == 'delivery') {
        manifest = DeliveryManifest(
          id: docRef.id,
          eventId: eventId,
          organizationId: organization.id,
          items: _convertToDeliveryManifestItems(items),
          createdAt: now,
          updatedAt: now,
          vehicleId: vehicleId,
        );
      } else {
        throw 'Invalid manifest type';
      }

      final Map<String, dynamic> data = manifest.toMap();
      data['manifestType'] = manifestType; // Store the manifest type
      data['organizationId'] = organization.id;
      data['createdBy'] = currentUser.uid;

      await docRef.set(data);
      notifyListeners();
      return manifest;
    } catch (e) {
      debugPrint('Error creating manifest: $e');
      rethrow;
    }
  }

  Future<void> updateManifest(Manifest manifest) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      final manifestDoc = await _firestore
          .collection('manifests')
          .doc(manifest.id)
          .get();

      if (!manifestDoc.exists) throw 'Manifest not found';

      final manifestData = manifestDoc.data()!;
      if (manifestData['organizationId'] != organization.id) {
        throw 'Manifest belongs to a different organization';
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) throw 'User data not found';
      final userRole = userDoc.get('role') as String?;

      if (userRole == null || !['admin', 'client', 'manager'].contains(userRole)) {
        throw 'Insufficient permissions to update manifests';
      }

      final Map<String, dynamic> updates = manifest.toMap();
      // Preserve the manifestType field
      updates['manifestType'] = manifestData['manifestType'];
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('manifests')
          .doc(manifest.id)
          .update(updates);

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating manifest: $e');
      rethrow;
    }
  }

  Future<void> deleteManifest(String manifestId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      final manifestDoc = await _firestore
          .collection('manifests')
          .doc(manifestId)
          .get();

      if (!manifestDoc.exists) throw 'Manifest not found';

      final manifestData = manifestDoc.data()!;
      if (manifestData['organizationId'] != organization.id) {
        throw 'Manifest belongs to a different organization';
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) throw 'User data not found';
      final userRole = userDoc.get('role') as String?;

      if (userRole == null || !['admin', 'client'].contains(userRole)) {
        throw 'Insufficient permissions to delete manifests';
      }

      await _firestore
          .collection('manifests')
          .doc(manifestId)
          .delete();

      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting manifest: $e');
      rethrow;
    }
  }

  Stream<List<DeliveryManifest>> getDeliveryManifestsByVehicle(String vehicleId) async* {
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
          .where('manifestType', isEqualTo: 'delivery')
          .where('vehicleId', isEqualTo: vehicleId)
          .snapshots()
          .map((snapshot) => snapshot.docs
          .map((doc) => _manifestFromMap(doc.data(), doc.id) as DeliveryManifest)
          .toList());
    } catch (e) {
      debugPrint('Error getting delivery manifests by vehicle: $e');
      yield [];
    }
  }

  // Helper method to create the appropriate manifest from Firestore data
  Manifest _manifestFromMap(Map<String, dynamic> map, String docId) {
    String manifestType = map['manifestType'] ?? 'event'; // Default to event if not specified

    if (manifestType == 'delivery') {
      return DeliveryManifest.fromMap(map, docId);
    } else {
      return EventManifest.fromMap(map, docId);
    }
  }

  // Helper method to convert generic ManifestItems to EventManifestItems
  List<EventManifestItem> _convertToEventManifestItems(List<ManifestItem> items) {
    return items.map((item) {
      if (item is EventManifestItem) {
        return item;
      } else {
        // Create a new EventManifestItem with default values
        return EventManifestItem(
          menuItemId: item.menuItemId,
          name: item.name,
          originalQuantity: 0,
          quantityRemaining: 0,
          readiness: item.readiness,
        );
      }
    }).toList();
  }

  // Helper method to convert generic ManifestItems to DeliveryManifestItems
  List<DeliveryManifestItem> _convertToDeliveryManifestItems(List<ManifestItem> items) {
    return items.map((item) {
      if (item is DeliveryManifestItem) {
        return item;
      } else {
        // Create a new DeliveryManifestItem with default values
        return DeliveryManifestItem(
          menuItemId: item.menuItemId,
          name: item.name,
          quantity: 0,
          readiness: item.readiness,
        );
      }
    }).toList();
  }

  Future<void> moveEventItemsToDelivery({
    required String eventId,
    required String vehicleId,
    required List<EventManifestItem> eventItems,
    required List<int> quantities,
  }) async {
    try {
      // Authentication and organization validation
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      // Validate input
      if (eventItems.length != quantities.length) {
        throw ArgumentError('Event items and quantities must have the same length');
      }

      // Validate vehicle
      final vehicleDoc = await _firestore.collection('vehicles').doc(vehicleId).get();
      if (!vehicleDoc.exists) throw 'Vehicle not found';

      final vehicleData = vehicleDoc.data()!;
      if (vehicleData['organizationId'] != organization.id) {
        throw 'Vehicle belongs to a different organization';
      }

      // Find the event manifest
      final eventManifest = await _firestore
          .collection('manifests')
          .where('eventId', isEqualTo: eventId)
          .where('manifestType', isEqualTo: 'event')
          .limit(1)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isEmpty) throw 'Event manifest not found';
        return EventManifest.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
      });

      // Prepare delivery items and updated event items
      final List<DeliveryManifestItem> deliveryItems = [];
      final List<EventManifestItem> updatedEventItems = List.from(eventManifest.items);

      // Process each item being moved
      for (int i = 0; i < eventItems.length; i++) {
        final eventItem = eventItems[i];
        final quantity = quantities[i];

        // Validate quantity
        if (quantity <= 0) continue;
        if (quantity > eventItem.quantityRemaining) {
          throw ArgumentError('Assigned quantity exceeds remaining for ${eventItem.name}');
        }

        // Create delivery manifest item
        deliveryItems.add(DeliveryManifestItem(
          menuItemId: eventItem.menuItemId,
          name: eventItem.name,
          quantity: quantity,
          readiness: eventItem.readiness,
        ));

        // Update event manifest item quantity
        final eventItemIndex = updatedEventItems.indexWhere((item) => item.menuItemId == eventItem.menuItemId);
        if (eventItemIndex != -1) {
          final original = updatedEventItems[eventItemIndex];
          updatedEventItems[eventItemIndex] = original.copyWith(
            quantityRemaining: original.quantityRemaining - quantity,
          );
        }
      }

      // Start a batch write for atomicity
      final batch = _firestore.batch();

      // Reference to existing delivery manifest (if any)
      final existingDeliveryManifestQuery = await _firestore
          .collection('manifests')
          .where('eventId', isEqualTo: eventId)
          .where('manifestType', isEqualTo: 'delivery')
          .where('vehicleId', isEqualTo: vehicleId)
          .limit(1)
          .get();

      if (existingDeliveryManifestQuery.docs.isNotEmpty) {
        // Update existing delivery manifest
        final existingDeliveryManifestDoc = existingDeliveryManifestQuery.docs.first;
        final existingItems = List<Map<String, dynamic>>.from(existingDeliveryManifestDoc.data()['items'] ?? []);

        // Merge new items with existing items
        for (final newItem in deliveryItems) {
          final existingItemIndex = existingItems.indexWhere(
                  (item) => item['menuItemId'] == newItem.menuItemId
          );

          if (existingItemIndex != -1) {
            // Update quantity of existing item
            existingItems[existingItemIndex]['quantity'] += newItem.quantity;
          } else {
            // Add new item
            existingItems.add(newItem.toMap());
          }
        }

        batch.update(existingDeliveryManifestDoc.reference, {
          'items': existingItems,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new delivery manifest
        final newDeliveryManifestRef = _firestore.collection('manifests').doc();
        batch.set(newDeliveryManifestRef, {
          'eventId': eventId,
          'organizationId': organization.id,
          'manifestType': 'delivery',
          'vehicleId': vehicleId,
          'items': deliveryItems.map((item) => item.toMap()).toList(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update event manifest
      final eventManifestRef = _firestore.collection('manifests').doc(eventManifest.id);
      batch.update(eventManifestRef, {
        'items': updatedEventItems.map((item) => item.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Commit the batch
      await batch.commit();

      notifyListeners();
    } catch (e) {
      debugPrint('Error moving event items to delivery: $e');
      rethrow;
    }
  }
}