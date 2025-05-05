import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum representing the workflow stages of a manifest item
enum Stage {
  prep,
  assign,
  load,
  deliver
}

/// Enum representing the status of a manifest item
enum ItemStatus {
  raw,
  cooked,
  serviceReady
}

/// Represents an individual manifest item in the catering workflow
class ManifestItem {
  final String id;               // Unique identifier
  final String eventId;          // Reference to parent event
  final String itemId;           // Reference to menu/inventory item
  final String itemName;         // Display name for convenience
  final int originalAmount;      // Total planned quantity for event (never changes)
  int currentAmount;             // Current quantity this document represents
  Stage currentStage;            // Current workflow stage
  ItemStatus? status;             // Item preparation status
  int assignedAmount;            // Amount assigned to a vehicle
  int loadedAmount;              // Amount confirmed loaded
  String? vehicleId;             // Reference to vehicle (if assigned)
  String lastUpdatedBy;          // User ID who last modified
  DateTime lastUpdatedAt;        // Last update timestamp
  final String organizationId;   // Organization context
  String? notes;                 // Optional notes

  ManifestItem({
    required this.id,
    required this.eventId,
    required this.itemId,
    required this.itemName,
    required this.originalAmount,
    required this.currentAmount,
    required this.currentStage,
    this.status,
    required this.assignedAmount,
    required this.loadedAmount,
    this.vehicleId,
    required this.lastUpdatedBy,
    required this.lastUpdatedAt,
    required this.organizationId,
    this.notes,
  });

  /// Creates a ManifestItem from a Firestore document
  factory ManifestItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ManifestItem(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      itemId: data['itemId'] ?? '',
      itemName: data['itemName'] ?? '',
      originalAmount: data['originalAmount'] ?? 0,
      currentAmount: data['currentAmount'] ?? 0,
      currentStage: stageFromString(data['currentStage']),
      status: _statusFromString(data['status'] ?? ''),
      assignedAmount: data['assignedAmount'] ?? 0,
      loadedAmount: data['loadedAmount'] ?? 0,
      vehicleId: data['vehicleId'],
      lastUpdatedBy: data['lastUpdatedBy'] ?? '',
      lastUpdatedAt: (data['lastUpdatedAt'] as Timestamp).toDate(),
      organizationId: data['organizationId'] ?? '',
      notes: data['notes'],
    );
  }

  /// Creates a ManifestItem from a map
  factory ManifestItem.fromMap(Map<String, dynamic> map, {String? docId}) {
    return ManifestItem(
      id: docId ?? map['id'] ?? '',
      eventId: map['eventId'] ?? '',
      itemId: map['itemId'] ?? '',
      itemName: map['itemName'] ?? '',
      originalAmount: map['originalAmount'] ?? 0,
      currentAmount: map['currentAmount'] ?? 0,
      currentStage: stageFromString(map['currentStage']),
      status: _statusFromString(map['status'] ?? ''),
      assignedAmount: map['assignedAmount'] ?? 0,
      loadedAmount: map['loadedAmount'] ?? 0,
      vehicleId: map['vehicleId'],
      lastUpdatedBy: map['lastUpdatedBy'] ?? '',
      lastUpdatedAt: map['lastUpdatedAt'] is Timestamp
          ? (map['lastUpdatedAt'] as Timestamp).toDate()
          : DateTime.parse(map['lastUpdatedAt'].toString()),
      organizationId: map['organizationId'] ?? '',
      notes: map['notes'],
    );
  }

  /// Converts Stage enum to string
  static String stageToString(Stage stage) {
    return stage.toString().split('.').last;
  }

  /// Converts string to Stage enum
  static Stage stageFromString(String? stageStr) {
    return Stage.values.firstWhere(
          (e) => e.toString().split('.').last == stageStr,
      orElse: () => throw ArgumentError('Invalid stage string: $stageStr'),
    );
  }

  /// Converts ItemStatus enum to string
  static String statusToString(ItemStatus status) {
    return status.toString().split('.').last;
  }

  /// Converts string to ItemStatus enum
static ItemStatus _statusFromString(String statusStr) {
  return ItemStatus.values.firstWhere(
    (e) => e.toString().split('.').last == statusStr,
    orElse: () => throw ArgumentError('Invalid status string: $statusStr'),
  );
}

  /// Converts this ManifestItem to a Firestore-compatible map
  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'itemId': itemId,
      'itemName': itemName,
      'originalAmount': originalAmount,
      'currentAmount': currentAmount,
      'currentStage': stageToString(currentStage),
      'status': statusToString(status!),
      'assignedAmount': assignedAmount,
      'loadedAmount': loadedAmount,
      'vehicleId': vehicleId,
      'lastUpdatedBy': lastUpdatedBy,
      'lastUpdatedAt': Timestamp.fromDate(lastUpdatedAt),
      'organizationId': organizationId,
      'notes': notes,
    };
  }

  /// Creates a copy of this ManifestItem with optional changes
  ManifestItem copyWith({
    String? eventId,
    String? itemId,
    String? itemName,
    int? originalAmount,
    int? currentAmount,
    Stage? currentStage,
    ItemStatus? status,
    int? assignedAmount,
    int? loadedAmount,
    String? vehicleId,
    bool clearVehicleId = false,
    String? lastUpdatedBy,
    DateTime? lastUpdatedAt,
    String? organizationId,
    String? notes,
    bool clearNotes = false,
  }) {
    return ManifestItem(
      id: id,
      eventId: eventId ?? this.eventId,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      originalAmount: originalAmount ?? this.originalAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      currentStage: currentStage ?? this.currentStage,
      status: status ?? this.status,
      assignedAmount: assignedAmount ?? this.assignedAmount,
      loadedAmount: loadedAmount ?? this.loadedAmount,
      vehicleId: clearVehicleId ? null : (vehicleId ?? this.vehicleId),
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
      lastUpdatedAt: lastUpdatedAt ?? DateTime.now(),
      organizationId: organizationId ?? this.organizationId,
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }
}