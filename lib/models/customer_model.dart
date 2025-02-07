
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore package for database operations

/// A model class representing a customer.
class CustomerModel {
  final String id; // Unique identifier for the customer
  final String firstName; // Customer's first name
  final String lastName; // Customer's last name
  final String email; // Customer's email address
  final String phoneNumber; // Customer's phone number
  final String organizationId;  // Links to the caterer's organization
  final DateTime createdAt; // Timestamp when the customer was created
  final DateTime updatedAt; // Timestamp when the customer was last updated
  final String createdBy;  // Reference to the staff member who created the customer

  /// Constructor for creating a new CustomerModel instance.
  CustomerModel({
    required this.id, // Required parameter for customer ID
    required this.firstName, // Required parameter for first name
    required this.lastName, // Required parameter for last name
    required this.email, // Required parameter for email
    required this.phoneNumber, // Required parameter for phone number
    required this.organizationId, // Required parameter for organization ID
    required this.createdAt, // Required parameter for creation timestamp
    required this.updatedAt, // Required parameter for update timestamp
    required this.createdBy, // Required parameter for creator's ID
  });

  /// Returns the full name of the customer.
  String get fullName => '$firstName $lastName';

  /// Converts the CustomerModel instance to a map for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName, // Customer's first name
      'lastName': lastName, // Customer's last name
      'email': email, // Customer's email address
      'phoneNumber': phoneNumber, // Customer's phone number
      'organizationId': organizationId, // Organization ID
      'createdAt': Timestamp.fromDate(createdAt), // Creation timestamp converted to Firestore Timestamp
      'updatedAt': Timestamp.fromDate(updatedAt), // Update timestamp converted to Firestore Timestamp
      'createdBy': createdBy, // ID of the creator
    };
  }

  /// Factory constructor to create a CustomerModel instance from a map.
  factory CustomerModel.fromMap(Map<String, dynamic> map, String id) {
    return CustomerModel(
      id: id, // Customer ID
      firstName: map['firstName'] ?? '', // First name from map or empty string if null
      lastName: map['lastName'] ?? '', // Last name from map or empty string if null
      email: map['email'] ?? '', // Email from map or empty string if null
      phoneNumber: map['phoneNumber'] ?? '', // Phone number from map or empty string if null
      organizationId: map['organizationId'] ?? '', // Organization ID from map or empty string if null
      createdAt: (map['createdAt'] as Timestamp).toDate(), // Creation timestamp converted from Firestore Timestamp
      updatedAt: (map['updatedAt'] as Timestamp).toDate(), // Update timestamp converted from Firestore Timestamp
      createdBy: map['createdBy'] ?? '', // Creator's ID from map or empty string if null
    );
  }
  CustomerModel copyWith({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? email,
    String? organizationId,
  }) {
    return CustomerModel(
      id: id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdBy: createdBy,
      organizationId: organizationId ?? this.organizationId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

}
