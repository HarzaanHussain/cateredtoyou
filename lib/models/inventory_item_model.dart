import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents different categories of inventory items.
enum InventoryCategory {
  food, // Food items
  beverage, // Beverage items
  equipment, // Equipment items
  supplies, // Supplies items
  disposable, // Disposable items
  cleaning, // Cleaning items
  other // Other items
}

/// Represents different unit types for inventory items.
enum UnitType {
  piece, // Measured in pieces
  kilogram, // Measured in kilograms
  gram, // Measured in grams
  liter, // Measured in liters
  milliliter, // Measured in milliliters
  box, // Measured in boxes
  pack, // Measured in packs
  other // Other unit types
}

/// A model class representing an inventory item.
class InventoryItem {
  final String id; // Unique identifier for the inventory item
  final String name; // Name of the inventory item
  final InventoryCategory category; // Category of the inventory item
  final UnitType unit; // Unit type of the inventory item
  final double quantity; // Quantity of the inventory item
  final double reorderPoint; // Reorder point for the inventory item
  final double costPerUnit; // Cost per unit of the inventory item
  final String? storageLocationId; // Optional storage location ID
  final String organizationId; // Organization ID to which the item belongs
  final Map<String, dynamic>? metadata; // Optional metadata for additional information
  final DateTime createdAt; // Timestamp when the item was created
  final DateTime updatedAt; // Timestamp when the item was last updated
  final String? lastModifiedBy; // Optional ID of the user who last modified the item

  /// Constructor for creating an [InventoryItem] instance.
  const InventoryItem({
    required this.id, // Required unique identifier
    required this.name, // Required name
    required this.category, // Required category
    required this.unit, // Required unit type
    required this.quantity, // Required quantity
    required this.reorderPoint, // Required reorder point
    required this.costPerUnit, // Required cost per unit
    this.storageLocationId, // Optional storage location ID
    required this.organizationId, // Required organization ID
    this.metadata, // Optional metadata
    required this.createdAt, // Required creation timestamp
    required this.updatedAt, // Required update timestamp
    this.lastModifiedBy, // Optional last modified by ID
  });

  /// Checks if the inventory item needs to be reordered.
  bool get needsReorder => quantity <= reorderPoint;

  /// Calculates the total value of the inventory item.
  double get totalValue => quantity * costPerUnit;

  /// Converts the [InventoryItem] instance to a map for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'name': name, // Name of the item
      'category': category.toString().split('.').last, // Category as a string
      'unit': unit.toString().split('.').last, // Unit type as a string
      'quantity': quantity, // Quantity of the item
      'reorderPoint': reorderPoint, // Reorder point of the item
      'costPerUnit': costPerUnit, // Cost per unit of the item
      'storageLocationId': storageLocationId, // Storage location ID
      'organizationId': organizationId, // Organization ID
      'metadata': metadata, // Metadata
      'createdAt': Timestamp.fromDate(createdAt), // Creation timestamp
      'updatedAt': Timestamp.fromDate(updatedAt), // Update timestamp
      'lastModifiedBy': lastModifiedBy, // Last modified by ID
    };
  }

  /// Factory constructor for creating an [InventoryItem] instance from a map.
  factory InventoryItem.fromMap(Map<String, dynamic> map, String documentId) {
    return InventoryItem(
      id: documentId, // Document ID from Firestore
      name: map['name'] ?? '', // Name from the map
      category: InventoryCategory.values.firstWhere(
        (e) => e.toString().split('.').last == map['category'],
        orElse: () => InventoryCategory.other,
      ), // Category from the map
      unit: UnitType.values.firstWhere(
        (e) => e.toString().split('.').last == map['unit'],
        orElse: () => UnitType.other,
      ), // Unit type from the map
      quantity: (map['quantity'] ?? 0).toDouble(), // Quantity from the map
      reorderPoint: (map['reorderPoint'] ?? 0).toDouble(), // Reorder point from the map
      costPerUnit: (map['costPerUnit'] ?? 0).toDouble(), // Cost per unit from the map
      storageLocationId: map['storageLocationId'], // Storage location ID from the map
      organizationId: map['organizationId'] ?? '', // Organization ID from the map
      metadata: map['metadata'], // Metadata from the map
      createdAt: (map['createdAt'] as Timestamp).toDate(), // Creation timestamp from the map
      updatedAt: (map['updatedAt'] as Timestamp).toDate(), // Update timestamp from the map
      lastModifiedBy: map['lastModifiedBy'], // Last modified by ID from the map
    );
  }

  /// Creates a copy of the [InventoryItem] instance with updated fields.
  InventoryItem copyWith({
    String? name, // Optional new name
    InventoryCategory? category, // Optional new category
    UnitType? unit, // Optional new unit type
    double? quantity, // Optional new quantity
    double? reorderPoint, // Optional new reorder point
    double? costPerUnit, // Optional new cost per unit
    String? storageLocationId, // Optional new storage location ID
    Map<String, dynamic>? metadata, // Optional new metadata
    String? lastModifiedBy, // Optional new last modified by ID
  }) {
    return InventoryItem(
      id: id, // Existing ID
      name: name ?? this.name, // New or existing name
      category: category ?? this.category, // New or existing category
      unit: unit ?? this.unit, // New or existing unit type
      quantity: quantity ?? this.quantity, // New or existing quantity
      reorderPoint: reorderPoint ?? this.reorderPoint, // New or existing reorder point
      costPerUnit: costPerUnit ?? this.costPerUnit, // New or existing cost per unit
      storageLocationId: storageLocationId ?? this.storageLocationId, // New or existing storage location ID
      organizationId: organizationId, // Existing organization ID
      metadata: metadata ?? this.metadata, // New or existing metadata
      createdAt: createdAt, // Existing creation timestamp
      updatedAt: DateTime.now(), // New update timestamp
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy, // New or existing last modified by ID
    );
  }
}