import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cateredtoyou/services/organization_service.dart';
import 'package:cateredtoyou/models/customer_model.dart';

class CustomerService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OrganizationService _organizationService;

  CustomerService(this._organizationService);

  Stream<List<CustomerModel>> getCustomers() async* {
    try {
      // Check authentication
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('CustomerService: No authenticated user');
        yield [];
        return;
      }

      // Get organization
      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        debugPrint('CustomerService: No organization found');
        yield [];
        return;
      }

      // Create the base query
      final query = _firestore
          .collection('customers')
          .where('organizationId', isEqualTo: organization.id);

      // Create and transform the stream
      await for (final snapshot in query.snapshots()) {
        try {
          final customers = snapshot.docs.map((doc) {
            try {
              return CustomerModel.fromMap(doc.data(), doc.id);
            } catch (e) {
              debugPrint('CustomerService: Error mapping document ${doc.id}: $e');
              return null;
            }
          }).whereType<CustomerModel>().toList();

          // Sort customers by name
          customers.sort((a, b) => a.fullName.compareTo(b.fullName));
          
          yield customers;
        } catch (e) {
          debugPrint('CustomerService: Error processing snapshot: $e');
          yield [];
        }
      }
    } catch (e) {
      debugPrint('CustomerService: Stream error: $e');
      yield [];
    }
  }

  Future<CustomerModel> createCustomer({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'Not authenticated. Please login and try again.';
      }

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found. Please try again.';
      }

      // Validate email format
      if (!email.contains('@')) {
        throw 'Invalid email address format';
      }

      // Create customer document
      final docRef = _firestore.collection('customers').doc();
      final now = DateTime.now();

      final customer = CustomerModel(
        id: docRef.id,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        email: email.trim(),
        phoneNumber: phoneNumber.trim(),
        organizationId: organization.id,
        createdAt: now,
        updatedAt: now,
        createdBy: currentUser.uid,
      );

      // Save to Firestore using transaction for atomicity
      await _firestore.runTransaction((transaction) async {
        // Check if email is already in use within the organization
        final existingCustomers = await _firestore
            .collection('customers')
            .where('organizationId', isEqualTo: organization.id)
            .where('email', isEqualTo: email.trim())
            .get();

        if (existingCustomers.docs.isNotEmpty) {
          throw 'A customer with this email already exists';
        }

        transaction.set(docRef, customer.toMap());
      });

      notifyListeners();
      return customer;
    } catch (e) {
      debugPrint('CustomerService: Error creating customer: $e');
      throw _getReadableError(e);
    }
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'Not authenticated. Please login and try again.';
      }

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found. Please try again.';
      }

      if (customer.organizationId != organization.id) {
        throw 'Cannot update customer from another organization';
      }

      // Update using transaction
      await _firestore.runTransaction((transaction) async {
        final customerRef = _firestore.collection('customers').doc(customer.id);
        final customerDoc = await transaction.get(customerRef);

        if (!customerDoc.exists) {
          throw 'Customer not found';
        }

        // Check if email is being used by another customer
        if (customer.email != customerDoc.data()?['email']) {
          final existingCustomers = await _firestore
              .collection('customers')
              .where('organizationId', isEqualTo: organization.id)
              .where('email', isEqualTo: customer.email)
              .get();

          if (existingCustomers.docs.isNotEmpty) {
            throw 'A customer with this email already exists';
          }
        }

        transaction.update(customerRef, customer.toMap());
      });

      notifyListeners();
    } catch (e) {
      debugPrint('CustomerService: Error updating customer: $e');
      throw _getReadableError(e);
    }
  }

  String _getReadableError(dynamic error) {
    if (error is String) return error;
    
    final message = error.toString();
    if (message.contains('permission-denied')) {
      return 'You do not have permission to perform this action';
    }
    if (message.contains('not-found')) {
      return 'Customer not found';
    }
    if (message.contains('already exists')) {
      return 'A customer with this email already exists';
    }
    return 'An unexpected error occurred. Please try again.';
  }

  Future<void> deleteCustomer(String customerId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'Not authenticated. Please login and try again.';
      }

      final organization = await _organizationService.getCurrentUserOrganization();
      if (organization == null) {
        throw 'Organization not found. Please try again.';
      }

      // Check for existing events
      final eventsWithCustomer = await _firestore
          .collection('events')
          .where('customerId', isEqualTo: customerId)
          .get();

      if (eventsWithCustomer.docs.isNotEmpty) {
        throw 'Cannot delete customer with existing events';
      }

      await _firestore.collection('customers').doc(customerId).delete();
      notifyListeners();
    } catch (e) {
      debugPrint('CustomerService: Error deleting customer: $e');
      throw _getReadableError(e);
    }
  }
}