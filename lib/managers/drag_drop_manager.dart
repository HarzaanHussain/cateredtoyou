import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/services/manifest_service.dart';

class DragDropManager {
  final BuildContext context;

  // Temporary state during drag operations
  List<ManifestItem>? _draggingItems;
  List<int>? _draggingQuantities;
  String? _draggingEventId;

  DragDropManager(this.context);

  // Improved method to handle drag start with proper event ID extraction
  void handleItemDragStart(List<ManifestItem> items, List<int> quantities, String eventId) {
    // Validate inputs before storing
    if (items.isEmpty || quantities.isEmpty || eventId.isEmpty) {
      debugPrint('Invalid drag start data');
      return;
    }

    _draggingItems = items;
    _draggingQuantities = quantities;
    _draggingEventId = eventId;

    // Log for debugging
    debugPrint('Starting drag with ${items.length} items from event $eventId');
  }

  // Updated to handle manifest creation more reliably
  Future<void> handleItemDropOnVehicle(String vehicleId) async {
    if (_draggingItems == null || _draggingQuantities == null || _draggingEventId == null) {
      debugPrint('Missing drag data');
      return;
    }

    if (_draggingItems!.isEmpty || _draggingQuantities!.isEmpty) {
      debugPrint('Empty drag data');
      return;
    }

    final manifestService = Provider.of<ManifestService>(context, listen: false);

    try {
      // Get all manifests first
      final manifests = await manifestService.getManifests().first;
      Manifest? targetManifest;

      // Find the manifest with the matching eventId
      for (var manifest in manifests) {
        if (manifest.eventId == _draggingEventId) {
          targetManifest = manifest;
          break;
        }
      }

      if (targetManifest == null) {
        // Create a new manifest if none exists
        final List<ManifestItem> itemsToCreate = [];

        for (int i = 0; i < _draggingItems!.length; i++) {
          final item = _draggingItems![i];
          final quantity = _draggingQuantities![i];

          if (quantity <= 0) continue;

          // Create a new item with the assigned vehicle
          itemsToCreate.add(ManifestItem(
            id: '${item.id}_${DateTime.now().millisecondsSinceEpoch}',
            menuItemId: item.menuItemId,
            name: item.name,
            quantity: quantity,
            vehicleId: vehicleId,
            loadingStatus: LoadingStatus.pending,
          ));
        }

        // Create the manifest with these items
        await manifestService.createManifest(
          eventId: _draggingEventId!,
          items: itemsToCreate,
        );

        // Show success message
        _showSuccessMessage('Items assigned to vehicle');
      } else {
        // Process each dragged item for an existing manifest
        int successCount = 0;

        for (int i = 0; i < _draggingItems!.length; i++) {
          final item = _draggingItems![i];
          final quantity = _draggingQuantities![i];

          if (quantity <= 0) continue;

          // Find if this item already exists in the manifest
          final existingItemIndex = targetManifest.items.indexWhere(
                  (planItem) => planItem.id == item.id
          );

          if (existingItemIndex >= 0) {
            // If the item exists, update its vehicle and status
            if (quantity >= item.quantity) {
              await manifestService.assignVehicleToItem(
                manifestId: targetManifest.id,
                manifestItemId: item.id,
                vehicleId: vehicleId,
              );
              successCount++;
            } else {
              // Handle partial loading
              await _handlePartialLoading(
                  manifestService,
                  targetManifest,
                  item,
                  vehicleId,
                  quantity
              );
              successCount++;
            }
          } else {
            // If the item doesn't exist, add it to the manifest
            final updatedItems = List<ManifestItem>.from(targetManifest.items);

            final newItem = ManifestItem(
              id: '${item.id}_${DateTime.now().millisecondsSinceEpoch}',
              menuItemId: item.menuItemId,
              name: item.name,
              quantity: quantity,
              vehicleId: vehicleId,
              loadingStatus: LoadingStatus.pending,
            );

            updatedItems.add(newItem);

            final updatedManifest = targetManifest.copyWith(items: updatedItems);
            await manifestService.updateManifest(updatedManifest);
            successCount++;
          }
        }

        // Show success message with count
        _showSuccessMessage('$successCount ${successCount == 1 ? 'item' : 'items'} assigned to vehicle');
      }
    } catch (e) {
      _showErrorMessage('Error assigning items: $e');
    } finally {
      // Clear drag state
      _clearDragState();
    }
  }

  // Handles partial loading of an item
  Future<void> _handlePartialLoading(
      ManifestService manifestService,
      Manifest manifest,
      ManifestItem item,
      String vehicleId,
      int quantity
      ) async {
    try {
      // Create a copy of the item with the assigned quantity
      final assignedItem = ManifestItem(
        id: '${item.id}_assigned_${DateTime.now().millisecondsSinceEpoch}',
        menuItemId: item.menuItemId,
        name: item.name,
        quantity: quantity,
        vehicleId: vehicleId,
        loadingStatus: LoadingStatus.pending,
      );

      // Update the original item with reduced quantity
      final remainingItem = ManifestItem(
        id: item.id,
        menuItemId: item.menuItemId,
        name: item.name,
        quantity: item.quantity - quantity,
        vehicleId: item.vehicleId,
        loadingStatus: item.loadingStatus,
      );

      // Create a new list of items for the updated manifest
      final updatedItems = List<ManifestItem>.from(manifest.items);

      // Find the index of the original item
      final itemIndex = updatedItems.indexWhere((i) => i.id == item.id);

      // Replace the original item with the remaining item
      updatedItems[itemIndex] = remainingItem;

      // Add the assigned item
      updatedItems.add(assignedItem);

      // Create an updated manifest
      final updatedManifest = manifest.copyWith(items: updatedItems);

      // Update the manifest
      await manifestService.updateManifest(updatedManifest);
    } catch (e) {
      debugPrint('Error handling partial loading: $e');
      rethrow;
    }
  }

  // Coordinates removal of an item from a vehicle
  Future<void> removeItemFromVehicle(ManifestItem item) async {
    try {
      final manifestService = Provider.of<ManifestService>(context, listen: false);

      // Find the manifest that contains this item
      final manifests = await manifestService.getManifests().first;

      for (var manifest in manifests) {
        final itemIndex = manifest.items.indexWhere((planItem) => planItem.id == item.id);

        if (itemIndex >= 0) {
          // Create a modified manifest with updated vehicle ID
          final updatedItems = List<ManifestItem>.from(manifest.items);
          final updatedItem = ManifestItem(
            id: item.id,
            menuItemId: item.menuItemId,
            name: item.name,
            quantity: item.quantity,
            vehicleId: null, // Remove vehicle assignment
            loadingStatus: LoadingStatus.unassigned,
          );

          updatedItems[itemIndex] = updatedItem;

          final updatedManifest = manifest.copyWith(items: updatedItems);
          await manifestService.updateManifest(updatedManifest);

          _showSuccessMessage('Item removed from vehicle');
          break;
        }
      }
    } catch (e) {
      _showErrorMessage('Error removing item: $e');
    }
  }

  // Updates the loading status of an item
  Future<void> updateItemLoadingStatus(ManifestItem item, LoadingStatus newStatus) async {
    try {
      final manifestService = Provider.of<ManifestService>(context, listen: false);

      // Find the manifest that contains this item
      final manifests = await manifestService.getManifests().first;

      for (var manifest in manifests) {
        final itemIndex = manifest.items.indexWhere((planItem) => planItem.id == item.id);

        if (itemIndex >= 0) {
          // Create a modified manifest with updated status
          final updatedItems = List<ManifestItem>.from(manifest.items);
          final updatedItem = ManifestItem(
            id: item.id,
            menuItemId: item.menuItemId,
            name: item.name,
            quantity: item.quantity,
            vehicleId: item.vehicleId,
            loadingStatus: newStatus,
          );

          updatedItems[itemIndex] = updatedItem;

          final updatedManifest = manifest.copyWith(items: updatedItems);
          await manifestService.updateManifest(updatedManifest);

          _showSuccessMessage('Item status updated');
          break;
        }
      }
    } catch (e) {
      _showErrorMessage('Error updating item status: $e');
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
}