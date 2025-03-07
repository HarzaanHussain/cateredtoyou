// lib/models/manifest_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class Manifest {
  String get id;
  String get eventId;
  String get organizationId;
  List<ManifestItem> get items;
  DateTime get createdAt;
  DateTime get updatedAt;

  Map<String, dynamic> toMap();
}

enum ItemReadiness {
  unloadable,
  raw,
  unassembled,
  dished,
}

abstract class ManifestItem {
  String get menuItemId;
  String get name;
  ItemReadiness get readiness;

  Map<String, dynamic> toMap();
}

class EventManifest implements Manifest {
  @override
  final String id;
  @override
  final String eventId;
  @override
  final String organizationId;
  @override
  final List<EventManifestItem> items;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  EventManifest({
    required this.id,
    required this.eventId,
    required this.organizationId,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'organizationId': organizationId,
      'items': items.map((item) => item.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory EventManifest.fromMap(Map<String, dynamic> map, String docId) {
    return EventManifest(
      id: docId,
      eventId: map['eventId'] ?? '',
      organizationId: map['organizationId'] ?? '',
      items: (map['items'] as List<dynamic>?)
          ?.map((item) => EventManifestItem.fromMap(item))
          .toList() ??
          [],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  EventManifest copyWith({
    String? id,
    String? eventId,
    String? organizationId,
    List<EventManifestItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventManifest(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      organizationId: organizationId ?? this.organizationId,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class EventManifestItem implements ManifestItem {
  @override
  final String menuItemId;
  @override
  final String name;
  final int originalQuantity;
  final int quantityRemaining;
  final String? storageLocationId;
  @override
  final ItemReadiness readiness;

  EventManifestItem({
    required this.menuItemId,
    required this.name,
    required this.originalQuantity,
    required this.quantityRemaining,
    this.storageLocationId,
    required this.readiness,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'menuItemId': menuItemId,
      'name': name,
      'originalQuantity': originalQuantity,
      'quantityRemaining': quantityRemaining,
      'storageLocationId': storageLocationId,
      'readiness': readiness.toString().split('.').last,
    };
  }

  factory EventManifestItem.fromMap(Map<String, dynamic> map) {
    return EventManifestItem(
      menuItemId: map['menuItemId'] ?? '',
      name: map['name'] ?? '',
      originalQuantity: map['originalQuantity'] ?? 0,
      quantityRemaining: map['quantityRemaining'] ?? 0,
      storageLocationId: map['storageLocationId'],
      readiness: ItemReadiness.values.firstWhere(
            (e) => e.toString().split('.').last == map['readiness'],
        orElse: () => ItemReadiness.unloadable,
      ),
    );
  }

  EventManifestItem copyWith({
    String? id,
    String? menuItemId,
    String? name,
    int? originalQuantity,
    int? quantityRemaining,
    String? storageLocationId,
    ItemReadiness? readiness,
  }) {
    return EventManifestItem(
      menuItemId: menuItemId ?? this.menuItemId,
      name: name ?? this.name,
      originalQuantity: originalQuantity ?? this.originalQuantity,
      quantityRemaining: quantityRemaining ?? this.quantityRemaining,
      storageLocationId: storageLocationId ?? this.storageLocationId,
      readiness: readiness ?? this.readiness,
    );
  }

}

class DeliveryManifest implements Manifest {
  @override
  final String id;
  @override
  final String eventId;
  @override
  final String organizationId;
  @override
  final List<DeliveryManifestItem> items;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final String? vehicleId; // New field

  DeliveryManifest({
    required this.id,
    required this.eventId,
    required this.organizationId,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.vehicleId,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'organizationId': organizationId,
      'items': items.map((item) => item.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'vehicleId': vehicleId,
    };
  }

  factory DeliveryManifest.fromMap(Map<String, dynamic> map, String docId) {
    return DeliveryManifest(
      id: docId,
      eventId: map['eventId'] ?? '',
      organizationId: map['organizationId'] ?? '',
      items: (map['items'] as List<dynamic>?)
          ?.map((item) => DeliveryManifestItem.fromMap(item))
          .toList() ??
          [],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      vehicleId: map['vehicleId'],
    );
  }

  DeliveryManifest copyWith({
    String? id,
    String? eventId,
    String? organizationId,
    List<DeliveryManifestItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? vehicleId,
  }) {
    return DeliveryManifest(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      organizationId: organizationId ?? this.organizationId,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      vehicleId: vehicleId ?? this.vehicleId,
    );
  }
}

class DeliveryManifestItem implements ManifestItem {
  @override
  final String menuItemId;
  @override
  final String name;
  final int quantity;
  @override
  final ItemReadiness readiness;

  DeliveryManifestItem({
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.readiness,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'menuItemId': menuItemId,
      'name': name,
      'quantity': quantity,
      'readiness': readiness.toString().split('.').last,
    };
  }

  factory DeliveryManifestItem.fromMap(Map<String, dynamic> map) {
    return DeliveryManifestItem(
      menuItemId: map['menuItemId'] ?? '',
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? 0,
      readiness: ItemReadiness.values.firstWhere(
            (e) => e.toString().split('.').last == map['readiness'],
        orElse: () => ItemReadiness.unloadable,
      ),
    );
  }

  DeliveryManifestItem copyWith({
    String? id,
    String? menuItemId,
    String? name,
    int? quantity,
    ItemReadiness? readiness,
  }) {
    return DeliveryManifestItem(
      menuItemId: menuItemId ?? this.menuItemId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      readiness: readiness ?? this.readiness,
    );
  }
}