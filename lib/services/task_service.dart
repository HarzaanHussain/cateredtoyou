import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cateredtoyou/models/task_model.dart';
import 'package:cateredtoyou/services/organization_service.dart';

class TaskService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OrganizationService _organizationService;

  TaskService(this._organizationService);

  // Get tasks with flexible filtering
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

      // Query tasks based on organization and assigned user
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

          // Apply additional filters in memory
          if (assignedTo != null) {
            tasks = tasks.where((task) => task.assignedTo == assignedTo).toList();
          }

          if (departmentId != null) {
            tasks = tasks.where((task) => task.departmentId == departmentId).toList();
          }

          // Sort by priority and due date
          tasks.sort((a, b) {
            final priorityComp = b.priority.index.compareTo(a.priority.index);
            if (priorityComp != 0) return priorityComp;
            return a.dueDate.compareTo(b.dueDate);
          });

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

  // Create a new task
  Future<Task> createTask({
    required String eventId,
    required String name,
    required String description,
    required DateTime dueDate,
    required TaskPriority priority,
    required String assignedTo,
    required String departmentId,
    List<String>? checklist,
     Map<String, dynamic>? inventoryUpdates,
  }) async {
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
      final docRef = _firestore.collection('tasks').doc();

      final task = Task(
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
        checklist: checklist ?? [],
        comments: [],
        inventoryUpdates: inventoryUpdates,
        createdBy: currentUser.uid,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(task.toMap());

      notifyListeners();
      return task;
    } catch (e) {
      debugPrint('Error creating task: $e');
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

      final task = Task.fromMap(taskDoc.data()!, taskId);
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      
      if (!userDoc.exists) throw 'User not found';
      final userRole = userDoc.data()?['role'] as String?;
      
      // Check if user can update the task
      if (task.assignedTo != currentUser.uid && 
          !['client', 'admin', 'manager'].contains(userRole)) {
        throw 'Insufficient permissions to update task';
      }

      if (!_isValidStatusTransition(task.status, newStatus)) {
        throw 'Invalid status transition';
      }

      await taskDoc.reference.update({
        'status': newStatus.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating task status: $e');
      rethrow;
    }
  }

  // Add comment to task
  Future<void> addTaskComment(String taskId, String content) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final taskDoc = await _firestore.collection('tasks').doc(taskId).get();
      if (!taskDoc.exists) throw 'Task not found';

      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) throw 'User not found';

      final userName = '${userDoc.data()?['firstName']} ${userDoc.data()?['lastName']}';
      final timestamp = FieldValue.serverTimestamp();

      // Create comment string in a consistent format
      final commentString = '${currentUser.uid}|$userName|$content|${DateTime.now().toIso8601String()}';

      await taskDoc.reference.update({
        'comments': FieldValue.arrayUnion([commentString]),
        'updatedAt': timestamp,
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error adding comment: $e');
      rethrow;
    }
  }

  // Parse comments from task
  List<TaskComment> parseComments(List<String> commentStrings) {
    return commentStrings.map((str) {
      final parts = str.split('|');
      if (parts.length != 4) return null;

      return TaskComment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: parts[0],
        userName: parts[1],
        content: parts[2],
        createdAt: DateTime.parse(parts[3]),
      );
    }).whereType<TaskComment>().toList();
  }

  // Update task checklist
  Future<void> updateTaskChecklist(String taskId, List<String> checklist) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final taskDoc = await _firestore.collection('tasks').doc(taskId).get();
      if (!taskDoc.exists) throw 'Task not found';

      final task = Task.fromMap(taskDoc.data()!, taskId);
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      
      if (!userDoc.exists) throw 'User not found';
      final userRole = userDoc.data()?['role'] as String?;
      
      // Check if user can update the task
      if (task.assignedTo != currentUser.uid && 
          !['client', 'admin', 'manager'].contains(userRole)) {
        throw 'Insufficient permissions to update task';
      }

      await taskDoc.reference.update({
        'checklist': checklist,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating task checklist: $e');
      rethrow;
    }
  }

  bool _isValidStatusTransition(TaskStatus current, TaskStatus next) {
    switch (current) {
      case TaskStatus.pending:
        return [TaskStatus.inProgress, TaskStatus.cancelled].contains(next);
      case TaskStatus.inProgress:
        return [TaskStatus.completed, TaskStatus.blocked].contains(next);
      case TaskStatus.blocked:
        return [TaskStatus.inProgress, TaskStatus.cancelled].contains(next);
      case TaskStatus.completed:
        return [TaskStatus.inProgress].contains(next);
      case TaskStatus.cancelled:
        return false;
      default:
        return false;
    }
  }

  // Get tasks by department
  Stream<List<Task>> getTasksByDepartment(String departmentId) {
    return getTasks(departmentId: departmentId);
  }

  // Get tasks assigned to user
  Stream<List<Task>> getAssignedTasks(String userId) {
    return getTasks(assignedTo: userId);
  }

  // Get overdue tasks
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
}