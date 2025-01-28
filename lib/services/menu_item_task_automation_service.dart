import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:cateredtoyou/models/event_model.dart';
import 'package:cateredtoyou/models/menu_item_model.dart';
import 'package:cateredtoyou/models/task_model.dart';
import 'package:cateredtoyou/services/task_service.dart';

class MenuItemTaskAutomationService {
  final TaskService _taskService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  MenuItemTaskAutomationService(this._taskService);

  Future<void> generateTasksForMenuItems(Event event, List<MenuItem> menuItems, {Event? originalEvent}) async {
    try {
      final Map<String, String> staffByRole = {};
      for (final staff in event.assignedStaff) {
        staffByRole[staff.role] = staff.userId;
      }

      if (originalEvent != null) {
        await _handleMenuItemUpdate(event, originalEvent, menuItems, staffByRole);
      } else {
        await _createInitialMenuItemTasks(event, menuItems, staffByRole);
      }
    } catch (e) {
      debugPrint('Error generating menu item tasks: $e');
      rethrow;
    }
  }

  Future<void> _handleMenuItemUpdate(
      Event newEvent,
      Event oldEvent,
      List<MenuItem> menuItems,
      Map<String, String> staffByRole
      ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'Not authenticated';

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) throw 'User not found';

      final userRole = userDoc.data()?['role'] as String?;
      final permDoc = await _firestore.collection('permissions').doc(user.uid).get();

      final isManager = ['admin', 'client', 'manager'].contains(userRole);
      final permissions = permDoc.exists ?
      List<String>.from(permDoc.data()?['permissions'] ?? []) : [];
      final hasRequiredPermission =
          permissions.contains('manage_tasks') || permissions.contains('manage_events');

      if (!isManager && !hasRequiredPermission) {
        throw 'Insufficient permissions to update menu item tasks';
      }

      // Compare menu items and regenerate tasks if necessary
      await _processMenuItemTaskUpdates(newEvent, menuItems, staffByRole);
    } catch (e) {
      debugPrint('Error in menu item task update: $e');
      rethrow;
    }
  }

  Future<void> _processMenuItemTaskUpdates(
      Event event,
      List<MenuItem> menuItems,
      Map<String, String> staffByRole
      ) async {
    // Delete existing menu item tasks for this event
    final taskSnapshot = await _firestore
        .collection('tasks')
        .where('eventId', isEqualTo: event.id)
        .where('source', isEqualTo: 'menu_item')
        .get();

    final batch = _firestore.batch();
    for (final doc in taskSnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // Recreate tasks for current menu items
    await _createInitialMenuItemTasks(event, menuItems, staffByRole);
  }

  Future<void> _createInitialMenuItemTasks(
      Event event,
      List<MenuItem> menuItems,
      Map<String, String> staffByRole
      ) async {
    for (final menuItem in menuItems) {
      for (final task in menuItem.tasks) {
        // Adjust task timing based on event dates
        final dueDate = _calculateDueDateForMenuItemTask(event, task);

        // Create task with menu item specific metadata
        await _taskService.createTask(
            eventId: event.id,
            name: '${menuItem.name}: ${task.name}',
            description: '${task.description} for ${menuItem.name}',
            dueDate: dueDate,
            priority: task.priority,
            assignedTo: staffByRole[task.departmentId] ?? '',
            departmentId: task.departmentId,
            checklist: task.checklist,
            inventoryUpdates: task.inventoryUpdates,
            metadata: {
              'source': 'menu_item',
              'menuItemId': menuItem.id,
              'menuItemName': menuItem.name,
            }
        );
      }
    }
  }

  DateTime _calculateDueDateForMenuItemTask(Event event, Task task) {
    // Logic to calculate due date based on event dates and task requirements
    // This is a placeholder and should be customized based on specific business logic
    switch (task.priority) {
      case TaskPriority.urgent:
        return event.startDate.subtract(const Duration(hours: 4));
      case TaskPriority.high:
        return event.startDate.subtract(const Duration(days: 1));
      case TaskPriority.medium:
        return event.startDate.subtract(const Duration(days: 2));
      case TaskPriority.low:
        return event.startDate.subtract(const Duration(days: 3));
    }
  }
}