import 'package:cloud_firestore/cloud_firestore.dart';

enum EventStatus {
  draft,
  pending,
  confirmed,
  inProgress,
  completed,
  cancelled,
  archived
}

class EventMenuItem {
  final String menuItemId;
  final String name;
  final double price;
  final int quantity;
  final String? specialInstructions;

  const EventMenuItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.quantity,
    this.specialInstructions,
  });

  Map<String, dynamic> toMap() {
    return {
      'menuItemId': menuItemId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'specialInstructions': specialInstructions,
    };
  }

  factory EventMenuItem.fromMap(Map<String, dynamic> map) {
    return EventMenuItem(
      menuItemId: map['menuItemId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 0,
      specialInstructions: map['specialInstructions'],
    );
  }
}

class EventSupply {
  final String inventoryId;
  final String name;
  final double quantity;
  final String unit;

  const EventSupply({
    required this.inventoryId,
    required this.name,
    required this.quantity,
    required this.unit,
  });

  Map<String, dynamic> toMap() {
    return {
      'inventoryId': inventoryId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
    };
  }

  factory EventSupply.fromMap(Map<String, dynamic> map) {
    return EventSupply(
      inventoryId: map['inventoryId'] ?? '',
      name: map['name'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: map['unit'] ?? '',
    );
  }
}
class AssignedStaff {
  final String userId;
  final String name;
  final String role;
  final DateTime assignedAt;

  const AssignedStaff({
    required this.userId,
    required this.name,
    required this.role,
    required this.assignedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'role': role,
      'assignedAt': Timestamp.fromDate(assignedAt),
    };
  }

  factory AssignedStaff.fromMap(Map<String, dynamic> map) {
    return AssignedStaff(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      assignedAt: (map['assignedAt'] as Timestamp).toDate(),
    );
  }
}


class Event {
  final String id;
  final String name;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final String location;
  final String customerId;
  final String organizationId;
  final int guestCount;
  final int minStaff;
  final String notes;
  final EventStatus status;
  final DateTime startTime;
  final DateTime endTime;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<EventMenuItem> menuItems;
  final List<EventSupply> supplies;
  final double totalPrice;
   final List<AssignedStaff> assignedStaff;
  final Map<String, dynamic>? metadata;
 
  

  const Event({
    required this.id,
    required this.name,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.customerId,
    required this.organizationId,
    required this.guestCount,
    required this.minStaff,
    this.notes = '',
    required this.status,
    required this.startTime,
    required this.endTime,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.menuItems = const [],
    this.supplies = const [],
    required this.totalPrice,
    this.assignedStaff = const [],
    this.metadata,
    
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'location': location,
      'customerId': customerId,
      'organizationId': organizationId,
      'guestCount': guestCount,
      'minStaff': minStaff,
      'notes': notes,
      'status': status.toString().split('.').last,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'menuItems': menuItems.map((item) => item.toMap()).toList(),
      'supplies': supplies.map((supply) => supply.toMap()).toList(),
      'totalPrice': totalPrice,
      'assignedStaff': assignedStaff.map((staff) => staff.toMap()).toList(),
      'metadata': metadata,
    };
  }

  factory Event.fromMap(Map<String, dynamic> map, String docId) {
    return Event(
      id: docId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      location: map['location'] ?? '',
      customerId: map['customerId'] ?? '',
      organizationId: map['organizationId'] ?? '',
      guestCount: map['guestCount'] ?? 0,
      minStaff: map['minStaff'] ?? 0,
      notes: map['notes'] ?? '',
      status: EventStatus.values.firstWhere(
        (status) => status.toString().split('.').last == map['status'],
        orElse: () => EventStatus.draft,
      ),
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp).toDate(),
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      menuItems: (map['menuItems'] as List<dynamic>?)
              ?.map((item) => EventMenuItem.fromMap(item))
              .toList() ??
          [],
      supplies: (map['supplies'] as List<dynamic>?)
              ?.map((supply) => EventSupply.fromMap(supply))
              .toList() ??
          [],
      totalPrice: (map['totalPrice'] ?? 0).toDouble(),
      assignedStaff: (map['assignedStaff'] as List<dynamic>?)
              ?.map((staff) => AssignedStaff.fromMap(staff))
              .toList() ??
          [],
      metadata: map['metadata'],
    );
  }

  Event copyWith({
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    String? customerId,
    int? guestCount,
    int? minStaff,
    String? notes,
    EventStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    List<EventMenuItem>? menuItems,
    List<EventSupply>? supplies,
    double? totalPrice,
    List<AssignedStaff>? assignedStaff,
    Map<String, dynamic>? metadata,
  }) {
    return Event(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      location: location ?? this.location,
      customerId: customerId ?? this.customerId,
      organizationId: organizationId,
      guestCount: guestCount ?? this.guestCount,
      minStaff: minStaff ?? this.minStaff,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      menuItems: menuItems ?? this.menuItems,
      supplies: supplies ?? this.supplies,
      totalPrice: totalPrice ?? this.totalPrice,
      assignedStaff: assignedStaff ?? this.assignedStaff,
      metadata: metadata ?? this.metadata,
    );
  }
}
