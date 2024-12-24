import 'package:cloud_firestore/cloud_firestore.dart';

class Organization {
  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? settings;
  final String? contactEmail;
  final String? contactPhone;
  final String? address;

  Organization({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    this.settings,
    this.contactEmail,
    this.contactPhone,
    this.address,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'ownerId': ownerId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'settings': settings,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'address': address,
    };
  }

  factory Organization.fromMap(Map<String, dynamic> map, String documentId) {
    return Organization(
      id: documentId,
      name: map['name'] ?? '',
      ownerId: map['ownerId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      settings: map['settings'],
      contactEmail: map['contactEmail'],
      contactPhone: map['contactPhone'],
      address: map['address'],
    );
  }

  Organization copyWith({
    String? name,
    Map<String, dynamic>? settings,
    String? contactEmail,
    String? contactPhone,
    String? address,
  }) {
    return Organization(
      id: id,
      name: name ?? this.name,
      ownerId: ownerId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      settings: settings ?? this.settings,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      address: address ?? this.address,
    );
  }
}