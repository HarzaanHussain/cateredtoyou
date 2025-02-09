
import 'package:flutter/foundation.dart'; // Provides ChangeNotifier for state management
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore database package
import 'package:firebase_auth/firebase_auth.dart'; // Firebase authentication package
import 'package:cateredtoyou/services/organization_service.dart'; // Custom service to handle organization-related operations
import 'package:cateredtoyou/models/customer_model.dart'; // Custom model representing a customer

/// Service class to handle customer-related operations
class CustomerService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance for database operations
  final FirebaseAuth _auth = FirebaseAuth.instance; // FirebaseAuth instance for authentication
  final OrganizationService _organizationService; // Service to handle organization-related operations

  /// Constructor to initialize the organization service
  CustomerService(this._organizationService);

  /// Stream to get a list of customers for the authenticated user's organization
  Stream<List<CustomerModel>> getCustomers() async* {
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) {
        debugPrint('CustomerService: No authenticated user'); // Log if no user is authenticated
        yield []; // Yield an empty list if no user is authenticated
        return;
      }

      final organization = await _organizationService.getCurrentUserOrganization(); // Get the organization of the current user
      if (organization == null) {
        debugPrint('CustomerService: No organization found'); // Log if no organization is found
        yield []; // Yield an empty list if no organization is found
        return;
      }

      final query = _firestore
          .collection('customers')
          .where('organizationId', isEqualTo: organization.id); // Query to get customers of the organization

      await for (final snapshot in query.snapshots()) {
        try {
          final customers = snapshot.docs.map((doc) {
            try {
              return CustomerModel.fromMap(doc.data(), doc.id); // Map Firestore document to CustomerModel
            } catch (e) {
              debugPrint('CustomerService: Error mapping document ${doc.id}: $e'); // Log mapping error
              return null;
            }
          }).whereType<CustomerModel>().toList(); // Filter out null values

          customers.sort((a, b) => a.fullName.compareTo(b.fullName)); // Sort customers by full name
          
          yield customers; // Yield the list of customers
        } catch (e) {
          debugPrint('CustomerService: Error processing snapshot: $e'); // Log snapshot processing error
          yield []; // Yield an empty list on error
        }
      }
    } catch (e) {
      debugPrint('CustomerService: Stream error: $e'); // Log stream error
      yield []; // Yield an empty list on error
    }
  }

  Future<bool> createCustomerStandalone({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
  }) async {
    try{
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'Not authenticated. Please login and try again.'; // Throw error if no user is authenticated
      }

      final organization = await _organizationService.getCurrentUserOrganization(); // Get the organization of the current user
      if (organization == null) {
        throw 'Organization not found. Please try again.'; // Throw error if no organization is found
      }

      if (!email.contains('@')) {
        throw 'Invalid email address format'; // Validate email format
      }

      final docRef = _firestore.collection('customers').doc(); // Reference to a new customer document
      final now = DateTime.now(); // Current timestamp

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
      ); // Create a new customer model

      await _firestore.runTransaction((transaction) async {
        final existingCustomers = await _firestore
            .collection('customers')
            .where('organizationId', isEqualTo: organization.id)
            .where('email', isEqualTo: email.trim())
            .get(); // Check if email is already in use within the organization

        if (existingCustomers.docs.isNotEmpty) {
          throw 'A customer with this email already exists'; // Throw error if email is already in use
        }

        transaction.set(docRef, customer.toMap()); // Save the customer document in a transaction
      });
      notifyListeners();
      return true;
    }catch (e){
      debugPrint('CustomerService: Error creating customer: $e'); // Log error
      throw _getReadableError(e); // Throw a readable error
    }
  }

  /// Creates a new customer in the Firestore database
  Future<CustomerModel> createCustomer({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
  }) async {
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) {
        throw 'Not authenticated. Please login and try again.'; // Throw error if no user is authenticated
      }

      final organization = await _organizationService.getCurrentUserOrganization(); // Get the organization of the current user
      if (organization == null) {
        throw 'Organization not found. Please try again.'; // Throw error if no organization is found
      }

      if (!email.contains('@')) {
        throw 'Invalid email address format'; // Validate email format
      }

      final docRef = _firestore.collection('customers').doc(); // Reference to a new customer document
      final now = DateTime.now(); // Current timestamp

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
      ); // Create a new customer model

      await _firestore.runTransaction((transaction) async {
        final existingCustomers = await _firestore
            .collection('customers')
            .where('organizationId', isEqualTo: organization.id)
            .where('email', isEqualTo: email.trim())
            .get(); // Check if email is already in use within the organization

        if (existingCustomers.docs.isNotEmpty) {
          throw 'A customer with this email already exists'; // Throw error if email is already in use
        }

        transaction.set(docRef, customer.toMap()); // Save the customer document in a transaction
      });

      notifyListeners(); // Notify listeners about the change
      return customer; // Return the created customer
    } catch (e) {
      debugPrint('CustomerService: Error creating customer: $e'); // Log error
      throw _getReadableError(e); // Throw a readable error
    }
  }

  /// Updates an existing customer in the Firestore database
  Future<void> updateCustomer(CustomerModel customer) async {
    try {
      final currentUser = _auth.currentUser; // Get the current authenticated user
      if (currentUser == null) {
        throw 'Not authenticated. Please login and try again.'; // Throw error if no user is authenticated
      }

      final organization = await _organizationService.getCurrentUserOrganization(); // Get the organization of the current user
      if (organization == null) {
        throw 'Organization not found. Please try again.'; // Throw error if no organization is found
      }

      if (customer.organizationId != organization.id) {
        throw 'Cannot update customer from another organization'; // Throw error if customer belongs to another organization
      }

      await _firestore.runTransaction((transaction) async {
        final customerRef = _firestore.collection('customers').doc(customer.id); // Reference to the customer document
        final customerDoc = await transaction.get(customerRef); // Get the customer document

        if (!customerDoc.exists) {
          throw 'Customer not found'; // Throw error if customer does not exist
        }

        if (customer.email != customerDoc.data()?['email']) {
          final existingCustomers = await _firestore
              .collection('customers')
              .where('organizationId', isEqualTo: organization.id)
              .where('email', isEqualTo: customer.email)
              .get(); // Check if email is being used by another customer

          if (existingCustomers.docs.isNotEmpty) {
            throw 'A customer with this email already exists'; // Throw error if email is already in use
          }
        }

        transaction.update(customerRef, customer.toMap()); // Update the customer document in a transaction
      });

      notifyListeners(); // Notify listeners about the change
    } catch (e) {
      debugPrint('CustomerService: Error updating customer: $e'); // Log error
      throw _getReadableError(e); // Throw a readable error
    }
  }

  /// Converts an error to a readable error message
  String _getReadableError(dynamic error) {
    if (error is String) return error; // Return the error if it is a string
    
    final message = error.toString(); // Convert the error to a string
    if (message.contains('permission-denied')) {
      return 'You do not have permission to perform this action'; // Return permission error message
    }
    if (message.contains('not-found')) {
      return 'Customer not found'; // Return not found error message
    }
    if (message.contains('already exists')) {
      return 'A customer with this email already exists'; // Return email already exists error message
    }
    return 'An unexpected error occurred. Please try again.'; // Return generic error message
  }

  /// Deletes a customer from the Firestore database
Future<void> deleteCustomer(String customerId) async {
  try {
    final currentUser = _auth.currentUser; // Get the current authenticated user
    if (currentUser == null) {
      throw 'Not authenticated. Please login and try again.'; // Throw error if no user is authenticated
    }

    final organization = await _organizationService.getCurrentUserOrganization(); // Get the organization of the current user
    if (organization == null) {
      throw 'Organization not found. Please try again.'; // Throw error if no organization is found
    }

    // Get the customer document first to verify organization
    final customerDoc = await _firestore.collection('customers').doc(customerId).get();
    
    if (!customerDoc.exists) {
      throw 'Customer not found'; // Throw error if customer does not exist
    }

    if (customerDoc.data()?['organizationId'] != organization.id) {
      throw 'Cannot delete customer from another organization'; // Throw error if customer belongs to another organization
    }

    // Check if user has management role
    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    final userRole = userDoc.data()?['role'];
    if (!['admin', 'client', 'manager'].contains(userRole)) {
      throw 'You do not have permission to delete customers'; // Throw error if user does not have permission
    }

    // Check for existing events with this customer
    final eventsQuery = await _firestore
        .collection('events')
        .where('customerId', isEqualTo: customerId)
        .where('organizationId', isEqualTo: organization.id)
        .get();

    if (eventsQuery.docs.isNotEmpty) {
      throw 'Cannot delete customer with existing events. Please delete or reassign their events first.'; // Throw error if customer has existing events
    }

    // Perform the deletion in a transaction
    await _firestore.runTransaction((transaction) async {
      // Delete the customer document
      transaction.delete(_firestore.collection('customers').doc(customerId)); // Delete the customer document in a transaction
    });

    notifyListeners(); // Notify listeners about the change
  } catch (e) {
    debugPrint('CustomerService: Error deleting customer: $e'); // Log error
    throw _getReadableError(e); // Throw a readable error
  }
}
}