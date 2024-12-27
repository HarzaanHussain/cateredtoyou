import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore package for database operations

// Enum representing the status of a task
enum TaskStatus {
  pending,    // Task is created but not started
  inProgress, // Task is currently being worked on
  completed,  // Task is finished
  blocked,    // Task is blocked by some dependency
  cancelled   // Task is cancelled
}

// Enum representing the priority of a task
enum TaskPriority {
  low,    // Low priority task
  medium, // Medium priority task
  high,   // High priority task
  urgent  // Urgent priority task
}

// Class representing a Task
class Task {
  final String id; // Unique identifier for the task
  final String eventId; // Identifier for the related event
  final String name; // Name of the task
  final String description; // Description of the task
  final DateTime dueDate; // Due date of the task
  final TaskStatus status; // Current status of the task
  final TaskPriority priority; // Priority level of the task
  final String assignedTo; // User ID of the assigned staff
  final String departmentId; // Department ID related to the task
  final String organizationId; // Organization ID related to the task
  final List<String> checklist; // List of checklist items for the task
  final List<String> comments; // List of comments on the task
  final Map<String, dynamic>? inventoryUpdates; // Inventory updates related to the task
  final String createdBy; // User ID of the creator of the task
  final DateTime createdAt; // Timestamp when the task was created
  final DateTime updatedAt; // Timestamp when the task was last updated

  // Constructor for the Task class
  const Task({
    required this.id, // Required parameter for task ID
    required this.eventId, // Required parameter for event ID
    required this.name, // Required parameter for task name
    required this.description, // Required parameter for task description
    required this.dueDate, // Required parameter for due date
    required this.status, // Required parameter for task status
    required this.priority, // Required parameter for task priority
    required this.assignedTo, // Required parameter for assigned user ID
    required this.departmentId, // Required parameter for department ID
    required this.organizationId, // Required parameter for organization ID
    this.checklist = const [], // Optional parameter for checklist, default is empty list
    this.comments = const [], // Optional parameter for comments, default is empty list
    this.inventoryUpdates, // Optional parameter for inventory updates
    required this.createdBy, // Required parameter for creator user ID
    required this.createdAt, // Required parameter for creation timestamp
    required this.updatedAt, // Required parameter for update timestamp
  });

  // Method to convert Task object to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId, // Event ID
      'name': name, // Task name
      'description': description, // Task description
      'dueDate': Timestamp.fromDate(dueDate), // Due date converted to Firestore Timestamp
      'status': status.toString().split('.').last, // Task status as string
      'priority': priority.toString().split('.').last, // Task priority as string
      'assignedTo': assignedTo, // Assigned user ID
      'departmentId': departmentId, // Department ID
      'organizationId': organizationId, // Organization ID
      'checklist': checklist, // Checklist items
      'comments': comments, // Comments
      'inventoryUpdates': inventoryUpdates, // Inventory updates
      'createdBy': createdBy, // Creator user ID
      'createdAt': Timestamp.fromDate(createdAt), // Creation timestamp converted to Firestore Timestamp
      'updatedAt': Timestamp.fromDate(updatedAt), // Update timestamp converted to Firestore Timestamp
    };
  }

  // Factory constructor to create a Task object from a map
  factory Task.fromMap(Map<String, dynamic> map, String documentId) {
    return Task(
      id: documentId, // Document ID as task ID
      eventId: map['eventId'] ?? '', // Event ID from map or empty string if null
      name: map['name'] ?? '', // Task name from map or empty string if null
      description: map['description'] ?? '', // Task description from map or empty string if null
      dueDate: map['dueDate'] is Timestamp 
          ? (map['dueDate'] as Timestamp).toDate() // Convert Firestore Timestamp to DateTime
          : DateTime.now(), // Default to current date if null
      status: TaskStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'], // Find matching TaskStatus enum
        orElse: () => TaskStatus.pending, // Default to pending if no match
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.toString().split('.').last == map['priority'], // Find matching TaskPriority enum
        orElse: () => TaskPriority.medium, // Default to medium if no match
      ),
      assignedTo: map['assignedTo'] ?? '', // Assigned user ID from map or empty string if null
      departmentId: map['departmentId'] ?? '', // Department ID from map or empty string if null
      organizationId: map['organizationId'] ?? '', // Organization ID from map or empty string if null
      checklist: List<String>.from(map['checklist'] ?? []), // Checklist items from map or empty list if null
      comments: List<String>.from(map['comments'] ?? []), // Comments from map or empty list if null
      inventoryUpdates: map['inventoryUpdates'], // Inventory updates from map
      createdBy: map['createdBy'] ?? '', // Creator user ID from map or empty string if null
      createdAt: map['createdAt'] is Timestamp 
          ? (map['createdAt'] as Timestamp).toDate() // Convert Firestore Timestamp to DateTime
          : DateTime.now(), // Default to current date if null
      updatedAt: map['updatedAt'] is Timestamp 
          ? (map['updatedAt'] as Timestamp).toDate() // Convert Firestore Timestamp to DateTime
          : DateTime.now(), // Default to current date if null
    );
  }

  // Method to create a copy of the Task object with updated fields
  Task copyWith({
    String? name, // Optional new name
    String? description, // Optional new description
    DateTime? dueDate, // Optional new due date
    TaskStatus? status, // Optional new status
    TaskPriority? priority, // Optional new priority
    String? assignedTo, // Optional new assigned user ID
    List<String>? checklist, // Optional new checklist items
    List<String>? comments, // Optional new comments
    Map<String, dynamic>? inventoryUpdates, // Optional new inventory updates
  }) {
    return Task(
      id: id, // Keep the same task ID
      eventId: eventId, // Keep the same event ID
      name: name ?? this.name, // Use new name if provided, otherwise keep the same
      description: description ?? this.description, // Use new description if provided, otherwise keep the same
      dueDate: dueDate ?? this.dueDate, // Use new due date if provided, otherwise keep the same
      status: status ?? this.status, // Use new status if provided, otherwise keep the same
      priority: priority ?? this.priority, // Use new priority if provided, otherwise keep the same
      assignedTo: assignedTo ?? this.assignedTo, // Use new assigned user ID if provided, otherwise keep the same
      departmentId: departmentId, // Keep the same department ID
      organizationId: organizationId, // Keep the same organization ID
      checklist: checklist ?? this.checklist, // Use new checklist items if provided, otherwise keep the same
      comments: comments ?? this.comments, // Use new comments if provided, otherwise keep the same
      inventoryUpdates: inventoryUpdates ?? this.inventoryUpdates, // Use new inventory updates if provided, otherwise keep the same
      createdBy: createdBy, // Keep the same creator user ID
      createdAt: createdAt, // Keep the same creation timestamp
      updatedAt: DateTime.now(), // Update the timestamp to current date and time
    );
  }
}

// Class representing a comment on a task
class TaskComment {
  final String id; // Unique identifier for the comment
  final String userId; // User ID of the commenter
  final String userName; // User name of the commenter
  final String content; // Content of the comment
  final DateTime createdAt; // Timestamp when the comment was created

  // Constructor for the TaskComment class
  TaskComment({
    required this.id, // Required parameter for comment ID
    required this.userId, // Required parameter for user ID
    required this.userName, // Required parameter for user name
    required this.content, // Required parameter for comment content
    required this.createdAt, // Required parameter for creation timestamp
  });

  // Method to convert TaskComment object to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId, // User ID
      'userName': userName, // User name
      'content': content, // Comment content
      'createdAt': Timestamp.fromDate(createdAt), // Creation timestamp converted to Firestore Timestamp
    };
  }

  // Factory constructor to create a TaskComment object from a map
  factory TaskComment.fromMap(Map<String, dynamic> map, String commentId) {
    return TaskComment(
      id: commentId, // Comment ID from map
      userId: map['userId'] ?? '', // User ID from map or empty string if null
      userName: map['userName'] ?? '', // User name from map or empty string if null
      content: map['content'] ?? '', // Comment content from map or empty string if null
      createdAt: (map['createdAt'] as Timestamp).toDate(), // Convert Firestore Timestamp to DateTime
    );
  }
}
