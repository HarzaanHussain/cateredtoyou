// menu_item_task.dart

import 'package:cateredtoyou/models/task/task_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// MenuItemTask class represents tasks related to menu items
class MenuItemTask extends Task {
  const MenuItemTask({
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
    required int quantity,
  });

  @override
  String getTaskType() => 'MenuItemTask';

  // Factory method to create MenuItemTask from Firestore map
  factory MenuItemTask.fromMap(Map<String, dynamic> map, String documentId) {
    try {
      return MenuItemTask(
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
        quantity: map['quantity'] ?? 0,
      );
    } catch (e, stackTrace) {
      debugPrint('Error creating MenuItemTask: $e');
      rethrow;
    }
  }
}
