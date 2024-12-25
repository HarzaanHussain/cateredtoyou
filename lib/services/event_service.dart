import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cateredtoyou/services/organization_service.dart';
import 'package:cateredtoyou/models/event_model.dart';
import 'package:cateredtoyou/models/inventory_item_model.dart';

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
      final doc = await _firestore
          .collection('inventory')
          .doc(supply.inventoryId)
          .get();

      if (!doc.exists) {
        throw 'Supply item ${supply.name} not found';
      }

      final item = InventoryItem.fromMap(doc.data()!, doc.id);
      if (item.quantity < supply.quantity) {
        throw 'Insufficient quantity available for ${supply.name}. Available: ${item.quantity} ${item.unit}';
      }
    }
  }

   // Replace the _verifyStaffAssignment function with this:
Future<void> _verifyStaffAssignment(String organizationId, List<AssignedStaff> staff) async {
  // If staff list is empty, no need to verify
  if (staff.isEmpty) return;
  
  // Check if current user is a client
  final currentUser = _auth.currentUser;
  if (currentUser == null) throw 'Not authenticated';
  
  final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
  final userRole = userDoc.data()?['role'];
  
  if (userRole != 'client') {
    throw 'Only client users can assign staff';
  }

  // Verify each staff member
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
    List<EventMenuItem> menuItems = const [],
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

      // Format staff data with proper types
      if (assignedStaff.isNotEmpty) {
        await _verifyStaffAssignment(organization.id, assignedStaff);
        debugPrint('Staff assignments verified successfully');
      }

      final staffData = assignedStaff.map((staff) => {
        'userId': staff.userId,
        'name': staff.name,
        'role': staff.role,
        'assignedAt': Timestamp.fromDate(staff.assignedAt),
      }).toList();

      debugPrint('Staff data prepared: $staffData');

      final totalPrice = menuItems.fold<double>(
        0,
        (total, item) => total + (item.price * item.quantity),
      ); 

      return await _firestore.runTransaction<Event>((transaction) async {
        // Verify customer belongs to organization
        final customerRef = _firestore.collection('customers').doc(customerId);
        final customerDoc = await transaction.get(customerRef);
        
        if (!customerDoc.exists || 
            customerDoc.data()?['organizationId'] != organization.id) {
          throw 'Invalid customer selected';
        }

        // Verify inventory availability
        await _verifyInventoryAvailability(supplies);
        debugPrint('Inventory availability verified');

        final docRef = _firestore.collection('events').doc();
        final now = DateTime.now();
        
        // Create event data with proper Timestamps
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

        // Update inventory
        for (final supply in supplies) {
          final inventoryRef = _firestore
              .collection('inventory')
              .doc(supply.inventoryId);
              
          transaction.update(inventoryRef, {
            'quantity': FieldValue.increment(-supply.quantity),
            'updatedAt': Timestamp.fromDate(now),
            'lastModifiedBy': currentUser.uid,
          });

          final transactionRef = _firestore
              .collection('inventory_transactions')
              .doc();
              
          transaction.set(transactionRef, {
            'itemId': supply.inventoryId,
            'eventId': docRef.id,
            'type': 'reservation',
            'quantity': supply.quantity,
            'timestamp': Timestamp.fromDate(now),
            'userId': currentUser.uid,
            'organizationId': organization.id,
          });
        }

        debugPrint('Event creation completed successfully');

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


 Future<void> updateEvent(Event updatedEvent) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      debugPrint('Starting event update for ID: ${updatedEvent.id}');

      // Get the organization info up front
      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found';
      }

      if (updatedEvent.organizationId != organization.id) {
        throw 'Event belongs to a different organization';
      }

      // First get the original event
      final eventDoc = await _firestore.collection('events').doc(updatedEvent.id).get();
      if (!eventDoc.exists) throw 'Event not found';
      final originalEvent = Event.fromMap(eventDoc.data()!, eventDoc.id);

      // Verify staff assignments
      if (updatedEvent.assignedStaff.isNotEmpty) {
        await _verifyStaffAssignment(organization.id, updatedEvent.assignedStaff);
      }

      // Format staff data for update
      final staffData = updatedEvent.assignedStaff.map((staff) => {
        'userId': staff.userId,
        'name': staff.name,
        'role': staff.role,
        'assignedAt': Timestamp.fromDate(staff.assignedAt),
      }).toList();

      debugPrint('Staff data being updated: $staffData');

      // Prepare update data
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
        'menuItems': updatedEvent.menuItems.map((item) => item.toMap()).toList(),
        'supplies': updatedEvent.supplies.map((supply) => supply.toMap()).toList(),
        'assignedStaff': staffData,
        'totalPrice': updatedEvent.totalPrice,
        'metadata': updatedEvent.metadata,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      // Handle inventory update if supplies changed
      if (!listEquals(originalEvent.supplies, updatedEvent.supplies)) {
        await _firestore.runTransaction((transaction) async {
          // Update event
          transaction.update(
            _firestore.collection('events').doc(updatedEvent.id),
            updateData
          );

          // Handle returned supplies
          for (final supply in originalEvent.supplies) {
            if (!updatedEvent.supplies.contains(supply)) {
              final inventoryRef = _firestore.collection('inventory').doc(supply.inventoryId);
              transaction.update(inventoryRef, {
                'quantity': FieldValue.increment(supply.quantity),
                'updatedAt': DateTime.now(),
                'lastModifiedBy': currentUser.uid,
              });
            }
          }

          // Handle new supplies
          for (final supply in updatedEvent.supplies) {
            if (!originalEvent.supplies.contains(supply)) {
              final inventoryRef = _firestore.collection('inventory').doc(supply.inventoryId);
              transaction.update(inventoryRef, {
                'quantity': FieldValue.increment(-supply.quantity),
                'updatedAt': DateTime.now(),
                'lastModifiedBy': currentUser.uid,
              });
            }
          }
        });
      } else {
        // If supplies didn't change, just update the event
        await _firestore
            .collection('events')
            .doc(updatedEvent.id)
            .update(updateData);
      }

      debugPrint('Event update completed successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating event: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<void> changeEventStatus(String eventId, EventStatus newStatus) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      if (newStatus == EventStatus.completed || newStatus == EventStatus.cancelled) {
        await _firestore.runTransaction((transaction) async {
          final eventDoc = await transaction.get(
            _firestore.collection('events').doc(eventId)
          );

          if (!eventDoc.exists) throw 'Event not found';
          final event = Event.fromMap(eventDoc.data()!, eventDoc.id);

          transaction.update(eventDoc.reference, {
            'status': newStatus.toString().split('.').last,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          final now = DateTime.now();

          for (final supply in event.supplies) {
            final inventoryRef = _firestore.collection('inventory').doc(supply.inventoryId);
            transaction.update(inventoryRef, {
              'quantity': FieldValue.increment(supply.quantity),
              'updatedAt': now,
              'lastModifiedBy': currentUser.uid,
            });
          }
        });
      } else {
        await _firestore
            .collection('events')
            .doc(eventId)
            .update({
              'status': newStatus.toString().split('.').last,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }

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

      await _firestore.runTransaction((transaction) async {
        final eventDoc = await transaction.get(
          _firestore.collection('events').doc(eventId)
        );

        if (!eventDoc.exists) throw 'Event not found';
        final event = Event.fromMap(eventDoc.data()!, eventDoc.id);

        transaction.delete(eventDoc.reference);

        final now = DateTime.now();

        for (final supply in event.supplies) {
          final inventoryRef = _firestore.collection('inventory').doc(supply.inventoryId);
          transaction.update(inventoryRef, {
            'quantity': FieldValue.increment(supply.quantity),
            'updatedAt': now,
            'lastModifiedBy': currentUser.uid,
          });
        }
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting event: $e');
      rethrow;
    }
  }
}