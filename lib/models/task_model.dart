// lib/models/task_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskStatus {
  pending,    // Task is created but not started
  inProgress, // Task is currently being worked on
  completed,  // Task is finished
  blocked,    // Task is blocked by some dependency
  cancelled   // Task is cancelled
}

enum TaskPriority {
  low,
  medium,
  high,
  urgent
}

class Task {
  final String id;
  final String eventId;
  final String name;
  final String description;
  final DateTime dueDate;
  final TaskStatus status;
  final TaskPriority priority;
  final String assignedTo; // User ID of assigned staff
  final String departmentId;
  final String organizationId;
  final List<String> checklist;
  final List<String> comments;
  final Map<String, dynamic>? inventoryUpdates; // For tasks that affect inventory
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Task({
    required this.id,
    required this.eventId,
    required this.name,
    required this.description,
    required this.dueDate,
    required this.status,
    required this.priority,
    required this.assignedTo,
    required this.departmentId,
    required this.organizationId,
    this.checklist = const [],
    this.comments = const [],
    this.inventoryUpdates,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'name': name,
      'description': description,
      'dueDate': Timestamp.fromDate(dueDate),
      'status': status.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'assignedTo': assignedTo,
      'departmentId': departmentId,
      'organizationId': organizationId,
      'checklist': checklist,
      'comments': comments,
      'inventoryUpdates': inventoryUpdates,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map, String documentId) {
    return Task(
      id: documentId,
      eventId: map['eventId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      dueDate: (map['dueDate'] as Timestamp).toDate(),
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
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Task copyWith({
    String? name,
    String? description,
    DateTime? dueDate,
    TaskStatus? status,
    TaskPriority? priority,
    String? assignedTo,
    List<String>? checklist,
    List<String>? comments,
    Map<String, dynamic>? inventoryUpdates,
  }) {
    return Task(
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
    );
  }
}

class TaskComment {
  final String id;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;

  TaskComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TaskComment.fromMap(Map<String, dynamic> map, String commentId) {
    return TaskComment(
      id: commentId,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      content: map['content'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
