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
    String? eventId, // Optional event ID to filter tasks by event
    String? assignedTo, // Optional user ID to filter tasks assigned to a specific user
    String? departmentId, // Optional department ID to filter tasks by department
    TaskStatus? status, // Optional task status to filter tasks by status
  }) async* {
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) { // If no user is authenticated
        yield []; // Return an empty list of tasks
        return;
      }

      final organization = await _organizationService.getCurrentUserOrganization(); // Get the organization of the current user
      if (organization == null) { // If no organization is found
        yield []; // Return an empty list of tasks
        return;
      }

      // Query tasks based on organization and assigned user
      var query = _firestore.collection('tasks').where(
        Filter.or(
          Filter('organizationId', isEqualTo: organization.id), // Filter tasks by organization ID
          Filter('assignedTo', isEqualTo: currentUser.uid), // Filter tasks assigned to the current user
        ),
      );

      if (eventId != null) { // If event ID is provided
        query = query.where('eventId', isEqualTo: eventId); // Filter tasks by event ID
      }

      if (status != null) { // If status is provided
        query = query.where('status', isEqualTo: status.toString().split('.').last); // Filter tasks by status
      }

      yield* query.snapshots().map((snapshot) { // Listen to query snapshots and map them to a list of tasks
        try {
          var tasks = snapshot.docs
              .map((doc) => Task.fromMap(doc.data(), doc.id)) // Map each document to a Task object
              .toList();

          // Apply additional filters in memory
          if (assignedTo != null) { // If assignedTo is provided
            tasks = tasks.where((task) => task.assignedTo == assignedTo).toList(); // Filter tasks by assigned user
          }

          if (departmentId != null) { // If departmentId is provided
            tasks = tasks.where((task) => task.departmentId == departmentId).toList(); // Filter tasks by department
          }

          // Sort by priority and due date
          tasks.sort((a, b) {
            final priorityComp = b.priority.index.compareTo(a.priority.index); // Compare tasks by priority
            if (priorityComp != 0) return priorityComp; // If priorities are different, return the comparison result
            return a.dueDate.compareTo(b.dueDate); // If priorities are the same, compare tasks by due date
          });

          return tasks; // Return the sorted list of tasks
        } catch (e) {
          debugPrint('Error mapping tasks: $e'); // Print error message if mapping fails
          return [];
        }
      });
    } catch (e) {
      debugPrint('Error in getTasks: $e'); // Print error message if query fails
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
      final currentUser = _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) throw 'Not authenticated'; // Throw an error if no user is authenticated

      final taskDoc = await _firestore.collection('tasks').doc(taskId).get(); // Get the task document
      if (!taskDoc.exists) throw 'Task not found'; // Throw an error if task document does not exist

      final task = Task.fromMap(taskDoc.data()!, taskId); // Map the task document data to a Task object
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get(); // Get the user document
      
      if (!userDoc.exists) throw 'User not found'; // Throw an error if user document does not exist
      final userRole = userDoc.data()?['role'] as String?; // Get the user role
      
      // Check if user can update the task
      if (task.assignedTo != currentUser.uid && 
          !['client', 'admin', 'manager'].contains(userRole)) {
        throw 'Insufficient permissions to update task'; // Throw an error if user does not have permission
      }

      if (!_isValidStatusTransition(task.status, newStatus)) { // Check if the status transition is valid
        throw 'Invalid status transition'; // Throw an error if the status transition is invalid
      }

      await taskDoc.reference.update({
        'status': newStatus.toString().split('.').last, // Update the task status
        'updatedAt': FieldValue.serverTimestamp(), // Update the last updated date and time
      });

      notifyListeners(); // Notify listeners of changes
    } catch (e) {
      debugPrint('Error updating task status: $e'); // Print error message if task status update fails
      rethrow; // Rethrow the error
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
  
  // Update task checklist
  Future<void> updateTaskChecklist(String taskId, List<String> checklist) async {
  try {
    // Debug print
    debugPrint('Updating checklist: $checklist'); // Print the checklist being updated
    
    final currentUser = _auth.currentUser; // Get the current authenticated user
    if (currentUser == null) throw 'Not authenticated'; // Throw an error if no user is authenticated

    final taskDoc = await _firestore.collection('tasks').doc(taskId).get(); // Get the task document
    if (!taskDoc.exists) throw 'Task not found'; // Throw an error if task document does not exist

    // Ensure all checklist items are properly formatted
    final formattedChecklist = checklist.map((item) {
      if (!item.startsWith('[')) { // If the checklist item does not start with '['
        return '[ ] $item'; // Add '[ ] ' to the beginning of the item
      }
      return item; // Return the item as is if it is already formatted
    }).toList();

    await _firestore.collection('tasks').doc(taskId).update({
      'checklist': formattedChecklist, // Update the task checklist
      'updatedAt': FieldValue.serverTimestamp(), // Update the last updated date and time
    });

    notifyListeners(); // Notify listeners of changes
  } catch (e) {
    debugPrint('Error updating task checklist: $e'); // Print error message if updating checklist fails
    rethrow; // Rethrow the error
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
  
}