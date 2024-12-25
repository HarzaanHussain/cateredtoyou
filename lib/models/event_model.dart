
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore package for database operations

// Enum representing the various statuses an event can have
enum EventStatus {
  draft, // Event is in draft state
  pending, // Event is pending approval or confirmation
  confirmed, // Event is confirmed
  inProgress, // Event is currently in progress
  completed, // Event has been completed
  cancelled, // Event has been cancelled
  archived // Event has been archived
}

// Class representing a menu item in an event
class EventMenuItem {
  final String menuItemId; // Unique identifier for the menu item
  final String name; // Name of the menu item
  final double price; // Price of the menu item
  final int quantity; // Quantity of the menu item
  final String? specialInstructions; // Special instructions for the menu item

  const EventMenuItem({
    required this.menuItemId, // Constructor parameter for menuItemId
    required this.name, // Constructor parameter for name
    required this.price, // Constructor parameter for price
    required this.quantity, // Constructor parameter for quantity
    this.specialInstructions, // Constructor parameter for special instructions
  });

  // Converts the EventMenuItem instance to a map
  Map<String, dynamic> toMap() {
    return {
      'menuItemId': menuItemId, // Map entry for menuItemId
      'name': name, // Map entry for name
      'price': price, // Map entry for price
      'quantity': quantity, // Map entry for quantity
      'specialInstructions': specialInstructions, // Map entry for special instructions
    };
  }

  // Factory constructor to create an EventMenuItem instance from a map
  factory EventMenuItem.fromMap(Map<String, dynamic> map) {
    return EventMenuItem(
      menuItemId: map['menuItemId'] ?? '', // Extracts menuItemId from map
      name: map['name'] ?? '', // Extracts name from map
      price: (map['price'] ?? 0).toDouble(), // Extracts and converts price from map
      quantity: map['quantity'] ?? 0, // Extracts quantity from map
      specialInstructions: map['specialInstructions'], // Extracts special instructions from map
    );
  }
}

// Class representing a supply item in an event
class EventSupply {
  final String inventoryId; // Unique identifier for the supply item
  final String name; // Name of the supply item
  final double quantity; // Quantity of the supply item
  final String unit; // Unit of measurement for the supply item

  const EventSupply({
    required this.inventoryId, // Constructor parameter for inventoryId
    required this.name, // Constructor parameter for name
    required this.quantity, // Constructor parameter for quantity
    required this.unit, // Constructor parameter for unit
  });

  // Converts the EventSupply instance to a map
  Map<String, dynamic> toMap() {
    return {
      'inventoryId': inventoryId, // Map entry for inventoryId
      'name': name, // Map entry for name
      'quantity': quantity, // Map entry for quantity
      'unit': unit, // Map entry for unit
    };
  }

  // Factory constructor to create an EventSupply instance from a map
  factory EventSupply.fromMap(Map<String, dynamic> map) {
    return EventSupply(
      inventoryId: map['inventoryId'] ?? '', // Extracts inventoryId from map
      name: map['name'] ?? '', // Extracts name from map
      quantity: (map['quantity'] ?? 0).toDouble(), // Extracts and converts quantity from map
      unit: map['unit'] ?? '', // Extracts unit from map
    );
  }
}

// Class representing an assigned staff member for an event
class AssignedStaff {
  final String userId; // Unique identifier for the staff member
  final String name; // Name of the staff member
  final String role; // Role of the staff member
  final DateTime assignedAt; // Date and time when the staff member was assigned

  const AssignedStaff({
    required this.userId, // Constructor parameter for userId
    required this.name, // Constructor parameter for name
    required this.role, // Constructor parameter for role
    required this.assignedAt, // Constructor parameter for assignedAt
  });

  // Converts the AssignedStaff instance to a map
  Map<String, dynamic> toMap() {
    return {
      'userId': userId, // Map entry for userId
      'name': name, // Map entry for name
      'role': role, // Map entry for role
      'assignedAt': Timestamp.fromDate(assignedAt), // Map entry for assignedAt
    };
  }

  // Factory constructor to create an AssignedStaff instance from a map
  factory AssignedStaff.fromMap(Map<String, dynamic> map) {
    return AssignedStaff(
      userId: map['userId'] ?? '', // Extracts userId from map
      name: map['name'] ?? '', // Extracts name from map
      role: map['role'] ?? '', // Extracts role from map
      assignedAt: (map['assignedAt'] as Timestamp).toDate(), // Extracts and converts assignedAt from map
    );
  }
}

// Class representing an event
class Event {
  final String id; // Unique identifier for the event
  final String name; // Name of the event
  final String description; // Description of the event
  final DateTime startDate; // Start date of the event
  final DateTime endDate; // End date of the event
  final String location; // Location of the event
  final String customerId; // Customer ID associated with the event
  final String organizationId; // Organization ID associated with the event
  final int guestCount; // Number of guests expected at the event
  final int minStaff; // Minimum number of staff required for the event
  final String notes; // Additional notes for the event
  final EventStatus status; // Status of the event
  final DateTime startTime; // Start time of the event
  final DateTime endTime; // End time of the event
  final String createdBy; // User ID of the creator of the event
  final DateTime createdAt; // Date and time when the event was created
  final DateTime updatedAt; // Date and time when the event was last updated
  final List<EventMenuItem> menuItems; // List of menu items for the event
  final List<EventSupply> supplies; // List of supplies for the event
  final double totalPrice; // Total price of the event
  final List<AssignedStaff> assignedStaff; // List of assigned staff for the event
  final Map<String, dynamic>? metadata; // Additional metadata for the event

  const Event({
    required this.id, // Constructor parameter for id
    required this.name, // Constructor parameter for name
    required this.description, // Constructor parameter for description
    required this.startDate, // Constructor parameter for startDate
    required this.endDate, // Constructor parameter for endDate
    required this.location, // Constructor parameter for location
    required this.customerId, // Constructor parameter for customerId
    required this.organizationId, // Constructor parameter for organizationId
    required this.guestCount, // Constructor parameter for guestCount
    required this.minStaff, // Constructor parameter for minStaff
    this.notes = '', // Constructor parameter for notes with default value
    required this.status, // Constructor parameter for status
    required this.startTime, // Constructor parameter for startTime
    required this.endTime, // Constructor parameter for endTime
    required this.createdBy, // Constructor parameter for createdBy
    required this.createdAt, // Constructor parameter for createdAt
    required this.updatedAt, // Constructor parameter for updatedAt
    this.menuItems = const [], // Constructor parameter for menuItems with default value
    this.supplies = const [], // Constructor parameter for supplies with default value
    required this.totalPrice, // Constructor parameter for totalPrice
    this.assignedStaff = const [], // Constructor parameter for assignedStaff with default value
    this.metadata, // Constructor parameter for metadata
  });

  // Converts the Event instance to a map
  Map<String, dynamic> toMap() {
    return {
      'name': name, // Map entry for name
      'description': description, // Map entry for description
      'startDate': Timestamp.fromDate(startDate), // Map entry for startDate
      'endDate': Timestamp.fromDate(endDate), // Map entry for endDate
      'location': location, // Map entry for location
      'customerId': customerId, // Map entry for customerId
      'organizationId': organizationId, // Map entry for organizationId
      'guestCount': guestCount, // Map entry for guestCount
      'minStaff': minStaff, // Map entry for minStaff
      'notes': notes, // Map entry for notes
      'status': status.toString().split('.').last, // Map entry for status
      'startTime': Timestamp.fromDate(startTime), // Map entry for startTime
      'endTime': Timestamp.fromDate(endTime), // Map entry for endTime
      'createdBy': createdBy, // Map entry for createdBy
      'createdAt': Timestamp.fromDate(createdAt), // Map entry for createdAt
      'updatedAt': Timestamp.fromDate(updatedAt), // Map entry for updatedAt
      'menuItems': menuItems.map((item) => item.toMap()).toList(), // Map entry for menuItems
      'supplies': supplies.map((supply) => supply.toMap()).toList(), // Map entry for supplies
      'totalPrice': totalPrice, // Map entry for totalPrice
      'assignedStaff': assignedStaff.map((staff) => staff.toMap()).toList(), // Map entry for assignedStaff
      'metadata': metadata, // Map entry for metadata
    };
  }

  // Factory constructor to create an Event instance from a map
  factory Event.fromMap(Map<String, dynamic> map, String docId) {
    return Event(
      id: docId, // Extracts id from map
      name: map['name'] ?? '', // Extracts name from map
      description: map['description'] ?? '', // Extracts description from map
      startDate: (map['startDate'] as Timestamp).toDate(), // Extracts and converts startDate from map
      endDate: (map['endDate'] as Timestamp).toDate(), // Extracts and converts endDate from map
      location: map['location'] ?? '', // Extracts location from map
      customerId: map['customerId'] ?? '', // Extracts customerId from map
      organizationId: map['organizationId'] ?? '', // Extracts organizationId from map
      guestCount: map['guestCount'] ?? 0, // Extracts guestCount from map
      minStaff: map['minStaff'] ?? 0, // Extracts minStaff from map
      notes: map['notes'] ?? '', // Extracts notes from map
      status: EventStatus.values.firstWhere(
        (status) => status.toString().split('.').last == map['status'], // Extracts and converts status from map
        orElse: () => EventStatus.draft, // Default value for status
      ),
      startTime: (map['startTime'] as Timestamp).toDate(), // Extracts and converts startTime from map
      endTime: (map['endTime'] as Timestamp).toDate(), // Extracts and converts endTime from map
      createdBy: map['createdBy'] ?? '', // Extracts createdBy from map
      createdAt: (map['createdAt'] as Timestamp).toDate(), // Extracts and converts createdAt from map
      updatedAt: (map['updatedAt'] as Timestamp).toDate(), // Extracts and converts updatedAt from map
      menuItems: (map['menuItems'] as List<dynamic>?)
              ?.map((item) => EventMenuItem.fromMap(item))
              .toList() ??
          [], // Extracts and converts menuItems from map
      supplies: (map['supplies'] as List<dynamic>?)
              ?.map((supply) => EventSupply.fromMap(supply))
              .toList() ??
          [], // Extracts and converts supplies from map
      totalPrice: (map['totalPrice'] ?? 0).toDouble(), // Extracts and converts totalPrice from map
      assignedStaff: (map['assignedStaff'] as List<dynamic>?)
              ?.map((staff) => AssignedStaff.fromMap(staff))
              .toList() ??
          [], // Extracts and converts assignedStaff from map
      metadata: map['metadata'], // Extracts metadata from map
    );
  }

  // Creates a copy of the Event instance with updated values
  Event copyWith({
    String? name, // Optional parameter for name
    String? description, // Optional parameter for description
    DateTime? startDate, // Optional parameter for startDate
    DateTime? endDate, // Optional parameter for endDate
    String? location, // Optional parameter for location
    String? customerId, // Optional parameter for customerId
    int? guestCount, // Optional parameter for guestCount
    int? minStaff, // Optional parameter for minStaff
    String? notes, // Optional parameter for notes
    EventStatus? status, // Optional parameter for status
    DateTime? startTime, // Optional parameter for startTime
    DateTime? endTime, // Optional parameter for endTime
    List<EventMenuItem>? menuItems, // Optional parameter for menuItems
    List<EventSupply>? supplies, // Optional parameter for supplies
    double? totalPrice, // Optional parameter for totalPrice
    List<AssignedStaff>? assignedStaff, // Optional parameter for assignedStaff
    Map<String, dynamic>? metadata, // Optional parameter for metadata
  }) {
    return Event(
      id: id, // Keeps the original id
      name: name ?? this.name, // Uses the new name if provided, otherwise keeps the original name
      description: description ?? this.description, // Uses the new description if provided, otherwise keeps the original description
      startDate: startDate ?? this.startDate, // Uses the new startDate if provided, otherwise keeps the original startDate
      endDate: endDate ?? this.endDate, // Uses the new endDate if provided, otherwise keeps the original endDate
      location: location ?? this.location, // Uses the new location if provided, otherwise keeps the original location
      customerId: customerId ?? this.customerId, // Uses the new customerId if provided, otherwise keeps the original customerId
      organizationId: organizationId, // Keeps the original organizationId
      guestCount: guestCount ?? this.guestCount, // Uses the new guestCount if provided, otherwise keeps the original guestCount
      minStaff: minStaff ?? this.minStaff, // Uses the new minStaff if provided, otherwise keeps the original minStaff
      notes: notes ?? this.notes, // Uses the new notes if provided, otherwise keeps the original notes
      status: status ?? this.status, // Uses the new status if provided, otherwise keeps the original status
      startTime: startTime ?? this.startTime, // Uses the new startTime if provided, otherwise keeps the original startTime
      endTime: endTime ?? this.endTime, // Uses the new endTime if provided, otherwise keeps the original endTime
      createdBy: createdBy, // Keeps the original createdBy
      createdAt: createdAt, // Keeps the original createdAt
      updatedAt: DateTime.now(), // Updates the updatedAt to the current date and time
      menuItems: menuItems ?? this.menuItems, // Uses the new menuItems if provided, otherwise keeps the original menuItems
      supplies: supplies ?? this.supplies, // Uses the new supplies if provided, otherwise keeps the original supplies
      totalPrice: totalPrice ?? this.totalPrice, // Uses the new totalPrice if provided, otherwise keeps the original totalPrice
      assignedStaff: assignedStaff ?? this.assignedStaff, // Uses the new assignedStaff if provided, otherwise keeps the original assignedStaff
      metadata: metadata ?? this.metadata, // Uses the new metadata if provided, otherwise keeps the original metadata
    );
  }
}
