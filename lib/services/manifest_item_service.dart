import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cateredtoyou/models/manifest_item_model.dart';
import 'organization_service.dart';
import 'package:cateredtoyou/models/organization_model.dart';

/// Primary service for database operations related to manifest items
class ManifestItemService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OrganizationService _organizationService;

  ManifestItemService(this._organizationService);

  // Collection reference
  CollectionReference<Map<String, dynamic>> get _manifestItemsCollection =>
      _firestore.collection('manifestItems');

  //
  // Core Stream Queries (Read operations)
  //

  /// Get all manifest items for an event
  Stream<List<ManifestItem>> getManifestItemsByEvent(String eventId) {
    return _safeStream(
        'getting manifest items by event',
            () async {
          final (_, org) = await _requireUserAndOrg();
          return _baseEventQuery(eventId, org.id)
              .snapshots()
              .map((snapshot) =>
              snapshot.docs
                  .map((doc) => ManifestItem.fromFirestore(doc))
                  .toList());
        },
        []);
  }

  /// Get all manifest items assigned to a vehicle
  Stream<List<ManifestItem>> getManifestItemsByVehicle(String vehicleId) {
    return _safeStream(
        'getting manifest items by vehicle',
            () async {
          final (_, org) = await _requireUserAndOrg();
          return _manifestItemsCollection
              .where('vehicleId', isEqualTo: vehicleId)
              .where('organizationId', isEqualTo: org.id)
              .snapshots()
              .map((snapshot) =>
              snapshot.docs
                  .map((doc) => ManifestItem.fromFirestore(doc))
                  .toList());
        },
        []);
  }

  /// Get manifest items by stage for an event
  Stream<List<ManifestItem>> getManifestItemsByStage(String eventId, Stage stage) {
    return _safeStream(
        'getting manifest items by stage',
            () async {
          final (_, org) = await _requireUserAndOrg();
          return _baseEventQuery(eventId, org.id)
              .where('currentStage', isEqualTo: ManifestItem.stageToString(stage))
              .snapshots()
              .map((snapshot) =>
              snapshot.docs
                  .map((doc) => ManifestItem.fromFirestore(doc))
                  .toList());
        },
        []);
  }

  /// Get all items that can be assigned (prep and assign stages)
  Stream<List<ManifestItem>> getAssignableItemsForEvent(String eventId) {
    return _safeStream(
        'getting assignable items',
            () async {
          final (_, org) = await _requireUserAndOrg();
          final baseQuery = _baseEventQuery(eventId, org.id);
          return _stageFilteredQuery(baseQuery, [Stage.prep, Stage.assign])
              .snapshots()
              .map((snapshot) =>
              snapshot.docs
                  .map((doc) => ManifestItem.fromFirestore(doc))
                  .toList());
        },
        []);
  }

  /// Get items grouped by vehicle for an event
  Stream<Map<String, List<ManifestItem>>> getItemsByVehicle(String eventId) {
    return _safeStream(
        'getting items by vehicle',
            () async {
          final (_, org) = await _requireUserAndOrg();

          // Get all items for this event that have a vehicleId
          return _baseEventQuery(eventId, org.id)
              .where('vehicleId', isNull: false)
              .snapshots()
              .map((snapshot) {
            final items = snapshot.docs
                .map((doc) => ManifestItem.fromFirestore(doc))
                .toList();

            // Group items by vehicleId
            final Map<String, List<ManifestItem>> groupedItems = {};

            for (final item in items) {
              if (item.vehicleId != null) {
                if (!groupedItems.containsKey(item.vehicleId)) {
                  groupedItems[item.vehicleId!] = [];
                }
                groupedItems[item.vehicleId!]!.add(item);
              }
            }

            return groupedItems;
          });
        },
        {});
  }

  /// Get loadable items for a specific vehicle
  Stream<List<ManifestItem>> getLoadableItemsForVehicle(String vehicleId) {
    return _safeStream(
        'getting loadable items for vehicle',
            () async {
          final (_, org) = await _requireUserAndOrg();

          return _manifestItemsCollection
              .where('vehicleId', isEqualTo: vehicleId)
              .where('organizationId', isEqualTo: org.id)
              .where('currentStage', whereIn: [
            ManifestItem.stageToString(Stage.assign),
            ManifestItem.stageToString(Stage.prep)
          ])
              .snapshots()
              .map((snapshot) =>
              snapshot.docs
                  .map((doc) => ManifestItem.fromFirestore(doc))
                  .toList());
        },
        []);
  }

  /// Get all loadable items grouped by event within a vehicle
  Stream<Map<String, List<ManifestItem>>> getLoadableItemsByEvent(String vehicleId) {
    return _safeStream(
        'getting loadable items by event',
            () async {
          final items = await getLoadableItemsForVehicle(vehicleId).first;

          // Group items by event
          final Map<String, List<ManifestItem>> groupedItems = {};

          for (final item in items) {
            if (!groupedItems.containsKey(item.eventId)) {
              groupedItems[item.eventId] = [];
            }
            groupedItems[item.eventId]!.add(item);
          }

          return Stream.value(groupedItems);
        },
        {});
  }

  //
  // Batch CRUD Operations
  //

  /// Batch create manifest items
  Future<List<ManifestItem>> batchCreateManifestItems(List<ManifestItem> items) async {
    try {
      final (user, org) = await _requireUserAndOrg();

      if (items.isEmpty) {
        return [];
      }

      final batch = _firestore.batch();
      final List<ManifestItem> createdItems = [];
      final now = DateTime.now();

      for (final item in items) {
        final docRef = _manifestItemsCollection.doc(item.id.isEmpty ? null : item.id);

        final newItem = ManifestItem(
          id: docRef.id,
          eventId: item.eventId,
          itemId: item.itemId,
          itemName: item.itemName,
          originalAmount: item.originalAmount,
          currentAmount: item.currentAmount,
          currentStage: item.currentStage,
          status: item.status,
          assignedAmount: item.assignedAmount,
          loadedAmount: item.loadedAmount,
          vehicleId: item.vehicleId,
          lastUpdatedBy: user.uid,
          lastUpdatedAt: now,
          organizationId: org.id,
          notes: item.notes,
        );

        batch.set(docRef, newItem.toMap());
        createdItems.add(newItem);
      }

      await batch.commit();
      notifyListeners();
      return createdItems;
    } catch (e) {
      debugPrint('Error batch creating manifest items: $e');
      rethrow;
    }
  }

  /// Batch update manifest items with common fields
  Future<void> batchUpdateManifestItems(
      List<String> itemIds,
      Map<String, dynamic> updates
      ) async {
    try {
      final (user, org) = await _requireUserAndOrg();

      if (itemIds.isEmpty) {
        return;
      }

      // Add audit fields
      updates['lastUpdatedBy'] = user.uid;
      updates['lastUpdatedAt'] = FieldValue.serverTimestamp();

      final batch = _firestore.batch();

      // Get all items to verify org ownership
      final itemDocs = await Future.wait(
          itemIds.map((id) => _manifestItemsCollection.doc(id).get())
      );

      for (final doc in itemDocs) {
        if (!doc.exists) continue;

        final item = ManifestItem.fromFirestore(doc);

        // Skip items from other organizations
        if (item.organizationId != org.id) continue;

        batch.update(doc.reference, updates);
      }

      await batch.commit();
      notifyListeners();
    } catch (e) {
      debugPrint('Error batch updating manifest items: $e');
      rethrow;
    }
  }

  /// Batch delete manifest items
  Future<void> batchDeleteManifestItems(List<String> itemIds) async {
    try {
      final (_, org) = await _requireUserAndOrg();

      if (itemIds.isEmpty) {
        return;
      }

      // Get all items to verify org ownership
      final itemDocs = await Future.wait(
          itemIds.map((id) => _manifestItemsCollection.doc(id).get())
      );

      final batch = _firestore.batch();

      for (final doc in itemDocs) {
        if (!doc.exists) continue;

        final item = ManifestItem.fromFirestore(doc);

        // Skip items from other organizations
        if (item.organizationId != org.id) continue;

        batch.delete(doc.reference);
      }

      await batch.commit();
      notifyListeners();
    } catch (e) {
      debugPrint('Error batch deleting manifest items: $e');
      rethrow;
    }
  }

  /// Transactional update of a manifest item
  Future<ManifestItem> transactionalUpdateManifestItem(ManifestItem item) async {
    try {
      final (user, org) = await _requireUserAndOrg();

      return await _firestore.runTransaction<ManifestItem>((transaction) async {
        // Get the current state
        final docRef = _manifestItemsCollection.doc(item.id);
        final docSnapshot = await transaction.get(docRef);

        if (!docSnapshot.exists) {
          throw 'Manifest item not found';
        }

        final currentItem = ManifestItem.fromFirestore(docSnapshot);

        // Verify ownership
        if (currentItem.organizationId != org.id) {
          throw 'Item belongs to another organization';
        }

        // Update with audit fields
        final updatedItem = item.copyWith(
          lastUpdatedBy: user.uid,
          lastUpdatedAt: DateTime.now(),
        );

        transaction.update(docRef, updatedItem.toMap());
        return updatedItem;
      });
    } catch (e) {
      debugPrint('Error in transactional update: $e');
      rethrow;
    }
  }

  /// Split an item into two separate items (transactional)
  Future<List<ManifestItem>> splitItem(
      String itemId,
      int splitAmount, {
        String? vehicleId,
        Stage? newStage,
      }) async {
    try {
      final (user, _) = await _requireUserAndOrg();

      // Run as a transaction to ensure consistency
      return await _firestore.runTransaction<List<ManifestItem>>((transaction) async {
        // Get the item
        final docSnapshot = await transaction.get(_manifestItemsCollection.doc(itemId));
        if (!docSnapshot.exists) {
          throw 'Manifest item not found';
        }

        final item = ManifestItem.fromFirestore(docSnapshot);

        // Validate split amount
        if (splitAmount <= 0 || splitAmount >= item.currentAmount) {
          throw 'Invalid split amount';
        }

        // Create a new document for the split portion
        final newDocRef = _manifestItemsCollection.doc();

        final newItem = ManifestItem(
          id: newDocRef.id,
          eventId: item.eventId,
          itemId: item.itemId,
          itemName: item.itemName,
          originalAmount: item.originalAmount,
          currentAmount: splitAmount,
          currentStage: newStage ?? item.currentStage,
          status: item.status,
          assignedAmount: newStage == Stage.assign || newStage == Stage.load
              ? splitAmount
              : 0,
          loadedAmount: newStage == Stage.load ? splitAmount : 0,
          vehicleId: vehicleId,
          lastUpdatedBy: user.uid,
          lastUpdatedAt: DateTime.now(),
          organizationId: item.organizationId,
          notes: item.notes,
        );

        // Update the original item
        final remainingAmount = item.currentAmount - splitAmount;
        final updatedOriginalItem = item.copyWith(
          currentAmount: remainingAmount,
          lastUpdatedBy: user.uid,
          lastUpdatedAt: DateTime.now(),
        );

        // Apply changes in transaction
        transaction.set(newDocRef, newItem.toMap());

        // If the remaining amount is 0, delete the original
        if (remainingAmount <= 0) {
          transaction.delete(_manifestItemsCollection.doc(itemId));
        } else {
          transaction.update(
              _manifestItemsCollection.doc(itemId),
              updatedOriginalItem.toMap()
          );
        }

        // Return both items - first is the updated original, second is the new split item
        return [updatedOriginalItem, newItem];
      });
    } catch (e) {
      debugPrint('Error splitting item: $e');
      rethrow;
    }
  }

  /// Process batch item updates with custom handling logic
  Future<void> processBatchItemUpdate(
      List<String> itemIds,
      List<int> amounts,
      Future<void> Function(ManifestItem, int, WriteBatch) processItem,
      ) async {
    try {
      final (_, org) = await _requireUserAndOrg();

      // Validate input lists have the same length
      if (itemIds.length != amounts.length) {
        throw 'Item IDs and amounts must have the same length';
      }

      if (itemIds.isEmpty) {
        return;
      }

      // Get all items to process
      final itemDocs = await Future.wait(
          itemIds.map((id) => _manifestItemsCollection.doc(id).get())
      );

      // Create a batch for operations that don't need splitting
      final batch = _firestore.batch();

      // Process each item according to the provided function
      for (int i = 0; i < itemDocs.length; i++) {
        final doc = itemDocs[i];
        if (!doc.exists) continue;

        final item = ManifestItem.fromFirestore(doc);

        // Skip items from other organizations
        if (item.organizationId != org.id) continue;

        final amount = amounts[i];

        // Apply the custom processing function
        await processItem(item, amount, batch);
      }

      // Commit the batch if not empty
      if (batch.length > 0) {
        await batch.commit();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error processing batch item update: $e');
      rethrow;
    }
  }

  //
  // Authentication and validation helpers
  //

  /// Validates user is authenticated and returns the user object
  Future<User> _requireUser() async {
    final user = _auth.currentUser;
    if (user == null) throw 'Not authenticated';
    return user;
  }

  /// Validates and returns the current user's organization
  Future<Organization> _requireOrganization() async {
    final org = await _organizationService.getCurrentUserOrganization();
    if (org == null) throw 'Organization not found';
    return org;
  }

  /// Validates both user and organization in one call
  Future<(User, Organization)> _requireUserAndOrg() async {
    final user = await _requireUser();
    final org = await _requireOrganization();
    return (user, org); // Dart 3.0 tuples
  }

  /// Validates item exists and returns it
  Future<ManifestItem> getItem(String itemId) async {
    final docSnapshot = await _manifestItemsCollection.doc(itemId).get();
    if (!docSnapshot.exists) {
      throw 'Manifest item not found';
    }
    return ManifestItem.fromFirestore(docSnapshot);
  }

  /// Validates item belongs to organization and returns it
  Future<ManifestItem> validateItemOwnership(String itemId, String orgId) async {
    final item = await getItem(itemId);
    if (item.organizationId != orgId) {
      throw 'Manifest item belongs to another organization';
    }
    return item;
  }

  //
  // Query helpers
  //

  /// Creates a base query for event items with organization filtering
  Query<Map<String, dynamic>> _baseEventQuery(String eventId, String orgId) {
    return _manifestItemsCollection
        .where('eventId', isEqualTo: eventId)
        .where('organizationId', isEqualTo: orgId);
  }

  /// Creates a query for items in specific stages
  Query<Map<String, dynamic>> _stageFilteredQuery(
      Query<Map<String, dynamic>> baseQuery, List<Stage> stages) {
    final stageStrings = stages.map(ManifestItem.stageToString).toList();
    return baseQuery.where('currentStage', whereIn: stageStrings);
  }

  /// Helper for safer stream generation with consistent error handling
  Stream<T> _safeStream<T>(
      String operationName,
      Future<Stream<T>> Function() streamFunction,
      T defaultValue
      ) async* {
    try {
      yield* await streamFunction();
    } catch (e) {
      debugPrint('Error $operationName: $e');
      yield defaultValue;
    }
  }
}