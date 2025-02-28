import 'package:flutter/foundation.dart'; // Importing foundation package for ChangeNotifier.
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore package for database operations.
import 'package:firebase_auth/firebase_auth.dart'; // Importing FirebaseAuth package for authentication.
import 'package:cateredtoyou/services/organization_service.dart'; // Importing OrganizationService for organization-related operations.
import 'package:cateredtoyou/models/event_model.dart'; // Importing Event model.
import 'package:cateredtoyou/models/inventory_item_model.dart'; // Importing InventoryItem model.
import 'package:cateredtoyou/services/task_automation_service.dart'; // Importing TaskAutomation model.

class EventService extends ChangeNotifier {
  // EventService class extending ChangeNotifier for state management.
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Firestore instance for database operations.
  final FirebaseAuth _auth =
      FirebaseAuth.instance; // FirebaseAuth instance for authentication.
  final OrganizationService
      _organizationService; // OrganizationService instance for organization-related operations.
  final TaskAutomationService _taskAutomationService;
  EventService(
    this._organizationService,
    this._taskAutomationService,
  ); // Constructor initializing OrganizationService.

  Stream<List<Event>> getEvents() async* {
    // Method to get a stream of events.
    try {
      final currentUser =
          _auth.currentUser; // Getting the current authenticated user.
      if (currentUser == null) {
        // If no user is authenticated, return an empty list.
        yield [];
        return;
      }

      final organization = await _organizationService
          .getCurrentUserOrganization(); // Getting the organization of the current user.
      if (organization == null) {
        // If no organization is found, return an empty list.
        yield [];
        return;
      }

      final query =
          _firestore // Querying Firestore for events belonging to the user's organization.
              .collection('events')
              .where('organizationId', isEqualTo: organization.id);

      yield* query.snapshots().map((snapshot) {
        // Mapping Firestore snapshots to a list of Event objects.
        try {
          final events = snapshot.docs
              .map((doc) => Event.fromMap(doc.data(),
                  doc.id)) // Converting Firestore documents to Event objects.
              .toList();
          events.sort((a, b) => b.startDate.compareTo(a
              .startDate)); // Sorting events by start date in descending order.
          return events;
        } catch (e) {
          debugPrint(
              'Error mapping events: $e'); // Printing error if mapping fails.
          return [];
        }
      });
    } catch (e) {
      debugPrint(
          'Error in getEvents: $e'); // Printing error if fetching events fails.
      yield [];
    }
  }

  Future<Event?> getEventById(String eventId) async {
    try {
      final currentUser = _auth.currentUser; // Getting the current authenticated user.
      if (currentUser == null) {
        return null; // Return null if no user is authenticated.
      }

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        return null; // Return null if no organization is found.
      }

      final docSnapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .get(); // Getting the document snapshot for the event by its ID.

      if (docSnapshot.exists) {
        return Event.fromMap(docSnapshot.data()!, docSnapshot.id);
      } else {
        return null; // Return null if the document doesn't exist.
      }
    } catch (e) {
      debugPrint('Error getting event by ID: $e'); // Printing error if fetching event fails.
      return null; // Return null in case of any error.
    }
  }


  Future<void> _verifyInventoryAvailability(List<EventSupply> supplies) async {
  for (final supply in supplies) {
    final doc = await _firestore.collection('inventory').doc(supply.inventoryId).get();
    if (!doc.exists) {
      throw 'Supply item ${supply.name} not found';
    }
    final item = InventoryItem.fromMap(doc.data()!, doc.id);
    if (item.quantity < supply.quantity) {
      throw 'Insufficient quantity available for ${supply.name}. Available: ${item.quantity} ${item.unit}';
    }
  }
}

  Future<void> _verifyStaffAssignment(
      String organizationId, List<AssignedStaff> staff) async {
    // Method to verify staff assignment.
    if (staff.isEmpty) return; // If staff list is empty, no need to verify.

    final currentUser =
        _auth.currentUser; // Getting the current authenticated user.
    if (currentUser == null) {
      throw 'Not authenticated'; // If no user is authenticated, throw an error.
    }

    final userDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get(); // Getting the user document from Firestore.
    final userRole = userDoc.data()?['role']; // Getting the user's role.

    if (!['client', 'manager', 'admin'].contains(userRole)) {
      // If the user does not have permission, throw an error.
      throw 'Insufficient permissions to assign staff';
    }

    for (final member in staff) {
      // Iterating through each staff member.
      final staffDoc = await _firestore
          .collection('users')
          .doc(member.userId)
          .get(); // Getting the staff member document from Firestore.

      if (!staffDoc.exists) {
        // If the staff member does not exist, throw an error.
        throw 'Staff member ${member.name} not found';
      }

      if (staffDoc.data()?['organizationId'] != organizationId) {
        // If the staff member belongs to a different organization, throw an error.
        throw 'Staff member ${member.name} belongs to a different organization';
      }

      if (staffDoc.data()?['employmentStatus'] != 'active') {
        // If the staff member is not active, throw an error.
        throw 'Staff member ${member.name} is not active';
      }

      final rolePermission =
          staffDoc.data()?['role']; // Getting the staff member's role.
      if (!['staff', 'server', 'chef', 'driver'].contains(rolePermission)) {
        // If the staff member has an invalid role, throw an error.
        throw 'Invalid staff role for ${member.name}';
      }
    }
  }

  Future<Event> createEvent({
    // Method to create a new event.
    required String name, // Event name.
    required String description, // Event description.
    required DateTime startDate, // Event start date.
    required DateTime endDate, // Event end date.
    required String location, // Event location.
    required String customerId, // Customer ID.
    required int guestCount, // Number of guests.
    required int minStaff, // Minimum number of staff required.
    String notes = '', // Additional notes.
    required DateTime startTime, // Event start time.
    required DateTime endTime, // Event end time.
    List<EventMenuItem> menuItems = const [], // List of menu items.
    List<EventSupply> supplies = const [], // List of supplies.
    List<AssignedStaff> assignedStaff = const [], // List of assigned staff.
    EventMetadata? metadata, // Additional metadata.
  }) async {
    try {
      debugPrint('Starting event creation'); // Printing debug message.
      debugPrint(
          'Starting event creation with task automation'); // Printing debug message.
      final currentUser =
          _auth.currentUser; // Getting the current authenticated user.
      if (currentUser == null) {
        throw 'Not authenticated'; // If no user is authenticated, throw an error.
      }

      final userRef = _firestore
          .collection('users')
          .doc(currentUser.uid); // Getting the user document reference.
      final userDoc = await userRef.get(); // Getting the user document.

      if (!userDoc.exists) {
        throw 'User not found'; // If the user does not exist, throw an error.
      }

      final userRole = userDoc.data()?['role']; // Getting the user's role.
      if (!['admin', 'client', 'manager'].contains(userRole)) {
        throw 'Insufficient permissions to create events'; // If the user does not have permission, throw an error.
      }

      final organization = await _organizationService
          .getCurrentUserOrganization(); // Getting the organization of the current user.
      if (organization == null) {
        throw 'Organization not found'; // If no organization is found, throw an error.
      }

      if (endDate.isBefore(startDate)) {
        throw 'End date must be after start date'; // If the end date is before the start date, throw an error.
      }

      if (startTime.isAfter(endTime)) {
        throw 'End time must be after start time'; // If the start time is after the end time, throw an error.
      }

      if (assignedStaff.isNotEmpty) {
        // If there are assigned staff, verify their assignments.
        await _verifyStaffAssignment(organization.id, assignedStaff);
        debugPrint(
            'Staff assignments verified successfully'); // Printing debug message.
      }

      final staffData = assignedStaff
          .map((staff) => {
                // Formatting staff data with proper types.
                'userId': staff.userId,
                'name': staff.name,
                'role': staff.role,
                'assignedAt': Timestamp.fromDate(staff.assignedAt),
              })
          .toList();

      debugPrint('Staff data prepared: $staffData'); // Printing debug message.

      final totalPrice = menuItems.fold<double>(
        // Calculating the total price of menu items.
        0,
        (total, item) => total + (item.price * item.quantity),
      );

      return await _firestore.runTransaction<Event>((transaction) async {
        // Running a Firestore transaction to create the event.
        final customerRef = _firestore
            .collection('customers')
            .doc(customerId); // Getting the customer document reference.
        final customerDoc = await transaction
            .get(customerRef); // Getting the customer document.

        if (!customerDoc.exists ||
            customerDoc.data()?['organizationId'] != organization.id) {
          throw 'Invalid customer selected'; // If the customer does not exist or belongs to a different organization, throw an error.
        }

        await _verifyInventoryAvailability(
            supplies); // Verifying inventory availability.
        debugPrint(
            'Inventory availability verified'); // Printing debug message.

        final docRef = _firestore
            .collection('events')
            .doc(); // Creating a new event document reference.
        final now = DateTime.now(); // Getting the current date and time.

        final docData = {
          // Creating event data with proper Timestamps.
          'name': name.trim(),
          'description': description.trim(),
          'startDate': Timestamp.fromDate(startDate),
          'endDate': Timestamp.fromDate(endDate),
          'location': location.trim(),
          'customerId': customerId,
          'organizationId': organization.id,
          'guestCount': guestCount,
          'minStaff': minStaff,
          'notes': notes.trim(),
          'status': EventStatus.draft.toString().split('.').last,
          'startTime': Timestamp.fromDate(startTime),
          'endTime': Timestamp.fromDate(endTime),
          'createdBy': currentUser.uid,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
          'menuItems': menuItems.map((item) => item.toMap()).toList(),
          'supplies': supplies.map((supply) => supply.toMap()).toList(),
          'assignedStaff': staffData,
          'totalPrice': totalPrice,
          'metadata': metadata?.toMap(),
        };

        transaction.set(
            docRef, docData); // Setting the event document data in Firestore.
        debugPrint('Event document created'); // Printing debug message.
       

        debugPrint(
            'Event creation completed successfully'); // Printing debug message.

      final eventObj = Event(
          // Returning the created Event object.
          id: docRef.id,
          name: name.trim(),
          description: description.trim(),
          startDate: startDate,
          endDate: endDate,
          location: location.trim(),
          customerId: customerId,
          organizationId: organization.id,
          guestCount: guestCount,
          minStaff: minStaff,
          notes: notes.trim(),
          status: EventStatus.draft,
          startTime: startTime,
          endTime: endTime,
          createdBy: currentUser.uid,
          createdAt: now,
          updatedAt: now,
          menuItems: menuItems,
          supplies: supplies,
          assignedStaff: assignedStaff,
          totalPrice: totalPrice,
          metadata: metadata?.toMap(),
        );
        await _taskAutomationService.generateTasksForEvent(eventObj);
        return eventObj;
        
      });
      
    } catch (e) {
      debugPrint(
          'Error creating event: $e'); // Printing error if event creation fails.
      debugPrint(
          'Stack trace: ${StackTrace.current}'); // Printing stack trace for debugging.
      rethrow; // Rethrowing the error.
    } finally {
      notifyListeners(); // Notifying listeners about the state change.
    }
  }

  /// Updates an existing event with new data.
  ///
  /// Throws an error if the user is not authenticated, the organization is not found,
  /// the event belongs to a different organization, or the event is not found.
  ///
  /// Verifies staff assignments and updates the event data in Firestore.
  /// If supplies have changed, updates the inventory accordingly.
  ///
  /// Notifies listeners upon successful update.
  Future<void> updateEvent(Event updatedEvent) async {
    try {
      final currentUser =
          _auth.currentUser; // Get the current authenticated user.
      if (currentUser == null) {
        throw 'Not authenticated'; // Throw error if user is not authenticated.
      }

      debugPrint(
          'Starting event update for ID: ${updatedEvent.id}'); // Log the start of the update process.
      debugPrint('Starting event update with task automation'); // Log the start of the update process.
      final organization = await _organizationService
          .getCurrentUserOrganization(); // Get the organization of the current user.
      if (organization == null) {
        throw 'Organization not found'; // Throw error if organization is not found.
      }

      if (updatedEvent.organizationId != organization.id) {
        throw 'Event belongs to a different organization'; // Throw error if event belongs to a different organization.
      }

      final eventDoc = await _firestore
          .collection('events')
          .doc(updatedEvent.id)
          .get(); // Get the original event document.
      if (!eventDoc.exists) {
        throw 'Event not found'; // Throw error if event is not found.
      }
      final originalEvent = Event.fromMap(eventDoc.data()!,
          eventDoc.id); // Convert the document data to an Event object.

      if (updatedEvent.assignedStaff.isNotEmpty) {
        await _verifyStaffAssignment(organization.id,
            updatedEvent.assignedStaff); // Verify staff assignments.
      }

      final staffData = updatedEvent.assignedStaff
          .map((staff) => {
                'userId': staff.userId,
                'name': staff.name,
                'role': staff.role,
                'assignedAt': Timestamp.fromDate(staff.assignedAt),
              })
          .toList(); // Format staff data for update.

      debugPrint(
          'Staff data being updated: $staffData'); // Log the staff data being updated.

      final Map<String, dynamic> updateData = {
        'name': updatedEvent.name.trim(),
        'description': updatedEvent.description.trim(),
        'startDate': Timestamp.fromDate(updatedEvent.startDate),
        'endDate': Timestamp.fromDate(updatedEvent.endDate),
        'location': updatedEvent.location.trim(),
        'customerId': updatedEvent.customerId,
        'organizationId': organization.id,
        'guestCount': updatedEvent.guestCount,
        'minStaff': updatedEvent.minStaff,
        'notes': updatedEvent.notes.trim(),
        'status': updatedEvent.status.toString().split('.').last,
        'startTime': Timestamp.fromDate(updatedEvent.startTime),
        'endTime': Timestamp.fromDate(updatedEvent.endTime),
        'menuItems':
            updatedEvent.menuItems.map((item) => item.toMap()).toList(),
        'supplies':
            updatedEvent.supplies.map((supply) => supply.toMap()).toList(),
        'assignedStaff': staffData,
        'totalPrice': updatedEvent.totalPrice,
        'metadata': updatedEvent.metadata != null
            ? (updatedEvent.metadata is EventMetadata
                ? (updatedEvent.metadata as EventMetadata).toMap()
                : updatedEvent.metadata)
            : null,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      }; // Prepare update data.

      await _firestore.collection('events').doc(updatedEvent.id).update(
            updateData);

      debugPrint(
          'Event update completed successfully'); // Log the successful completion of the update.
          // Generate new tasks based on updated event data
      await _taskAutomationService.generateTasksForEvent(
      updatedEvent,
      originalEvent: originalEvent
    );
      notifyListeners(); // Notify listeners about the update.
    } catch (e) {
      debugPrint('Error updating event: $e'); // Log the error.
      debugPrint('Stack trace: ${StackTrace.current}'); // Log the stack trace.
      rethrow; // Rethrow the error.
    }
  }

  

Future<void> changeEventStatus(String eventId, EventStatus newStatus) async {
  try {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw 'Not authenticated';

    await _firestore.collection('events').doc(eventId).update({
      'status': newStatus.toString().split('.').last,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    notifyListeners();
  } catch (e) {
    debugPrint('Error changing event status: $e');
    rethrow;
  }
}
 
  Future<void> deleteEvent(String eventId) async {
  try {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw 'Not authenticated';
    
    // Get event data first to check permissions
    final eventDoc = await _firestore.collection('events').doc(eventId).get();
    if (!eventDoc.exists) throw 'Event not found';

    final eventData = eventDoc.data()!;
    final organization = await _organizationService.getCurrentUserOrganization();
    if (organization == null) throw 'Organization not found';

    // Check if user belongs to the same organization as the event
    if (eventData['organizationId'] != organization.id) {
      throw 'Event belongs to a different organization';
    }

    // Check if user has permission to delete the event
    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    if (!userDoc.exists) throw 'User not found';
    
    final userRole = userDoc.data()?['role'] as String?;
    final creatorId = eventData['createdBy'] as String?;

    // Verify user has management role or created the event
    final hasPermission = ['admin', 'client', 'manager'].contains(userRole) || 
                          creatorId == currentUser.uid;
    if (!hasPermission) {
      throw 'Insufficient permissions to delete event';
    }

    // Use batch to perform all deletions atomically
    final batch = _firestore.batch();

    // Get all tasks related to this event
    final tasksSnapshot = await _firestore
        .collection('tasks')
        .where('eventId', isEqualTo: eventId)
        .where('organizationId', isEqualTo: organization.id) // Add organization filter
        .get();

    // Add task deletions to batch
    for (var taskDoc in tasksSnapshot.docs) {
      batch.delete(taskDoc.reference);
    }

    // Add event deletion to batch
    batch.delete(eventDoc.reference);

    // Commit all deletions
    await batch.commit();

    notifyListeners();
  } catch (e) {
    debugPrint('Error deleting event and related tasks: $e');
    rethrow;
  }
}
}
