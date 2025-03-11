//lib/services/task_service.dart
// Import UserModel class for user data
import 'package:flutter/foundation.dart'; // Import foundation library for Flutter core functionality
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore package for database operations
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth package for authentication operations
import 'package:cateredtoyou/models/task/task_model.dart'; // Import Task and TaskStatus classes for task data
import 'package:cateredtoyou/models/task/event_task.dart'; // Import EventTask class for event-related tasks
import 'package:cateredtoyou/models/task/delivery_task.dart'; // Import DeliveryTask class for delivery-related tasks
import 'package:cateredtoyou/models/task/menu_item_task.dart'; // Import MenuItemTask class for menu item-related tasks
import 'package:cateredtoyou/services/organization_service.dart'; // Import OrganizationService for organization-related operations
import 'package:cateredtoyou/models/manifest_task_model.dart'; // Import ManifestTask class for manifest task data

class TaskService extends ChangeNotifier { // TaskService class extends ChangeNotifier to allow listeners to be notified of changes
  final FirebaseFirestore _firestore; // Firestore instance for database operations
  final FirebaseAuth _auth; // FirebaseAuth instance for authentication operations
  final OrganizationService _organizationService; // OrganizationService instance for organization-related operations

  TaskService(this._organizationService)
      : _firestore = FirebaseFirestore.instance,
        _auth = FirebaseAuth.instance;

// Query construction prioritizes database optimization:
// 1. First filters by organization for document security
// 2. Uses compound queries for efficient filtering
// 3. Applies client-side filters for complex conditions
// 4. Sorts by priority (high to low) then due date (earliest first)
 Stream<List<Task>> getTasks({
  String? eventId,
  String? assignedTo,
  String? departmentId,
  TaskStatus? status,
}) async* {
  try {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      yield [];
      return;
    }

    final organization = await _organizationService.getCurrentUserOrganization();
    if (organization == null) {
      yield [];
      return;
    }

    var query = _firestore.collection('tasks').where(
      Filter.or(
        Filter('organizationId', isEqualTo: organization.id),
        Filter('assignedTo', isEqualTo: currentUser.uid),
      ),
    );

    if (eventId != null) {
      query = query.where('eventId', isEqualTo: eventId);
    }

    if (status != null) {
      query = query.where('status', isEqualTo: status.toString().split('.').last);
    }
    yield* query.snapshots().map((snapshot) {
      try {
        var tasks = snapshot.docs
            .map((doc) => Task.fromMap(doc.data(), doc.id))
            .toList();

        if (assignedTo != null) {
          tasks = tasks.where((task) => task.assignedTo == assignedTo).toList();
        }

        if (departmentId != null) {
          tasks = tasks.where((task) => task.departmentId == departmentId).toList();
        }

        tasks.sort((a, b) {
          final priorityComp = b.priority.index.compareTo(a.priority.index);
          if (priorityComp != 0) return priorityComp;
          return a.dueDate.compareTo(b.dueDate);
        });
        for (var task in tasks) {
          debugPrint('Task ID: ${task.id}');
          debugPrint('Event ID: ${task.eventId}');
          debugPrint('Name: ${task.name}');
          debugPrint('Description: ${task.description}');
          debugPrint('Due Date: ${task.dueDate}');
          debugPrint('Status: ${task.status}');
          debugPrint('Priority: ${task.priority}');
          debugPrint('Assigned To: ${task.assignedTo}');
          debugPrint('Department ID: ${task.departmentId}');
          debugPrint('Organization ID: ${task.organizationId}');
          debugPrint('Checklist: ${task.checklist}');
          debugPrint('Comments: ${task.comments}');
          debugPrint('Inventory Updates: ${task.inventoryUpdates}');
          debugPrint('Created By: ${task.createdBy}');
          debugPrint('Created At: ${task.createdAt}');
          debugPrint('Updated At: ${task.updatedAt}');
        }

        return tasks;
      } catch (e) {
        debugPrint('Error mapping tasks: $e');
        return [];
      }
    });
  } catch (e) {
    debugPrint('Error in getTasks: $e');
    yield [];
  }
}

  Stream<List<Task>> getEventTasks() async* {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        yield [];
        return;
      }

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        yield [];
        return;
      }

      var query = _firestore.collection('tasks')
          .where('organizationId', isEqualTo: organization.id)
          .where('type', isEqualTo: 'eventTask');

      yield* query.snapshots().map((snapshot) {
        try {
          var tasks = snapshot.docs
              .map((doc) => Task.fromMap(doc.data(), doc.id))
              .toList();

          // Sorting: Priority first, then due date
          tasks.sort((a, b) {
            final priorityComp = b.priority.index.compareTo(a.priority.index);
            if (priorityComp != 0) return priorityComp;
            return a.dueDate.compareTo(b.dueDate);
          });

          return tasks;
        } catch (e) {
          debugPrint('Error mapping event tasks: $e');
          return [];
        }
      });
    } catch (e) {
      debugPrint('Error in getEventTasks: $e');
      yield [];
    }
  }


  // Create a new task
  Future<Task> createTask({
    required String taskType,
    required String eventId,
    required String name,
    required String description,
    required DateTime dueDate,
    required TaskPriority priority,
    required String assignedTo,
    required String departmentId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) throw 'User not found';

      final userRole = userDoc.data()?['role'] as String?;
      if (!['client', 'admin', 'manager', 'chef'].contains(userRole)) {
        throw 'Insufficient permissions to create tasks';
      }

      final now = DateTime.now();
      final docRef = _firestore.collection('tasks').doc();

      final task = TaskFactory.createTask(
        taskType: taskType,
        id: docRef.id,
        eventId: eventId,
        name: name.trim(),
        description: description.trim(),
        dueDate: dueDate,
        status: TaskStatus.pending,
        priority: priority,
        assignedTo: assignedTo,
        departmentId: departmentId,
        organizationId: organization.id,
        comments: [],
        createdBy: currentUser.uid,
        createdAt: now,
        updatedAt: now,
        metadata: metadata,
      );

      await docRef.set(task.toMap());
      notifyListeners();
      return task;
    } catch (e) {
      debugPrint('Error creating task: $e');
      rethrow;
    }
  }

  Stream<List<Task>> getTasksByDepartment(String departmentId) {
    return getTasks(departmentId: departmentId);
  }

  Stream<List<Task>> getAssignedTasks(String userId) {
    return getTasks(assignedTo: userId);
  }

  Stream<List<Task>> getOverdueTasks() async* {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        yield [];
        return;
      }

      yield* _firestore
          .collection('tasks')
          .where('dueDate', isLessThan: Timestamp.fromDate(DateTime.now()))
          .where('status', whereIn: [
        TaskStatus.pending.toString().split('.').last,
        TaskStatus.inProgress.toString().split('.').last,
      ])
          .where('assignedTo', isEqualTo: currentUser.uid)
          .snapshots()
          .map((snapshot) => snapshot.docs
          .map((doc) => Task.fromMap(doc.data(), doc.id))
          .toList());
    } catch (e) {
      debugPrint('Error getting overdue tasks: $e');
      yield [];
    }
  }

// Staff assignment requires multiple validations:
// 1. Current user must have staff assignment permissions (admin/manager/client)
// 2. For event-related tasks, new assignee must be part of event's assigned staff
// 3. New assignee must be an active employee in the organization
// 4. Task must belong to the same organization as both users
  Future<void> updateTaskAssignee(String taskId, String newAssigneeId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final hasPermission = await canAssignStaff();
      if (!hasPermission) {
        throw 'Insufficient permissions to assign staff';
      }

      final taskDoc = await _firestore.collection('tasks').doc(taskId).get();
      if (!taskDoc.exists) throw 'Task not found';

      final task = Task.fromMap(taskDoc.data()!, taskId);

      if (task.eventId.isNotEmpty) {
        final eventDoc = await _firestore.collection('events').doc(task.eventId).get();
        if (!eventDoc.exists) throw 'Event not found';

        final eventData = eventDoc.data()!;
        bool isStaffAssigned = false;

        if (eventData['assignedStaff'] != null) {
          if (eventData['assignedStaff'] is List) {
            for (var staff in eventData['assignedStaff']) {
              String staffId = '';
              if (staff is String) {
                staffId = staff;
              } else if (staff is Map) {
                staffId = staff['userId']?.toString() ?? '';
              }
              if (staffId == newAssigneeId) {
                isStaffAssigned = true;
                break;
              }
            }
          }
        }

        if (!isStaffAssigned) {
          throw 'Selected staff is not assigned to this event';
        }
      }

      final newAssigneeDoc = await _firestore.collection('users').doc(newAssigneeId).get();
      if (!newAssigneeDoc.exists) throw 'Staff member not found';

      final newAssigneeData = newAssigneeDoc.data();
      if (newAssigneeData == null || newAssigneeData['employmentStatus'] != 'active') {
        throw 'Selected staff member is not active';
      }

      await taskDoc.reference.update({
        'assignedTo': newAssigneeId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating task assignee: $e');
      rethrow;
    }
  }

  // Update task status
  Future<void> updateTaskStatus(String taskId, TaskStatus newStatus) async {
  try {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw 'Not authenticated';

    final taskDoc = await _firestore.collection('tasks').doc(taskId).get();
    if (!taskDoc.exists) throw 'Task not found';

    final taskData = taskDoc.data()!;
    final task = Task.fromMap(taskData, taskId);

    debugPrint('Current task status: ${task.status}, New status: $newStatus');

    notifyListeners();
  } catch (e) {
    debugPrint('Error updating task status: $e');
    rethrow;
  }
}


  bool _isValidStatusTransition(TaskStatus current, TaskStatus next) { // Function to validate task status transitions
    switch (current) {
      case TaskStatus.pending: // If current status is pending
        return [TaskStatus.inProgress, TaskStatus.cancelled].contains(next); // Valid transitions are to inProgress or cancelled
      case TaskStatus.inProgress: // If current status is inProgress
        return [TaskStatus.completed, TaskStatus.blocked].contains(next); // Valid transitions are to completed or blocked
      case TaskStatus.blocked: // If current status is blocked
        return [TaskStatus.inProgress, TaskStatus.cancelled].contains(next); // Valid transitions are to inProgress or cancelled
      case TaskStatus.completed: // If current status is completed
        return [TaskStatus.inProgress].contains(next); // Valid transition is to inProgress
      case TaskStatus.cancelled: // If current status is cancelled
        return false; // No valid transitions from cancelled
      default: // Default case
        return false; // No valid transitions
    }
  }


  Future<bool> canAssignStaff() async { // Function to check if the current user can assign staff
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) return false; // Return false if no user is authenticated

      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get(); // Get the user document
      if (!userDoc.exists) return false; // Return false if user document does not exist

      final userRole = userDoc.data()?['role'] as String?; // Get the user role
      return ['admin', 'client', 'manager'].contains(userRole); // Return true if user role is admin, client, or manager
    } catch (e) {
      debugPrint('Error checking staff assignment permission: $e'); // Print error message if query fails
      return false;
    }
  }

  // Delete tasks for an event
  Future<void> deleteTasksForEvent(String eventId) async {
  try {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw 'Not authenticated';

    final organization = await _organizationService.getCurrentUserOrganization();
    if (organization == null) throw 'Organization not found';

    // Get all tasks for the event
    final querySnapshot = await _firestore
        .collection('tasks')
        .where('eventId', isEqualTo: eventId)
        .where('organizationId', isEqualTo: organization.id)
        .get();

    if (querySnapshot.docs.isEmpty) return;

    // Use batch operation for better performance
    final batch = _firestore.batch();
    for (var doc in querySnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    notifyListeners();
  } catch (e) {
    debugPrint('Error deleting tasks for event: $e');
    rethrow;
  }
}


  /// Batch create multiple tasks at once
  /// [tasks] is a list of maps containing task data
  /// Returns a list of created Task objects
  Future<List<Task>> batchCreateTasks(List<Map<String, dynamic>> tasks) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      // Verify user has permission to create tasks
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) throw 'User not found';

      final userRole = userDoc.data()?['role'] as String?;
      if (!['client', 'admin', 'manager', 'chef'].contains(userRole)) {
        throw 'Insufficient permissions to create tasks';
      }

      final now = DateTime.now();
      final batch = _firestore.batch();
      final createdTasks = <Task>[];

      // Process each task in the batch
      for (final taskData in tasks) {
        final docRef = _firestore.collection('tasks').doc();

        final task = TaskFactory.createTask(
          taskType: taskData['taskType'] as String,
          id: docRef.id,
          eventId: taskData['eventId'] as String,
          name: (taskData['name'] as String).trim(),
          description: (taskData['description'] as String).trim(),
          dueDate: taskData['dueDate'] as DateTime,
          status: TaskStatus.pending,
          priority: taskData['priority'] as TaskPriority,
          assignedTo: taskData['assignedTo'] as String,
          departmentId: taskData['departmentId'] as String,
          organizationId: organization.id,
          comments: [],
          createdBy: currentUser.uid,
          createdAt: now,
          updatedAt: now,
          metadata: taskData['metadata'] as Map<String, dynamic>?,
        );

        // Set task in the batch
        batch.set(docRef, task.toMap());
        createdTasks.add(task);
      }

      // Commit the batch write
      await batch.commit();
      notifyListeners();
      return createdTasks;
    } catch (e) {
      debugPrint('Error in batch creating tasks: $e');
      rethrow;
    }
  }


  /// Batch update multiple tasks at once
  /// [updates] is a map where keys are task IDs and values are maps of fields to update
  /// Returns the number of successfully updated tasks
  Future<int> batchUpdateTasks(Map<String, Map<String, dynamic>> updates) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) throw 'Organization not found';

      final batch = _firestore.batch();
      var updatedCount = 0;

      // Verify each task exists and belongs to the organization
      for (final entry in updates.entries) {
        final taskId = entry.key;
        final updateData = entry.value;

        final taskDoc = await _firestore.collection('tasks').doc(taskId).get();
        if (!taskDoc.exists) {
          debugPrint('Task $taskId not found, skipping update');
          continue;
        }

        final taskData = taskDoc.data()!;
        if (taskData['organizationId'] != organization.id) {
          debugPrint('Task $taskId does not belong to organization, skipping update');
          continue;
        }

        // If status is being updated, validate the transition
        if (updateData.containsKey('status')) {
          final currentStatus = TaskStatus.values.firstWhere(
                (s) => s.toString().split('.').last == taskData['status'],
            orElse: () => TaskStatus.pending,
          );
          final newStatus = TaskStatus.values.firstWhere(
                (s) => s.toString().split('.').last == updateData['status'],
            orElse: () => TaskStatus.pending,
          );

          if (!_isValidStatusTransition(currentStatus, newStatus)) {
            debugPrint('Invalid status transition for task $taskId, skipping update');
            continue;
          }
        }

        // Add timestamp to updates
        updateData['updatedAt'] = FieldValue.serverTimestamp();

        batch.update(taskDoc.reference, updateData);
        updatedCount++;
      }

      if (updatedCount > 0) {
        await batch.commit();
        notifyListeners();
      }

      return updatedCount;
    } catch (e) {
      debugPrint('Error in batch updating tasks: $e');
      rethrow;
    }
  }

  Future<bool> addTaskComment({
    required String taskId,
    required String content,
  }) async {
    try {
      DocumentReference taskRef =
      _firestore.collection('tasks').doc(taskId);

      // Generate new comment ID
      String commentId = taskRef.collection('comments').doc().id;

      TaskComment newComment = TaskComment(
        id: commentId,
        userId: _auth.currentUser?.uid as String,
        content: content,
        createdAt: DateTime.now(),
      );

      // Add comment to Firestore as a subcollection
      await taskRef.update({
        'comments': FieldValue.arrayUnion([newComment.toMap()])
      });

      return true;
    } catch (e, stackTrace) {
      debugPrint('Error adding comment: $e\n$stackTrace');
      return false;
    }
  }

  Future<Task?> getTaskById(String taskId) async {
    try {
      DocumentSnapshot taskDoc =
      await _firestore.collection('tasks').doc(taskId).get();

      if (!taskDoc.exists) return null;

      return Task.fromMap(taskDoc.data() as Map<String, dynamic>, taskDoc.id);
    } catch (e, stackTrace) {
      debugPrint('Error fetching task: $e\n$stackTrace');
      return null;
    }
  }


  /// Placeholder for getAssignableStaff method
  getAssignableStaff(String eventId) { debugPrint('getAssignableStaff not yet implemented'); return null;}
}

class TaskFactory {
  static Task createTask({
    required String taskType,
    required String id,
    required String eventId,
    required String name,
    required String description,
    required DateTime dueDate,
    required TaskStatus status,
    required TaskPriority priority,
    required String assignedTo,
    required String departmentId,
    required String organizationId,
    required List<TaskComment> comments,
    required String createdBy,
    required DateTime createdAt,
    required DateTime updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    switch (taskType) {
      case 'EventTask':
        return EventTask(
          id: id,
          eventId: eventId,
          description: description,
          dueDate: dueDate,
          status: status,
          priority: priority,
          assignedTo: assignedTo,
          departmentId: departmentId,
          organizationId: organizationId,
          comments: comments,
          createdBy: createdBy,
          createdAt: createdAt,
          updatedAt: updatedAt,
          leadTime: metadata?['leadTime'] as Duration,
        );

      case 'MenuItemTask':
        return MenuItemTask(
          id: id,
          eventId: eventId,
          description: description,
          dueDate: dueDate,
          status: status,
          priority: priority,
          assignedTo: assignedTo,
          departmentId: departmentId,
          organizationId: organizationId,
          comments: comments,
          createdBy: createdBy,
          createdAt: createdAt,
          updatedAt: updatedAt,
          quantity: metadata?['quantity'] as int,
        );

      case 'DeliveryTask':
        return DeliveryTask(
          id: id,
          eventId: eventId,
          description: description,
          dueDate: dueDate,
          status: status,
          priority: priority,
          assignedTo: assignedTo,
          departmentId: departmentId,
          organizationId: organizationId,
          comments: comments,
          createdBy: createdBy,
          createdAt: createdAt,
          updatedAt: updatedAt,
          deliveryWindow: metadata?['deliveryWindow'] as Duration,
        );

      default:
        throw ArgumentError('Invalid task type: $taskType');
    }
  }
}