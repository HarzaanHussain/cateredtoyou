import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cateredtoyou/services/delivery_route_service.dart';

class LocationService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DeliveryRouteService _deliveryService;
  
  Position? _currentPosition;
  String? _activeDeliveryId;
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  Timer? _updateTimer;
  
  // Expose read-only properties
  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  String? get activeDeliveryId => _activeDeliveryId;
  
  LocationService(this._deliveryService);
  
  // Initialize location service
  Future<bool> initializeLocationTracking() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      // Check for location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }
      
      // Try to recover any active delivery tracking
      await _recoverActiveDelivery();
      
      return true;
    } catch (e) {
      debugPrint('Error initializing location tracking: $e');
      return false;
    }
  }

  // Start tracking location for a delivery
  Future<bool> startTrackingDelivery(String deliveryId) async {
    try {
      await stopTrackingDelivery(); // Stop any existing tracking
      
      final routeDoc = await _firestore.collection('delivery_routes').doc(deliveryId).get();
      if (!routeDoc.exists) return false;
      
      _activeDeliveryId = deliveryId;
      _isTracking = true;
      
      // Update delivery status to in_progress if it's not already
      if (routeDoc.data()?['status'] != 'in_progress') {
        await _deliveryService.updateRouteStatus(deliveryId, 'in_progress');
      }
      
      // Get current position first
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      
      // Update initial position
      await _updatePosition(_currentPosition!);
      
      // Start position stream
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters of movement
        ),
      ).listen(_onPositionUpdate);
      
      // Save active delivery to preferences for recovery
      await _saveActiveDelivery(deliveryId);
      
      // Start periodic updates for when the app is in background
      _startPeriodicUpdates();
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error starting location tracking: $e');
      _isTracking = false;
      _activeDeliveryId = null;
      return false;
    }
  }

  // Stop tracking location
  Future<void> stopTrackingDelivery({bool completed = false}) async {
    try {
      _isTracking = false;
      
      await _positionStream?.cancel();
      _positionStream = null;
      
      _updateTimer?.cancel();
      _updateTimer = null;
      
      // Mark delivery as completed if requested
      if (completed && _activeDeliveryId != null) {
        await _deliveryService.updateRouteStatus(_activeDeliveryId!, 'completed');
      }
      
      _activeDeliveryId = null;
      
      // Clear saved delivery
      await _clearActiveDelivery();
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping location tracking: $e');
    }
  }

  // Handler for position updates
  void _onPositionUpdate(Position position) async {
    _currentPosition = position;
    
    // Update Firestore with new position
    await _updatePosition(position);
    
    notifyListeners();
  }
  
  // Update position in Firestore
  Future<void> _updatePosition(Position position) async {
    if (_activeDeliveryId == null || !_isTracking) return;
    
    try {
      // Convert position to GeoPoint
      final location = GeoPoint(position.latitude, position.longitude);
      
      // Update delivery route with new location
      await _deliveryService.updateDriverLocation(
        _activeDeliveryId!,
        location,
        heading: position.heading,
        speed: position.speed,
      );
    } catch (e) {
      debugPrint('Error updating position: $e');
    }
  }
  
  // Start periodic background updates
  void _startPeriodicUpdates() {
    _updateTimer?.cancel();
    
    // Update every 30 seconds even if position hasn't changed significantly
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!_isTracking || _activeDeliveryId == null) return;
      
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        
        _currentPosition = position;
        await _updatePosition(position);
        notifyListeners();
      } catch (e) {
        debugPrint('Error in periodic update: $e');
      }
    });
  }
  
  // Save active delivery ID to preferences for recovery
  Future<void> _saveActiveDelivery(String deliveryId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_delivery_id', deliveryId);
      await prefs.setBool('is_tracking_active', true);
    } catch (e) {
      debugPrint('Error saving active delivery: $e');
    }
  }
  
  // Clear active delivery from preferences
  Future<void> _clearActiveDelivery() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_delivery_id');
      await prefs.setBool('is_tracking_active', false);
    } catch (e) {
      debugPrint('Error clearing active delivery: $e');
    }
  }
  
  // Recover active delivery from preferences
  Future<void> _recoverActiveDelivery() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deliveryId = prefs.getString('active_delivery_id');
      final isActive = prefs.getBool('is_tracking_active') ?? false;
      
      if (deliveryId != null && isActive) {
        // Check if delivery is still in progress
        final doc = await _firestore.collection('delivery_routes').doc(deliveryId).get();
        if (doc.exists && doc.data()?['status'] == 'in_progress') {
          // Resume tracking
          await startTrackingDelivery(deliveryId);
        } else {
          // Clear saved delivery if it's no longer active
          await _clearActiveDelivery();
        }
      }
    } catch (e) {
      debugPrint('Error recovering active delivery: $e');
    }
  }
  
  // Check for any active deliveries for the current user
  Future<String?> checkForActiveDelivery() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      
      final snapshot = await _firestore
          .collection('delivery_routes')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'in_progress')
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      debugPrint('Error checking for active deliveries: $e');
      return null;
    }
  }
  
  @override
  void dispose() {
    _positionStream?.cancel();
    _updateTimer?.cancel();
    super.dispose();
  }
}