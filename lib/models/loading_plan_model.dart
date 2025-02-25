//lib/models/loading_plan_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class LoadingPlan {
  final String id; // Unique identifier for the loading plan
  final String eventId; // Associated event ID
  final List<LoadingItem> items; // List of items assigned to this loading plan
  final DateTime createdAt; // Timestamp for when the plan was created
  final DateTime updatedAt; // Timestamp for when the plan was last updated

  LoadingPlan({
    required this.id,
    required this.eventId,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to Firestore-compatible map
  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'items': items.map((item) => item.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create from Firestore map
  factory LoadingPlan.fromMap(Map<String, dynamic> map, String docId) {
    return LoadingPlan(
      id: docId,
      eventId: map['eventId'] ?? '',
      items: (map['items'] as List<dynamic>?)
          ?.map((item) => LoadingItem.fromMap(item))
          .toList() ??
          [],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Copy with updated fields
  LoadingPlan copyWith({
    String? eventId,
    List<LoadingItem>? items,
  }) {
    return LoadingPlan(
      id: id,
      eventId: eventId ?? this.eventId,
      items: items ?? this.items,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class LoadingItem {
  final String eventMenuItemId; // ID of the menu item
  final int quantity; // Quantity of the item
  final String? vehicleId; // Assigned vehicle ID (nullable)

  LoadingItem({
    required this.eventMenuItemId,
    required this.quantity,
    this.vehicleId,
  });

  // Convert to Firestore-compatible map
  Map<String, dynamic> toMap() {
    return {
      'eventMenuItemId': eventMenuItemId,
      'quantity': quantity,
      'vehicleId': vehicleId,
    };
  }

  // Create from Firestore map
  factory LoadingItem.fromMap(Map<String, dynamic> map) {
    return LoadingItem(
      eventMenuItemId: map['eventMenuItemId'] ?? '',
      quantity: map['quantity'] ?? 0,
      vehicleId: map['vehicleId'],
    );
  }
}
