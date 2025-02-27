import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/services/manifest_service.dart';

class DragDropManager {
  final BuildContext context;

  // Temporary state during drag operations
  List<ManifestItem>? _draggingItems;
  List<int>? _draggingQuantities;

  DragDropManager(this.context);

  // Prepares items for dragging
  void handleItemDragStart(List<ManifestItem> items, List<int> quantities) {
    _draggingItems = items;
    _draggingQuantities = quantities;
  }

  // Processes assignment when items are dropped on a vehicle
  Future<void> handleItemDropOnVehicle(String vehicleId) async {
    if (_draggingItems == null || _draggingQuantities == null) {
      debugPrint('No items being dragged');
      return;
    }

    if (_draggingItems!.isEmpty || _draggingQuantities!.isEmpty) {
      debugPrint('Empty drag data');
      return;
    }

    final manifestService = Provider.of<ManifestService>(context, listen: false);

    try {
      // Process each dragged item
      for (int i = 0; i < _draggingItems!.length; i++) {
        final item = _draggingItems![i];
        final quantity = _draggingQuantities![i];

        // Skip if quantity is 0
        if (quantity <= 0) continue;

        // Find the manifest that contains this item
        final manifest = await manifestService.getManifests().first;

        for (var plan in manifest) {
          final itemIndex = plan.items.indexWhere((planItem) => planItem.id == item.id);

          if (itemIndex >= 0) {
            // If we're assigning the full quantity
            if (quantity >= item.quantity) {
              await manifestService.assignVehicleToItem(
                manifestId: plan.id,
                manifestItemId: item.id,
                vehicleId: vehicleId,
              );
            } else {
              // Handle partial loading
              await _handlePartialLoading(
                  manifestService,
                  plan,
                  item,
                  vehicleId,
                  quantity
              );
            }
            break;
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error assigning items: $e')),
      );
    } finally {
      // Clear drag state
      _clearDragState();
    }
  }

  // Handles partial loading of an item
  Future<void> _handlePartialLoading(
      ManifestService manifestService,
      Manifest plan,
      ManifestItem item,
      String vehicleId,
      int quantity
      ) async {
    try {
      // Create a copy of the item with the assigned quantity
      final assignedItem = ManifestItem(
        id: '${item.id}_assigned_${DateTime.now().millisecondsSinceEpoch}',
        menuItemId: item.menuItemId,
        quantity: quantity,
        vehicleId: vehicleId,
        loadingStatus: LoadingStatus.pending,
      );

      // Update the original item with reduced quantity
      final remainingItem = ManifestItem(
        id: item.id,
        menuItemId: item.menuItemId,
        quantity: item.quantity - quantity,
        vehicleId: item.vehicleId,
        loadingStatus: item.loadingStatus,
      );

      // Create a new list of items for the updated plan
      final updatedItems = List<ManifestItem>.from(plan.items);

      // Find the index of the original item
      final itemIndex = updatedItems.indexWhere((i) => i.id == item.id);

      // Replace the original item with the remaining item
      updatedItems[itemIndex] = remainingItem;

      // Add the assigned item
      updatedItems.add(assignedItem);

      // Create an updated plan
      final updatedPlan = plan.copyWith(items: updatedItems);

      // Update the manifest
      await manifestService.updateManifest(updatedPlan);
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
      final manifest = await manifestService.getManifests().first;

      for (var plan in manifest) {
        final itemIndex = plan.items.indexWhere((planItem) => planItem.id == item.id);

        if (itemIndex >= 0) {
          // Create a modified manifest with updated vehicle ID
          final updatedItems = List<ManifestItem>.from(plan.items);
          final updatedItem = ManifestItem(
            id: item.id,
            menuItemId: item.menuItemId,
            quantity: item.quantity,
            vehicleId: null, // Remove vehicle assignment
            loadingStatus: LoadingStatus.unassigned,
          );

          updatedItems[itemIndex] = updatedItem;

          final updatedPlan = plan.copyWith(items: updatedItems);
          await manifestService.updateManifest(updatedPlan);
          break;
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing item: $e')),
      );
    }
  }

  // Updates the loading status of an item
  Future<void> updateItemLoadingStatus(ManifestItem item, LoadingStatus newStatus) async {
    try {
      final manifestService = Provider.of<ManifestService>(context, listen: false);

      // Find the manifest that contains this item
      final manifest = await manifestService.getManifests().first;

      for (var plan in manifest) {
        final itemIndex = plan.items.indexWhere((planItem) => planItem.id == item.id);

        if (itemIndex >= 0) {
          // Create a modified manifest with updated status
          final updatedItems = List<ManifestItem>.from(plan.items);
          final updatedItem = ManifestItem(
            id: item.id,
            menuItemId: item.menuItemId,
            quantity: item.quantity,
            vehicleId: item.vehicleId,
            loadingStatus: newStatus,
          );

          updatedItems[itemIndex] = updatedItem;

          final updatedPlan = plan.copyWith(items: updatedItems);
          await manifestService.updateManifest(updatedPlan);
          break;
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating item status: $e')),
      );
    }
  }

  // Clears the current drag state
  void _clearDragState() {
    _draggingItems = null;
    _draggingQuantities = null;
  }

  // Provides the data for dragging
  Map<String, dynamic> getDragData() {
    if (_draggingItems == null || _draggingQuantities == null) {
      return {};
    }

    return {
      'items': _draggingItems,
      'quantities': _draggingQuantities,
    };
  }

  // Checks if there are items currently being dragged
  bool isDragging() {
    return _draggingItems != null && _draggingQuantities != null;
  }
}