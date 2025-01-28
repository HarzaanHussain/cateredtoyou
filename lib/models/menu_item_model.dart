import 'package:cloud_firestore/cloud_firestore.dart';
import 'task_model.dart'; // Importing the Task model
import 'package:flutter/foundation.dart';


// Enum representing different types of menu items
enum MenuItemType {
  appetizer, // Appetizer type
  mainCourse, // Main course type
  sideDish, // Side dish type
  dessert, // Dessert type
  beverage, // Beverage type
  other // Other type for unspecified categories
}

// Class representing a menu item
class MenuItem {
  final String id; // Unique identifier for the menu item
  final String name; // Name of the menu item
  final String description; // Description of the menu item
  final MenuItemType type; // Type of the menu item
  final bool plated; // Indicates if the menu item is plated or not
  final double price; // Price of the menu item
  final String organizationId; // ID of the organization that owns the menu item
  final Map<String, double> inventoryRequirements; // Inventory requirements for the menu item
  final DateTime createdAt; // Timestamp when the menu item was created
  final DateTime updatedAt; // Timestamp when the menu item was last updated
  final String createdBy; // ID of the user who created the menu item
  final List<Task> tasks; // List of tasks associated with the menu item

  // Constructor for creating a MenuItem instance
  const MenuItem({
    required this.id, // Required parameter for unique identifier
    required this.name, // Required parameter for name
    required this.description, // Required parameter for description
    required this.type, // Required parameter for type
    required this.plated, // Required parameter for plated status
    required this.price, // Required parameter for price
    required this.organizationId, // Required parameter for organization ID
    required this.inventoryRequirements, // Required parameter for inventory requirements
    required this.createdAt, // Required parameter for creation timestamp
    required this.updatedAt, // Required parameter for update timestamp
    required this.createdBy, // Required parameter for creator ID
    this.tasks = const [], // Optional parameter for tasks, default is an empty list
  });

  // Method to convert MenuItem instance to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name, // Name of the menu item
      'description': description, // Description of the menu item
      'type': type.toString().split('.').last, // Type of the menu item as a string
      'plated': plated, // Add plated status to map
      'price': price, // Price of the menu item
      'organizationId': organizationId, // Organization ID
      'inventoryRequirements': inventoryRequirements, // Inventory requirements
      'createdAt': Timestamp.fromDate(createdAt), // Creation timestamp as Firestore Timestamp
      'updatedAt': Timestamp.fromDate(updatedAt), // Update timestamp as Firestore Timestamp
      'createdBy': createdBy, // Creator ID
      'tasks': tasks.map((task) => task.toMap()).toList(), // Convert tasks to a list of maps
    };
  }

  // Factory constructor to create a MenuItem instance from a map
  factory MenuItem.fromMap(Map<String, dynamic> map, String docId) {
    map.forEach((key, value) {
      debugPrint('$key: ${value ?? "null"}'); // Print each key with value or "null" if value is null
    });
    return MenuItem(
      id: docId, // Document ID from Firestore
      name: map['name'] ?? '', // Name from map or empty string if null
      description: map['description'] ?? '', // Description from map or empty string if null
      type: MenuItemType.values.firstWhere(
            (type) => type.toString().split('.').last == map['type'], // Type from map or default to 'other'
        orElse: () => MenuItemType.other,
      ),
      plated: map['plated'] ?? false, // Read plated status from map
      price: (map['price'] ?? 0).toDouble(), // Price from map or 0 if null
      organizationId: map['organizationId'] ?? '', // Organization ID from map or empty string if null
      inventoryRequirements: Map<String, double>.from(map['inventoryRequirements'] ?? {}), // Inventory requirements
      createdAt: (map['createdAt'] as Timestamp).toDate(), // Convert Firestore Timestamp to DateTime
      updatedAt: (map['updatedAt'] as Timestamp).toDate(), // Convert Firestore Timestamp to DateTime
      createdBy: map['createdBy'] ?? '', // Creator ID from map or empty string if null
      tasks: (map['tasks'] as List<dynamic>? ?? []) // Parse tasks list
          .map((taskMap) => Task.fromMap(taskMap as Map<String, dynamic>, taskMap['id']))
          .toList(),
    );
  }

  // Method to create a copy of MenuItem instance with updated fields
  MenuItem copyWith({
    String? name,
    String? description,
    MenuItemType? type,
    bool? plated,
    double? price,
    Map<String, double>? inventoryRequirements,
    List<Task>? tasks,
  }) {
    return MenuItem(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      plated: plated ?? this.plated, // Use new plated status if provided, otherwise retain existing
      price: price ?? this.price,
      organizationId: organizationId,
      inventoryRequirements: inventoryRequirements ?? this.inventoryRequirements,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      createdBy: createdBy,
      tasks: tasks ?? this.tasks, // Use new tasks if provided, otherwise retain existing
    );
  }
}
