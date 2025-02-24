// lib/models/menu_item_prototype_service.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/menu_item_prototype.dart';
import './organization_service.dart';
import '../models/task/menu_item_task_prototype.dart';
import '../models/menu_item_model.dart';

class MenuItemPrototypeService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OrganizationService _organizationService;

  MenuItemPrototypeService(this._organizationService);

  Stream<List<MenuItemPrototype>> getMenuItemPrototypes() async* {
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
          .collection('menu_item_prototypes')
          .where('organizationId', isEqualTo: organization.id);

      yield* query.snapshots().map((snapshot) {
        try {
          final prototypes = snapshot.docs
              .map((doc) => MenuItemPrototype.fromMap(doc.data(), doc.id))
              .toList();
          prototypes.sort((a, b) => a.name.compareTo(b.name));
          return prototypes;
        } catch (e) {
          debugPrint('Error mapping menu item prototypes: $e');
          return [];
        }
      });
    } catch (e) {
      debugPrint('Error in getMenuItemPrototypes: $e');
      yield [];
    }
  }

  Future<MenuItemPrototype> createMenuItemPrototype({
    required String name,
    required String description,
    required bool plated,
    required double price,
    required MenuItemType menuItemType,
    required Map<String, double> inventoryRequirements,
    required List<String> recipe,
    List<MenuItemTaskPrototype> taskPrototypes = const [],
  }) async {
    debugPrint('Starting createMenuItemPrototype');
    debugPrint('Inputs - Name: $name, Description: $description, Plated: $plated, Price: $price, MenuItemType: $menuItemType');
    debugPrint('Inventory Requirements: $inventoryRequirements');
    debugPrint('Recipe: $recipe');
    debugPrint('Task Prototypes Count: ${taskPrototypes.length}');

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('ERROR: Not authenticated');
      throw 'Not authenticated';
    }
    debugPrint('Authenticated as: ${currentUser.uid}');

    final organization = await _organizationService.getCurrentUserOrganization();
    if (organization == null) {
      debugPrint('ERROR: Organization not found');
      throw 'Organization not found';
    }
    debugPrint('Organization ID: ${organization.id}');

    try {
      final now = DateTime.now();
      final docRef = _firestore.collection('menu_item_prototypes').doc();
      debugPrint('Generated Firestore document ID: ${docRef.id}');

      final prototype = MenuItemPrototype(
        menuItemPrototypeId: docRef.id,
        name: name,
        description: description,
        plated: plated,
        price: price,
        organizationId: organization.id,
        menuItemType: menuItemType,
        inventoryRequirements: inventoryRequirements,
        recipe: recipe,
        createdAt: now,
        updatedAt: now,
        createdBy: currentUser.uid,
        taskPrototypes: taskPrototypes,
      );

      debugPrint('Prototype object created: ${prototype.toMap()}');

      await docRef.set(prototype.toMap());
      debugPrint('Firestore write successful for ${docRef.id}');

      notifyListeners();
      debugPrint('Notified listeners');

      return prototype;
    } catch (e, stackTrace) {
      debugPrint('ERROR: Exception while creating menu item prototype: $e');
      debugPrint('Stack Trace: $stackTrace');
      rethrow;
    }
  }


  Future<void> updateMenuItemPrototype(MenuItemPrototype prototype) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      if (prototype.organizationId != organization.id) {
        throw 'Prototype belongs to a different organization';
      }

      await _firestore
          .collection('menu_item_prototypes')
          .doc(prototype.menuItemPrototypeId)
          .update({
        ...prototype.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating menu item prototype: $e');
      rethrow;
    }
  }

  Future<void> deleteMenuItemPrototype(String prototypeId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      final prototypeDoc = await _firestore
          .collection('menu_item_prototypes')
          .doc(prototypeId)
          .get();

      if (!prototypeDoc.exists || prototypeDoc.data()?['organizationId'] != organization.id) {
        throw 'Prototype not found in your organization';
      }

      await _firestore.collection('menu_item_prototypes').doc(prototypeId).delete();
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting menu item prototype: $e');
      rethrow;
    }
  }

  Future<List<MenuItemPrototype>> getMenuItemPrototypesByType(MenuItemType type) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      final snapshot = await _firestore
          .collection('menu_item_prototypes')
          .where('organizationId', isEqualTo: organization.id)
          .where('menuItemType', isEqualTo: type.name)
          .get();

      final prototypes = snapshot.docs
          .map((doc) => MenuItemPrototype.fromMap(doc.data(), doc.id))
          .toList();

      prototypes.sort((a, b) => a.name.compareTo(b.name));
      return prototypes;
    } catch (e) {
      debugPrint('Error getting menu item prototypes by type: $e');
      rethrow;
    }
  }

  Future<MenuItemPrototype?> getMenuItemPrototype(String prototypeId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      final doc = await _firestore
          .collection('menu_item_prototypes')
          .doc(prototypeId)
          .get();

      if (!doc.exists || doc.data()?['organizationId'] != organization.id) {
        return null;
      }

      return MenuItemPrototype.fromMap(doc.data()!, doc.id);
    } catch (e) {
      debugPrint('Error getting menu item prototype: $e');
      rethrow;
    }
  }
}