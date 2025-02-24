// lib/models/menu_item_prototype.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'task/menu_item_task_prototype.dart';
import 'package:cateredtoyou/models/menu_item_model.dart';

// Class representing a reusable menu item prototype for organizations.
class MenuItemPrototype {
  final String menuItemPrototypeId; // Unique identifier for the menu item prototype.
  final String name; // Name of the menu item.
  final String description; // Description of the menu item.
  final bool plated; // Indicates if the menu item is plated or buffet-style.
  final double price; // Standard price of the menu item.
  final String organizationId; // ID of the organization that owns this prototype.
  final MenuItemType menuItemType; // Type of menu item (appetizer, main course, etc.).
  final Map<String, double> inventoryRequirements; // Ingredients and their required quantities.
  final List<String> recipe; // Step-by-step instructions for preparing this menu item.
  final DateTime createdAt; // Timestamp when this prototype was created.
  final DateTime updatedAt; // Last modified timestamp.
  final String createdBy; // ID of the user who created this prototype.
  final List<MenuItemTaskPrototype> taskPrototypes; // Full list of task prototypes for this menu item.

  // Constructor for creating a MenuItemPrototype.
  const MenuItemPrototype({
    required this.menuItemPrototypeId,
    required this.name,
    required this.description,
    required this.plated,
    required this.price,
    required this.organizationId,
    required this.menuItemType,
    required this.inventoryRequirements,
    required this.recipe,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.taskPrototypes = const [],
  });

  // Converts the MenuItemPrototype instance into a map for Firestore.
  Map<String, dynamic> toMap() {
    try {
      return {
        'name': name,
        'description': description,
        'plated': plated,
        'price': price,
        'organizationId': organizationId,
        'menuItemType': menuItemType.name, // Store as a string.
        'inventoryRequirements': inventoryRequirements,
        'recipe': recipe,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'createdBy': createdBy,
        'taskPrototypes': taskPrototypes.map((task) => task.toMap()).toList(),
      };
    } catch (e) {
      debugPrint('Error converting MenuItemPrototype to map: $e');
      rethrow;
    }
  }

  // Factory constructor to create a MenuItemPrototype instance from Firestore.
  factory MenuItemPrototype.fromMap(Map<String, dynamic> map, String docId) {
    try {
      return MenuItemPrototype(
        menuItemPrototypeId: docId,
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        plated: map['plated'] ?? false,
        price: (map['price'] ?? 0).toDouble(),
        organizationId: map['organizationId'] ?? '',
        menuItemType: MenuItemType.values.firstWhere(
              (e) => e.name == (map['menuItemType'] ?? 'other'),
          orElse: () => MenuItemType.other,
        ),
        inventoryRequirements: Map<String, double>.from(map['inventoryRequirements'] ?? {}),
        recipe: List<String>.from(map['recipe'] ?? []),
        createdAt: (map['createdAt'] as Timestamp).toDate(),
        updatedAt: (map['updatedAt'] as Timestamp).toDate(),
        createdBy: map['createdBy'] ?? '',
        taskPrototypes: (map['taskPrototypes'] as List<dynamic>? ?? [])
            .map((taskMap) => MenuItemTaskPrototype.fromMap(taskMap as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      debugPrint('Error creating MenuItemPrototype from map: $e');
      rethrow;
    }
  }
}