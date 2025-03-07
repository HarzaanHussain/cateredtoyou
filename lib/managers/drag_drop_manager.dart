import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/services/manifest_service.dart';
import 'package:collection/collection.dart';

class DragDropManager {
  final BuildContext context;

  // Temporary state during drag operations
  List<EventManifestItem>? _draggingItems;
  List<int>? _draggingQuantities;
  String? _draggingEventId;

  DragDropManager(this.context);

  // Handle drag start with proper event ID extraction
  void handleItemDragStart(List<EventManifestItem> items, List<int> quantities, String eventId) {
    // Validate inputs before storing
  if (items.isEmpty || quantities.isEmpty || eventId.isEmpty) {
    debugPrint('Invalid drag start data: items=${items.length}, quantities=${quantities.length}, eventId=$eventId');
      return;
    }

    _draggingItems = items;
    _draggingQuantities = quantities;
    _draggingEventId = eventId;

    // Log for debugging
    debugPrint('Starting drag with ${items.length} items from event $eventId with items of type ${items.first.runtimeType}');
  }

  // Handle dropping items on a vehicle
  Future<void> handleItemDropOnVehicle(String vehicleId) async {
    debugPrint('handleItemDropOnVehicle called for vehicleId: $vehicleId');

    if (_draggingItems == null || _draggingQuantities == null || _draggingEventId == null) {
      debugPrint('Missing drag data: items=$_draggingItems, quantities=$_draggingQuantities, eventId=$_draggingEventId');
      return;
    }

    if (_draggingItems!.isEmpty || _draggingQuantities!.isEmpty) {
      debugPrint('Empty drag data');
      return;
    }

    debugPrint('Dragging data looks good. EventId: $_draggingEventId');

    final manifestService = Provider.of<ManifestService>(context, listen: false);

    try {
      debugPrint('Calling moveEventItemsToDelivery...');

      // Call moveEventItemsToDelivery to handle the manifest creation/updating
      await manifestService.moveEventItemsToDelivery(
        eventId: _draggingEventId!,
        vehicleId: vehicleId,
        eventItems: _draggingItems!.cast<EventManifestItem>(),
        quantities: _draggingQuantities!,
      );

      _showSuccessMessage('Items assigned to vehicle');
    } catch (e) {
      debugPrint('Exception during handleItemDropOnVehicle: $e');
      _showErrorMessage('Error assigning items: $e');
    } finally {
      debugPrint('Clearing drag state.');
      _clearDragState();
    }
  }

  // Helper method to update an EventManifestItem's quantity
  Future<void> _updateEventManifestItemQuantity(
      ManifestService manifestService,
      EventManifest manifest,
      EventManifestItem item,
      int newQuantity,
      ) async {
    try {
      final updatedItems = List<EventManifestItem>.from(manifest.items);

      // Only match by menuItemId — eventId is implied by the manifest itself
      final itemIndex = updatedItems.indexWhere((i) => i.menuItemId == item.menuItemId);

      if (itemIndex >= 0) {
        updatedItems[itemIndex] = EventManifestItem(
          menuItemId: item.menuItemId,
          name: item.name,
          originalQuantity: item.originalQuantity,
          quantityRemaining: newQuantity,
          storageLocationId: item.storageLocationId,
          readiness: item.readiness,
        );

        final updatedManifest = EventManifest(
          id: manifest.id,
          eventId: manifest.eventId,
          organizationId: manifest.organizationId,
          items: updatedItems,
          createdAt: manifest.createdAt,
          updatedAt: DateTime.now(),
        );

        await manifestService.updateManifest(updatedManifest);
      } else {
        debugPrint('Item with menuItemId ${item.menuItemId} not found in event ${manifest.eventId}');
      }
    } catch (e) {
      debugPrint('Error updating item quantity: $e');
      rethrow;
    }
  }


  // Remove an item from a vehicle
  Future<void> removeItemFromVehicle(DeliveryManifestItem item) async {
    try {
      final manifestService = Provider.of<ManifestService>(context, listen: false);

      // Get all manifests (both delivery and event manifests)
      final manifests = await manifestService.getManifests().first;

      // Find the delivery manifest containing this item
      final deliveryManifest = manifests
          .whereType<DeliveryManifest>()
          .firstWhereOrNull((manifest) =>
          manifest.items.any((manifestItem) => manifestItem.menuItemId == item.menuItemId));

      if (deliveryManifest == null) {
        _showErrorMessage('Item not found in any delivery manifest.');
        return;
      }

      // Remove the item from the delivery manifest
      final updatedDeliveryItems = deliveryManifest.items
          .where((manifestItem) => manifestItem.menuItemId != item.menuItemId)
          .toList();

      final updatedDeliveryManifest = deliveryManifest.copyWith(
        items: updatedDeliveryItems,
        updatedAt: DateTime.now(),
      );

      await manifestService.updateManifest(updatedDeliveryManifest);

      // Find the original event manifest for this event
      final eventManifest = manifests
          .whereType<EventManifest>()
          .firstWhereOrNull((manifest) =>
      manifest.eventId == deliveryManifest.eventId);

      if (eventManifest == null) {
        _showErrorMessage('Original event manifest not found for event ${deliveryManifest.eventId}');
        return;
      }

      // Find the matching item in the event manifest (by menuItemId)
      final eventItemIndex = eventManifest.items
          .indexWhere((eventItem) => eventItem.menuItemId == item.menuItemId);

      if (eventItemIndex < 0) {
        _showErrorMessage('Item not found in original event manifest.');
        return;
      }

      // Update the event manifest item's quantityRemaining (return the item)
      final eventItem = eventManifest.items[eventItemIndex];
      final updatedEventItem = eventItem.copyWith(
        quantityRemaining: eventItem.quantityRemaining + item.quantity,
      );

      final updatedEventItems = List<EventManifestItem>.from(eventManifest.items);
      updatedEventItems[eventItemIndex] = updatedEventItem;

      final updatedEventManifest = eventManifest.copyWith(
        items: updatedEventItems,
        updatedAt: DateTime.now(),
      );

      await manifestService.updateManifest(updatedEventManifest);

      _showSuccessMessage('Item removed from vehicle and returned to event manifest.');
    } catch (e) {
      _showErrorMessage('Error removing item: $e');
    }
  }

  // Clears the current drag state
  void _clearDragState() {
    _draggingItems = null;
    _draggingQuantities = null;
    _draggingEventId = null;
  }

  // Helper method to show success messages
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Helper method to show error messages
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Provides the data for dragging
  Map<String, dynamic> getDragData() {
    if (_draggingItems == null || _draggingQuantities == null || _draggingEventId == null) {
      return {};
    }

    return {
      'items': _draggingItems,
      'quantities': _draggingQuantities,
      'eventId': _draggingEventId,
    };
  }

  // Checks if there are items currently being dragged
  bool isDragging() {
    return _draggingItems != null && _draggingQuantities != null && _draggingEventId != null;
  }

  void updateItemReadiness(DeliveryManifestItem item, ItemReadiness newReadiness) {
    void updateItemReadiness(DeliveryManifestItem item, ItemReadiness newReadiness) async {
      try {
        final manifestService = Provider.of<ManifestService>(context, listen: false);

        // Get all manifests (both delivery and event manifests)
        final manifests = await manifestService.getManifests().first;

        // Find the delivery manifest containing this item
        final deliveryManifest = manifests
            .whereType<DeliveryManifest>()
            .firstWhereOrNull((manifest) =>
                manifest.items.any((manifestItem) => manifestItem.menuItemId == item.menuItemId));

        if (deliveryManifest == null) {
          _showErrorMessage('Item not found in any delivery manifest.');
          return;
        }

        // Update the item's readiness in the delivery manifest
        final updatedDeliveryItems = deliveryManifest.items.map((manifestItem) {
          if (manifestItem.menuItemId == item.menuItemId) {
            return manifestItem.copyWith(readiness: newReadiness);
          }
          return manifestItem;
        }).toList();

        final updatedDeliveryManifest = deliveryManifest.copyWith(
          items: updatedDeliveryItems,
          updatedAt: DateTime.now(),
        );

        await manifestService.updateManifest(updatedDeliveryManifest);

        _showSuccessMessage('Item readiness updated successfully.');
      } catch (e) {
        _showErrorMessage('Error updating item readiness: $e');
      }
    }
  }
}