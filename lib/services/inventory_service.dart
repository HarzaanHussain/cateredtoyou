// lib/services/inventory_service.dart

import 'package:cateredtoyou/models/inventory_item_model.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cateredtoyou/services/organization_service.dart';

class InventoryService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OrganizationService _organizationService;
  String? _cachedOrgId;

  InventoryService(this._organizationService);

  Future<String?> _getOrganizationId() async {
    if (_cachedOrgId != null) return _cachedOrgId;
    
    final organization = await _organizationService.getCurrentUserOrganization();
    _cachedOrgId = organization?.id;
    return _cachedOrgId;
  }

  // Stream inventory items for current organization
  Stream<List<InventoryItem>> getInventoryItems() async* {
    try {
      final orgId = await _getOrganizationId();
      if (orgId == null) {
        yield [];
        return;
      }

      yield* _firestore
          .collection('inventory')
          .where('organizationId', isEqualTo: orgId)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => InventoryItem.fromMap(doc.data(), doc.id))
              .toList());
    } catch (e) {
      debugPrint('Error in getInventoryItems: $e');
      yield [];
    }
  }

  // Create inventory item
  Future<InventoryItem> createInventoryItem({
    required String name,
    required InventoryCategory category,
    required UnitType unit,
    required double quantity,
    required double reorderPoint,
    required double costPerUnit,
    String? storageLocationId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final orgId = await _getOrganizationId();
      if (orgId == null) throw 'Organization not found';

      final now = DateTime.now();
      final docRef = _firestore.collection('inventory').doc();

      final item = InventoryItem(
        id: docRef.id,
        name: name,
        category: category,
        unit: unit,
        quantity: quantity,
        reorderPoint: reorderPoint,
        costPerUnit: costPerUnit,
        storageLocationId: storageLocationId,
        organizationId: orgId,
        metadata: metadata,
        createdAt: now,
        updatedAt: now,
        lastModifiedBy: currentUser.uid,
      );

      await docRef.set(item.toMap());
      
      // Create inventory transaction record
      await _createInventoryTransaction(
        itemId: docRef.id,
        type: 'created',
        quantity: quantity,
        previousQuantity: 0,
        notes: 'Initial inventory creation',
      );

      notifyListeners();
      return item;
    } catch (e) {
      debugPrint('Error creating inventory item: $e');
      rethrow;
    }
  }

  // Update inventory item
  Future<void> updateInventoryItem(InventoryItem item) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final orgId = await _getOrganizationId();
      if (orgId == null) throw 'Organization not found';
      if (item.organizationId != orgId) {
        throw 'Item belongs to a different organization';
      }

      // Get the current item to compare quantities
      final currentDoc = await _firestore
          .collection('inventory')
          .doc(item.id)
          .get();

      if (!currentDoc.exists) throw 'Item not found';
      
      final currentItem = InventoryItem.fromMap(
        currentDoc.data()!,
        currentDoc.id,
      );

      // Update the item
      final updatedItem = item.copyWith(
        lastModifiedBy: currentUser.uid,
      );

      await _firestore
          .collection('inventory')
          .doc(item.id)
          .update(updatedItem.toMap());

      // Create transaction record if quantity changed
      if (currentItem.quantity != item.quantity) {
        await _createInventoryTransaction(
          itemId: item.id,
          type: 'updated',
          quantity: item.quantity,
          previousQuantity: currentItem.quantity,
          notes: 'Quantity updated',
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating inventory item: $e');
      rethrow;
    }
  }

  // Delete inventory item
  Future<void> deleteInventoryItem(String itemId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final orgId = await _getOrganizationId();
      if (orgId == null) throw 'Organization not found';

      // Get the item first
      final doc = await _firestore
          .collection('inventory')
          .doc(itemId)
          .get();

      if (!doc.exists) throw 'Item not found';
      
      final item = InventoryItem.fromMap(doc.data()!, doc.id);
      if (item.organizationId != orgId) {
        throw 'Item belongs to a different organization';
      }

      // Create transaction record before deletion
      await _createInventoryTransaction(
        itemId: itemId,
        type: 'deleted',
        quantity: 0,
        previousQuantity: item.quantity,
        notes: 'Item deleted',
      );

      // Delete the item
      await _firestore
          .collection('inventory')
          .doc(itemId)
          .delete();

      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting inventory item: $e');
      rethrow;
    }
  }

  // Adjust inventory quantity
  Future<void> adjustQuantity(
    String itemId,
    double newQuantity, {
    String? notes,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final orgId = await _getOrganizationId();
      if (orgId == null) throw 'Organization not found';

      // Get current item
      final doc = await _firestore
          .collection('inventory')
          .doc(itemId)
          .get();

      if (!doc.exists) throw 'Item not found';
      
      final item = InventoryItem.fromMap(doc.data()!, doc.id);
      if (item.organizationId != orgId) {
        throw 'Item belongs to a different organization';
      }

      // Update quantity
      final updatedItem = item.copyWith(
        quantity: newQuantity,
        lastModifiedBy: currentUser.uid,
      );

      await _firestore
          .collection('inventory')
          .doc(itemId)
          .update(updatedItem.toMap());

      // Create transaction record
      await _createInventoryTransaction(
        itemId: itemId,
        type: 'adjusted',
        quantity: newQuantity,
        previousQuantity: item.quantity,
        notes: notes ?? 'Quantity adjusted',
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error adjusting inventory quantity: $e');
      rethrow;
    }
  }

  // Private method to create inventory transactions
  Future<void> _createInventoryTransaction({
    required String itemId,
    required String type,
    required double quantity,
    required double previousQuantity,
    String? notes,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final now = DateTime.now();
      
      await _firestore
          .collection('inventory_transactions')
          .add({
            'itemId': itemId,
            'type': type,
            'quantity': quantity,
            'previousQuantity': previousQuantity,
            'difference': quantity - previousQuantity,
            'timestamp': now,
            'userId': currentUser.uid,
            'notes': notes,
          });
    } catch (e) {
      debugPrint('Error creating inventory transaction: $e');
      // Don't rethrow - this is a secondary operation
    }
  }

  // Get low stock items
  Stream<List<InventoryItem>> getLowStockItems() async* {
    try {
      final orgId = await _getOrganizationId();
      if (orgId == null) {
        yield [];
        return;
      }

      yield* _firestore
          .collection('inventory')
          .where('organizationId', isEqualTo: orgId)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => InventoryItem.fromMap(doc.data(), doc.id))
              .where((item) => item.needsReorder)
              .toList());
    } catch (e) {
      debugPrint('Error in getLowStockItems: $e');
      yield [];
    }
  }

  // Clear cached organization ID
  void clearCache() {
    _cachedOrgId = null;
    notifyListeners();
  }
}