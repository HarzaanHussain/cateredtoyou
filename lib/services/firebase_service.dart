import 'package:firebase_core/firebase_core.dart'; // Import Firebase core package for initializing Firebase
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore package for database operations
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth package for authentication
import 'package:flutter/foundation.dart'; // Import Flutter foundation package for debugging
import 'package:cateredtoyou/firebase_options.dart'; // Import Firebase options specific to the project

class FirebaseService {
  // Method to initialize Firebase
  static Future<void> initialize() async {
    try {
      // Initialize Firebase with platform-specific options
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Optional: Configure Firebase Auth settings
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: false, // Disable app verification for testing
      );
      
      // Optional: Configure Firestore settings
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true, // Enable offline data persistence
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // Set cache size to unlimited
      );
    } catch (e) {
      // Print error message if initialization fails
      debugPrint('Failed to initialize Firebase: $e');
      rethrow; // Rethrow the exception to handle it elsewhere
    }
  }
  
  // Singleton pattern to ensure only one instance of FirebaseService
  static final FirebaseService _instance = FirebaseService._internal();
  
  // Factory constructor to return the singleton instance
  factory FirebaseService() {
    return _instance;
  }
  
  // Private constructor for singleton pattern
  FirebaseService._internal();
  
  // Getter to access Firebase Auth instance
  FirebaseAuth get auth => FirebaseAuth.instance;
  // Getter to access Firestore instance
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
}

// Class to hold Firestore collection names
class Collections {
  static const String users = 'users'; // Collection name for users
  static const String events = 'events'; // Collection name for events
  static const String inventory = 'inventory'; // Collection name for inventory
  static const String departments = 'departments'; // Collection name for departments
  static const String menuItems = 'menuItems'; // Collection name for menu items
  static const String storageLocations = 'storageLocations'; // Collection name for storage locations
}