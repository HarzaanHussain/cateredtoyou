import 'package:cateredtoyou/models/inventory_item_model.dart'; // Import the InventoryItem model
import 'package:flutter/foundation.dart'; // Import foundation for ChangeNotifier
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore for database operations
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth for authentication
import 'package:cateredtoyou/services/organization_service.dart'; // Import OrganizationService for organization-related operations

class InventoryService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance for database operations
  final FirebaseAuth _auth = FirebaseAuth.instance; // FirebaseAuth instance for authentication
  final OrganizationService _organizationService; // OrganizationService instance for organization-related operations
  String? _cachedOrgId; // Cached organization ID to avoid redundant database calls

  InventoryService(this._organizationService); // Constructor to initialize OrganizationService

  Future<String?> _getOrganizationId() async {
    if (_cachedOrgId != null) return _cachedOrgId; // Return cached organization ID if available
    
    final organization = await _organizationService.getCurrentUserOrganization(); // Get current user's organization
    _cachedOrgId = organization?.id; // Cache the organization ID
    return _cachedOrgId; // Return the organization ID
  }

  // Stream inventory items for current organization
  Stream<List<InventoryItem>> getInventoryItems() async* {
    try {
      final orgId = await _getOrganizationId(); // Get organization ID
      if (orgId == null) {
        yield []; // Yield empty list if organization ID is null
        return;
      }

      yield* _firestore
          .collection('inventory') // Access 'inventory' collection
          .where('organizationId', isEqualTo: orgId) // Filter by organization ID
          .snapshots() // Get real-time updates
          .map((snapshot) => snapshot.docs
              .map((doc) => InventoryItem.fromMap(doc.data(), doc.id)) // Map documents to InventoryItem
              .toList()); // Convert to list
    } catch (e) {
      debugPrint('Error in getInventoryItems: $e'); // Print error message
      yield []; // Yield empty list on error
    }
  }

  // Create inventory item
  Future<InventoryItem> createInventoryItem({
    required String name, // Item name
    required InventoryCategory category, // Item category
    required UnitType unit, // Unit type
    required double quantity, // Quantity
    required double reorderPoint, // Reorder point
    required double costPerUnit, // Cost per unit
    String? storageLocationId, // Optional storage location ID
    Map<String, dynamic>? metadata, // Optional metadata
  }) async {
    try {
      final currentUser = _auth.currentUser; // Get current user
      if (currentUser == null) throw 'Not authenticated'; // Throw error if not authenticated

      final orgId = await _getOrganizationId(); // Get organization ID
      if (orgId == null) throw 'Organization not found'; // Throw error if organization not found

      final now = DateTime.now(); // Get current date and time
      final docRef = _firestore.collection('inventory').doc(); // Create new document reference

      final item = InventoryItem(
        id: docRef.id, // Document ID
        name: name, // Item name
        category: category, // Item category
        unit: unit, // Unit type
        quantity: quantity, // Quantity
        reorderPoint: reorderPoint, // Reorder point
        costPerUnit: costPerUnit, // Cost per unit
        storageLocationId: storageLocationId, // Storage location ID
        organizationId: orgId, // Organization ID
        metadata: metadata, // Metadata
        createdAt: now, // Creation timestamp
        updatedAt: now, // Update timestamp
        lastModifiedBy: currentUser.uid, // Last modified by user ID
      );

      await docRef.set(item.toMap()); // Save item to Firestore
      
      // Create inventory transaction record
      await _createInventoryTransaction(
        itemId: docRef.id, // Item ID
        type: 'created', // Transaction type
        quantity: quantity, // Quantity
        previousQuantity: 0, // Previous quantity
        notes: 'Initial inventory creation', // Notes
      );

      notifyListeners(); // Notify listeners of changes
      return item; // Return created item
    } catch (e) {
      debugPrint('Error creating inventory item: $e'); // Print error message
      rethrow; // Rethrow error
    }
  }

  // Update inventory item
  Future<void> updateInventoryItem(InventoryItem item) async {
    try {
      final currentUser = _auth.currentUser; // Get current user
      if (currentUser == null) throw 'Not authenticated'; // Throw error if not authenticated

      final orgId = await _getOrganizationId(); // Get organization ID
      if (orgId == null) throw 'Organization not found'; // Throw error if organization not found
      if (item.organizationId != orgId) {
        throw 'Item belongs to a different organization'; // Throw error if item belongs to a different organization
      }

      // Get the current item to compare quantities
      final currentDoc = await _firestore
          .collection('inventory')
          .doc(item.id)
          .get();

      if (!currentDoc.exists) throw 'Item not found'; // Throw error if item not found
      
      final currentItem = InventoryItem.fromMap(
        currentDoc.data()!, // Get current item data
        currentDoc.id, // Get current item ID
      );

      // Update the item
      final updatedItem = item.copyWith(
        lastModifiedBy: currentUser.uid, // Update last modified by user ID
      );

      await _firestore
          .collection('inventory')
          .doc(item.id)
          .update(updatedItem.toMap()); // Update item in Firestore

      // Create transaction record if quantity changed
      if (currentItem.quantity != item.quantity) {
        await _createInventoryTransaction(
          itemId: item.id, // Item ID
          type: 'updated', // Transaction type
          quantity: item.quantity, // New quantity
          previousQuantity: currentItem.quantity, // Previous quantity
          notes: 'Quantity updated', // Notes
        );
      }

      notifyListeners(); // Notify listeners of changes
    } catch (e) {
      debugPrint('Error updating inventory item: $e'); // Print error message
      rethrow; // Rethrow error
    }
  }

  // Delete inventory item
  Future<void> deleteInventoryItem(String itemId) async {
    try {
      final currentUser = _auth.currentUser; // Get current user
      if (currentUser == null) throw 'Not authenticated'; // Throw error if not authenticated

      final orgId = await _getOrganizationId(); // Get organization ID
      if (orgId == null) throw 'Organization not found'; // Throw error if organization not found

      // Get the item first
      final doc = await _firestore
          .collection('inventory')
          .doc(itemId)
          .get();

      if (!doc.exists) throw 'Item not found'; // Throw error if item not found
      
      final item = InventoryItem.fromMap(doc.data()!, doc.id); // Get item data
      if (item.organizationId != orgId) {
        throw 'Item belongs to a different organization'; // Throw error if item belongs to a different organization
      }

      // Create transaction record before deletion
      await _createInventoryTransaction(
        itemId: itemId, // Item ID
        type: 'deleted', // Transaction type
        quantity: 0, // New quantity
        previousQuantity: item.quantity, // Previous quantity
        notes: 'Item deleted', // Notes
      );

      // Delete the item
      await _firestore
          .collection('inventory')
          .doc(itemId)
          .delete(); // Delete item from Firestore

      notifyListeners(); // Notify listeners of changes
    } catch (e) {
      debugPrint('Error deleting inventory item: $e'); // Print error message
      rethrow; // Rethrow error
    }
  }

  // Adjust inventory quantity
  Future<void> adjustQuantity(
    String itemId,
    double newQuantity, {
    String? notes,
  }) async {
    try {
      final currentUser = _auth.currentUser; // Get current user
      if (currentUser == null) throw 'Not authenticated'; // Throw error if not authenticated

      final orgId = await _getOrganizationId(); // Get organization ID
      if (orgId == null) throw 'Organization not found'; // Throw error if organization not found

      // Get current item
      final doc = await _firestore
          .collection('inventory')
          .doc(itemId)
          .get();

      if (!doc.exists) throw 'Item not found'; // Throw error if item not found
      
      final item = InventoryItem.fromMap(doc.data()!, doc.id); // Get item data
      if (item.organizationId != orgId) {
        throw 'Item belongs to a different organization'; // Throw error if item belongs to a different organization
      }

      // Update quantity
      final updatedItem = item.copyWith(
        quantity: newQuantity, // Update quantity
        lastModifiedBy: currentUser.uid, // Update last modified by user ID
      );

      await _firestore
          .collection('inventory')
          .doc(itemId)
          .update(updatedItem.toMap()); // Update item in Firestore

      // Create transaction record
      await _createInventoryTransaction(
        itemId: itemId, // Item ID
        type: 'adjusted', // Transaction type
        quantity: newQuantity, // New quantity
        previousQuantity: item.quantity, // Previous quantity
        notes: notes ?? 'Quantity adjusted', // Notes
      );

      notifyListeners(); // Notify listeners of changes
    } catch (e) {
      debugPrint('Error adjusting inventory quantity: $e'); // Print error message
      rethrow; // Rethrow error
    }
  }

  // Private method to create inventory transactions
  Future<void> _createInventoryTransaction({
    required String itemId, // Item ID
    required String type, // Transaction type
    required double quantity, // New quantity
    required double previousQuantity, // Previous quantity
    String? notes, // Optional notes
  }) async {
    try {
      final currentUser = _auth.currentUser; // Get current user
      if (currentUser == null) return; // Return if not authenticated

      final now = DateTime.now(); // Get current date and time
      
      await _firestore
          .collection('inventory_transactions') // Access 'inventory_transactions' collection
          .add({
            'itemId': itemId, // Item ID
            'type': type, // Transaction type
            'quantity': quantity, // New quantity
            'previousQuantity': previousQuantity, // Previous quantity
            'difference': quantity - previousQuantity, // Quantity difference
            'timestamp': now, // Timestamp
            'userId': currentUser.uid, // User ID
            'notes': notes, // Notes
          });
    } catch (e) {
      debugPrint('Error creating inventory transaction: $e'); // Print error message
      // Don't rethrow - this is a secondary operation
    }
  }

  // Get low stock items
  Stream<List<InventoryItem>> getLowStockItems() async* {
    try {
      final orgId = await _getOrganizationId(); // Get organization ID
      if (orgId == null) {
        yield []; // Yield empty list if organization ID is null
        return;
      }

      yield* _firestore
          .collection('inventory') // Access 'inventory' collection
          .where('organizationId', isEqualTo: orgId) // Filter by organization ID
          .snapshots() // Get real-time updates
          .map((snapshot) => snapshot.docs
              .map((doc) => InventoryItem.fromMap(doc.data(), doc.id)) // Map documents to InventoryItem
              .where((item) => item.needsReorder) // Filter items that need reorder
              .toList()); // Convert to list
    } catch (e) {
      debugPrint('Error in getLowStockItems: $e'); // Print error message
      yield []; // Yield empty list on error
    }
  }

  // Clear cached organization ID
  void clearCache() {
    _cachedOrgId = null; // Clear cached organization ID
    notifyListeners(); // Notify listeners of changes
  }
}
