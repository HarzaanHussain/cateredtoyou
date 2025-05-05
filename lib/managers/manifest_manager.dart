import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/manifest_item_model.dart';
import '../models/event_model.dart';
import '../services/manifest_item_service.dart';
import '../services/organization_service.dart';
import '../services/event_service.dart';

/// Manager class for high-level manifest operations and business logic
class ManifestManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ManifestItemService _manifestItemService;
  final OrganizationService _organizationService;
  final EventService _eventService;

  ManifestManager(
      this._manifestItemService,
      this._organizationService,
      this._eventService,
      );

  /// Generates manifest items from an event's menu items and supplies
  Future<List<ManifestItem>> generateManifestItemsFromEvent(String eventId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'Not authenticated';
      }

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found';
      }

      // Get the event to access its menu items
      final event = await _eventService.getEventById(eventId);
      if (event == null) {
        throw 'Event not found';
      }

      // Check if there are already manifest items for this event
      final existingItems = await _firestore
          .collection('manifestItems')
          .where('eventId', isEqualTo: eventId)
          .get();

      if (existingItems.docs.isNotEmpty) {
        throw 'Manifest items already exist for this event';
      }

      final List<ManifestItem> itemsToCreate = [];
      final now = DateTime.now();

      // Process menu items
      for (final EventMenuItem menuItem in event.menuItems) {
        final newItem = ManifestItem(
          id: "", // Service will generate ID
          eventId: eventId,
          itemId: menuItem.menuItemId,
          itemName: menuItem.name,
          originalAmount: menuItem.quantity,
          currentAmount: menuItem.quantity,
          currentStage: Stage.prep,
          status: null,
          assignedAmount: 0,
          loadedAmount: 0,
          vehicleId: null,
          lastUpdatedBy: currentUser.uid,
          lastUpdatedAt: now,
          organizationId: organization.id,
          notes: menuItem.specialInstructions,
        );

        itemsToCreate.add(newItem);
      }

      // Process supplies
      for (final EventSupply supply in event.supplies) {
        final newItem = ManifestItem(
          id: "", // Service will generate ID
          eventId: eventId,
          itemId: supply.inventoryId,
          itemName: '${supply.name} (${supply.unit})',
          originalAmount: supply.quantity.toInt(),
          currentAmount: supply.quantity.toInt(),
          currentStage: Stage.prep,
          status: null,
          assignedAmount: 0,
          loadedAmount: 0,
          vehicleId: null,
          lastUpdatedBy: currentUser.uid,
          lastUpdatedAt: now,
          organizationId: organization.id,
          notes: null,
        );

        itemsToCreate.add(newItem);
      }

      // Use service to batch create all items
      return await _manifestItemService.batchCreateManifestItems(itemsToCreate);
    } catch (e) {
      debugPrint('Error generating manifest items from event: $e');
      rethrow;
    }
  }

  /// Deletes all manifest items for an event
  Future<void> deleteManifestItemsForEvent(String eventId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'Not authenticated';
      }

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found';
      }

      // Get all items for this event
      final querySnapshot = await _firestore
          .collection('manifestItems')
          .where('eventId', isEqualTo: eventId)
          .where('organizationId', isEqualTo: organization.id)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return; // No items to delete
      }

      // Extract item IDs
      final itemIds = querySnapshot.docs.map((doc) => doc.id).toList();

      // Use service to batch delete
      await _manifestItemService.batchDeleteManifestItems(itemIds);
    } catch (e) {
      debugPrint('Error deleting manifest for event: $e');
      rethrow;
    }
  }

  /// Batch update status/quantity for multiple items and advance stage if appropriate
  Future<void> updatePrep(
      List<String> itemIds,
      List<ItemStatus> statuses,
      List<int> amounts
      ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'Not authenticated';
      }

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found';
      }

      // Validate lists
      if (itemIds.length != statuses.length || itemIds.length != amounts.length) {
        throw 'Item IDs, statuses, and amounts must have matching length';
      }

      if (itemIds.isEmpty) {
        return;
      }

      // Get all items
      final itemDocs = await Future.wait(
          itemIds.map((id) => _firestore.collection('manifestItems').doc(id).get())
      );

      // Create map of item ID to status and amount for efficient lookup
      final Map<String, (ItemStatus, int)> updates = {};
      for (int i = 0; i < itemIds.length; i++) {
        updates[itemIds[i]] = (statuses[i], amounts[i]);
      }

      // Prepare items for update or deletion
      final List<String> itemsToDelete = [];
      final List<ManifestItem> itemsToUpdate = [];

      for (final doc in itemDocs) {
        if (!doc.exists) continue;

        final item = ManifestItem.fromFirestore(doc);

        // Org check
        if (item.organizationId != organization.id) {
          continue;
        }

        final update = updates[item.id];
        if (update == null) continue;

        final (status, amount) = update;

        if (amount > item.originalAmount) {
          debugPrint(
              'Warning: Amount $amount exceeds original amount ${item.originalAmount} and will be skipped.'
          );
          continue;
        }

        // Handle deletes vs updates
        if (amount == 0) {
          itemsToDelete.add(item.id);
        } else {
          // Apply business logic: advance to assign stage if currently in prep
          final updatedItem = item.copyWith(
            currentAmount: amount,
            status: status,
            currentStage: item.currentStage == Stage.prep ? Stage.assign : item.currentStage,
          );

          itemsToUpdate.add(updatedItem);
        }
      }

      // Process deletes
      if (itemsToDelete.isNotEmpty) {
        await _manifestItemService.batchDeleteManifestItems(itemsToDelete);
      }

      // Process updates through transactional updates
      for (final item in itemsToUpdate) {
        await _manifestItemService.transactionalUpdateManifestItem(item);
      }
    } catch (e) {
      debugPrint('Error in updatePrep: $e');
      rethrow;
    }
  }

  /// Batch assign multiple items to a single vehicle
  Future<void> assignItemsToVehicle(
      List<String> itemIds,
      List<int> amounts,
      String vehicleId,
      ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'Not authenticated';
      }

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found';
      }

      // Validate lists have matching length
      if (itemIds.length != amounts.length) {
        throw 'Item IDs and amounts must have matching length';
      }

      if (itemIds.isEmpty) {
        return;
      }

      // Validate vehicle exists and belongs to organization
      final vehicleDoc = await _firestore.collection('vehicles')
          .doc(vehicleId)
          .get();

      if (!vehicleDoc.exists) {
        throw 'Vehicle not found';
      }

      final vehicleData = vehicleDoc.data() as Map<String, dynamic>;
      if (vehicleData['organizationId'] != organization.id) {
        throw 'Vehicle belongs to another organization';
      }

      // Process assign operations using the service's batch update processor
      await _manifestItemService.processBatchItemUpdate(
        itemIds,
        amounts,
            (item, amount, batch) async {
          // Skip invalid assignments
          if (amount <= 0 || amount > item.currentAmount) {
            return;
          }

          // If assigning partial amount, split the item
          if (amount < item.currentAmount) {
            await _manifestItemService.splitItem(
              item.id,
              amount,
              vehicleId: vehicleId,
              newStage: Stage.load,
            );
          } else {
            // Direct update for full amount assignment
            final updatedItem = item.copyWith(
              vehicleId: vehicleId,
              assignedAmount: amount,
              currentStage: Stage.load,
            );

            await _manifestItemService.transactionalUpdateManifestItem(updatedItem);
          }
        },
      );
    } catch (e) {
      debugPrint('Error in assignItemsToVehicle: $e');
      rethrow;
    }
  }

  /// Mark multiple items as loaded
  Future<void> markItemsAsLoaded(
      List<String> itemIds,
      List<int> amounts
      ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'Not authenticated';
      }

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found';
      }

      // Validate lists have matching length
      if (itemIds.length != amounts.length) {
        throw 'Item IDs and amounts must have matching length';
      }

      // Track warnings
      final List<String> warnings = [];

      // Process load operations using the service's batch update processor
      await _manifestItemService.processBatchItemUpdate(
        itemIds,
        amounts,
            (item, amount, batch) async {
          // Check if item is still in prep stage
          if (item.currentStage == Stage.prep) {
            warnings.add('Warning: Item "${item.itemName}" is still in prep stage');
          }

          // Validate if assigned to a vehicle
          if (item.vehicleId == null) {
            warnings.add('Warning: Item "${item.itemName}" is not assigned to a vehicle');
            return; // Skip this item
          }

          // Check if loading amount exceeds assigned amount
          if (amount > item.assignedAmount) {
            warnings.add(
                'Warning: Loading more "${item.itemName}" than assigned (${amount} > ${item.assignedAmount})'
            );
          }

          // Skip invalid loads
          if (amount <= 0 || amount > item.assignedAmount) {
            return;
          }

          // If loading partial amount, split the item
          if (amount < item.assignedAmount) {
            await _manifestItemService.splitItem(
                item.id,
                amount,
                newStage: Stage.deliver
            );
          } else {
            // Direct update for full amount loading
            final updatedItem = item.copyWith(
              loadedAmount: amount,
              currentStage: Stage.deliver,
            );

            await _manifestItemService.transactionalUpdateManifestItem(updatedItem);
          }
        },
      );

      // Print warnings if any
      if (warnings.isNotEmpty) {
        debugPrint('Loading warnings: ${warnings.join(', ')}');
      }
    } catch (e) {
      debugPrint('Error in markItemsAsLoaded: $e');
      rethrow;
    }
  }

  /// Mark all items for a vehicle as loaded
  Future<void> markAllVehicleItemsAsLoaded(String vehicleId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'Not authenticated';
      }

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found';
      }

      // Get all assigned items for this vehicle
      final itemsSnapshot = await _firestore
          .collection('manifestItems')
          .where('vehicleId', isEqualTo: vehicleId)
          .where('currentStage', isEqualTo: ManifestItem.stageToString(Stage.assign))
          .where('organizationId', isEqualTo: organization.id)
          .get();

      if (itemsSnapshot.docs.isEmpty) {
        return; // No items to load
      }

      final List<String> itemIds = [];
      final List<int> amounts = [];

      for (final doc in itemsSnapshot.docs) {
        final item = ManifestItem.fromFirestore(doc);
        itemIds.add(item.id);
        amounts.add(item.assignedAmount);
      }

      // Use existing function to mark all as loaded
      await markItemsAsLoaded(itemIds, amounts);
    } catch (e) {
      debugPrint('Error marking all vehicle items as loaded: $e');
      rethrow;
    }
  }

  /// Advance all loaded items to delivery stage
  Future<void> advanceToDeliveryStage(String vehicleId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'Not authenticated';
      }

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found';
      }

      // Get all loaded items for this vehicle
      final itemsSnapshot = await _firestore
          .collection('manifestItems')
          .where('vehicleId', isEqualTo: vehicleId)
          .where('currentStage', isEqualTo: ManifestItem.stageToString(Stage.load))
          .where('organizationId', isEqualTo: organization.id)
          .get();

      if (itemsSnapshot.docs.isEmpty) {
        return; // No items to advance
      }

      // Prepare updates with business logic applied
      final List<ManifestItem> itemsToUpdate = [];

      for (final doc in itemsSnapshot.docs) {
        final item = ManifestItem.fromFirestore(doc);

        // Apply business logic: advance from load to deliver stage
        final updatedItem = item.copyWith(
          currentStage: Stage.deliver,
        );

        itemsToUpdate.add(updatedItem);
      }

      // Update each item transactionally
      for (final item in itemsToUpdate) {
        await _manifestItemService.transactionalUpdateManifestItem(item);
      }
    } catch (e) {
      debugPrint('Error advancing to delivery stage: $e');
      rethrow;
    }
  }

  /// Get loadable items for a specific vehicle
  Stream<List<ManifestItem>> getLoadableItemsForVehicle(String vehicleId) {
    return _manifestItemService.getLoadableItemsForVehicle(vehicleId);
  }

  //
  // Helper methods for specific operations
  //

  /// Update the status and quantity of a single item
  Future<void> updateItemStatus(String itemId, ItemStatus status, int amount) async {
    try {
      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found';
      }

      // Get the item
      final item = await _manifestItemService.getItem(itemId);

      // Verify ownership
      if (item.organizationId != organization.id) {
        throw 'Item belongs to another organization';
      }

      // Validate amount
      if (amount > item.originalAmount) {
        throw 'Amount cannot exceed original amount';
      }

      // If the amount is 0, delete the item
      if (amount == 0) {
        await _manifestItemService.batchDeleteManifestItems([itemId]);
        return;
      }

      // Update the item with new status and amount
      final updatedItem = item.copyWith(
        status: status,
        currentAmount: amount,
      );

      await _manifestItemService.transactionalUpdateManifestItem(updatedItem);
    } catch (e) {
      debugPrint('Error updating item status: $e');
      rethrow;
    }
  }

  /// Update the preparation status and advance to the next stage if applicable
  Future<void> updateItemPrep(String itemId, ItemStatus status, int amount) async {
    try {
      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found';
      }

      // Get the item
      final item = await _manifestItemService.getItem(itemId);

      // Verify ownership
      if (item.organizationId != organization.id) {
        throw 'Item belongs to another organization';
      }

      // Apply business logic: update status and amount, and advance stage if in prep
      final updatedItem = item.copyWith(
        status: status,
        currentAmount: amount,
        currentStage: item.currentStage == Stage.prep ? Stage.assign : item.currentStage,
      );

      // If amount is now 0, delete the item
      if (amount == 0) {
        await _manifestItemService.batchDeleteManifestItems([itemId]);
      } else {
        await _manifestItemService.transactionalUpdateManifestItem(updatedItem);
      }
    } catch (e) {
      debugPrint('Error updating item prep: $e');
      rethrow;
    }
  }

  /// Assign a single item to a vehicle with a specified amount
  Future<void> assignToVehicle(String itemId, String vehicleId, int amount) async {
    try {
      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found';
      }

      // Get the item
      final item = await _manifestItemService.getItem(itemId);

      // Verify ownership
      if (item.organizationId != organization.id) {
        throw 'Item belongs to another organization';
      }

      // Validate assignment amount
      if (amount > item.currentAmount) {
        throw 'Assignment amount cannot exceed current amount';
      }

      // If assigning partial amount, split the item
      if (amount < item.currentAmount) {
        await _manifestItemService.splitItem(
            itemId,
            amount,
            vehicleId: vehicleId,
            newStage: Stage.assign
        );
      } else {
        // Assign full amount
        final updatedItem = item.copyWith(
          vehicleId: vehicleId,
          assignedAmount: amount,
          currentStage: Stage.assign,
        );

        await _manifestItemService.transactionalUpdateManifestItem(updatedItem);
      }
    } catch (e) {
      debugPrint('Error assigning item to vehicle: $e');
      rethrow;
    }
  }

  /// Mark a single item as loaded with a specified amount
  Future<void> markAsLoaded(String itemId, int amount) async {
    try {
      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found';
      }

      // Get the item
      final item = await _manifestItemService.getItem(itemId);

      // Verify ownership
      if (item.organizationId != organization.id) {
        throw 'Item belongs to another organization';
      }

      // Validate the vehicleId exists
      if (item.vehicleId == null) {
        throw 'Item must be assigned to a vehicle first';
      }

      // Validate load amount
      if (amount > item.assignedAmount) {
        throw 'Load amount cannot exceed assigned amount';
      }

      // If loading partial amount, split the item
      if (amount < item.assignedAmount) {
        await _manifestItemService.splitItem(
            itemId,
            amount,
            newStage: Stage.load
        );
      } else {
        // Load full amount
        final updatedItem = item.copyWith(
          loadedAmount: amount,
          currentStage: Stage.load,
        );

        await _manifestItemService.transactionalUpdateManifestItem(updatedItem);
      }
    } catch (e) {
      debugPrint('Error marking item as loaded: $e');
      rethrow;
    }
  }
}