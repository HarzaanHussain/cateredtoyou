import 'package:cloud_firestore/cloud_firestore.dart';

enum MenuItemType {
  appetizer,
  mainCourse,
  sideDish,
  dessert,
  beverage,
  other
}

class MenuItem {
  final String id;
  final String name;
  final String description;
  final MenuItemType type;
  final double price;
  final String organizationId;
  final Map<String, double> inventoryRequirements;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.price,
    required this.organizationId,
    required this.inventoryRequirements,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'type': type.toString().split('.').last,
      'price': price,
      'organizationId': organizationId,
      'inventoryRequirements': inventoryRequirements,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
    };
  }

  factory MenuItem.fromMap(Map<String, dynamic> map, String docId) {
    return MenuItem(
      id: docId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      type: MenuItemType.values.firstWhere(
        (type) => type.toString().split('.').last == map['type'],
        orElse: () => MenuItemType.other,
      ),
      price: (map['price'] ?? 0).toDouble(),
      organizationId: map['organizationId'] ?? '',
      inventoryRequirements: Map<String, double>.from(map['inventoryRequirements'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      createdBy: map['createdBy'] ?? '',
    );
  }

  MenuItem copyWith({
    String? name,
    String? description,
    MenuItemType? type,
    double? price,
    Map<String, double>? inventoryRequirements,
  }) {
    return MenuItem(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      price: price ?? this.price,
      organizationId: organizationId,
      inventoryRequirements: inventoryRequirements ?? this.inventoryRequirements,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      createdBy: createdBy,
    );
  }
}