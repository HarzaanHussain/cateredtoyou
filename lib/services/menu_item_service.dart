// lib/services/menu_item_service.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/menu_item_model.dart';
import './organization_service.dart';

class MenuItemService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OrganizationService _organizationService;

  MenuItemService(this._organizationService);

  Stream<List<MenuItem>> getMenuItems() async* {
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

      final query = _firestore
          .collection('menu_items')
          .where('organizationId', isEqualTo: organization.id);

      yield* query.snapshots().map((snapshot) {
        try {
          final items = snapshot.docs
              .map((doc) => MenuItem.fromMap(doc.data(), doc.id))
              .toList();
          items.sort((a, b) => a.name.compareTo(b.name));
          return items;
        } catch (e) {
          debugPrint('Error mapping menu items: $e');
          return [];
        }
      });
    } catch (e) {
      debugPrint('Error in getMenuItems: $e');
      yield [];
    }
  }

  Future<MenuItem> createMenuItem({
    required String name,
    required String description,
    required bool plated,
    required double price,
    required int quantity,
    required MenuItemType menuItemType,
    required Map<String, double> inventoryRequirements,
    required String prototypeId,
    required String specialInstructions,  // Added specialInstructions
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw 'Not authenticated';

    final organization = await _organizationService.getCurrentUserOrganization();
    if (organization == null) throw 'Organization not found';

    try {
      debugPrint('Creating menu item for organization: ${organization.id}');
      final now = DateTime.now();
      final docRef = _firestore.collection('menu_items').doc();

      final menuItem = MenuItem(
        id: docRef.id,
        name: name,
        description: description,
        plated: plated,
        price: price,
        quantity: quantity,
        organizationId: organization.id,
        menuItemType: menuItemType,
        inventoryRequirements: inventoryRequirements,
        createdAt: now,
        updatedAt: now,
        createdBy: currentUser.uid,
        prototypeId: prototypeId,
        specialInstructions: specialInstructions, // Added specialInstructions
      );

      await docRef.set(menuItem.toMap()!);
      notifyListeners();
      return menuItem;
    } catch (e) {
      debugPrint('Error creating menu item: $e');
      rethrow;
    }
  }

  Future<void> updateMenuItem(MenuItem menuItem) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      if (menuItem.organizationId != organization.id) {
        throw 'Menu item belongs to a different organization';
      }

      await _firestore
          .collection('menu_items')
          .doc(menuItem.id)
          .update({
        ...menuItem.toMap()!,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating menu item: $e');
      rethrow;
    }
  }

  Future<void> batchUpdateMenuItems(List<MenuItem> menuItems) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      final batch = _firestore.batch();
      final now = FieldValue.serverTimestamp();

      for (var menuItem in menuItems) {
        if (menuItem.organizationId != organization.id) {
          throw 'One or more menu items belong to a different organization';
        }

        final docRef = _firestore.collection('menu_items').doc(menuItem.id);
        batch.update(docRef, {
          ...menuItem.toMap()!,
          'updatedAt': now,
        });
      }

      await batch.commit();
      notifyListeners();
    } catch (e) {
      debugPrint('Error in batch update menu items: $e');
      rethrow;
    }
  }

  Future<void> batchUpdateQuantities(Map<String, int> quantityUpdates) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      final batch = _firestore.batch();
      final now = FieldValue.serverTimestamp();

      for (var entry in quantityUpdates.entries) {
        final docRef = _firestore.collection('menu_items').doc(entry.key);
        batch.update(docRef, {
          'quantity': entry.value,
          'updatedAt': now,
        });
      }

      await batch.commit();
      notifyListeners();
    } catch (e) {
      debugPrint('Error in batch update quantities: $e');
      rethrow;
    }
  }

  Future<void> deleteMenuItem(String menuItemId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      final menuItemDoc = await _firestore
          .collection('menu_items')
          .doc(menuItemId)
          .get();

      if (!menuItemDoc.exists || menuItemDoc.data()?['organizationId'] != organization.id) {
        throw 'Menu item not found in your organization';
      }

      await _firestore.collection('menu_items').doc(menuItemId).delete();
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting menu item: $e');
      rethrow;
    }
  }

  Future<void> batchDeleteMenuItems(List<String> menuItemIds) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      final batch = _firestore.batch();

      for (var id in menuItemIds) {
        final docRef = _firestore.collection('menu_items').doc(id);
        final doc = await docRef.get();

        if (!doc.exists || doc.data()?['organizationId'] != organization.id) {
          throw 'One or more menu items not found in your organization';
        }

        batch.delete(docRef);
      }

      await batch.commit();
      notifyListeners();
    } catch (e) {
      debugPrint('Error in batch delete menu items: $e');
      rethrow;
    }
  }

  Future<List<MenuItem>> getMenuItemsByType(MenuItemType type) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      final snapshot = await _firestore
          .collection('menu_items')
          .where('organizationId', isEqualTo: organization.id)
          .where('menuItemType', isEqualTo: type.name)
          .get();

      final items = snapshot.docs
          .map((doc) => MenuItem.fromMap(doc.data(), doc.id))
          .toList();

      items.sort((a, b) => a.name.compareTo(b.name));
      return items;
    } catch (e) {
      debugPrint('Error getting menu items by type: $e');
      rethrow;
    }
  }

  Future<MenuItem?> getMenuItemById(String menuItemId) async {
    try {
      final currentUser = _auth.currentUser; // Check authenticated user
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization(); // Get user's organization
      if (organization == null) throw 'Organization not found';

      final doc = await _firestore.collection('menu_items').doc(menuItemId).get(); // Fetch menu item document

      if (!doc.exists) return null; // Return null if no such menu item exists

      final data = doc.data();
      if (data?['organizationId'] != organization.id) {
        throw 'Menu item does not belong to your organization'; // Ensure the menu item belongs to this user's organization
      }

      return MenuItem.fromMap(data!, doc.id); // Map the document to a MenuItem object
    } catch (e) {
      debugPrint('Error getting menu item by ID: $e');
      rethrow;
    }
  }

}