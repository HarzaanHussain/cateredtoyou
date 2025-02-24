// models/task/task_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:cateredtoyou/models/task/event_task.dart';
import 'package:cateredtoyou/models/task/menu_item_task.dart';
import 'package:cateredtoyou/models/task/delivery_task.dart';

// Enum for task status
enum TaskStatus {
  pending,
  inProgress,
  completed,
  blocked,
  cancelled
}

// Enum for task priority
enum TaskPriority {
  low,
  medium,
  high,
  urgent
}

// TaskComment class to store comment details for tasks
class TaskComment {
  final String id;
  final String userId;
  final String content;
  final DateTime createdAt;

  TaskComment({
    required this.id,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  // Convert TaskComment to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Factory method to create TaskComment from Firestore map
  factory TaskComment.fromMap(Map<String, dynamic> map, String commentId) {
    try {
      return TaskComment(
        id: commentId,
        userId: map['userId'] ?? '',
        content: map['content'] ?? '',
        createdAt: (map['createdAt'] as Timestamp).toDate(),
      );
    } catch (e, stackTrace) {
      debugPrint('Error creating TaskComment: $e\n$stackTrace');
      rethrow;
    }
  }
}

// Abstract Task class representing a general task with common fields
abstract class Task {
  final String id;
  final String eventId;
  final String description;
  final DateTime dueDate;
  final TaskStatus status;
  final TaskPriority priority;
  final String assignedTo;
  final String departmentId;
  final String organizationId;
  final List<TaskComment> comments;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Task({
    required this.id,
    required this.eventId,
    required this.description,
    required this.dueDate,
    required this.status,
    required this.priority,
    required this.assignedTo,
    required this.departmentId,
    required this.organizationId,
    this.comments = const [],
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  // Abstract method to get task type
  String getTaskType();

  // Convert Task to Firestore map
  Map<String, dynamic> toMap() {
    try {
      return {
        'eventId': eventId,
        'description': description,
        'dueDate': Timestamp.fromDate(dueDate),
        'status': status.toString().split('.').last,
        'priority': priority.toString().split('.').last,
        'assignedTo': assignedTo,
        'departmentId': departmentId,
        'organizationId': organizationId,
        'comments': comments.map((comment) => comment.toMap()).toList(),
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'taskType': getTaskType(),
      };
    } catch (e, stackTrace) {
      debugPrint('Error converting Task to map: $e\n$stackTrace');
      rethrow;
    }
  }

  // Static method to map Firestore data to specific Task subclass
  static Task fromMap(Map<String, dynamic> map, String documentId) {
    try {
      switch (map['taskType']) {
        case 'EventTask':
          return EventTask.fromMap(map, documentId);
        case 'MenuItemTask':
          return MenuItemTask.fromMap(map, documentId);
        case 'DeliveryTask':
          return DeliveryTask.fromMap(map, documentId);
        default:
          throw ArgumentError('Unknown taskType: ${map['taskType']}');
      }
    } catch (e, stackTrace) {
      debugPrint('Error converting Firestore data to Task: $e\n$stackTrace');
      rethrow;
    }
  }
}