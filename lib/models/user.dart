import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String role;
  final String? employmentStatus;
  final List<String>? departments;
  final String? createdBy;
  final String organizationId;
  final DateTime createdAt;
  final DateTime updatedAt;

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

  String get fullName => '$firstName $lastName';

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
