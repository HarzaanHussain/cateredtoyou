
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore package to handle Firestore data types

class Organization {
  final String id; // Unique identifier for the organization
  final String name; // Name of the organization
  final String ownerId; // Identifier for the owner of the organization
  final DateTime createdAt; // Timestamp when the organization was created
  final DateTime updatedAt; // Timestamp when the organization was last updated
  final Map<String, dynamic>? settings; // Optional settings for the organization
  final String? contactEmail; // Optional contact email for the organization
  final String? contactPhone; // Optional contact phone number for the organization
  final String? address; // Optional address for the organization

  Organization({
    required this.id, // Constructor parameter for id
    required this.name, // Constructor parameter for name
    required this.ownerId, // Constructor parameter for ownerId
    required this.createdAt, // Constructor parameter for createdAt
    required this.updatedAt, // Constructor parameter for updatedAt
    this.settings, // Constructor parameter for settings
    this.contactEmail, // Constructor parameter for contactEmail
    this.contactPhone, // Constructor parameter for contactPhone
    this.address, // Constructor parameter for address
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, // Convert id to map
      'name': name, // Convert name to map
      'ownerId': ownerId, // Convert ownerId to map
      'createdAt': Timestamp.fromDate(createdAt), // Convert createdAt to Firestore Timestamp
      'updatedAt': Timestamp.fromDate(updatedAt), // Convert updatedAt to Firestore Timestamp
      'settings': settings, // Convert settings to map
      'contactEmail': contactEmail, // Convert contactEmail to map
      'contactPhone': contactPhone, // Convert contactPhone to map
      'address': address, // Convert address to map
    };
  }

  factory Organization.fromMap(Map<String, dynamic> map, String documentId) {
    return Organization(
      id: documentId, // Assign documentId to id
      name: map['name'] ?? '', // Assign name from map or default to empty string
      ownerId: map['ownerId'] ?? '', // Assign ownerId from map or default to empty string
      createdAt: (map['createdAt'] as Timestamp).toDate(), // Convert Firestore Timestamp to DateTime for createdAt
      updatedAt: (map['updatedAt'] as Timestamp).toDate(), // Convert Firestore Timestamp to DateTime for updatedAt
      settings: map['settings'], // Assign settings from map
      contactEmail: map['contactEmail'], // Assign contactEmail from map
      contactPhone: map['contactPhone'], // Assign contactPhone from map
      address: map['address'], // Assign address from map
    );
  }

  Organization copyWith({
    String? name, // Optional parameter to update name
    Map<String, dynamic>? settings, // Optional parameter to update settings
    String? contactEmail, // Optional parameter to update contactEmail
    String? contactPhone, // Optional parameter to update contactPhone
    String? address, // Optional parameter to update address
  }) {
    return Organization(
      id: id, // Keep the same id
      name: name ?? this.name, // Update name if provided, otherwise keep the same
      ownerId: ownerId, // Keep the same ownerId
      createdAt: createdAt, // Keep the same createdAt
      updatedAt: DateTime.now(), // Update updatedAt to current time
      settings: settings ?? this.settings, // Update settings if provided, otherwise keep the same
      contactEmail: contactEmail ?? this.contactEmail, // Update contactEmail if provided, otherwise keep the same
      contactPhone: contactPhone ?? this.contactPhone, // Update contactPhone if provided, otherwise keep the same
      address: address ?? this.address, // Update address if provided, otherwise keep the same
    );
  }
}