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

  // Get events stream
   Stream<List<Event>> getEvents() async* {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        yield [];
        return;
      }

      // Get organization info
      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        yield [];
        return;
      }

      // Create query
      final query = _firestore
          .collection('events')
          .where('organizationId', isEqualTo: organization.id);

      // Stream events
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

  

  // Verify inventory availability
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

  // Create event
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
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw 'Not authenticated';
    }

    // Validate user permissions
    final userRef = _firestore.collection('users').doc(currentUser.uid);
    final userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      throw 'User not found';
    }

    final userRole = userDoc.data()?['role'];
    final hasPermission = ['admin', 'client', 'manager'].contains(userRole);
    
    if (!hasPermission) {
      throw 'Insufficient permissions to create events';
    }

    // Get organization
    final organization = await _organizationService.getCurrentUserOrganization();
    if (organization == null) {
      throw 'Organization not found';
    }

    // Validate dates
    if (endDate.isBefore(startDate)) {
      throw 'End date must be after start date';
    }

    if (startTime.isAfter(endTime)) {
      throw 'End time must be after start time';
    }

    // Calculate total price
    final totalPrice = menuItems.fold<double>(
      0,
      (total, item) => total + (item.price * item.quantity),
    );

    try {
      // Use transaction for atomicity
      final event = await _firestore.runTransaction<Event>((transaction) async {
        // Verify customer exists and belongs to organization
        final customerRef = _firestore.collection('customers').doc(customerId);
        final customerDoc = await transaction.get(customerRef);
        
        if (!customerDoc.exists || 
            customerDoc.data()?['organizationId'] != organization.id) {
          throw 'Invalid customer selected';
        }

        // Verify inventory availability
        for (final supply in supplies) {
          final inventoryRef = _firestore
              .collection('inventory')
              .doc(supply.inventoryId);
          
          final inventoryDoc = await transaction.get(inventoryRef);
          
          if (!inventoryDoc.exists) {
            throw 'Supply item ${supply.name} not found';
          }

          final item = InventoryItem.fromMap(inventoryDoc.data()!, inventoryDoc.id);
          
          if (item.quantity < supply.quantity) {
            throw '''Insufficient quantity available for ${supply.name}. 
                    Available: ${item.quantity} ${item.unit}''';
          }

          if (item.organizationId != organization.id) {
            throw 'Invalid inventory item selected';
          }
        }

        // Create event document
        final docRef = _firestore.collection('events').doc();
        final now = DateTime.now();
        
        final event = Event(
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

        // Set event document
        transaction.set(docRef, event.toMap());

        // Update inventory quantities
        for (final supply in supplies) {
          final inventoryRef = _firestore
              .collection('inventory')
              .doc(supply.inventoryId);
              
          transaction.update(inventoryRef, {
            'quantity': FieldValue.increment(-supply.quantity),
            'updatedAt': now,
            'lastModifiedBy': currentUser.uid,
          });

          // Create inventory transaction record
          final transactionRef = _firestore
              .collection('inventory_transactions')
              .doc();
              
          transaction.set(transactionRef, {
            'itemId': supply.inventoryId,
            'eventId': docRef.id,
            'type': 'reservation',
            'quantity': supply.quantity,
            'timestamp': now,
            'userId': currentUser.uid,
            'organizationId': organization.id,
          });
        }

        return event;
      });

      notifyListeners();
      return event;
    } catch (e) {
      debugPrint('Error creating event: $e');
      rethrow;
    }
  }


  // Update event
  Future<void> updateEvent(Event updatedEvent) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found';
      }

      if (updatedEvent.organizationId != organization.id) {
        throw 'Event belongs to a different organization';
      }

      // Get current event to compare supplies
      final eventDoc = await _firestore
          .collection('events')
          .doc(updatedEvent.id)
          .get();

      if (!eventDoc.exists) throw 'Event not found';
      final currentEvent = Event.fromMap(eventDoc.data()!, eventDoc.id);

      // Calculate supplies to return and new supplies to allocate
      final suppliesToReturn = currentEvent.supplies.where(
        (original) => !updatedEvent.supplies.any((updated) => 
          updated.inventoryId == original.inventoryId && 
          updated.quantity == original.quantity
        )
      ).toList();

      final suppliesToAllocate = updatedEvent.supplies.where(
        (updated) => !currentEvent.supplies.any((original) => 
          original.inventoryId == updated.inventoryId &&
          original.quantity == updated.quantity
        )
      ).toList();

      // Verify availability for new supplies
      if (suppliesToAllocate.isNotEmpty) {
        await _verifyInventoryAvailability(suppliesToAllocate);
      }

      // Use transaction for atomic updates
      await _firestore.runTransaction((transaction) async {
        final eventRef = _firestore.collection('events').doc(updatedEvent.id);
        
        // Update event
        transaction.update(eventRef, updatedEvent.toMap());

        final now = DateTime.now();

        // Return old supplies
        for (final supply in suppliesToReturn) {
          final inventoryRef = _firestore.collection('inventory').doc(supply.inventoryId);
          transaction.update(inventoryRef, {
            'quantity': FieldValue.increment(supply.quantity),
            'updatedAt': now,
            'lastModifiedBy': currentUser.uid,
          });
        }

        // Allocate new supplies
        for (final supply in suppliesToAllocate) {
          final inventoryRef = _firestore.collection('inventory').doc(supply.inventoryId);
          transaction.update(inventoryRef, {
            'quantity': FieldValue.increment(-supply.quantity),
            'updatedAt': now,
            'lastModifiedBy': currentUser.uid,
          });
        }
      });

       final removedStaff = currentEvent.assignedStaff
          .where((staff) => !updatedEvent.assignedStaff
              .any((updated) => updated.userId == staff.userId))
          .toList();

      final addedStaff = updatedEvent.assignedStaff
          .where((staff) => !currentEvent.assignedStaff
              .any((current) => current.userId == staff.userId))
          .toList();

      

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating event: $e');
      rethrow;
    }
  }

  // Change event status
  Future<void> changeEventStatus(String eventId, EventStatus newStatus) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      // Complete or cancel event
      if (newStatus == EventStatus.completed || newStatus == EventStatus.cancelled) {
        await _firestore.runTransaction((transaction) async {
          final eventDoc = await transaction.get(
            _firestore.collection('events').doc(eventId)
          );

          if (!eventDoc.exists) throw 'Event not found';
          final event = Event.fromMap(eventDoc.data()!, eventDoc.id);

          // Update event status
          transaction.update(eventDoc.reference, {
            'status': newStatus.toString().split('.').last,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          

          final now = DateTime.now();

          // Return supplies to inventory
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
        // Simple status update
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

  // Delete event
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

        // Delete event
        transaction.delete(eventDoc.reference);

        final now = DateTime.now();

        // Return supplies to inventory
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