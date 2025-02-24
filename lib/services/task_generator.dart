import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cateredtoyou/models/task/task_model.dart';
import 'package:cateredtoyou/models/task/event_task.dart';
import 'package:cateredtoyou/models/task/menu_item_task.dart';
import 'package:cateredtoyou/models/task/delivery_task.dart';
import 'package:cateredtoyou/models/task/event_task_prototype.dart';
import 'package:cateredtoyou/models/task/menu_item_task_prototype.dart';
import 'package:cateredtoyou/models/task/delivery_task_prototype.dart';

/// Utility class responsible for generating different types of tasks from prototypes.
class TaskGenerator {
  // Common fields that will be needed for all task types
  final String organizationId;
  final String createdBy;

  const TaskGenerator({
    required this.organizationId,
    required this.createdBy,
  });

  // Helper method to generate a new task ID
  String _generateTaskId() => FirebaseFirestore.instance.collection('tasks').doc().id;

  // Helper method to create base task map with common fields
  Map<String, dynamic> _createBaseTaskMap({
    required String eventId,
    required String description,
    required DateTime dueDate,
    required TaskPriority priority,
    required String departmentId,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now();
    return {
      'eventId': eventId,
      'description': description,
      'dueDate': Timestamp.fromDate(dueDate),
      'status': TaskStatus.pending.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'assignedTo': '',
      'departmentId': departmentId,
      'organizationId': organizationId,
      'comments': [],
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// Extension for generating Event Tasks
extension EventTaskGeneration on TaskGenerator {
  EventTask generateEventTask(
      String eventId,
      EventTaskPrototype prototype,
      DateTime eventDate,
      ) {
    if (!prototype.validate()) {
      throw ArgumentError('Invalid event task prototype: ${prototype.description}');
    }

    final dueDate = eventDate.subtract(prototype.leadTime);
    final metadata = {'leadTime': prototype.leadTime.inMinutes};

    final taskMap = {
      ..._createBaseTaskMap(
        eventId: eventId,
        description: prototype.description,
        dueDate: dueDate,
        priority: prototype.defaultPriority,
        departmentId: prototype.departmentId,
        metadata: metadata,
      ),
      'taskType': 'EventTask',
    };

    return EventTask.fromMap(taskMap, _generateTaskId());
  }

  List<EventTask> generateEventTasks(
      String eventId,
      List<EventTaskPrototype> prototypes,
      DateTime eventDate,
      ) {
    return prototypes.map((prototype) =>
        generateEventTask(eventId, prototype, eventDate)
    ).toList();
  }
}

/// Extension for generating Menu Item Tasks
extension MenuItemTaskGeneration on TaskGenerator {
  MenuItemTask generateMenuItemTask(
      String eventId,
      MenuItemTaskPrototype prototype,
      DateTime eventDate, {
        required String menuItemId,
        required int quantity,
      }) {
    if (!prototype.validate()) {
      throw ArgumentError('Invalid menu item task prototype: ${prototype.description}');
    }

    final dueDate = eventDate;
    final metadata = {
      'preparationTime': 1, //todo:replace placeholder
      'menuItemId': menuItemId,
      'quantity': quantity,
      'equipmentNeeded': null, //todo:replace placeholder
    };

    final taskMap = {
      ..._createBaseTaskMap(
        eventId: eventId,
        description: prototype.description,
        dueDate: dueDate,
        priority: prototype.defaultPriority,
        departmentId: prototype.departmentId,
        metadata: metadata,
      ),
      'taskType': 'MenuItemTask',
    };

    return MenuItemTask.fromMap(taskMap, _generateTaskId());
  }

}