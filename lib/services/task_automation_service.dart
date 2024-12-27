// lib/services/task_automation_service.dart

import 'package:flutter/foundation.dart';
import 'package:cateredtoyou/models/event_model.dart';
import 'package:cateredtoyou/models/task_model.dart';
import 'package:cateredtoyou/services/task_service.dart';

class TaskAutomationService {
  final TaskService _taskService;

  TaskAutomationService(this._taskService);

  Future<void> generateTasksForEvent(Event event) async {
    try {
      // Convert assigned staff list to map for easy lookup
      final Map<String, String> staffByRole = {};
      for (final staff in event.assignedStaff) {
        staffByRole[staff.role] = staff.userId;
      }

      // Calculate time until event
      final daysUntilEvent = event.startDate.difference(DateTime.now()).inDays;

      // Adjust task timelines based on how soon the event is
      if (daysUntilEvent < 7) {
        await _createUrgentTasks(event, staffByRole);
      } else {
        await _createStandardTasks(event, staffByRole);
      }

      // Create inventory-related tasks
      await _createInventoryTasks(event, staffByRole);

      // Create specific tasks based on event metadata
      if (event.metadata != null) {
        await _createCustomTasks(event, staffByRole);
      }

    } catch (e) {
      debugPrint('Error generating tasks: $e');
      rethrow;
    }
  }

  Future<void> _createStandardTasks(Event event, Map<String, String> staffByRole) async {
    final List<Map<String, dynamic>> planningTasks = [
      {
        'name': 'Initial Menu Review',
        'description': 'Review and finalize menu items and quantities',
        'department': 'kitchen',
        'role': 'chef',
        'priority': TaskPriority.high,
        'daysBeforeEvent': 14,
        'checklist': [
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

    for (final task in planningTasks) {
      final dueDate = event.startDate.subtract(
        Duration(days: task['daysBeforeEvent'] as int)
      );

      // Only create task if due date is in the future
      if (dueDate.isAfter(DateTime.now())) {
        await _taskService.createTask(
          eventId: event.id,
          name: task['name'] as String,
          description: task['description'] as String,
          dueDate: dueDate,
          priority: task['priority'] as TaskPriority,
          assignedTo: staffByRole[task['role']] ?? '',
          departmentId: task['department'] as String,
          checklist: task['checklist'] as List<String>,
        );
      }
    }
  }

  Future<void> _createUrgentTasks(Event event, Map<String, String> staffByRole) async {
    final List<Map<String, dynamic>> urgentTasks = [
      {
        'name': 'URGENT: Menu Finalization',
        'description': 'Immediately finalize menu and quantities',
        'department': 'kitchen',
        'role': 'chef',
        'priority': TaskPriority.urgent,
        'hoursFromNow': 4,
        'checklist': [
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

    // Create urgent tasks
    for (final task in urgentTasks) {
      final dueDate = DateTime.now().add(
        Duration(hours: task['hoursFromNow'] as int)
      );

      await _taskService.createTask(
        eventId: event.id,
        name: task['name'] as String,
        description: task['description'] as String,
        dueDate: dueDate,
        priority: task['priority'] as TaskPriority,
        assignedTo: staffByRole[task['role']] ?? '',
        departmentId: task['department'] as String,
        checklist: task['checklist'] as List<String>,
      );
    }
  }

  Future<void> _createInventoryTasks(Event event, Map<String, String> staffByRole) async {
    // Create a task for each supply that needs inventory management
    for (final supply in event.supplies) {
      final inventoryUpdates = {
        supply.inventoryId: {
          'quantity': supply.quantity,
          'type': 'subtract',
          'unit': supply.unit
        }
      };

      await _taskService.createTask(
        eventId: event.id,
        name: 'Prepare ${supply.name}',
        description: 'Prepare and allocate ${supply.quantity} ${supply.unit} of ${supply.name}',
        dueDate: event.startDate.subtract(const Duration(days: 1)),
        priority: TaskPriority.high,
        assignedTo: staffByRole['inventory_manager'] ?? staffByRole['chef'] ?? '',
        departmentId: 'inventory',
        inventoryUpdates: inventoryUpdates,
        checklist: [
          'Verify current stock',
          'Allocate required quantity',
          'Update inventory system',
          'Label for event',
          'Store appropriately'
        ],
      );
    }
    

    // Create post-event inventory return task
    await _taskService.createTask(
      eventId: event.id,
      name: 'Post-Event Inventory Update',
      description: 'Update inventory after event completion',
      dueDate: event.endDate.add(const Duration(hours: 2)),
      priority: TaskPriority.high,
      assignedTo: staffByRole['inventory_manager'] ?? '',
      departmentId: 'inventory',
      checklist: [
        'Count returned items',
        'Document usage',
        'Update inventory system',
        'Report discrepancies',
        'Restock if needed'
      ],
    );
  }

  Future<void> _createCustomTasks(Event event, Map<String, String> staffByRole) async {
    final metadata = event.metadata;
    if (metadata == null) return;

    // Handle dietary requirements
    if (metadata['has_dietary_requirements'] == true) {
      await _createDietaryTasks(event, staffByRole);
    }

    // Handle special equipment
    if (metadata['has_special_equipment'] == true) {
      await _createEquipmentTasks(event, staffByRole);
    }

    // Handle bar service
    if (metadata['has_bar_service'] == true) {
      await _createBarServiceTasks(event, staffByRole);
    }

    // Large event tasks
    if (event.guestCount > 100) {
      await _createLargeEventTasks(event, staffByRole);
    }
  }

  Future<void> _createDietaryTasks(Event event, Map<String, String> staffByRole) async {
    await _taskService.createTask(
      eventId: event.id,
      name: 'Dietary Requirements Management',
      description: 'Handle special dietary requirements for event',
      dueDate: event.startDate.subtract(const Duration(days: 2)),
      priority: TaskPriority.high,
      assignedTo: staffByRole['chef'] ?? '',
      departmentId: 'kitchen',
      checklist: [
        'Review dietary requirements',
        'Plan alternative dishes',
        'Label ingredients',
        'Set up separate prep areas',
        'Brief kitchen staff'
      ],
    );
  }

  Future<void> _createEquipmentTasks(Event event, Map<String, String> staffByRole) async {
    await _taskService.createTask(
      eventId: event.id,
      name: 'Special Equipment Setup',
      description: 'Prepare and test special equipment',
      dueDate: event.startDate.subtract(const Duration(days: 1)),
      priority: TaskPriority.high,
      assignedTo: staffByRole['chef'] ?? '',
      departmentId: 'kitchen',
      checklist: [
        'Test equipment',
        'Clean thoroughly',
        'Verify safety measures',
        'Train staff if needed',
        'Prepare backup plans'
      ],
    );
  }

  Future<void> _createBarServiceTasks(Event event, Map<String, String> staffByRole) async {
    await _taskService.createTask(
      eventId: event.id,
      name: 'Bar Service Setup',
      description: 'Prepare bar service for event',
      dueDate: event.startDate.subtract(const Duration(hours: 4)),
      priority: TaskPriority.high,
      assignedTo: staffByRole['service_manager'] ?? '',
      departmentId: 'service',
      checklist: [
        'Set up bar area',
        'Prepare garnishes',
        'Stock supplies',
        'Verify licenses',
        'Brief bar staff'
      ],
    );
  }

  Future<void> _createLargeEventTasks(Event event, Map<String, String> staffByRole) async {
    await _taskService.createTask(
      eventId: event.id,
      name: 'Large Event Coordination',
      description: 'Special coordination for large event',
      dueDate: event.startDate.subtract(const Duration(days: 1)),
      priority: TaskPriority.high,
      assignedTo: staffByRole['manager'] ?? '',
      departmentId: 'management',
      checklist: [
        'Review staffing levels',
        'Create zone assignments',
        'Set up communication system',
        'Establish backup plans',
        'Brief team leaders'
      ],
    );
  }
}