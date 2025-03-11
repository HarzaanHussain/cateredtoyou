import 'package:cateredtoyou/models/task_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Task model

// Define the readiness enum
enum ItemReadiness {
  unloadable,  // Not ready to be loaded
  raw,         // Raw ingredients
  cooked,      // Cooked but needs more preparation
  unassembled, // Components ready but not assembled
  assembled,   // Fully assembled but not ready for service
  service      // Ready for service
}

// Class representing a ManifestTask that extends Task
class ManifestTask extends Task {
  final String menuItemId;      // ID of the menu item
  final ItemReadiness readiness; // Readiness state of the item

  // Constructor for the ManifestTask class
  const ManifestTask({
    required super.id,
    required super.eventId,
    required super.name,
    required super.description,
    required super.dueDate,
    required super.status,
    required super.priority,
    required super.assignedTo,
    required super.departmentId,
    required super.organizationId,
    super.checklist = const [],
    super.comments = const [],
    super.inventoryUpdates,
    required super.createdBy,
    required super.createdAt,
    required super.updatedAt,
    required this.menuItemId,
    required this.readiness,
  });

  // Method to convert ManifestTask object to a map for Firestore
  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['menuItemId'] = menuItemId;
    map['readiness'] = readiness.toString().split('.').last;
    map['taskType'] = 'manifestTask'; // Add a type identifier
    return map;
  }

  // Factory constructor to create a ManifestTask object from a map
  factory ManifestTask.fromMap(Map<String, dynamic> map, String documentId) {
    return ManifestTask(
      id: documentId,
      eventId: map['eventId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      dueDate: map['dueDate'] is Timestamp
          ? (map['dueDate'] as Timestamp).toDate()
          : DateTime.now(),
      status: TaskStatus.values.firstWhere(
            (e) => e.toString().split('.').last == map['status'],
        orElse: () => TaskStatus.pending,
      ),
      priority: TaskPriority.values.firstWhere(
            (e) => e.toString().split('.').last == map['priority'],
        orElse: () => TaskPriority.medium,
      ),
      assignedTo: map['assignedTo'] ?? '',
      departmentId: map['departmentId'] ?? '',
      organizationId: map['organizationId'] ?? '',
      checklist: List<String>.from(map['checklist'] ?? []),
      comments: List<String>.from(map['comments'] ?? []),
      inventoryUpdates: map['inventoryUpdates'],
      createdBy: map['createdBy'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      menuItemId: map['menuItemId'] ?? '',
      readiness: ItemReadiness.values.firstWhere(
            (e) => e.toString().split('.').last == map['readiness'],
        orElse: () => ItemReadiness.unloadable,
      ),
    );
  }

  // Method to create a copy of the ManifestTask object with updated fields
  @override
  ManifestTask copyWith({
    String? name,
    String? description,
    DateTime? dueDate,
    TaskStatus? status,
    TaskPriority? priority,
    String? assignedTo,
    List<String>? checklist,
    List<String>? comments,
    Map<String, dynamic>? inventoryUpdates,
    String? menuItemId,
    ItemReadiness? readiness,
  }) {
    return ManifestTask(
      id: id,
      eventId: eventId,
      name: name ?? this.name,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignedTo: assignedTo ?? this.assignedTo,
      departmentId: departmentId,
      organizationId: organizationId,
      checklist: checklist ?? this.checklist,
      comments: comments ?? this.comments,
      inventoryUpdates: inventoryUpdates ?? this.inventoryUpdates,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      menuItemId: menuItemId ?? this.menuItemId,
      readiness: readiness ?? this.readiness,
    );
  }
}