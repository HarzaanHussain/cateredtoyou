import 'package:flutter/foundation.dart'; // Importing Flutter's foundation library for debugging purposes
import 'package:cateredtoyou/models/event_model.dart'; // Importing the Event model
import 'package:cateredtoyou/models/task_model.dart'; // Importing the Task model
import 'package:cateredtoyou/services/task_service.dart'; // Importing the TaskService

class TaskAutomationService {
  final TaskService _taskService; // Declaring a private TaskService instance

  TaskAutomationService(this._taskService); // Constructor to initialize TaskService

  Future<void> generateTasksForEvent(Event event) async { // Method to generate tasks for a given event
    try {
      final Map<String, String> staffByRole = {}; // Creating a map to store staff by their roles
      for (final staff in event.assignedStaff) { // Looping through assigned staff
        staffByRole[staff.role] = staff.userId; // Adding staff to the map
      }

      final daysUntilEvent = event.startDate.difference(DateTime.now()).inDays; // Calculating days until the event

      if (daysUntilEvent < 7) { // Checking if the event is within a week
        await _createUrgentTasks(event, staffByRole); // Creating urgent tasks if the event is soon
      } else {
        await _createStandardTasks(event, staffByRole); // Creating standard tasks otherwise
      }

      await _createInventoryTasks(event, staffByRole); // Creating inventory-related tasks

      if (event.metadata != null) { // Checking if event has metadata
        await _createCustomTasks(event, staffByRole); // Creating custom tasks based on metadata
      }

    } catch (e) {
      debugPrint('Error generating tasks: $e'); // Printing error message
      rethrow; // Rethrowing the error
    }
  }

  Future<void> _createStandardTasks(Event event, Map<String, String> staffByRole) async { // Method to create standard tasks
    final List<Map<String, dynamic>> planningTasks = [ // List of standard tasks
      {
        'name': 'Initial Menu Review', // Task name
        'description': 'Review and finalize menu items and quantities', // Task description
        'department': 'kitchen', // Department responsible
        'role': 'chef', // Role responsible
        'priority': TaskPriority.high, // Task priority
        'daysBeforeEvent': 14, // Days before event to complete task
        'checklist': [ // Checklist for the task
          'Review menu items',
          'Check dietary requirements',
          'Calculate quantities',
          'Verify ingredient availability',
          'Update recipes if needed'
        ]
      },
      {
        'name': 'Staff Assignment Planning',
        'description': 'Plan staff requirements and assignments',
        'department': 'management',
        'role': 'manager',
        'priority': TaskPriority.medium,
        'daysBeforeEvent': 10,
        'checklist': [
          'Review event requirements',
          'Check staff availability',
          'Create staff schedule',
          'Assign roles',
          'Send notifications'
        ]
      },
      {
        'name': 'Equipment Check',
        'description': 'Verify all required equipment is available',
        'department': 'kitchen',
        'role': 'chef',
        'priority': TaskPriority.medium,
        'daysBeforeEvent': 7,
        'checklist': [
          'List required equipment',
          'Check equipment condition',
          'Test all equipment',
          'Schedule repairs if needed',
          'Arrange replacements if necessary'
        ]
      },
      {
        'name': 'Service Setup Planning',
        'description': 'Plan service setup and flow',
        'department': 'service',
        'role': 'service_manager',
        'priority': TaskPriority.medium,
        'daysBeforeEvent': 5,
        'checklist': [
          'Create setup diagram',
          'Plan service stations',
          'Assign serving areas',
          'Plan guest flow',
          'Review with team'
        ]
      }
    ];

    for (final task in planningTasks) { // Looping through each task
      final dueDate = event.startDate.subtract(
        Duration(days: task['daysBeforeEvent'] as int) // Calculating due date for the task
      );

      if (dueDate.isAfter(DateTime.now())) { // Checking if due date is in the future
        await _taskService.createTask( // Creating the task
          eventId: event.id,
          name: task['name'] as String,
          description: task['description'] as String,
          dueDate: dueDate,
          priority: task['priority'] as TaskPriority,
          assignedTo: staffByRole[task['role']] ?? '', // Assigning task to the appropriate staff
          departmentId: task['department'] as String,
          checklist: task['checklist'] as List<String>,
        );
      }
    }
  }

  Future<void> _createUrgentTasks(Event event, Map<String, String> staffByRole) async { // Method to create urgent tasks
    final List<Map<String, dynamic>> urgentTasks = [ // List of urgent tasks
      {
        'name': 'URGENT: Menu Finalization', // Task name
        'description': 'Immediately finalize menu and quantities', // Task description
        'department': 'kitchen', // Department responsible
        'role': 'chef', // Role responsible
        'priority': TaskPriority.urgent, // Task priority
        'hoursFromNow': 4, // Hours from now to complete task
        'checklist': [ // Checklist for the task
          'Confirm menu items',
          'Verify quantities',
          'Check inventory',
          'Place urgent orders',
          'Identify alternatives'
        ]
      },
      {
        'name': 'URGENT: Staff Scheduling',
        'description': 'Immediate staff scheduling required',
        'department': 'management',
        'role': 'manager',
        'priority': TaskPriority.urgent,
        'hoursFromNow': 4,
        'checklist': [
          'Contact all staff',
          'Confirm availability',
          'Create quick schedule',
          'Brief team leaders',
          'Send notifications'
        ]
      },
      {
        'name': 'URGENT: Equipment Preparation',
        'description': 'Immediate equipment check and preparation',
        'department': 'kitchen',
        'role': 'chef',
        'priority': TaskPriority.urgent,
        'hoursFromNow': 6,
        'checklist': [
          'Verify equipment availability',
          'Test all equipment',
          'Prepare backup options',
          'Clean equipment',
          'Set up stations'
        ]
      }
    ];

    for (final task in urgentTasks) { // Looping through each urgent task
      final dueDate = DateTime.now().add(
        Duration(hours: task['hoursFromNow'] as int) // Calculating due date for the task
      );

      await _taskService.createTask( // Creating the task
        eventId: event.id,
        name: task['name'] as String,
        description: task['description'] as String,
        dueDate: dueDate,
        priority: task['priority'] as TaskPriority,
        assignedTo: staffByRole[task['role']] ?? '', // Assigning task to the appropriate staff
        departmentId: task['department'] as String,
        checklist: task['checklist'] as List<String>,
      );
    }
  }

  Future<void> _createInventoryTasks(Event event, Map<String, String> staffByRole) async { // Method to create inventory tasks
    for (final supply in event.supplies) { // Looping through each supply
      final inventoryUpdates = {
        supply.inventoryId: {
          'quantity': supply.quantity, // Quantity of supply
          'type': 'subtract', // Type of inventory update
          'unit': supply.unit // Unit of supply
        }
      };

      await _taskService.createTask( // Creating task for each supply
        eventId: event.id,
        name: 'Prepare ${supply.name}', // Task name
        description: 'Prepare and allocate ${supply.quantity} ${supply.unit} of ${supply.name}', // Task description
        dueDate: event.startDate.subtract(const Duration(days: 1)), // Due date for the task
        priority: TaskPriority.high, // Task priority
        assignedTo: staffByRole['inventory_manager'] ?? staffByRole['chef'] ?? '', // Assigning task to the appropriate staff
        departmentId: 'inventory', // Department responsible
        inventoryUpdates: inventoryUpdates, // Inventory updates
        checklist: [ // Checklist for the task
          'Verify current stock',
          'Allocate required quantity',
          'Update inventory system',
          'Label for event',
          'Store appropriately'
        ],
      );
    }

    await _taskService.createTask( // Creating post-event inventory return task
      eventId: event.id,
      name: 'Post-Event Inventory Update', // Task name
      description: 'Update inventory after event completion', // Task description
      dueDate: event.endDate.add(const Duration(hours: 2)), // Due date for the task
      priority: TaskPriority.high, // Task priority
      assignedTo: staffByRole['inventory_manager'] ?? '', // Assigning task to the appropriate staff
      departmentId: 'inventory', // Department responsible
      checklist: [ // Checklist for the task
        'Count returned items',
        'Document usage',
        'Update inventory system',
        'Report discrepancies',
        'Restock if needed'
      ],
    );
  }

  Future<void> _createCustomTasks(Event event, Map<String, String> staffByRole) async { // Method to create custom tasks
    final metadata = event.metadata; // Getting event metadata
    if (metadata == null) return; // Returning if no metadata

    if (metadata['has_dietary_requirements'] == true) { // Checking if event has dietary requirements
      await _createDietaryTasks(event, staffByRole); // Creating dietary tasks
    }

    if (metadata['has_special_equipment'] == true) { // Checking if event has special equipment
      await _createEquipmentTasks(event, staffByRole); // Creating equipment tasks
    }

    if (metadata['has_bar_service'] == true) { // Checking if event has bar service
      await _createBarServiceTasks(event, staffByRole); // Creating bar service tasks
    }

    if (event.guestCount > 100) { // Checking if event has more than 100 guests
      await _createLargeEventTasks(event, staffByRole); // Creating large event tasks
    }
  }

  Future<void> _createDietaryTasks(Event event, Map<String, String> staffByRole) async { // Method to create dietary tasks
    await _taskService.createTask( // Creating dietary task
      eventId: event.id,
      name: 'Dietary Requirements Management', // Task name
      description: 'Handle special dietary requirements for event', // Task description
      dueDate: event.startDate.subtract(const Duration(days: 2)), // Due date for the task
      priority: TaskPriority.high, // Task priority
      assignedTo: staffByRole['chef'] ?? '', // Assigning task to the appropriate staff
      departmentId: 'kitchen', // Department responsible
      checklist: [ // Checklist for the task
        'Review dietary requirements',
        'Plan alternative dishes',
        'Label ingredients',
        'Set up separate prep areas',
        'Brief kitchen staff'
      ],
    );
  }

  Future<void> _createEquipmentTasks(Event event, Map<String, String> staffByRole) async { // Method to create equipment tasks
    await _taskService.createTask( // Creating equipment task
      eventId: event.id,
      name: 'Special Equipment Setup', // Task name
      description: 'Prepare and test special equipment', // Task description
      dueDate: event.startDate.subtract(const Duration(days: 1)), // Due date for the task
      priority: TaskPriority.high, // Task priority
      assignedTo: staffByRole['chef'] ?? '', // Assigning task to the appropriate staff
      departmentId: 'kitchen', // Department responsible
      checklist: [ // Checklist for the task
        'Test equipment',
        'Clean thoroughly',
        'Verify safety measures',
        'Train staff if needed',
        'Prepare backup plans'
      ],
    );
  }

  Future<void> _createBarServiceTasks(Event event, Map<String, String> staffByRole) async { // Method to create bar service tasks
    await _taskService.createTask( // Creating bar service task
      eventId: event.id,
      name: 'Bar Service Setup', // Task name
      description: 'Prepare bar service for event', // Task description
      dueDate: event.startDate.subtract(const Duration(hours: 4)), // Due date for the task
      priority: TaskPriority.high, // Task priority
      assignedTo: staffByRole['service_manager'] ?? '', // Assigning task to the appropriate staff
      departmentId: 'service', // Department responsible
      checklist: [ // Checklist for the task
        'Set up bar area',
        'Prepare garnishes',
        'Stock supplies',
        'Verify licenses',
        'Brief bar staff'
      ],
    );
  }

  Future<void> _createLargeEventTasks(Event event, Map<String, String> staffByRole) async { // Method to create large event tasks
    await _taskService.createTask( // Creating large event task
      eventId: event.id,
      name: 'Large Event Coordination', // Task name
      description: 'Special coordination for large event', // Task description
      dueDate: event.startDate.subtract(const Duration(days: 1)), // Due date for the task
      priority: TaskPriority.high, // Task priority
      assignedTo: staffByRole['manager'] ?? '', // Assigning task to the appropriate staff
      departmentId: 'management', // Department responsible
      checklist: [ // Checklist for the task
        'Review staffing levels',
        'Create zone assignments',
        'Set up communication system',
        'Establish backup plans',
        'Brief team leaders'
      ],
    );
  }
}
