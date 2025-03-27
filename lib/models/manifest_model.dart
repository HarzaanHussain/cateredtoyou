import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a manifest, which is essentially a list of items assigned to a specific event.
/// This is tied to an event and an organization, and tracks the status of item loading.
class Manifest {
  final String id; // Unique identifier for the manifest document in Firestore
  final String eventId; // ID of the event this manifest belongs to
  final String organizationId; // ID of the organization managing this manifest
  final List<ManifestItem> items; // All items included in this manifest
  final DateTime createdAt; // Timestamp when the manifest was created
  final DateTime updatedAt; // Timestamp when the manifest was last updated
  final bool isArchived; // Whether this manifest is archived

  Manifest({
    required this.id,
    required this.eventId,
    required this.organizationId,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
  });

  /// Converts this manifest into a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'organizationId': organizationId,
      'items': items.map((item) => item.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isArchived': isArchived,
    };
  }

  /// Creates a Manifest object from a Firestore document snapshot.
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
      isArchived: map['isArchived'] ?? false,
    );
  }

  /// Creates a copy of the manifest with optional changes.
  /// The `updatedAt` field will always get refreshed to `DateTime.now()`.
  Manifest copyWith({
    String? eventId,
    String? organizationId,
    List<ManifestItem>? items,
    bool? isArchived,
  }) {
    return Manifest(
      id: id,
      eventId: eventId ?? this.eventId,
      organizationId: organizationId ?? this.organizationId,
      items: items ?? this.items,
      createdAt: createdAt,
      updatedAt: DateTime.now(), // Auto-update timestamp on change
      isArchived: isArchived ?? this.isArchived,
    );
  }
}

/// Enum representing the loading status of a manifest item.
enum LoadingStatus { unassigned, pending, loaded }

/// Represents an individual item within a manifest.
/// This tracks the item itself, how many are needed, and its loading status.
class ManifestItem {
  final String id; // Unique identifier for this manifest item (within the manifest)
  final String menuItemId; // ID of the actual menu item this represents
  final String name; // Human-readable name of the item (e.g., "Caesar Salad")
  final int quantity; // Number of this item needed for the event
  final String? vehicleId; // ID of the vehicle assigned to transport this item (optional)
  final LoadingStatus loadingStatus; // Current loading status (unassigned/pending/loaded)

  ManifestItem({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.quantity,
    this.vehicleId,
    required this.loadingStatus,
  });

  /// Converts this manifest item into a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'menuItemId': menuItemId,
      'name': name,
      'quantity': quantity,
      'vehicleId': vehicleId,
      'loadingStatus': loadingStatus.toString().split('.').last, // Store as simple string
    };
  }

  /// Creates a ManifestItem object from a Firestore map.
  factory ManifestItem.fromMap(Map<String, dynamic> map) {
    return ManifestItem(
      id: map['id'] ?? '',
      menuItemId: map['menuItemId'] ?? '',
      name: map['name'] ?? '', // New field - ensure we pull this correctly
      quantity: map['quantity'] ?? 0,
      vehicleId: map['vehicleId'],
      loadingStatus: LoadingStatus.values.firstWhere(
            (e) => e.toString().split('.').last == map['loadingStatus'],
        orElse: () => LoadingStatus.unassigned,
      ),
    );
  }

  /// Creates a copy of the manifest item with optional changes.
  ManifestItem copyWith({
    String? menuItemId,
    String? name,
    int? quantity,
    String? vehicleId,
    LoadingStatus? loadingStatus,
  }) {
    return ManifestItem(
      id: id,
      menuItemId: menuItemId ?? this.menuItemId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      vehicleId: vehicleId ?? this.vehicleId,
      loadingStatus: loadingStatus ?? this.loadingStatus,
    );
  }
}