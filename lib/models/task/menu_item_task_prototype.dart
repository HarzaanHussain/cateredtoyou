import 'package:cateredtoyou/models/task/task_prototype.dart';
import 'package:cateredtoyou/models/task/task_model.dart';
import 'package:flutter/foundation.dart';

/// A prototype for tasks associated with menu items.
/// These tasks are generated based on the menu selection.
class MenuItemTaskPrototype extends TaskPrototype {
  MenuItemTaskPrototype({
    required super.description,
    required super.defaultPriority,
    required super.departmentId,
  });

  @override
  String getPrototypeType() {
    return 'MenuItemTaskPrototype';
  }

  /// Converts the prototype to a map for Firestore storage.
  @override
  Map<String, dynamic> toMap() {
    return super.toMap();
  }

  /// Factory method to create a MenuItemTaskPrototype from Firestore data.
  factory MenuItemTaskPrototype.fromMap(Map<String, dynamic> map) {
    try {
      return MenuItemTaskPrototype(
        description: map['description'] ?? '',
        defaultPriority: TaskPriority.values.firstWhere(
              (e) => e.toString().split('.').last == map['defaultPriority'],
          orElse: () {
            debugPrint('Invalid priority value: ${map['defaultPriority']}');
            return TaskPriority.medium;
          },
        ),
        departmentId: map['departmentId'] ?? '',
      );
    } catch (e) {
      debugPrint('Error in MenuItemTaskPrototype.fromMap: $e');
      rethrow;
    }
  }
}
