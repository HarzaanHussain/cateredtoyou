// lib/models/inventory_item_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum InventoryCategory {
  food,
  beverage,
  equipment,
  supplies,
  disposable,
  cleaning,
  other
}

enum UnitType {
  piece,
  kilogram,
  gram,
  liter,
  milliliter,
  box,
  pack,
  other
}

class InventoryItem {
  final String id;
  final String name;
  final InventoryCategory category;
  final UnitType unit;
  final double quantity;
  final double reorderPoint;
  final double costPerUnit;
  final String? storageLocationId;
  final String organizationId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastModifiedBy;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.quantity,
    required this.reorderPoint,
    required this.costPerUnit,
    this.storageLocationId,
    required this.organizationId,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.lastModifiedBy,
  });

  bool get needsReorder => quantity <= reorderPoint;

  double get totalValue => quantity * costPerUnit;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category.toString().split('.').last,
      'unit': unit.toString().split('.').last,
      'quantity': quantity,
      'reorderPoint': reorderPoint,
      'costPerUnit': costPerUnit,
      'storageLocationId': storageLocationId,
      'organizationId': organizationId,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastModifiedBy': lastModifiedBy,
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map, String documentId) {
    return InventoryItem(
      id: documentId,
      name: map['name'] ?? '',
      category: InventoryCategory.values.firstWhere(
        (e) => e.toString().split('.').last == map['category'],
        orElse: () => InventoryCategory.other,
      ),
      unit: UnitType.values.firstWhere(
        (e) => e.toString().split('.').last == map['unit'],
        orElse: () => UnitType.other,
      ),
      quantity: (map['quantity'] ?? 0).toDouble(),
      reorderPoint: (map['reorderPoint'] ?? 0).toDouble(),
      costPerUnit: (map['costPerUnit'] ?? 0).toDouble(),
      storageLocationId: map['storageLocationId'],
      organizationId: map['organizationId'] ?? '',
      metadata: map['metadata'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      lastModifiedBy: map['lastModifiedBy'],
    );
  }

  InventoryItem copyWith({
    String? name,
    InventoryCategory? category,
    UnitType? unit,
    double? quantity,
    double? reorderPoint,
    double? costPerUnit,
    String? storageLocationId,
    Map<String, dynamic>? metadata,
    String? lastModifiedBy,
  }) {
    return InventoryItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      reorderPoint: reorderPoint ?? this.reorderPoint,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      storageLocationId: storageLocationId ?? this.storageLocationId,
      organizationId: organizationId,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
    );
  }
}