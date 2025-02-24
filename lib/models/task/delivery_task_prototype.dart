import 'package:flutter/foundation.dart';
import 'package:cateredtoyou/models/task/task_prototype.dart';
import 'package:cateredtoyou/models/task/task_model.dart';

/// A prototype for delivery-related tasks.
/// These tasks specify when and how deliveries should be handled.
class DeliveryTaskPrototype extends TaskPrototype {
  final Duration deliveryWindow; // The time window in which the delivery should occur

  DeliveryTaskPrototype({
    required super.description,
    required super.defaultPriority,
    required super.departmentId,
    required this.deliveryWindow,
  });

  @override
  String getPrototypeType() {
    return 'DeliveryTaskPrototype';
  }

  /// Converts the prototype to a map for Firestore storage.
  @override
  Map<String, dynamic> toMap() {
    final baseMap = super.toMap();
    baseMap['deliveryWindow'] = deliveryWindow.inMinutes;
    return baseMap;
  }

  /// Factory method to create a DeliveryTaskPrototype from Firestore data.
  factory DeliveryTaskPrototype.fromMap(Map<String, dynamic> map) {
    try {
      return DeliveryTaskPrototype(
        description: map['description'] ?? '',
        defaultPriority: TaskPriority.values.firstWhere(
              (e) => e.toString().split('.').last == map['defaultPriority'],
          orElse: () {
            debugPrint('Invalid priority value: ${map['defaultPriority']}');
            return TaskPriority.medium;
          },
        ),
        departmentId: map['departmentId'] ?? '',
        deliveryWindow: Duration(minutes: map['deliveryWindow'] ?? 0),
      );
    } catch (e) {
      debugPrint('Error in DeliveryTaskPrototype.fromMap: $e');
      rethrow;
    }
  }
}
