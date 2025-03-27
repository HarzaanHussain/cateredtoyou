import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/services/manifest_service.dart';

/// Helper class to manage drag and drop operations between manifests and vehicles
///
/// This class centralizes all drag and drop operations, provides proper error handling,
/// and manages the state necessary for dragging operations.
class DragDropManager {
  final BuildContext context;
  
  // Items being dragged
  List<ManifestItem>? _items;
  List<int>? _quantities;
  String? _manifestId;
  
  // Callback for successful operations
  final Function(String)? onSuccess;
  
  // Constructor
  DragDropManager(this.context, {this.onSuccess});
  
  /// Start dragging items
  void startDrag(List<ManifestItem> items, List<int> quantities, String manifestId) {
    _items = items;
    _quantities = quantities;
    _manifestId = manifestId;
  }
  
  /// Drop items on a vehicle
  Future<bool> dropOnVehicle(String vehicleId) async {
    if (_items == null || _quantities == null || _manifestId == null) {
      debugPrint('DragDropManager: No items being dragged');
      return false;
    }
    
    if (_items!.isEmpty) {
      debugPrint('DragDropManager: Empty items list');
      return false;
    }
    
    try {
      final manifestService = Provider.of<ManifestService>(context, listen: false);
      
      // Get the manifest
      final manifestStream = manifestService.getManifestById(_manifestId!);
      final manifest = await manifestStream.first;
      
      if (manifest == null) {
        throw Exception('Manifest not found');
      }
      
      // Create a copy of the items to update
      final updatedItems = List<ManifestItem>.from(manifest.items);
      bool anyUpdated = false;
      
      // Update each dragged item
      for (int i = 0; i < _items!.length; i++) {
        final item = _items![i];
        final quantity = _quantities![i];
        
        // Find the item index
        final itemIndex = updatedItems.indexWhere((manifestItem) => manifestItem.id == item.id);
        
        if (itemIndex != -1) {
          // Replace with updated item
          updatedItems[itemIndex] = ManifestItem(
            id: item.id,
            name: item.name,
            menuItemId: item.menuItemId,
            quantity: quantity,
            vehicleId: vehicleId,
            loadingStatus: LoadingStatus.pending,
          );
          anyUpdated = true;
        }
      }
      
      if (!anyUpdated) {
        debugPrint('DragDropManager: No items were updated');
        return false;
      }
      
      // Create updated manifest
      final updatedManifest = Manifest(
        id: manifest.id,
        eventId: manifest.eventId,
        organizationId: manifest.organizationId,
        items: updatedItems,
        createdAt: manifest.createdAt,
        updatedAt: DateTime.now(),
      );
      
      // Update the manifest
      await manifestService.updateManifest(updatedManifest);
      
      // Call success callback if provided
      if (onSuccess != null && context.mounted) {
        onSuccess!(vehicleId);
      }
      
      // Reset drag state
      _resetDragState();
      return true;
    } catch (e) {
      debugPrint('DragDropManager: Error assigning items - $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning items: $e')),
        );
      }
      return false;
    }
  }
  
  /// Remove an item from a vehicle
  Future<bool> removeFromVehicle(ManifestItem item) async {
    if (item.vehicleId == null) {
      debugPrint('DragDropManager: Item is not assigned to a vehicle');
      return false;
    }
    
    try {
      final manifestService = Provider.of<ManifestService>(context, listen: false);
      
      // Get the manifest directly if we know its ID
      String manifestId = item.id.split('_').first;
      final manifest = await manifestService.getManifestById(manifestId).first;
      
      if (manifest == null) {
        // Fallback to searching through all manifests
        final manifests = await manifestService.getManifests().first;
        Manifest? targetManifest;
        
        for (final m in manifests) {
          if (m.items.any((manifestItem) => manifestItem.id == item.id)) {
            targetManifest = m;
            break;
          }
        }
        
        if (targetManifest == null) {
          throw Exception('Manifest containing this item not found');
        }
        
        manifestId = targetManifest.id;
      }
      
      // Get manifest items
      final manifestItems = await manifestService.getManifestById(manifestId).first;
      if (manifestItems == null) {
        throw Exception('Could not load manifest items');
      }
      
      // Update the item in the manifest
      final updatedItems = manifestItems.items.map((manifestItem) {
        if (manifestItem.id == item.id) {
          return ManifestItem(
            id: manifestItem.id,
            name: manifestItem.name,
            menuItemId: manifestItem.menuItemId,
            quantity: manifestItem.quantity,
            vehicleId: null, // Remove vehicle assignment
            loadingStatus: LoadingStatus.unassigned, // Reset status
          );
        }
        return manifestItem;
      }).toList();
      
      // Create updated manifest
      final updatedManifest = Manifest(
        id: manifestItems.id,
        eventId: manifestItems.eventId,
        organizationId: manifestItems.organizationId,
        items: updatedItems,
        createdAt: manifestItems.createdAt,
        updatedAt: DateTime.now(),
      );
      
      // Update the manifest
      await manifestService.updateManifest(updatedManifest);
      
      // Show success message if context is still valid
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item removed from vehicle')),
        );
      }
      
      return true;
    } catch (e) {
      debugPrint('DragDropManager: Error removing item - $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing item: $e')),
        );
      }
      return false;
    }
  }
  
  /// Update item loading status
  Future<bool> updateItemStatus(ManifestItem item, LoadingStatus status) async {
    try {
      final manifestService = Provider.of<ManifestService>(context, listen: false);
      
      // Get the manifest directly if we know its ID
      String manifestId = item.id.split('_').first;
      final manifest = await manifestService.getManifestById(manifestId).first;
      
      if (manifest == null) {
        // Fallback to searching through all manifests
        final manifests = await manifestService.getManifests().first;
        Manifest? targetManifest;
        
        for (final m in manifests) {
          if (m.items.any((manifestItem) => manifestItem.id == item.id)) {
            targetManifest = m;
            break;
          }
        }
        
        if (targetManifest == null) {
          throw Exception('Manifest containing this item not found');
        }
        
        manifestId = targetManifest.id;
      }
      
      // Get manifest items
      final manifestItems = await manifestService.getManifestById(manifestId).first;
      if (manifestItems == null) {
        throw Exception('Could not load manifest items');
      }
      
      // Update the item status
      final updatedItems = manifestItems.items.map((manifestItem) {
        if (manifestItem.id == item.id) {
          return ManifestItem(
            id: manifestItem.id,
            name: manifestItem.name,
            menuItemId: manifestItem.menuItemId,
            quantity: manifestItem.quantity,
            vehicleId: manifestItem.vehicleId,
            loadingStatus: status, // Update the status
          );
        }
        return manifestItem;
      }).toList();
      
      // Create updated manifest
      final updatedManifest = Manifest(
        id: manifestItems.id,
        eventId: manifestItems.eventId,
        organizationId: manifestItems.organizationId,
        items: updatedItems,
        createdAt: manifestItems.createdAt,
        updatedAt: DateTime.now(),
      );
      
      // Update the manifest
      await manifestService.updateManifest(updatedManifest);
      
      // Show success message if context is still valid
      if (context.mounted) {
        final statusName = status == LoadingStatus.loaded ? 'Loaded' : 'Pending';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item status updated to $statusName')),
        );
      }
      
      return true;
    } catch (e) {
      debugPrint('DragDropManager: Error updating status - $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
      return false;
    }
  }
  
  /// Reset the drag state
  void _resetDragState() {
    _items = null;
    _quantities = null;
    _manifestId = null;
  }
  
  /// Get currently dragged items
  List<ManifestItem>? get draggedItems => _items;
  
  /// Get currently dragged quantities
  List<int>? get draggedQuantities => _quantities;
  
  /// Check if an item is being dragged
  bool get isDragging => _items != null && _items!.isNotEmpty;
  
  /// Get total quantity of dragged items
  int get totalDraggedQuantity {
    if (_items == null || _quantities == null || _items!.isEmpty) {
      return 0;
    }
    
    int total = 0;
    for (int i = 0; i < _quantities!.length; i++) {
      total += _quantities![i];
    }
    return total;
  }
}