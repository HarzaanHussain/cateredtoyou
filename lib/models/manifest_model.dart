//lib/models/manifest_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Manifest {
  final String id; // Unique identifier for the manifest
  final String eventId; // Associated event ID
  final String organizationId; // Associated organization ID
  final List<ManifestItem> items; // List of items assigned to this manifest
  final DateTime createdAt; // Timestamp for when the plan was created
  final DateTime updatedAt; // Timestamp for when the plan was last updated

  Manifest({
    required this.id,
    required this.eventId,
    required this.organizationId,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to Firestore-compatible map
  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'organizationId': organizationId,
      'items': items.map((item) => item.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create from Firestore map
  factory Manifest.fromMap(Map<String, dynamic> map, String docId) {
    return Manifest(
      id: docId,
      eventId: map['eventId'] ?? '',
      organizationId: map['organizationId'] ?? '',
      items: (map['items'] as List<dynamic>?)
          ?.map((item) => ManifestItem.fromMap(item))
          .toList() ??
          [],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Copy with updated fields
  Manifest copyWith({
    String? eventId,
    String? organizationId,
    List<ManifestItem>? items,
  }) {
    return Manifest(
      id: id,
      eventId: eventId ?? this.eventId,
      organizationId: organizationId ?? this.organizationId,
      items: items ?? this.items,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

enum LoadingStatus { unassigned, pending, loaded }

class ManifestItem {
  final String id; // Unique identifier for the manifest item
  final String menuItemId; // ID of the menu item
  final int quantity; // Quantity of the item
  final String? vehicleId; // Assigned vehicle ID (nullable)
  final LoadingStatus loadingStatus; // Status of the manifest item

  ManifestItem({
    required this.id,
    required this.menuItemId,
    required this.quantity,
    this.vehicleId,
    required this.loadingStatus,
  });

  // Convert to Firestore-compatible map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'menuItemId': menuItemId,
      'quantity': quantity,
      'vehicleId': vehicleId,
      'loadingStatus': loadingStatus.toString().split('.').last,
    };
  }

  // Create from Firestore map
  factory ManifestItem.fromMap(Map<String, dynamic> map) {
    return ManifestItem(
      id: map['id'] ?? '',
      menuItemId: map['menuItemId'] ?? '',
      quantity: map['quantity'] ?? 0,
      vehicleId: map['vehicleId'],
      loadingStatus: LoadingStatus.values.firstWhere(
            (e) => e.toString().split('.').last == map['loadingStatus'],
        orElse: () => LoadingStatus.unassigned,
      ),
    );
  }
}
