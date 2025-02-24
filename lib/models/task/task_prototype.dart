import 'package:flutter/foundation.dart';
import 'package:cateredtoyou/models/task/task_model.dart';
import 'package:cateredtoyou/models/task/event_task_prototype.dart';
import 'package:cateredtoyou/models/task/menu_item_task_prototype.dart';
import 'package:cateredtoyou/models/task/delivery_task_prototype.dart';

/// Abstract base class for task prototypes.
/// Task prototypes define the template for tasks that will be instantiated later.
abstract class TaskPrototype {
  final String description; // Description of the task
  final TaskPriority defaultPriority; // Default priority level of this task
  final String departmentId; // The department responsible for this task

  const TaskPrototype({
    required this.description,
    required this.defaultPriority,
    required this.departmentId,
  });

  /// Converts the prototype to a map for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'defaultPriority': defaultPriority.toString().split('.').last,
      'departmentId': departmentId,
      'prototypeType': getPrototypeType(),
    };
  }

  /// Returns the specific type of task prototype.
  /// Each subclass must override this method.
  String getPrototypeType();

  /// Validates that all required fields are present and correctly formatted.
  bool validate() {
    bool isValid = description.isNotEmpty &&
        departmentId.isNotEmpty;
    if (!isValid) {
      debugPrint('TaskPrototype validation failed for task: $description');
    }
    return isValid;
  }

  /// Factory method to create the appropriate subclass from Firestore data.
  static TaskPrototype fromMap(Map<String, dynamic> map) {
    try {
      switch (map['prototypeType']) {
        case 'EventTaskPrototype':
          return EventTaskPrototype.fromMap(map);
        case 'MenuItemTaskPrototype':
          return MenuItemTaskPrototype.fromMap(map);
        case 'DeliveryTaskPrototype':
          return DeliveryTaskPrototype.fromMap(map);
        default:
          throw ArgumentError('Unknown prototypeType: ${map['prototypeType']}');
      }
    } catch (e) {
      debugPrint('Error in TaskPrototype.fromMap: $e');
      rethrow; // Propagate the error
    }
  }
}
