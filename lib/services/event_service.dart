import 'package:cateredtoyou/models/organization_model.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cateredtoyou/services/organization_service.dart';
import 'package:cateredtoyou/models/event_model.dart';
import 'package:cateredtoyou/models/inventory_item_model.dart';
import 'package:cateredtoyou/models/menu_item_model.dart';
import 'package:cateredtoyou/services/task_generator.dart';

class EventService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OrganizationService _organizationService;

  EventService(this._organizationService);

  Stream<List<Event>> getEvents() async* {
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

      final query = _firestore
          .collection('events')
          .where('organizationId', isEqualTo: organization.id);

      yield* query.snapshots().map((snapshot) {
        try {
          final events = snapshot.docs
              .map((doc) => Event.fromMap(doc.data(), doc.id))
              .toList();
          events.sort((a, b) => b.startDate.compareTo(a.startDate));
          return events;
        } catch (e) {
          debugPrint('Error mapping events: $e');
          return [];
        }
      });
    } catch (e) {
      debugPrint('Error in getEvents: $e');
      yield [];
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
    if (staff.isEmpty) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw 'Not authenticated';
    }

    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    final userRole = userDoc.data()?['role'];

    if (!['client', 'manager', 'admin'].contains(userRole)) {
      throw 'Insufficient permissions to assign staff';
    }

    for (final member in staff) {
      final staffDoc = await _firestore.collection('users').doc(member.userId).get();

      if (!staffDoc.exists) {
        throw 'Staff member ${member.name} not found';
      }

      if (staffDoc.data()?['organizationId'] != organizationId) {
        throw 'Staff member ${member.name} belongs to a different organization';
      }

      if (staffDoc.data()?['employmentStatus'] != 'active') {
        throw 'Staff member ${member.name} is not active';
      }

      final rolePermission = staffDoc.data()?['role'];
      if (!['staff', 'server', 'chef', 'driver'].contains(rolePermission)) {
        throw 'Invalid staff role for ${member.name}';
      }
    }
  }

  Future<Event> createEvent({
    required String name,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    required String location,
    required String customerId,
    required int guestCount,
    required int minStaff,
    String notes = '',
    required DateTime startTime,
    required DateTime endTime,
    List<MenuItem> menuItems = const [],
    List<EventSupply> supplies = const [],
    List<AssignedStaff> assignedStaff = const [],
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('Starting event creation');
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'Not authenticated';
      }

      final userRef = _firestore.collection('users').doc(currentUser.uid);
      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        throw 'User not found';
      }

      final userRole = userDoc.data()?['role'];
      if (!['admin', 'client', 'manager'].contains(userRole)) {
        throw 'Insufficient permissions to create events';
      }

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found';
      }

      if (endDate.isBefore(startDate)) {
        throw 'End date must be after start date';
      }

      if (startTime.isAfter(endTime)) {
        throw 'End time must be after start time';
      }

      if (assignedStaff.isNotEmpty) {
        await _verifyStaffAssignment(organization.id, assignedStaff);
        debugPrint('Staff assignments verified successfully');
      }

      final staffData = assignedStaff
          .map((staff) => {
        'userId': staff.userId,
        'name': staff.name,
        'role': staff.role,
        'assignedAt': Timestamp.fromDate(staff.assignedAt),
      })
          .toList();

      debugPrint('Staff data prepared: $staffData');

      final totalPrice = menuItems.fold<double>(
        0,
            (total, item) => total + (item.price * item.quantity),
      );

      return await _firestore.runTransaction<Event>((transaction) async {
        final customerRef = _firestore.collection('customers').doc(customerId);
        final customerDoc = await transaction.get(customerRef);

        if (!customerDoc.exists ||
            customerDoc.data()?['organizationId'] != organization.id) {
          throw 'Invalid customer selected';
        }

        await _verifyInventoryAvailability(supplies);
        debugPrint('Inventory availability verified');

        final docRef = _firestore.collection('events').doc();
        final now = DateTime.now();

        final docData = {
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
          'metadata': metadata,
        };

        transaction.set(docRef, docData);
        debugPrint('Event document created');

        return Event(
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
          metadata: metadata,
        );
      });
    } catch (e) {
      debugPrint('Error creating event: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      rethrow;
    } finally {
      notifyListeners();
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
            ? updatedEvent.metadata
            : null,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      }; // Prepare update data.

      await _firestore.collection('events').doc(updatedEvent.id).update(
            updateData);
      //todo: implement event and menuitem task updates

      debugPrint(
          'Event update completed successfully'); // Log the successful completion of the update.
          // Generate new tasks based on updated event data

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

/// Placeholder for getting event by ID
  getEvent(String eventId) { debugPrint('getEvent not yet implemented'); return null;}

/// Placeholder for getting event task prototypes
  getEventTaskPrototypes(Future<Organization?> currentUserOrganization) { debugPrint('getEventTaskPrototypes not yet implemented'); return null;}
}
