import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cateredtoyou/models/menu_item_model.dart';
import 'package:cateredtoyou/services/organization_service.dart';

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

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        yield [];
        return;
      }

      final organizationId = userDoc.data()?['organizationId'];

      // Simple query without compound indexes
      final query = _firestore
          .collection('menu_items')
          .where('organizationId', isEqualTo: organizationId);

      yield* query.snapshots().map((snapshot) {
        try {
          final items = snapshot.docs
              .map((doc) => MenuItem.fromMap(doc.data(), doc.id))
              .toList();
          
          // Sort in application instead of database
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
    required MenuItemType type,
    required double price,
    required Map<String, double> inventoryRequirements,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw 'Not authenticated';

    final organization = await _organizationService.getCurrentUserOrganization();
    if (organization == null) {
      throw 'Organization not found';
    }

    final userDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (!userDoc.exists) throw 'User data not found';
    final userRole = userDoc.get('role');

    if (!['admin', 'client', 'manager', 'chef'].contains(userRole)) {
      throw 'Insufficient permissions to create menu items';
    }

    try {
      final now = DateTime.now();
      final docRef = _firestore.collection('menu_items').doc();

      final menuItem = MenuItem(
        id: docRef.id,
        name: name,
        description: description,
        type: type,
        price: price,
        organizationId: organization.id,
        inventoryRequirements: inventoryRequirements,
        createdAt: now,
        updatedAt: now,
        createdBy: currentUser.uid,
      );

      await docRef.set(menuItem.toMap());

      notifyListeners();
      return menuItem;
    } catch (e) {
      debugPrint('Error creating menu item: $e');
      rethrow;
    }
  }

  Future<void> updateMenuItem(MenuItem item) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found';
      }

      if (item.organizationId != organization.id) {
        throw 'Menu item belongs to a different organization';
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) throw 'User data not found';
      final userRole = userDoc.get('role');

      if (!['admin', 'client', 'manager', 'chef'].contains(userRole)) {
        throw 'Insufficient permissions to update menu items';
      }

      await _firestore
          .collection('menu_items')
          .doc(item.id)
          .update({
            ...item.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating menu item: $e');
      rethrow;
    }
  }

  Future<void> deleteMenuItem(String menuItemId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found';
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) throw 'User data not found';
      final userRole = userDoc.get('role');

      if (!['admin', 'client', 'manager', 'chef'].contains(userRole)) {
        throw 'Insufficient permissions to delete menu items';
      }

      final menuItemDoc = await _firestore
          .collection('menu_items')
          .doc(menuItemId)
          .get();

      if (!menuItemDoc.exists || menuItemDoc.data()?['organizationId'] != organization.id) {
        throw 'Menu item not found in your organization';
      }

      // Check if menu item is used in any events before deleting
      final eventsWithItem = await _firestore
          .collection('events')
          .where('organizationId', isEqualTo: organization.id)
          .get();

      for (var eventDoc in eventsWithItem.docs) {
        final menuItems = List<Map<String, dynamic>>.from(eventDoc.data()['menuItems'] ?? []);
        if (menuItems.any((item) => item['menuItemId'] == menuItemId)) {
          throw 'Cannot delete menu item as it is used in one or more events';
        }
      }

      await _firestore.collection('menu_items').doc(menuItemId).delete();

      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting menu item: $e');
      rethrow;
    }
  }

  Future<List<MenuItem>> getMenuItemsByType(MenuItemType type) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found';
      }

      final snapshot = await _firestore
          .collection('menu_items')
          .where('organizationId', isEqualTo: organization.id)
          .get();

      final items = snapshot.docs
          .map((doc) => MenuItem.fromMap(doc.data(), doc.id))
          .where((item) => item.type == type)
          .toList();

      items.sort((a, b) => a.name.compareTo(b.name));
      return items;
    } catch (e) {
      debugPrint('Error getting menu items by type: $e');
      rethrow;
    }
  }
}