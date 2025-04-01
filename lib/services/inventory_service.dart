import 'package:flutter/foundation.dart'; // Importing foundation package for ChangeNotifier
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore package for database operations
import 'package:firebase_auth/firebase_auth.dart'; // Importing Firebase Auth package for authentication
import 'package:cateredtoyou/models/inventory_item_model.dart'; // Importing InventoryItem model
import 'package:cateredtoyou/services/organization_service.dart'; // Importing OrganizationService for dependency injection

class InventoryService extends ChangeNotifier { // InventoryService class extending ChangeNotifier for state management
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance for database operations
  final FirebaseAuth _auth = FirebaseAuth.instance; // FirebaseAuth instance for authentication

  InventoryService(OrganizationService organizationService); // Constructor for dependency injection

  // Stream inventory items for current user's organization only
  Stream<List<InventoryItem>> getInventoryItems() async* { // Method to get inventory items as a stream
    try {
      final currentUser = _auth.currentUser; // Get current authenticated user
      if (currentUser == null) { // If no user is authenticated
        yield []; // Yield an empty list
        return; // Return from the method
      }

      // Get user's organization ID
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get(); // Get user document from Firestore

      if (!userDoc.exists) { // If user document does not exist
        yield []; // Yield an empty list
        return; // Return from the method
      }

      final orgId = userDoc.data()?['organizationId']; // Get organization ID from user document
      if (orgId == null) { // If organization ID is null
        yield []; // Yield an empty list
        return; // Return from the method
      }

      // Cache the organization ID for future use
      debugPrint('Fetching inventory for organization: $orgId'); // Print organization ID for debugging

      // Filter inventory items by organization ID
      yield* _firestore
          .collection('inventory')
          .where('organizationId', isEqualTo: orgId) // Query inventory items by organization ID
          .snapshots() // Get snapshots of the query
          .handleError((error) { // Handle errors in the stream
            debugPrint('Error in inventory stream: $error'); // Print error for debugging
            return []; // Return an empty list on error
          })
          .map((snapshot) { // Map snapshot to list of InventoryItem
            try {
              final items = snapshot.docs
                  .map((doc) => InventoryItem.fromMap(doc.data(), doc.id)) // Convert document to InventoryItem
                  .where((item) => item.organizationId == orgId) // Filter items by organization ID
                  .toList(); // Convert to list
              debugPrint('Found ${items.length} items for organization $orgId'); // Print number of items for debugging
              return items; // Return list of items
            } catch (e) { // Catch any errors
              debugPrint('Error mapping inventory data: $e'); // Print error for debugging
              return []; // Return an empty list on error
            }
          });
    } catch (e) { // Catch any errors
      debugPrint('Error in getInventoryItems: $e'); // Print error for debugging
      yield []; // Yield an empty list on error
    }
  }

  // Create inventory item with strict organization ID validation
  Future<InventoryItem> createInventoryItem({
    required String name, // Required name parameter
    required InventoryCategory category, // Required category parameter
    required UnitType unit, // Required unit parameter
    required double quantity, // Required quantity parameter
    required double reorderPoint, // Required reorder point parameter
    required double costPerUnit, // Required cost per unit parameter
    String? storageLocationId, // Optional storage location ID parameter
    Map<String, dynamic>? metadata, // Optional metadata parameter
  }) async {
    final currentUser = _auth.currentUser; // Get current authenticated user
    if (currentUser == null) throw 'Not authenticated'; // Throw error if no user is authenticated

    // Get user's organization ID
    final userDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get(); // Get user document from Firestore

    if (!userDoc.exists) throw 'User data not found'; // Throw error if user document does not exist
    
    final orgId = userDoc.data()?['organizationId']; // Get organization ID from user document
    if (orgId == null) throw 'Organization ID not found'; // Throw error if organization ID is null

    try {
      final now = DateTime.now(); // Get current date and time
      final docRef = _firestore.collection('inventory').doc(); // Create a new document reference in inventory collection

      final item = InventoryItem(
        id: docRef.id, // Set item ID to document ID
        name: name, // Set item name
        category: category, // Set item category
        unit: unit, // Set item unit
        quantity: quantity, // Set item quantity
        reorderPoint: reorderPoint, // Set item reorder point
        costPerUnit: costPerUnit, // Set item cost per unit
        storageLocationId: storageLocationId, // Set item storage location ID
        organizationId: orgId, // Set item organization ID
        metadata: metadata, // Set item metadata
        createdAt: now, // Set item creation date
        updatedAt: now, // Set item update date
        lastModifiedBy: currentUser.uid, // Set item last modified by user ID
      );

      await _firestore.runTransaction((transaction) async { // Run Firestore transaction
        transaction.set(docRef, item.toMap()); // Set item data in Firestore

        // Create transaction record
        final transactionDoc = _firestore.collection('inventory_transactions').doc(); // Create a new document reference in inventory_transactions collection
        transaction.set(transactionDoc, {
          'itemId': docRef.id, // Set transaction item ID
          'type': 'created', // Set transaction type
          'quantity': quantity, // Set transaction quantity
          'previousQuantity': 0, // Set previous quantity to 0
          'difference': quantity, // Set quantity difference
          'timestamp': now, // Set transaction timestamp
          'userId': currentUser.uid, // Set transaction user ID
          'organizationId': orgId, // Set transaction organization ID
          'notes': 'Initial inventory creation', // Set transaction notes
        });
      });

      notifyListeners(); // Notify listeners of state change
      return item; // Return created item
    } catch (e) { // Catch any errors
      debugPrint('Error creating inventory item: $e'); // Print error for debugging
      rethrow; // Rethrow error
    }
  }

  Future<InventoryItem?> getInventoryItemById(String itemId) async {
  try {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    // Get user's organization ID
    final userDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (!userDoc.exists) return null;
    
    final orgId = userDoc.data()?['organizationId'];
    if (orgId == null) return null;

    // Get the inventory item
    final doc = await _firestore
        .collection('inventory')
        .doc(itemId)
        .get();

    if (!doc.exists) return null;
    
    final item = InventoryItem.fromMap(doc.data()!, doc.id);
    
    // Verify the item belongs to the user's organization
    if (item.organizationId != orgId) return null;
    
    return item;
  } catch (e) {
    debugPrint('Error getting inventory item by ID: $e');
    return null;
  }
}

  // Update inventory item with organization ID verification
  Future<void> updateInventoryItem(InventoryItem item) async {
    final currentUser = _auth.currentUser; // Get current authenticated user
    if (currentUser == null) throw 'Not authenticated'; // Throw error if no user is authenticated

    final userDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get(); // Get user document from Firestore

    if (!userDoc.exists) throw 'User data not found'; // Throw error if user document does not exist
    
    final orgId = userDoc.data()?['organizationId']; // Get organization ID from user document
    if (orgId == null) throw 'Organization ID not found'; // Throw error if organization ID is null

    // Verify item belongs to user's organization
    if (item.organizationId != orgId) { // If item organization ID does not match user's organization ID
      throw 'Item belongs to a different organization'; // Throw error
    }

    try {
      await _firestore.runTransaction((transaction) async { // Run Firestore transaction
        final doc = await transaction.get(
          _firestore.collection('inventory').doc(item.id)
        ); // Get item document from Firestore

        if (!doc.exists) throw 'Item not found'; // Throw error if item document does not exist
        
        final currentItem = InventoryItem.fromMap(doc.data()!, doc.id); // Convert document to InventoryItem
        if (currentItem.organizationId != orgId) { // If item organization ID does not match user's organization ID
          throw 'Organization verification failed'; // Throw error
        }

        final updatedItem = item.copyWith(
          lastModifiedBy: currentUser.uid, // Update item last modified by user ID
        );

        transaction.update(
          _firestore.collection('inventory').doc(item.id),
          updatedItem.toMap()
        ); // Update item data in Firestore

        if (currentItem.quantity != item.quantity) { // If item quantity has changed
          final now = DateTime.now(); // Get current date and time
          final transactionDoc = _firestore.collection('inventory_transactions').doc(); // Create a new document reference in inventory_transactions collection
          transaction.set(transactionDoc, {
            'itemId': item.id, // Set transaction item ID
            'type': 'updated', // Set transaction type
            'quantity': item.quantity, // Set transaction quantity
            'previousQuantity': currentItem.quantity, // Set previous quantity
            'difference': item.quantity - currentItem.quantity, // Set quantity difference
            'timestamp': now, // Set transaction timestamp
            'userId': currentUser.uid, // Set transaction user ID
            'organizationId': orgId, // Set transaction organization ID
            'notes': 'Quantity updated', // Set transaction notes
          });
        }
      });

      notifyListeners(); // Notify listeners of state change
    } catch (e) { // Catch any errors
      debugPrint('Error updating inventory item: $e'); // Print error for debugging
      rethrow; // Rethrow error
    }
  }

  // Adjust quantity with organization verification
  Future<void> adjustQuantity(
    String itemId,
    double newQuantity, {
    String? notes,
  }) async {
    final currentUser = _auth.currentUser; // Get current authenticated user
    if (currentUser == null) throw 'Not authenticated'; // Throw error if no user is authenticated

    final userDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get(); // Get user document from Firestore

    if (!userDoc.exists) throw 'User data not found'; // Throw error if user document does not exist
    
    final orgId = userDoc.data()?['organizationId']; // Get organization ID from user document
    if (orgId == null) throw 'Organization ID not found'; // Throw error if organization ID is null

    try {
      await _firestore.runTransaction((transaction) async { // Run Firestore transaction
        final doc = await transaction.get(
          _firestore.collection('inventory').doc(itemId)
        ); // Get item document from Firestore

        if (!doc.exists) throw 'Item not found'; // Throw error if item document does not exist
        
        final item = InventoryItem.fromMap(doc.data()!, itemId); // Convert document to InventoryItem
        if (item.organizationId != orgId) { // If item organization ID does not match user's organization ID
          throw 'Organization verification failed'; // Throw error
        }

        final updatedItem = item.copyWith(
          quantity: newQuantity, // Update item quantity
          lastModifiedBy: currentUser.uid, // Update item last modified by user ID
        );

        transaction.update(
          _firestore.collection('inventory').doc(itemId),
          updatedItem.toMap()
        ); // Update item data in Firestore

        final now = DateTime.now(); // Get current date and time
        final transactionDoc = _firestore.collection('inventory_transactions').doc(); // Create a new document reference in inventory_transactions collection
        transaction.set(transactionDoc, {
          'itemId': itemId, // Set transaction item ID
          'type': 'adjusted', // Set transaction type
          'quantity': newQuantity, // Set transaction quantity
          'previousQuantity': item.quantity, // Set previous quantity
          'difference': newQuantity - item.quantity, // Set quantity difference
          'timestamp': now, // Set transaction timestamp
          'userId': currentUser.uid, // Set transaction user ID
          'organizationId': orgId, // Set transaction organization ID
          'notes': notes ?? 'Quantity adjusted', // Set transaction notes
        });
      });

      notifyListeners(); // Notify listeners of state change
    } catch (e) { // Catch any errors
      debugPrint('Error adjusting inventory quantity: $e'); // Print error for debugging
      rethrow; // Rethrow error
    }
  }

  // Delete inventory item with organization verification
  Future<void> deleteInventoryItem(String itemId) async {
    final currentUser = _auth.currentUser; // Get current authenticated user
    if (currentUser == null) throw 'Not authenticated'; // Throw error if no user is authenticated

    final userDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get(); // Get user document from Firestore

    if (!userDoc.exists) throw 'User data not found'; // Throw error if user document does not exist
    
    final orgId = userDoc.data()?['organizationId']; // Get organization ID from user document
    if (orgId == null) throw 'Organization ID not found'; // Throw error if organization ID is null

    try {
      await _firestore.runTransaction((transaction) async { // Run Firestore transaction
        final doc = await transaction.get(
          _firestore.collection('inventory').doc(itemId)
        ); // Get item document from Firestore

        if (!doc.exists) throw 'Item not found'; // Throw error if item document does not exist
        
        final item = InventoryItem.fromMap(doc.data()!, itemId); // Convert document to InventoryItem
        if (item.organizationId != orgId) { // If item organization ID does not match user's organization ID
          throw 'Organization verification failed'; // Throw error
        }

        final now = DateTime.now(); // Get current date and time
        final transactionDoc = _firestore.collection('inventory_transactions').doc(); // Create a new document reference in inventory_transactions collection
        transaction.set(transactionDoc, {
          'itemId': itemId, // Set transaction item ID
          'type': 'deleted', // Set transaction type
          'quantity': 0, // Set transaction quantity to 0
          'previousQuantity': item.quantity, // Set previous quantity
          'difference': -item.quantity, // Set quantity difference
          'timestamp': now, // Set transaction timestamp
          'userId': currentUser.uid, // Set transaction user ID
          'organizationId': orgId, // Set transaction organization ID
          'notes': 'Item deleted', // Set transaction notes
        });

        transaction.delete(
          _firestore.collection('inventory').doc(itemId)
        ); // Delete item document from Firestore
      });

      notifyListeners(); // Notify listeners of state change
    } catch (e) { // Catch any errors
      debugPrint('Error deleting inventory item: $e'); // Print error for debugging
      rethrow; // Rethrow error
    }
  }

  // Get low stock items with organization verification
  Stream<List<InventoryItem>> getLowStockItems() async* { // Method to get low stock items as a stream
    try {
      final currentUser = _auth.currentUser; // Get current authenticated user
      if (currentUser == null) { // If no user is authenticated
        yield []; // Yield an empty list
        return; // Return from the method
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get(); // Get user document from Firestore

      if (!userDoc.exists) { // If user document does not exist
        yield []; // Yield an empty list
        return; // Return from the method
      }

      final orgId = userDoc.data()?['organizationId']; // Get organization ID from user document
      if (orgId == null) { // If organization ID is null
        yield []; // Yield an empty list
        return; // Return from the method
      }

      yield* _firestore
          .collection('inventory')
          .where('organizationId', isEqualTo: orgId) // Query inventory items by organization ID
          .snapshots() // Get snapshots of the query
          .handleError((error) { // Handle errors in the stream
            debugPrint('Error in low stock items stream: $error'); // Print error for debugging
            return []; // Return an empty list on error
          })
          .map((snapshot) => snapshot.docs
              .map((doc) => InventoryItem.fromMap(doc.data(), doc.id)) // Convert document to InventoryItem
              .where((item) => 
                  item.organizationId == orgId && 
                  item.needsReorder) // Filter items by organization ID and reorder point
              .toList()); // Convert to list
    } catch (e) { // Catch any errors
      debugPrint('Error in getLowStockItems: $e'); // Print error for debugging
      yield []; // Yield an empty list on error
    }
  }

  void clearCache() {
    notifyListeners(); // Notify listeners to clear cache
  }
}