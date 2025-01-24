import 'package:cateredtoyou/models/user_model.dart'; // Import UserModel class for user data
import 'package:flutter/foundation.dart'; // Import foundation library for Flutter core functionality
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore package for database operations
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth package for authentication operations
import 'package:cateredtoyou/models/task_model.dart'; // Import Task and TaskStatus classes for task data
import 'package:cateredtoyou/services/organization_service.dart'; // Import OrganizationService for organization-related operations

class TaskService extends ChangeNotifier { // TaskService class extends ChangeNotifier to allow listeners to be notified of changes
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance for database operations
  final FirebaseAuth _auth = FirebaseAuth.instance; // FirebaseAuth instance for authentication operations
  final OrganizationService _organizationService; // OrganizationService instance for organization-related operations

  TaskService(this._organizationService); // Constructor to initialize OrganizationService

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
    required String eventId, // Required event ID for the task
    required String name, // Required name for the task
    required String description, // Required description for the task
    required DateTime dueDate, // Required due date for the task
    required TaskPriority priority, // Required priority for the task
    required String assignedTo, // Required user ID to assign the task to
    required String departmentId, // Required department ID for the task
    List<String>? checklist, // Optional checklist for the task
    Map<String, dynamic>? inventoryUpdates, // Optional inventory updates for the task
  }) async {
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) throw 'Not authenticated'; // Throw an error if no user is authenticated

      final organization = await _organizationService.getCurrentUserOrganization(); // Get the organization of the current user
      if (organization == null) throw 'Organization not found'; // Throw an error if no organization is found

      // Verify user has permission to create tasks
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get(); // Get the user document
      if (!userDoc.exists) throw 'User not found'; // Throw an error if user document does not exist

      final userRole = userDoc.data()?['role'] as String?; // Get the user role
      if (!['client', 'admin', 'manager', 'chef'].contains(userRole)) { // Check if user has permission to create tasks
        throw 'Insufficient permissions to create tasks'; // Throw an error if user does not have permission
      }

      final now = DateTime.now(); // Get the current date and time
      final docRef = _firestore.collection('tasks').doc(); // Create a new document reference for the task

      final task = Task(
        id: docRef.id, // Set the task ID to the document reference ID
        eventId: eventId, // Set the event ID for the task
        name: name.trim(), // Set the name for the task, trimming any whitespace
        description: description.trim(), // Set the description for the task, trimming any whitespace
        dueDate: dueDate, // Set the due date for the task
        status: TaskStatus.pending, // Set the initial status of the task to pending
        priority: priority, // Set the priority for the task
        assignedTo: assignedTo, // Set the user ID to assign the task to
        departmentId: departmentId, // Set the department ID for the task
        organizationId: organization.id, // Set the organization ID for the task
        checklist: checklist ?? [], // Set the checklist for the task, defaulting to an empty list if not provided
        comments: [], // Initialize the comments list for the task
        inventoryUpdates: inventoryUpdates, // Set the inventory updates for the task
        createdBy: currentUser.uid, // Set the user ID of the task creator
        createdAt: now, // Set the creation date and time for the task
        updatedAt: now, // Set the last updated date and time for the task
      );

      await docRef.set(task.toMap()); // Save the task to Firestore

      notifyListeners(); // Notify listeners of changes
      return task; // Return the created task
    } catch (e) {
      debugPrint('Error creating task: $e'); // Print error message if task creation fails
      rethrow; // Rethrow the error
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
    debugPrint('Task has inventory updates: ${taskData['inventoryUpdates'] != null}');
    
    // If task has inventory updates, log them
    if (taskData['inventoryUpdates'] != null) {
      debugPrint('Inventory updates data: ${taskData['inventoryUpdates']}');
    }

    // First check if all checklist items are complete
    if (newStatus == TaskStatus.completed && !_areAllChecklistItemsComplete(task.checklist)) {
      throw 'Cannot mark task as completed until all checklist items are done';
    }

    // Process inventory updates first if task is being completed
    if (newStatus == TaskStatus.completed && taskData['inventoryUpdates'] != null) {
      debugPrint('Processing inventory updates for completed task');
      
      await _firestore.runTransaction((transaction) async {
        for (final entry in (taskData['inventoryUpdates'] as Map<String, dynamic>).entries) {
          final inventoryId = entry.key;
          final updateData = entry.value as Map<String, dynamic>;
          final quantity = updateData['quantity'] as num;
          final type = updateData['type'] as String;

          debugPrint('Processing inventory item: $inventoryId');
          debugPrint('Update type: $type, Quantity: $quantity');

          final inventoryRef = _firestore.collection('inventory').doc(inventoryId);
          final inventoryDoc = await transaction.get(inventoryRef);

          if (!inventoryDoc.exists) {
            throw 'Inventory item $inventoryId not found';
          }

          final currentQuantity = inventoryDoc.data()?['quantity'] ?? 0;
          final quantityChange = type == 'add' ? quantity : -quantity;
          final newQuantity = currentQuantity + quantityChange;

          debugPrint('Current quantity: $currentQuantity, New quantity: $newQuantity');

          if (newQuantity < 0) {
            throw 'Cannot reduce inventory below 0';
          }

          // Update inventory quantity
          transaction.update(inventoryRef, {
            'quantity': newQuantity,
            'updatedAt': FieldValue.serverTimestamp(),
            'lastModifiedBy': currentUser.uid,
          });

          // Record the transaction
          final transactionRef = _firestore.collection('inventory_transactions').doc();
          transaction.set(transactionRef, {
            'itemId': inventoryId,
            'eventId': task.eventId,
            'taskId': taskId,
            'type': 'task_inventory_update',
            'quantity': quantity,
            'previousQuantity': currentQuantity,
            'newQuantity': newQuantity,
            'difference': quantityChange,
            'updateType': type,
            'timestamp': FieldValue.serverTimestamp(),
            'userId': currentUser.uid,
            'organizationId': task.organizationId,
            'notes': 'Inventory ${type == "add" ? "returned" : "allocated"} via task completion',
          });
        }

        // Update task status in the same transaction
        transaction.update(taskDoc.reference, {
          'status': newStatus.toString().split('.').last,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } else {
      // If no inventory updates or task not being completed, just update status
      await taskDoc.reference.update({
        'status': newStatus.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    notifyListeners();
  } catch (e) {
    debugPrint('Error updating task status: $e');
    rethrow;
  }
}

 
 Future<void> _processInventoryUpdates(Task task, String userId) async {
  debugPrint('Starting inventory updates for task: ${task.id}');
  debugPrint('Inventory updates data: ${task.inventoryUpdates}');
  
  try {
    if (task.inventoryUpdates == null || task.inventoryUpdates!.isEmpty) {
      debugPrint('No inventory updates found for task');
      return;
    }

    await _firestore.runTransaction((transaction) async {
      for (final entry in task.inventoryUpdates!.entries) {
        final inventoryId = entry.key;
        final updateData = entry.value as Map<String, dynamic>;
        final quantity = updateData['quantity'] as num;
        final type = updateData['type'] as String;

        debugPrint('Processing inventory item: $inventoryId');
        debugPrint('Update type: $type, Quantity: $quantity');

        final inventoryRef = _firestore.collection('inventory').doc(inventoryId);
        final inventoryDoc = await transaction.get(inventoryRef);

        if (!inventoryDoc.exists) {
          throw 'Inventory item $inventoryId not found';
        }

        final currentQuantity = inventoryDoc.data()?['quantity'] ?? 0;
        debugPrint('Current quantity: $currentQuantity');

        final quantityChange = type == 'add' ? quantity : -quantity;
        final newQuantity = currentQuantity + quantityChange;

        if (newQuantity < 0) {
          throw 'Cannot reduce inventory below 0. Current: $currentQuantity, Change: $quantityChange';
        }

        debugPrint('Updating quantity from $currentQuantity to $newQuantity');
        
        // Update inventory quantity
        transaction.update(inventoryRef, {
          'quantity': newQuantity,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
          'lastModifiedBy': userId,
        });

        // Record the transaction
        final transactionRef = _firestore.collection('inventory_transactions').doc();
        transaction.set(transactionRef, {
          'itemId': inventoryId,
          'eventId': task.eventId,
          'taskId': task.id,
          'type': 'task_inventory_update',
          'quantity': quantity,
          'previousQuantity': currentQuantity,
          'newQuantity': newQuantity,
          'difference': quantityChange,
          'updateType': type,
          'timestamp': FieldValue.serverTimestamp(),
          'userId': userId,
          'organizationId': task.organizationId,
          'notes': 'Inventory ${type == "add" ? "returned" : "allocated"} via task completion'
        });
      }
    });

    debugPrint('Inventory updates completed successfully');
  } catch (e) {
    debugPrint('Error processing inventory updates: $e');
    rethrow;
  }
}

  // Add comment to task
  Future<void> addTaskComment(String taskId, String content) async {
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) throw 'Not authenticated'; // Throw an error if no user is authenticated

      final taskDoc = await _firestore.collection('tasks').doc(taskId).get(); // Get the task document
      if (!taskDoc.exists) throw 'Task not found'; // Throw an error if task document does not exist

      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get(); // Get the user document
      if (!userDoc.exists) throw 'User not found'; // Throw an error if user document does not exist

      final userName = '${userDoc.data()?['firstName']} ${userDoc.data()?['lastName']}'; // Get the user's full name
      final timestamp = FieldValue.serverTimestamp(); // Get the current server timestamp

      // Create comment string in a consistent format
      final commentString = '${currentUser.uid}|$userName|$content|${DateTime.now().toIso8601String()}';

      await taskDoc.reference.update({
        'comments': FieldValue.arrayUnion([commentString]), // Add the comment to the task's comments array
        'updatedAt': timestamp, // Update the last updated date and time
      });

      notifyListeners(); // Notify listeners of changes
    } catch (e) {
      debugPrint('Error adding comment: $e'); // Print error message if adding comment fails
      rethrow; // Rethrow the error
    }
  }

  // Parse comments from task
 List<TaskComment> parseComments(List<String> commentStrings) {
    return commentStrings.map((str) {
      try {
        final parts = str.split('|'); // Split the comment string into parts
        if (parts.length != 4) return null; // Return null if the comment string is not in the expected format

        final timestamp = DateTime.tryParse(parts[3]); // Parse the timestamp from the comment string
        if (timestamp == null) return null; // Return null if the timestamp is invalid

        return TaskComment(
          id: DateTime.now().millisecondsSinceEpoch.toString(), // Generate a unique ID for the comment
          userId: parts[0], // Set the user ID for the comment
          userName: parts[1], // Set the user name for the comment
          content: parts[2], // Set the content for the comment
          createdAt: timestamp, // Set the creation date and time for the comment
        );
      } catch (e) {
        debugPrint('Error parsing comment: $e'); // Print error message if parsing comment fails
        return null;
      }
    }).whereType<TaskComment>().toList(); // Filter out null comments and return the list of TaskComment objects
  }
  
 
 Future<void> updateTaskChecklist(String taskId, List<String> checklist) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      // Get current task data
      final taskDoc = await _firestore.collection('tasks').doc(taskId).get();
      if (!taskDoc.exists) throw 'Task not found';
      
      final task = Task.fromMap(taskDoc.data()!, taskId);
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      
      // Ensure user has permission to update the task
      if (task.assignedTo != currentUser.uid && 
          !['client', 'admin', 'manager'].contains(userDoc.data()?['role'])) {
        throw 'Insufficient permissions to update task';
      }

      // Determine new status based on checklist completion
      final newStatus = _determineStatus(checklist, task.status);
      final now = DateTime.now();

      // Use a transaction to ensure atomic updates
      await _firestore.runTransaction((transaction) async {
        transaction.update(taskDoc.reference, {
          'checklist': checklist,
          'status': newStatus.toString().split('.').last,
          'updatedAt': Timestamp.fromDate(now),
        });
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating task checklist: $e');
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

  // Get tasks by department
  Stream<List<Task>> getTasksByDepartment(String departmentId) { // Function to get tasks by department
    return getTasks(departmentId: departmentId); // Call getTasks with departmentId filter
  }

  // Get tasks assigned to user
  Stream<List<Task>> getAssignedTasks(String userId) { // Function to get tasks assigned to a specific user
    return getTasks(assignedTo: userId); // Call getTasks with assignedTo filter
  }

  // Get overdue tasks
  Stream<List<Task>> getOverdueTasks() async* { // Function to get overdue tasks
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) { // If no user is authenticated
        yield []; // Return an empty list of tasks
        return;
      }

      yield* _firestore
          .collection('tasks')
          .where('dueDate', isLessThan: Timestamp.fromDate(DateTime.now())) // Filter tasks with due dates less than the current date
          .where('status', whereIn: [
            TaskStatus.pending.toString().split('.').last, // Include tasks with status pending
            TaskStatus.inProgress.toString().split('.').last, // Include tasks with status inProgress
          ])
          .where('assignedTo', isEqualTo: currentUser.uid) // Filter tasks assigned to the current user
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Task.fromMap(doc.data(), doc.id)) // Map each document to a Task object
              .toList());
    } catch (e) {
      debugPrint('Error getting overdue tasks: $e'); // Print error message if query fails
      yield [];
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

  Future<List<UserModel>> getAssignableStaff(String? eventId) async { // Function to get assignable staff
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) throw 'Not authenticated'; // Throw an error if no user is authenticated

      final organization = await _organizationService.getCurrentUserOrganization(); // Get the organization of the current user
      if (organization == null) throw 'Organization not found'; // Throw an error if no organization is found

      if (eventId != null && eventId.isNotEmpty) { // If event ID is provided
        final eventDoc = await _firestore.collection('events').doc(eventId).get(); // Get the event document
        if (!eventDoc.exists) throw 'Event not found'; // Throw an error if event document does not exist
        
        // Get assigned staff IDs from the event document
        final eventData = eventDoc.data()!;
        List<String> assignedStaffIds = [];
        
        // Handle both array of strings and array of maps cases
        if (eventData['assignedStaff'] != null) {
          if (eventData['assignedStaff'] is List) {
            for (var staff in eventData['assignedStaff']) {
              if (staff is String) {
                assignedStaffIds.add(staff); // Add staff ID to the list if it is a string
              } else if (staff is Map) {
                assignedStaffIds.add(staff['userId']?.toString() ?? ''); // Add staff ID to the list if it is a map
              }
            }
          }
        }
        
        if (assignedStaffIds.isEmpty) { // If no staff are assigned to the event
          debugPrint('No staff assigned to event'); // Print debug message
          return [];
        }

        // Query for staff members that are assigned to the event
        final staffDocs = await Future.wait(
          assignedStaffIds.map((staffId) => 
            _firestore.collection('users').doc(staffId).get()
          )
        );

        return staffDocs
            .where((doc) => doc.exists) // Filter out non-existent documents
            .map((doc) {
              final data = doc.data()!;
              return UserModel.fromMap({
                ...data,
                'uid': doc.id,
                'createdAt': data['createdAt'] ?? Timestamp.now(),
                'updatedAt': data['updatedAt'] ?? Timestamp.now(),
              });
            })
            .where((staff) => 
                staff.employmentStatus == 'active' && // Filter active staff
                !['client', 'admin'].contains(staff.role)) // Exclude client and admin roles
            .toList();
      } else {
        // If no event ID, get all active staff
        final staffQuery = await _firestore
            .collection('users')
            .where('organizationId', isEqualTo: organization.id) // Filter by organization ID
            .where('employmentStatus', isEqualTo: 'active') // Filter active staff
            .get();

        return staffQuery.docs
            .map((doc) {
              final data = doc.data();
              return UserModel.fromMap({
                ...data,
                'uid': doc.id,
                'createdAt': data['createdAt'] ?? Timestamp.now(),
                'updatedAt': data['updatedAt'] ?? Timestamp.now(),
              });
            })
            .where((staff) => !['client', 'admin'].contains(staff.role)) // Exclude client and admin roles
            .toList();
      }
    } catch (e) {
      debugPrint('Error getting assignable staff: $e'); // Print error message if query fails
      return [];
    }
  }


  /// Updates the assignee of a task.
  /// 
  /// This method updates the assignee of a task identified by [taskId] to a new assignee identified by [newAssigneeId].
  /// It performs several checks to ensure the current user is authenticated, has permission to assign staff, 
  /// the task and event (if associated) exist, and the new assignee is valid and active.
  /// 
  /// Throws an error if any of the checks fail.
  /// 
  /// - Parameters:
  ///   - taskId: The ID of the task to update.
  ///   - newAssigneeId: The ID of the new assignee.
  /// 
  /// - Returns: A [Future] that completes when the task assignee is updated.
   Future<void> updateTaskAssignee(String taskId, String newAssigneeId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      // Check permission
      final hasPermission = await canAssignStaff();
      if (!hasPermission) {
        throw 'Insufficient permissions to assign staff';
      }

      final taskDoc = await _firestore.collection('tasks').doc(taskId).get();
      if (!taskDoc.exists) throw 'Task not found';

      final task = Task.fromMap(taskDoc.data()!, taskId);

      // If task is associated with an event, verify staff is assigned to event
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

      // Verify new assignee exists and is active
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
  bool _areAllChecklistItemsComplete(List<String> checklist) {
    if (checklist.isEmpty) return false;
    return checklist.every((item) => item.trim().startsWith('[x]'));
  }

  // Helper method to determine if any checklist items are completed
  bool _hasAnyChecklistItemComplete(List<String> checklist) {
    return checklist.any((item) => item.trim().startsWith('[x]'));
  }

  // Helper method to get appropriate status based on checklist completion
  TaskStatus _determineStatus(List<String> checklist, TaskStatus currentStatus) {
    // Don't change status if task is cancelled or blocked
    if (currentStatus == TaskStatus.cancelled || currentStatus == TaskStatus.blocked) {
      return currentStatus;
    }

    if (_areAllChecklistItemsComplete(checklist)) {
      return TaskStatus.completed;
    } else if (_hasAnyChecklistItemComplete(checklist)) {
      return TaskStatus.inProgress;
    } else if (currentStatus == TaskStatus.completed) {
      // If task was completed but no items are checked now, revert to in progress
      return TaskStatus.inProgress;
    }
    
    return currentStatus;
  }
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
  
}