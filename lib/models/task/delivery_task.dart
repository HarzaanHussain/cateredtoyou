// delivery_task.dart

import 'package:cateredtoyou/models/task/task_model.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// DeliveryTask class represents delivery-related tasks
class DeliveryTask extends Task {
  final Duration deliveryWindow;

  const DeliveryTask({
    required super.id,
    required super.eventId,
    required super.description,
    required super.dueDate,
    required super.status,
    required super.priority,
    required super.assignedTo,
    required super.departmentId,
    required super.organizationId,
    required super.comments,
    required super.createdBy,
    required super.createdAt,
    required super.updatedAt,
    required this.deliveryWindow,
  });

  @override
  String getTaskType() => 'DeliveryTask';

  // Convert DeliveryTask to Firestore map
  @override
  Map<String, dynamic> toMap() {
    try {
      final baseMap = super.toMap();
      baseMap['deliveryWindow'] = deliveryWindow.inMinutes;
      return baseMap;
    } catch (e, stackTrace) {
      debugPrint('Error converting DeliveryTask to map: $e\n$stackTrace');
      rethrow;
    }
  }

  // Factory method to create DeliveryTask from Firestore map
  factory DeliveryTask.fromMap(Map<String, dynamic> map, String documentId) {
    try {
      return DeliveryTask(
        id: documentId,
        eventId: map['eventId'] ?? '',
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
        comments: (map['comments'] as List<dynamic>?)
            ?.map((comment) => TaskComment.fromMap(comment as Map<String, dynamic>, ''))
            .toList() ?? [],
        createdBy: map['createdBy'] ?? '',
        createdAt: map['createdAt'] is Timestamp
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        updatedAt: map['updatedAt'] is Timestamp
            ? (map['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
        deliveryWindow: Duration(minutes: map['deliveryWindow'] ?? 0),
      );
    } catch (e, stackTrace) {
      debugPrint('Error creating DeliveryTask: $e\n$stackTrace');
      rethrow;
    }
  }
}
