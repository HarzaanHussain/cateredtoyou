import 'package:flutter/foundation.dart'; // Importing foundation package for ChangeNotifier
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore package for database operations
import 'package:firebase_auth/firebase_auth.dart'; // Importing Firebase Auth package for authentication
import 'package:cateredtoyou/models/menu_item_model.dart'; // Importing MenuItem model
import 'package:cateredtoyou/services/organization_service.dart'; // Importing OrganizationService for organization-related operations

// MenuItemService class extends ChangeNotifier to provide state management
class MenuItemService extends ChangeNotifier {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Firestore instance for database operations
  final FirebaseAuth _auth =
      FirebaseAuth.instance; // FirebaseAuth instance for authentication
  final OrganizationService
      _organizationService; // OrganizationService instance for organization-related operations

  // Constructor to initialize OrganizationService
  MenuItemService(this._organizationService);

  // Stream to get menu items from Firestore
  Stream<List<MenuItem>> getMenuItems() async* {
    try {
      final currentUser =
          _auth.currentUser; // Get the current authenticated user
      debugPrint('current user:  $currentUser');
      if (currentUser == null) {
        yield []; // If no user is authenticated, yield an empty list
        return;
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get(); // Get the user document from Firestore

      if (!userDoc.exists) {
        yield []; // If user document does not exist, yield an empty list
        return;
      }

      final organizationId = userDoc.data()?[
          'organizationId']; // Get the organization ID from user document
      debugPrint('organization id:  $organizationId');
      // Query to get menu items for the organization
      final query = _firestore
          .collection('menu_items')
          .where('organizationId', isEqualTo: organizationId);

      // Map the query snapshots to a list of MenuItem objects
      yield* query.snapshots().map((snapshot) {
        try {
          debugPrint('Snapshot docs count: ${snapshot.docs.length}');
          final items = snapshot.docs
              .map((doc) => MenuItem.fromMap(doc.data(), doc.id))
              .toList();

          // Sort the menu items by name
          items.sort((a, b) => a.name.compareTo(b.name));
          debugPrint('Mapped menu items count: ${items.length}');

          return items;
        } catch (e) {
          debugPrint(
              'Error mapping menu items: $e'); // Print error if mapping fails
          return [];
        }
      });
    } catch (e) {
      debugPrint(
          'Error in getMenuItems: $e'); // Print error if any exception occurs
      yield [];
    }
  }

  // Method to create a new menu item
  Future<MenuItem> createMenuItem({
    required String name, // Name of the menu item
    required String description, // Description of the menu item
    required MenuItemType type, // Type of the menu item
    required double price, // Price of the menu item
    required Map<String, double>
        inventoryRequirements, // Inventory requirements for the menu item
  }) async {
    final currentUser = _auth.currentUser; // Get the current authenticated user
    if (currentUser == null)
      throw 'Not authenticated'; // Throw error if no user is authenticated

    final organization = await _organizationService
        .getCurrentUserOrganization(); // Get the current user's organization
    if (organization == null) {
      throw 'Organization not found'; // Throw error if organization is not found
    }

    final userDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get(); // Get the user document from Firestore

    if (!userDoc.exists)
      throw 'User data not found'; // Throw error if user document does not exist
    final userRole =
        userDoc.get('role'); // Get the user role from user document

    // Check if user has sufficient permissions to create menu items
    if (!['admin', 'client', 'manager', 'chef'].contains(userRole)) {
      throw 'Insufficient permissions to create menu items';
    }

    try {
      final now = DateTime.now(); // Get the current date and time
      final docRef = _firestore
          .collection('menu_items')
          .doc(); // Create a new document reference for the menu item

      // Create a new MenuItem object
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

      await docRef.set(menuItem.toMap()); // Save the menu item to Firestore

      notifyListeners(); // Notify listeners about the change
      return menuItem; // Return the created menu item
    } catch (e) {
      debugPrint(
          'Error creating menu item: $e'); // Print error if any exception occurs
      rethrow; // Rethrow the exception
    }
  }

  // Method to update an existing menu item
  Future<void> updateMenuItem(MenuItem item) async {
    try {
      final currentUser =
          _auth.currentUser; // Get the current authenticated user
      if (currentUser == null)
        throw 'Not authenticated'; // Throw error if no user is authenticated

      final organization = await _organizationService
          .getCurrentUserOrganization(); // Get the current user's organization
      if (organization == null) {
        throw 'Organization not found'; // Throw error if organization is not found
      }

      if (item.organizationId != organization.id) {
        throw 'Menu item belongs to a different organization'; // Throw error if menu item belongs to a different organization
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get(); // Get the user document from Firestore

      if (!userDoc.exists)
        throw 'User data not found'; // Throw error if user document does not exist
      final userRole =
          userDoc.get('role'); // Get the user role from user document

      // Check if user has sufficient permissions to update menu items
      if (!['admin', 'client', 'manager', 'chef'].contains(userRole)) {
        throw 'Insufficient permissions to update menu items';
      }

      await _firestore.collection('menu_items').doc(item.id).update({
        ...item.toMap(),
        'updatedAt': FieldValue
            .serverTimestamp(), // Update the updatedAt field with server timestamp
      });

      notifyListeners(); // Notify listeners about the change
    } catch (e) {
      debugPrint(
          'Error updating menu item: $e'); // Print error if any exception occurs
      rethrow; // Rethrow the exception
    }
  }

  // Method to delete a menu item
  Future<void> deleteMenuItem(String menuItemId) async {
    try {
      final currentUser =
          _auth.currentUser; // Get the current authenticated user
      if (currentUser == null)
        throw 'Not authenticated'; // Throw error if no user is authenticated

      final organization = await _organizationService
          .getCurrentUserOrganization(); // Get the current user's organization
      if (organization == null) {
        throw 'Organization not found'; // Throw error if organization is not found
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get(); // Get the user document from Firestore

      if (!userDoc.exists)
        throw 'User data not found'; // Throw error if user document does not exist
      final userRole =
          userDoc.get('role'); // Get the user role from user document

      // Check if user has sufficient permissions to delete menu items
      if (!['admin', 'client', 'manager', 'chef'].contains(userRole)) {
        throw 'Insufficient permissions to delete menu items';
      }

      final menuItemDoc = await _firestore
          .collection('menu_items')
          .doc(menuItemId)
          .get(); // Get the menu item document from Firestore

      // Check if menu item exists and belongs to the user's organization
      if (!menuItemDoc.exists ||
          menuItemDoc.data()?['organizationId'] != organization.id) {
        throw 'Menu item not found in your organization';
      }

      // Check if menu item is used in any events before deleting
      final eventsWithItem = await _firestore
          .collection('events')
          .where('organizationId', isEqualTo: organization.id)
          .get();

      for (var eventDoc in eventsWithItem.docs) {
        final menuItems =
            List<Map<String, dynamic>>.from(eventDoc.data()['menuItems'] ?? []);
        if (menuItems.any((item) => item['menuItemId'] == menuItemId)) {
          throw 'Cannot delete menu item as it is used in one or more events';
        }
      }

      await _firestore
          .collection('menu_items')
          .doc(menuItemId)
          .delete(); // Delete the menu item from Firestore

      notifyListeners(); // Notify listeners about the change
    } catch (e) {
      debugPrint(
          'Error deleting menu item: $e'); // Print error if any exception occurs
      rethrow; // Rethrow the exception
    }
  }

  // Method to get menu items by type
  Future<List<MenuItem>> getMenuItemsByType(MenuItemType type) async {
    try {
      final currentUser =
          _auth.currentUser; // Get the current authenticated user
      if (currentUser == null)
        throw 'Not authenticated'; // Throw error if no user is authenticated

      final organization = await _organizationService
          .getCurrentUserOrganization(); // Get the current user's organization
      if (organization == null) {
        throw 'Organization not found'; // Throw error if organization is not found
      }

      final snapshot = await _firestore
          .collection('menu_items')
          .where('organizationId', isEqualTo: organization.id)
          .get(); // Get the menu items for the organization from Firestore

      // Map the query snapshots to a list of MenuItem objects and filter by type
      final items = snapshot.docs
          .map((doc) => MenuItem.fromMap(doc.data(), doc.id))
          .where((item) => item.type == type)
          .toList();

      items.sort(
          (a, b) => a.name.compareTo(b.name)); // Sort the menu items by name
      return items; // Return the list of menu items
    } catch (e) {
      debugPrint(
          'Error getting menu items by type: $e'); // Print error if any exception occurs
      rethrow; // Rethrow the exception
    }
  }

  Future<MenuItem?> getMenuItemById(String menuItemId) async {
    try {
      final currentUser = _auth.currentUser; // Check authenticated user
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService
          .getCurrentUserOrganization(); // Get user's organization
      if (organization == null) throw 'Organization not found';

      final doc = await _firestore
          .collection('menu_items')
          .doc(menuItemId)
          .get(); // Fetch menu item document

      if (!doc.exists) return null; // Return null if no such menu item exists

      final data = doc.data();
      if (data?['organizationId'] != organization.id) {
        throw 'Menu item does not belong to your organization'; // Ensure the menu item belongs to this user's organization
      }

      return MenuItem.fromMap(
          data!, doc.id); // Map the document to a MenuItem object
    } catch (e) {
      debugPrint('Error getting menu item by ID: $e');
      rethrow;
    }
  }
}
