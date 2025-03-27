import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Importing Flutter's foundation library for debugging purposes
import 'package:cateredtoyou/models/event_model.dart'; // Importing the Event model
import 'package:cateredtoyou/models/task_model.dart'; // Importing the Task model
import 'package:cateredtoyou/services/task_service.dart';

import '../models/manifest_model.dart';
import '../models/manifest_task_model.dart';
import 'manifest_service.dart';
import 'organization_service.dart'; // Importing the TaskService

class TaskAutomationService {
  final TaskService _taskService; // Declaring a private TaskService instance
  final OrganizationService _organizationService; // Declaring OrganizationService instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Declaring a FirebaseFirestore instance


  TaskAutomationService(this._taskService, this._organizationService); // Constructor to initialize TaskService and organization service

  Future<void> generateTasksForEvent(Event event, {Event? originalEvent}) async {
  try {
    final Map<String, String> staffByRole = {};
    for (final staff in event.assignedStaff) {
      staffByRole[staff.role] = staff.userId;
    }

    // If this is an update (originalEvent exists), compare and only generate necessary tasks
    if (originalEvent != null) {
      await _handleEventUpdate(event, originalEvent, staffByRole);
    } else {
      // This is a new event, generate all tasks
      final daysUntilEvent = event.startDate.difference(DateTime.now()).inDays;

      if (daysUntilEvent < 7) {
        await _createUrgentTasks(event, staffByRole);
      } else {
        await _createStandardTasks(event, staffByRole);
      }

      await _createInventoryTasks(event, staffByRole);

      if (event.metadata != null) {
        await _createCustomTasks(event, staffByRole);
      }
    }

    await manageManifest(event.id, event.menuItems);
    await createManifestTasks(event.id, event.startDate);
  } catch (e) {
    debugPrint('Error generating tasks: $e');
    rethrow;
  }
}
Future<void> _handleEventUpdate(Event newEvent, Event oldEvent, Map<String, String> staffByRole) async {
  debugPrint('Starting event update handler for event: ${newEvent.id}');
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'Not authenticated';

    // Get both user role and permissions
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw 'User not found';

    final userRole = userDoc.data()?['role'] as String?;
    final permDoc = await _firestore.collection('permissions').doc(user.uid).get();

    // Check if user has management role OR required permissions
    final isManager = ['admin', 'client', 'manager'].contains(userRole);
    final permissions = permDoc.exists ?
        List<String>.from(permDoc.data()?['permissions'] ?? []) : [];
    final hasRequiredPermission = permissions.contains('manage_tasks') ||
                                permissions.contains('manage_events');

    if (!isManager && !hasRequiredPermission) {
      debugPrint('Permission denied. User role: $userRole, Permissions: $permissions');
      throw 'Insufficient permissions to update tasks';
    }

    // Only process updates if there are actual changes
    if (!listEquals(oldEvent.supplies, newEvent.supplies) ||
        oldEvent.startDate != newEvent.startDate ||
        oldEvent.endDate != newEvent.endDate ||
        !listEquals(oldEvent.assignedStaff, newEvent.assignedStaff) ||
        oldEvent.metadata != newEvent.metadata) {
      await _processBatchUpdates(newEvent, oldEvent, staffByRole);
    }

    await manageManifest(newEvent.id, newEvent.menuItems);
    await createManifestTasks(newEvent.id, newEvent.startDate);

    debugPrint('Event update handler completed successfully');
  } catch (e, stack) {
    debugPrint('Error in event update handler: $e');
    debugPrint('Stack trace: $stack');
    rethrow;
  }
}

Future<void> _processBatchUpdates(Event newEvent, Event oldEvent, Map<String, String> staffByRole) async {
  debugPrint('Processing batch updates for event: ${newEvent.id}');

  try {
    final querySnapshot = await _firestore
        .collection('tasks')
        .where('eventId', isEqualTo: newEvent.id)
        .where('organizationId', isEqualTo: newEvent.organizationId)  // Add organization filter
        .get();

    if (querySnapshot.docs.isEmpty) {
      debugPrint('No tasks found for event: ${newEvent.id}');
      return;
    }

    const int batchSize = 500;
    int processedCount = 0;
    WriteBatch currentBatch = _firestore.batch();

    for (final doc in querySnapshot.docs) {
      final taskData = doc.data();
      final isInventoryTask = taskData['departmentId'] == 'inventory';

      // Handle inventory tasks
      if (isInventoryTask && !listEquals(oldEvent.supplies, newEvent.supplies)) {
        currentBatch.delete(doc.reference);
        processedCount++;
        debugPrint('Deleting inventory task: ${doc.id}');
      } else {
        Map<String, dynamic> updates = {};
        bool needsUpdate = false;

        // Update due dates if needed
        if (oldEvent.startDate != newEvent.startDate ||
            oldEvent.endDate != newEvent.endDate) {
          final isPostEvent = taskData['name'].toString().contains('Post-Event');
          final newDueDate = isPostEvent
              ? newEvent.endDate.add(const Duration(hours: 2))
              : newEvent.startDate.subtract(const Duration(days: 1));

          updates['dueDate'] = Timestamp.fromDate(newDueDate);
          updates['updatedAt'] = FieldValue.serverTimestamp();
          needsUpdate = true;
          debugPrint('Updating due date for task: ${doc.id}');
        }

        // Update staff assignment if needed
        if (!listEquals(oldEvent.assignedStaff, newEvent.assignedStaff)) {
          final role = taskData['role'] as String?;
          if (role != null && staffByRole.containsKey(role)) {
            updates['assignedTo'] = staffByRole[role];
            needsUpdate = true;
            debugPrint('Updating staff assignment for task: ${doc.id}');
          }
        }

        if (needsUpdate) {
          currentBatch.update(doc.reference, updates);
          processedCount++;
        }
      }

      // Commit batch if we've reached the size limit
      if (processedCount >= batchSize) {
        debugPrint('Committing batch with $processedCount updates');
        await currentBatch.commit();
        currentBatch = _firestore.batch();
        processedCount = 0;
      }
    }

    // Commit any remaining updates
    if (processedCount > 0) {
      debugPrint('Committing final batch with $processedCount updates');
      await currentBatch.commit();
    }

    // Create new inventory tasks if needed
    if (!listEquals(oldEvent.supplies, newEvent.supplies)) {
      debugPrint('Creating new inventory tasks');
      await _createInventoryTasks(newEvent, staffByRole);
    }

    // Handle metadata changes last
    if (oldEvent.metadata != newEvent.metadata) {
      debugPrint('Updating custom tasks');
      await _createCustomTasks(newEvent, staffByRole);
    }

    debugPrint('Batch updates completed successfully');
  } catch (e, stack) {
    debugPrint('Error in batch updates: $e');
    debugPrint('Stack trace: $stack');
    rethrow;
  }
}

  Future<void> manageManifest(String eventId, List<EventMenuItem> selectedMenuItems) async {
  try {
    if (eventId.isEmpty) {
      debugPrint('Error: Empty event ID provided to manageManifest');
      return;
    }

    if (selectedMenuItems.isEmpty) {
      debugPrint('No menu items provided to manageManifest for event: $eventId');
      // We'll continue anyway to create an empty manifest if needed
    }

    final manifestService = ManifestService(_organizationService);
    debugPrint('Starting manifest management for event: $eventId');

    // Check if a manifest already exists for this event
    final exists = await manifestService.doesManifestExist(eventId);
    debugPrint('Manifest exists for event $eventId: $exists');

    if (!exists) {
      debugPrint('No existing manifest found. Creating a new one for event: $eventId');
      // Create manifest items from selected menu items
      final manifestItems = selectedMenuItems.map((menuItem) {
        // Generate unique ID for manifest item
        final newItemId = '${DateTime.now().millisecondsSinceEpoch}_${menuItem.menuItemId}';
        debugPrint('Creating manifest item: name=${menuItem.name}, menuItemId=${menuItem.menuItemId}, id=$newItemId');

        return ManifestItem(
          id: newItemId,
          menuItemId: menuItem.menuItemId,
          name: menuItem.name,
          quantity: menuItem.quantity,
          vehicleId: null, // Initially, no vehicle is assigned
          loadingStatus: LoadingStatus.unassigned, // Initial status is unassigned
        );
      }).toList();

      debugPrint('Created ${manifestItems.length} manifest items');
      
      try {
        await manifestService.createManifest(
          eventId: eventId,
          items: manifestItems,
        );
        debugPrint('Successfully created new manifest for event: $eventId');
      } catch (e) {
        debugPrint('Error creating manifest in Firestore: $e');
        // Don't rethrow - we want to continue with task creation even if manifest fails
      }
    } else {
      debugPrint('Existing manifest found. Updating it for event: $eventId');
      
      try {
        final existingManifest = await manifestService.getManifestByEventId(eventId).first;
        
        if (existingManifest == null) {
          debugPrint('Strange - manifest exists but could not be retrieved. Creating new one.');
          // Try to create a new manifest instead
          final newManifestItems = selectedMenuItems.map((menuItem) {
            final newItemId = '${DateTime.now().millisecondsSinceEpoch}_${menuItem.menuItemId}';
            return ManifestItem(
              id: newItemId,
              menuItemId: menuItem.menuItemId,
              name: menuItem.name,
              quantity: menuItem.quantity,
              vehicleId: null,
              loadingStatus: LoadingStatus.unassigned,
            );
          }).toList();
          
          await manifestService.createManifest(
            eventId: eventId,
            items: newManifestItems,
          );
          debugPrint('Created new manifest for event: $eventId');
          return;
        }
        
        // Get current menu item IDs
        final currentMenuItemIds = selectedMenuItems.map((item) => item.menuItemId).toSet();
        debugPrint('Current menu item IDs: $currentMenuItemIds');

        // Keep existing items that still exist in the menu
        final updatedItems = <ManifestItem>[];
        
        // Keep existing items that are still in the menu
        for (final item in existingManifest.items) {
          if (currentMenuItemIds.contains(item.menuItemId)) {
            updatedItems.add(item);
            debugPrint('Keeping existing manifest item: ${item.name} (${item.menuItemId})');
          } else {
            debugPrint('Removing manifest item no longer in menu: ${item.name} (${item.menuItemId})');
          }
        }

        // Add new items that aren't in the manifest yet
        for (final menuItem in selectedMenuItems) {
          final alreadyExists = updatedItems.any((item) => item.menuItemId == menuItem.menuItemId);

          if (!alreadyExists) {
            final newItemId = '${DateTime.now().millisecondsSinceEpoch}_${menuItem.menuItemId}';
            debugPrint('Adding new manifest item: ${menuItem.name} (${menuItem.menuItemId}), id=$newItemId');

            updatedItems.add(ManifestItem(
              id: newItemId,
              menuItemId: menuItem.menuItemId,
              name: menuItem.name,
              quantity: menuItem.quantity,
              vehicleId: null,
              loadingStatus: LoadingStatus.unassigned,
            ));
          }
        }

        debugPrint('Updating manifest with ${updatedItems.length} total items.');
        final updatedManifest = existingManifest.copyWith(items: updatedItems);
        await manifestService.updateManifest(updatedManifest);
        debugPrint('Successfully updated manifest for event: $eventId');
      } catch (e) {
        debugPrint('Error updating manifest: $e');
        // Don't rethrow - we want to continue with task creation even if manifest fails
      }
    }
  } catch (e) {
    debugPrint('Error managing manifest: $e');
    // We don't want to fail the whole submission if just the manifest fails
    // So we catch the error here and just log it
  }
}

  Future<void> createManifestTasks(String eventId, DateTime startDate) async {
    try {
      // Get the manifest for this event
      final manifestService = ManifestService(_organizationService);
      final manifest = await manifestService.getManifestByEventId(eventId).first;

      if (manifest == null || manifest.items.isEmpty) {
        debugPrint('No manifest or manifest items found. Skipping task creation.');
        return;
      }

      debugPrint('Creating manifest tasks for ${manifest.items.length} items');

      // Get a reference to the tasks collection
      final tasksCollection = FirebaseFirestore.instance.collection('tasks');

      // First, check if there are existing manifest tasks for this event
      final existingTasksSnapshot = await tasksCollection
          .where('eventId', isEqualTo: eventId)
          .where('organizationId', isEqualTo: manifest.organizationId)
          .where('menuItemId', isNotEqualTo: null)
          .get();

      // Create a map of existing tasks by menuItemId for quick lookup
      final Map<String, DocumentSnapshot> existingTasksByMenuItemId = {};
      for (final doc in existingTasksSnapshot.docs) {
        final menuItemId = doc.data()['menuItemId'] as String?;
        if (menuItemId != null) {
          existingTasksByMenuItemId[menuItemId] = doc;
        }
      }

      debugPrint('Found ${existingTasksByMenuItemId.length} existing manifest tasks');

      // Set a due date for the tasks (1 day before event start)
      final dueDate = startDate.subtract(const Duration(days: 1));

      // Create a batch write to add/update all tasks at once
      final batch = FirebaseFirestore.instance.batch();

      // Get current user ID
      final currentUser = FirebaseAuth.instance.currentUser;
      final createdBy = currentUser?.uid ?? '';
      final organizationId = manifest.organizationId;
      final now = DateTime.now();

      // For tracking what we've processed
      final processedMenuItemIds = <String>{};
      int newTasksCount = 0;
      int updatedTasksCount = 0;

      // Process each manifest item
      for (final item in manifest.items) {
        processedMenuItemIds.add(item.menuItemId);

        // Check if we already have a task for this menu item
        if (existingTasksByMenuItemId.containsKey(item.menuItemId)) {
          // Update existing task
       final existingDoc = existingTasksByMenuItemId[item.menuItemId]!;

       // Only update if something has changed
       final existingData = existingDoc.data() as Map<String, dynamic>?;
       if (existingData?['dueDate'] != Timestamp.fromDate(dueDate) ||
           existingData?['name'] != "Prepare ${item.name}") {

            batch.update(existingDoc.reference, {
              'name': "Prepare ${item.name}",
              'description': "Prepare ${item.name} for loading",
              'dueDate': Timestamp.fromDate(dueDate),
              'updatedAt': Timestamp.fromDate(now),
            });

            updatedTasksCount++;
            debugPrint('Updated manifest task for item: ${item.name} (${item.menuItemId})');
          }
        } else {
          // Create a new task
          final taskDocRef = tasksCollection.doc();

          // Create the ManifestTask
          final manifestTask = ManifestTask(
            id: taskDocRef.id,
            eventId: eventId,
            name: "Prepare ${item.name}",
            description: "Prepare ${item.name} for loading",
            dueDate: dueDate,
            status: TaskStatus.pending,
            priority: TaskPriority.medium,
            assignedTo: '', // No specific user assigned
            departmentId: '', // No specific department
            organizationId: organizationId, // Using the org ID passed in
            checklist: ["Prep for loading"],
            createdBy: createdBy,
            createdAt: now,
            updatedAt: now,
            menuItemId: item.menuItemId,
            readiness: ItemReadiness.unloadable, // Default readiness is unloadable
          );

          // Add to batch
          batch.set(taskDocRef, manifestTask.toMap());
          newTasksCount++;
          debugPrint('Created new manifest task for item: ${item.name} (${item.menuItemId})');
        }
      }

      // Delete tasks for menu items that are no longer in the manifest
      for (final entry in existingTasksByMenuItemId.entries) {
        if (!processedMenuItemIds.contains(entry.key)) {
          batch.delete(entry.value.reference);
          debugPrint('Deleting manifest task for removed menu item: ${entry.key}');
        }
      }

      // Commit the batch if there are any operations
      if (newTasksCount > 0 || updatedTasksCount > 0 || existingTasksByMenuItemId.length != processedMenuItemIds.length) {
        await batch.commit();
        debugPrint('Manifest tasks update completed: $newTasksCount created, $updatedTasksCount updated, ${existingTasksByMenuItemId.length - processedMenuItemIds.length} deleted');
      } else {
        debugPrint('No manifest task changes needed');
      }

    } catch (e) {
      debugPrint('Error managing manifest tasks: $e');
      // We don't want to fail the whole submission if just the task creation fails
      // So we catch the error here and just log it
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

  Future<void> _createInventoryTasks(Event event, Map<String, String> staffByRole) async {
  debugPrint('Creating inventory tasks for event: ${event.id}');

  for (final supply in event.supplies) {
    // Create preparation task (taking items from inventory)
    await _taskService.createTask(
      eventId: event.id,
      name: 'Prepare ${supply.name}',
      description: 'Allocate ${supply.quantity} ${supply.unit} of ${supply.name} for event',
      dueDate: event.startDate.subtract(const Duration(days: 1)),
      priority: TaskPriority.high,
      assignedTo: staffByRole['inventory_manager'] ?? staffByRole['chef'] ?? '',
      departmentId: 'inventory',
      checklist: [
        '[ ] Verify current stock',
        '[ ] Check item condition',
        '[ ] Allocate required quantity',
        '[ ] Update inventory system',
        '[ ] Label for event'
      ],
      inventoryUpdates: {
        supply.inventoryId: {
          'quantity': supply.quantity,
          'type': 'remove',
          'unit': supply.unit
        }
      }
    );

    // Create return task (putting items back in inventory)
    await _taskService.createTask(
      eventId: event.id,
      name: 'Return ${supply.name}',
      description: 'Return ${supply.quantity} ${supply.unit} of ${supply.name} to inventory after event',
      dueDate: event.endDate.add(const Duration(hours: 2)),
      priority: TaskPriority.high,
      assignedTo: staffByRole['inventory_manager'] ?? staffByRole['chef'] ?? '',
      departmentId: 'inventory',
      checklist: [
        '[ ] Collect all items',
        '[ ] Check for damages',
        '[ ] Clean if necessary',
        '[ ] Return to storage',
        '[ ] Update inventory record'
      ],
      inventoryUpdates: {
        supply.inventoryId: {
          'quantity': supply.quantity,
          'type': 'add',
          'unit': supply.unit
        }
      }
    );
  }
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