// lib/models/menu_item_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'task/menu_item_task.dart';

// Enum representing the type of menu item.
enum MenuItemType {
  appetizer,
  mainCourse,
  sideDish,
  dessert,
  beverage,
  other,
}

// Class representing an individual instance of a menu item in an event.
class MenuItem {
  final String id; // Unique identifier for this menu item instance.
  final String name; // Name of the menu item.
  final String description; // Description of the menu item.
  final bool plated; // Indicates if this menu item is plated or buffet-style.
  final double price; // Price for this menu item.
  final int quantity; // Number of servings ordered for this event.
  final String organizationId; // ID of the organization that owns the menu item.
  final MenuItemType menuItemType; // Type of menu item (appetizer, main course, etc.).
  final Map<String, double> inventoryRequirements; // Ingredients and their required quantities.
  final DateTime createdAt; // Timestamp for when this instance was created.
  final DateTime updatedAt; // Last updated timestamp.
  final String createdBy; // ID of the user who created this menu item.
  final String prototypeId; // ID of the original MenuItemPrototype this was created from.
  final List<MenuItemTask> tasks; // Full list of tasks for preparing this menu item.
  final String specialInstructions; // Special instructions for this menu item.

  // Constructor for creating a MenuItem instance.
  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.plated,
    required this.price,
    required this.quantity,
    required this.organizationId,
    required this.menuItemType,
    required this.inventoryRequirements,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.prototypeId,
    this.tasks = const [],
    this.specialInstructions = '', // Default empty string for special instructions.
  });

  // Converts the MenuItem instance into a map for Firestore storage.
  Map<String, dynamic>? toMap() {
    try {
      return {
        'name': name,
        'description': description,
        'plated': plated,
        'price': price,
        'quantity': quantity,
        'organizationId': organizationId,
        'menuItemType': menuItemType.name, // Store as a string.
        'inventoryRequirements': inventoryRequirements,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'createdBy': createdBy,
        'prototypeId': prototypeId,
        'tasks': tasks.map((task) => task.toMap()).toList(),
        'specialInstructions': specialInstructions, // Include special instructions in the map.
      };
    } catch (e) {
      debugPrint('Error converting MenuItem to map: $e');
      rethrow;
    }
  }

  factory MenuItem.fromMap(Map<String, dynamic> map, String docId) {
    try {
      debugPrint('Creating MenuItem from map: $map');
      return MenuItem(
        id: docId,
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        plated: map['plated'] ?? false,
        price: (map['price'] ?? 0).toDouble(),
        quantity: map['quantity'] ?? 0,
        organizationId: map['organizationId'] ?? '',
        menuItemType: MenuItemType.values.firstWhere(
              (e) => e.name == (map['menuItemType'] ?? 'other'),
          orElse: () => MenuItemType.other,
        ),
        inventoryRequirements: Map<String, double>.from(map['inventoryRequirements'] ?? {}),
        createdAt: (map['createdAt'] as Timestamp).toDate(),
        updatedAt: (map['updatedAt'] as Timestamp).toDate(),
        createdBy: map['createdBy'] ?? '',
        prototypeId: map['prototypeId'] ?? '',
        tasks: (map['tasks'] as List<dynamic>? ?? [])
            .map((taskMap) => MenuItemTask.fromMap(taskMap as Map<String, dynamic>, taskMap['id']))
            .toList(),
        specialInstructions: map['specialInstructions'] ?? '', // Set special instructions.
      );
    } catch (e) {
      debugPrint('Error creating MenuItem from map: $e');
      rethrow;
    }
  }

  get type => menuItemType;

  MenuItem copyWith({
    String? id,
    String? name,
    String? description,
    bool? plated,
    double? price,
    int? quantity,
    String? organizationId,
    MenuItemType? menuItemType,
    Map<String, double>? inventoryRequirements,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? prototypeId,
    List<MenuItemTask>? tasks,
    String? specialInstructions, // Allow overriding specialInstructions
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      plated: plated ?? this.plated,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      organizationId: organizationId ?? this.organizationId,
      menuItemType: menuItemType ?? this.menuItemType,
      inventoryRequirements: inventoryRequirements ?? Map.from(this.inventoryRequirements),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      prototypeId: prototypeId ?? this.prototypeId,
      tasks: tasks ?? List.from(this.tasks),
      specialInstructions: specialInstructions ?? this.specialInstructions, // Default if not provided.
    );
  }
}