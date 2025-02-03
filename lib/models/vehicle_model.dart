import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore package for database operations

enum VehicleStatus { // Enum to represent the status of the vehicle
  available, // Vehicle is available
  inUse, // Vehicle is currently in use
  maintenance, // Vehicle is under maintenance
  outOfService // Vehicle is out of service
}

enum VehicleType { // Enum to represent the type of the vehicle
  car, // Car type vehicle
  van, // Van type vehicle
  truck, // Truck type vehicle
  motorcycle // Motorcycle type vehicle
}

class Vehicle { // Class to represent a vehicle
  final String id; // Unique identifier for the vehicle
  final String organizationId; // Identifier for the organization that owns the vehicle
  final String model; // Model of the vehicle
  final String make; // Make of the vehicle
  final String year; // Year of manufacture of the vehicle
  final String licensePlate; // License plate number of the vehicle
  final VehicleType type; // Type of the vehicle
  final VehicleStatus status; // Current status of the vehicle
  final String? assignedDriverId; // Identifier for the driver assigned to the vehicle, if any
  final Map<String, dynamic>? telematicsData; // Telematics data for the vehicle, if any
  final DateTime lastMaintenanceDate; // Date of the last maintenance
  final DateTime nextMaintenanceDate; // Date of the next scheduled maintenance
  final DateTime createdAt; // Date and time when the vehicle record was created
  final DateTime updatedAt; // Date and time when the vehicle record was last updated
  final String createdBy; // Identifier for the user who created the vehicle record

  const Vehicle({ // Constructor for the Vehicle class
    required this.id, // Initializing id
    required this.organizationId, // Initializing organizationId
    required this.model, // Initializing model
    required this.make, // Initializing make
    required this.year, // Initializing year
    required this.licensePlate, // Initializing licensePlate
    required this.type, // Initializing type
    required this.status, // Initializing status
    this.assignedDriverId, // Initializing assignedDriverId
    this.telematicsData, // Initializing telematicsData
    required this.lastMaintenanceDate, // Initializing lastMaintenanceDate
    required this.nextMaintenanceDate, // Initializing nextMaintenanceDate
    required this.createdAt, // Initializing createdAt
    required this.updatedAt, // Initializing updatedAt
    required this.createdBy, // Initializing createdBy
  });

  Map<String, dynamic> toMap() { // Method to convert Vehicle object to a map
    return {
      'organizationId': organizationId, // Adding organizationId to the map
      'model': model, // Adding model to the map
      'make': make, // Adding make to the map
      'year': year, // Adding year to the map
      'licensePlate': licensePlate, // Adding licensePlate to the map
      'type': type.toString().split('.').last, // Adding type to the map as a string
      'status': status.toString().split('.').last, // Adding status to the map as a string
      'assignedDriverId': assignedDriverId, // Adding assignedDriverId to the map
      'telematicsData': telematicsData, // Adding telematicsData to the map
      'lastMaintenanceDate': Timestamp.fromDate(lastMaintenanceDate), // Adding lastMaintenanceDate to the map as a Timestamp
      'nextMaintenanceDate': Timestamp.fromDate(nextMaintenanceDate), // Adding nextMaintenanceDate to the map as a Timestamp
      'createdAt': Timestamp.fromDate(createdAt), // Adding createdAt to the map as a Timestamp
      'updatedAt': Timestamp.fromDate(updatedAt), // Adding updatedAt to the map as a Timestamp
      'createdBy': createdBy, // Adding createdBy to the map
    };
  }

  factory Vehicle.fromMap(Map<String, dynamic> map, String docId) { // Factory constructor to create a Vehicle object from a map
    return Vehicle(
      id: docId, // Setting id from docId
      organizationId: map['organizationId'] ?? '', // Setting organizationId from map or defaulting to empty string
      model: map['model'] ?? '', // Setting model from map or defaulting to empty string
      make: map['make'] ?? '', // Setting make from map or defaulting to empty string
      year: map['year'] ?? '', // Setting year from map or defaulting to empty string
      licensePlate: map['licensePlate'] ?? '', // Setting licensePlate from map or defaulting to empty string
      type: VehicleType.values.firstWhere( // Setting type from map or defaulting to VehicleType.car
        (type) => type.toString().split('.').last == map['type'],
        orElse: () => VehicleType.car,
      ),
      status: VehicleStatus.values.firstWhere( // Setting status from map or defaulting to VehicleStatus.available
        (status) => status.toString().split('.').last == map['status'],
        orElse: () => VehicleStatus.available,
      ),
      assignedDriverId: map['assignedDriverId'], // Setting assignedDriverId from map
      telematicsData: map['telematicsData'], // Setting telematicsData from map
      lastMaintenanceDate: (map['lastMaintenanceDate'] as Timestamp).toDate(), // Setting lastMaintenanceDate from map
      nextMaintenanceDate: (map['nextMaintenanceDate'] as Timestamp).toDate(), // Setting nextMaintenanceDate from map
      createdAt: (map['createdAt'] as Timestamp).toDate(), // Setting createdAt from map
      updatedAt: (map['updatedAt'] as Timestamp).toDate(), // Setting updatedAt from map
      createdBy: map['createdBy'] ?? '', // Setting createdBy from map or defaulting to empty string
    );
  }

  Vehicle copyWith({ // Method to create a copy of the Vehicle object with updated fields
    String? model, // Optional new model
    String? make, // Optional new make
    String? year, // Optional new year
    String? licensePlate, // Optional new licensePlate
    VehicleType? type, // Optional new type
    VehicleStatus? status, // Optional new status
    String? assignedDriverId, // Optional new assignedDriverId
    Map<String, dynamic>? telematicsData, // Optional new telematicsData
    DateTime? lastMaintenanceDate, // Optional new lastMaintenanceDate
    DateTime? nextMaintenanceDate, // Optional new nextMaintenanceDate
  }) {
    return Vehicle(
      id: id, // Keeping the same id
      organizationId: organizationId, // Keeping the same organizationId
      model: model ?? this.model, // Updating model if provided, otherwise keeping the same
      make: make ?? this.make, // Updating make if provided, otherwise keeping the same
      year: year ?? this.year, // Updating year if provided, otherwise keeping the same
      licensePlate: licensePlate ?? this.licensePlate, // Updating licensePlate if provided, otherwise keeping the same
      type: type ?? this.type, // Updating type if provided, otherwise keeping the same
      status: status ?? this.status, // Updating status if provided, otherwise keeping the same
      assignedDriverId: assignedDriverId ?? this.assignedDriverId, // Updating assignedDriverId if provided, otherwise keeping the same
      telematicsData: telematicsData ?? this.telematicsData, // Updating telematicsData if provided, otherwise keeping the same
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate, // Updating lastMaintenanceDate if provided, otherwise keeping the same
      nextMaintenanceDate: nextMaintenanceDate ?? this.nextMaintenanceDate, // Updating nextMaintenanceDate if provided, otherwise keeping the same
      createdAt: createdAt, // Keeping the same createdAt
      updatedAt: DateTime.now(), // Setting updatedAt to the current date and time
      createdBy: createdBy, // Keeping the same createdBy
    );
  }
}
