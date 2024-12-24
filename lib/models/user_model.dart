import 'package:cloud_firestore/cloud_firestore.dart';

/// A model class representing a user in the system.
class UserModel {
  /// The unique identifier for the user.
  final String uid;

  /// The email address of the user.
  final String email;

  /// The first name of the user.
  final String firstName;

  /// The last name of the user.
  final String lastName;

  /// The phone number of the user.
  final String phoneNumber;

  /// The role of the user (e.g., admin, client).
  final String role;

  /// The employment status of the user (optional).
  final String? employmentStatus;

  /// The departments the user belongs to (optional).
  final List<String>? departments;

  /// The user who created this user record (optional).
  final String? createdBy;

  /// The organization ID the user belongs to.
  final String organizationId;

  /// The date and time when the user was created.
  final DateTime createdAt;

  /// The date and time when the user was last updated.
  final DateTime updatedAt;

  /// Constructor for creating a new [UserModel] instance.
  UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.role,
    this.employmentStatus,
    this.departments,
    this.createdBy,
    required this.organizationId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Returns the full name of the user by concatenating first and last names.
  String get fullName => '$firstName $lastName';

  /// Converts the [UserModel] instance to a map for serialization.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'role': role,
      'employmentStatus': employmentStatus ?? 'active',
      'departments': departments ?? [],
      'createdBy': createdBy ?? uid,
      'organizationId': organizationId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Creates a new [UserModel] instance from a map.
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      role: map['role'] ?? 'client',
      employmentStatus: map['employmentStatus'] ?? 'active',
      departments: map['departments'] != null 
          ? List<String>.from(map['departments']) 
          : null,
      createdBy: map['createdBy'],
      organizationId: map['organizationId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Creates a copy of the current [UserModel] instance with updated fields.
  UserModel copyWith({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? role,
    String? employmentStatus,
    List<String>? departments,
    String? organizationId,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      departments: departments ?? this.departments,
      createdBy: createdBy,
      organizationId: organizationId ?? this.organizationId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
