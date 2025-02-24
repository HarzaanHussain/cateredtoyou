import 'package:flutter/foundation.dart';
import 'package:cateredtoyou/models/task/task_prototype.dart';
import 'package:cateredtoyou/models/task/task_model.dart';

/// A prototype for event-related tasks.
/// These tasks are tied to specific events and require a lead time.
class EventTaskPrototype extends TaskPrototype {
  final Duration leadTime; // The time needed before the event to complete the task

  EventTaskPrototype({
    required super.description,
    required super.defaultPriority,
    required super.departmentId,
    required this.leadTime,
  });

  @override
  String getPrototypeType() {
    return 'EventTaskPrototype';
  }

  /// Converts the prototype to a map for Firestore storage.
  @override
  Map<String, dynamic> toMap() {
    final baseMap = super.toMap();
    baseMap['leadTime'] = leadTime.inMinutes;
    return baseMap;
  }

  /// Factory method to create an EventTaskPrototype from Firestore data.
  factory EventTaskPrototype.fromMap(Map<String, dynamic> map) {
    try {
      return EventTaskPrototype(
        description: map['description'] ?? '',
        defaultPriority: TaskPriority.values.firstWhere(
              (e) => e.toString().split('.').last == map['defaultPriority'],
          orElse: () {
            debugPrint('Invalid priority value: ${map['defaultPriority']}');
            return TaskPriority.medium;
          },
        ),
        departmentId: map['departmentId'] ?? '',
        leadTime: Duration(minutes: map['leadTime'] ?? 0),
      );
    } catch (e) {
      debugPrint('Error in EventTaskPrototype.fromMap: $e');
      rethrow;
    }
  }
}
