import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore package for database operations

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
  final double price; // Price of the menu item
  final String organizationId; // ID of the organization that owns the menu item
  final Map<String, double> inventoryRequirements; // Inventory requirements for the menu item
  final DateTime createdAt; // Timestamp when the menu item was created
  final DateTime updatedAt; // Timestamp when the menu item was last updated
  final String createdBy; // ID of the user who created the menu item

  // Constructor for creating a MenuItem instance
  const MenuItem({
    required this.id, // Required parameter for unique identifier
    required this.name, // Required parameter for name
    required this.description, // Required parameter for description
    required this.type, // Required parameter for type
    required this.price, // Required parameter for price
    required this.organizationId, // Required parameter for organization ID
    required this.inventoryRequirements, // Required parameter for inventory requirements
    required this.createdAt, // Required parameter for creation timestamp
    required this.updatedAt, // Required parameter for update timestamp
    required this.createdBy, // Required parameter for creator ID
  });

  // Method to convert MenuItem instance to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name, // Name of the menu item
      'description': description, // Description of the menu item
      'type': type.toString().split('.').last, // Type of the menu item as a string
      'price': price, // Price of the menu item
      'organizationId': organizationId, // Organization ID
      'inventoryRequirements': inventoryRequirements, // Inventory requirements
      'createdAt': Timestamp.fromDate(createdAt), // Creation timestamp as Firestore Timestamp
      'updatedAt': Timestamp.fromDate(updatedAt), // Update timestamp as Firestore Timestamp
      'createdBy': createdBy, // Creator ID
    };
  }

  // Factory constructor to create a MenuItem instance from a map
  factory MenuItem.fromMap(Map<String, dynamic> map, String docId) {
  // Convert price safely
  final dynamic rawPrice = map['price'] ?? 0;
  final double price = rawPrice is int ? rawPrice.toDouble() : (rawPrice as num).toDouble();
  
  // Convert inventory requirements safely
  final Map<String, dynamic> rawInventory = map['inventoryRequirements'] ?? {};
  final Map<String, double> inventory = {};
  
  rawInventory.forEach((key, value) {
    if (value is int) {
      inventory[key] = value.toDouble();
    } else if (value is double) {
      inventory[key] = value;
    } else {
      inventory[key] = 0.0; // Default for unexpected types
    }
  });
  
  return MenuItem(
    id: docId,
    name: map['name'] ?? '',
    description: map['description'] ?? '',
    type: MenuItemType.values.firstWhere(
      (type) => type.toString().split('.').last == map['type'],
      orElse: () => MenuItemType.other,
    ),
    price: price,
    organizationId: map['organizationId'] ?? '',
    inventoryRequirements: inventory,
    createdAt: (map['createdAt'] as Timestamp).toDate(),
    updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    createdBy: map['createdBy'] ?? '',
  );
}

  // Method to create a copy of MenuItem instance with updated fields
  MenuItem copyWith({
    String? name, // Optional new name
    String? description, // Optional new description
    MenuItemType? type, // Optional new type
    double? price, // Optional new price
    Map<String, double>? inventoryRequirements, // Optional new inventory requirements
  }) {
    return MenuItem(
      id: id, // Retain existing ID
      name: name ?? this.name, // Use new name if provided, otherwise retain existing
      description: description ?? this.description, // Use new description if provided, otherwise retain existing
      type: type ?? this.type, // Use new type if provided, otherwise retain existing
      price: price ?? this.price, // Use new price if provided, otherwise retain existing
      organizationId: organizationId, // Retain existing organization ID
      inventoryRequirements: inventoryRequirements ?? this.inventoryRequirements, // Use new inventory requirements if provided, otherwise retain existing
      createdAt: createdAt, // Retain existing creation timestamp
      updatedAt: DateTime.now(), // Update timestamp to current time
      createdBy: createdBy, // Retain existing creator ID
    );
  }
}