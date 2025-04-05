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
  Timer? _trackingWatchdog;
  Timer? _locationRetryTimer;
  
  // For faster updates
  final int _fastUpdateIntervalMs = 1000; // Update UI every 1 second
  final int _firebaseUpdateIntervalMs = 3000; // Update Firebase every 3 seconds
  DateTime? _lastFirebaseUpdate;
  
  // Error states and recovery
  int _errorCount = 0;
  bool _isRecovering = false;
  
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
        debugPrint('Location services are disabled');
        _startLocationServicesWatchdog();
        return false;
      }

      // Check for location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          _startLocationServicesWatchdog();
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied');
        _startLocationServicesWatchdog();
        return false;
      }
      
      // Try to recover any active delivery tracking
      await _recoverActiveDelivery();
      
      // Start a watchdog timer to ensure tracking stays active
      _startTrackingWatchdog();
      
      return true;
    } catch (e) {
      debugPrint('Error initializing location tracking: $e');
      _startLocationServicesWatchdog();
      return false;
    }
  }

  // Start tracking location for a delivery
  Future<bool> startTrackingDelivery(String deliveryId) async {
    try {
      await stopTrackingDelivery(completed: false, clearDeliveryId: false);
      
      final routeDoc = await _firestore.collection('delivery_routes').doc(deliveryId).get();
      if (!routeDoc.exists) {
        debugPrint('Delivery route not found: $deliveryId');
        return false;
      }
      
      _activeDeliveryId = deliveryId;
      _isTracking = true;
      _errorCount = 0;
      _lastFirebaseUpdate = null; // Reset last update time
      
      // Update delivery status to in_progress if it's not already
      if (routeDoc.data()?['status'] != 'in_progress') {
        await _deliveryService.updateRouteStatus(deliveryId, 'in_progress');
      }
      
      // Get current position first with high accuracy
      debugPrint('Getting initial position for delivery tracking...');
      try {
        _currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5), // Shorter timeout for faster startup
          ),
        );
        
        // Update initial position immediately
        if (_currentPosition != null) {
          await _updatePosition(_currentPosition!, forceUpdate: true);
        }
      } catch (e) {
        debugPrint('Error getting current position, trying last known: $e');
        final lastKnownPosition = await Geolocator.getLastKnownPosition();
        if (lastKnownPosition != null) {
          _currentPosition = lastKnownPosition;
          await _updatePosition(_currentPosition!, forceUpdate: true);
        }
      }
      
      // Start position stream with optimized settings for faster updates
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 2, // Update every 2 meters for more frequent updates
          timeLimit: Duration(seconds: 5), // Shorter timeout
        ),
      ).listen(_onPositionUpdate, onError: _handlePositionError);
      
      // Save active delivery to preferences for recovery
      await _saveActiveDelivery(deliveryId);
      
      // Start very frequent UI updates
      _startFrequentUpdates();
      
      // Ensure watchdog is running
      _startTrackingWatchdog();
      
      debugPrint('🚚 Started tracking delivery: $deliveryId');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error starting location tracking: $e');
      if (!_isRecovering) {
        _isTracking = false;
      }
      _handleTrackingError();
      return false;
    }
  }

  // Handle position stream errors
  void _handlePositionError(dynamic error) {
    debugPrint('❌ Position stream error: $error');
    _handleTrackingError();
  }
  
  // Handle general tracking errors with recovery logic
  void _handleTrackingError() {
    _errorCount++;
    
    // If we're having persistent issues, try to recover
    if (_errorCount >= 3 && !_isRecovering) {
      _isRecovering = true;
      
      // Cancel existing retry timer
      _locationRetryTimer?.cancel();
      
      // Schedule recovery attempt
      _locationRetryTimer = Timer(const Duration(seconds: 5), () async {
        debugPrint('🔄 Attempting to recover tracking...');
        if (_activeDeliveryId != null) {
          await startTrackingDelivery(_activeDeliveryId!);
        }
        _isRecovering = false;
      });
    }
  }

  // Stop tracking location
  Future<void> stopTrackingDelivery({bool completed = false, bool clearDeliveryId = true}) async {
    try {
      _isTracking = false;
      
      await _positionStream?.cancel();
      _positionStream = null;
      
      _updateTimer?.cancel();
      _updateTimer = null;
      
      _locationRetryTimer?.cancel();
      
      // Mark delivery as completed if requested
      if (completed && _activeDeliveryId != null) {
        await _deliveryService.updateRouteStatus(_activeDeliveryId!, 'completed');
      }
      
      if (clearDeliveryId) {
        final oldDeliveryId = _activeDeliveryId;
        _activeDeliveryId = null;
        // Clear saved delivery
        await _clearActiveDelivery();
        debugPrint('🛑 Stopped tracking delivery: $oldDeliveryId');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping location tracking: $e');
    }
  }

  // Handler for position updates - this creates local updates very quickly
  void _onPositionUpdate(Position position) async {
    _currentPosition = position;
    
    // Always notify listeners for very fast UI updates
    notifyListeners();
    
    // Only update Firebase every few seconds to reduce server load
    final now = DateTime.now();
    if (_lastFirebaseUpdate == null || 
        now.difference(_lastFirebaseUpdate!).inMilliseconds > _firebaseUpdateIntervalMs) {
      await _updatePosition(position);
      _lastFirebaseUpdate = now;
      _errorCount = 0; // Reset error count on successful Firebase update
    }
  }
  
  // Update position in Firestore
  Future<void> _updatePosition(Position position, {bool forceUpdate = false}) async {
    if (_activeDeliveryId == null) return;
    
    try {
      // Skip updates if we're not actively tracking unless forced
      if (!_isTracking && !forceUpdate) return;
      
      // Convert position to GeoPoint
      final location = GeoPoint(position.latitude, position.longitude);
      
      // Calculate speed if available
      double? speed = position.speed;
      
      // If speed is invalid, calculate a reasonable value
      if (!speed.isFinite || speed <= 0) {
        speed = 5.0; // Default to 5 m/s (about 11 mph)
      }
      
      // Update delivery route with new location
      await _deliveryService.updateDriverLocation(
        _activeDeliveryId!,
        location,
        heading: position.heading,
        speed: speed,
      );
      
      debugPrint('📍 Position updated: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('❌ Error updating position: $e');
      _handleTrackingError();
    }
  }
  
  // Start very frequent UI updates
  void _startFrequentUpdates() {
    _updateTimer?.cancel();
    
    // Update UI very frequently even if position hasn't changed
    _updateTimer = Timer.periodic(Duration(milliseconds: _fastUpdateIntervalMs), (_) async {
      if (_activeDeliveryId == null || !_isTracking) return;
      
      // Simply notify listeners to refresh UI with current position
      // This creates the illusion of real-time tracking even if Firebase updates are less frequent
      notifyListeners();
      
      // Every few seconds, also try to get a fresh position if stream isn't providing one
      if (_lastFirebaseUpdate != null && 
          DateTime.now().difference(_lastFirebaseUpdate!).inSeconds > 5) {
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 3),
            ),
          );
          
          _currentPosition = position;
          await _updatePosition(position, forceUpdate: true);
          _lastFirebaseUpdate = DateTime.now();
          notifyListeners();
        } catch (e) {
          // Just log the error, don't disrupt the UI refresh
          debugPrint('Error in background position refresh: $e');
        }
      }
    });
  }
  
  // Watchdog to ensure tracking stays active for in-progress deliveries
  void _startTrackingWatchdog() {
    _trackingWatchdog?.cancel();
    
    // Check every 30 seconds that tracking is active for in-progress deliveries
    _trackingWatchdog = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_activeDeliveryId == null) {
        // Check if there's an active delivery we should be tracking
        final deliveryId = await checkForActiveDelivery();
        if (deliveryId != null) {
          debugPrint('⚠️ Found active delivery that was not being tracked: $deliveryId');
          await startTrackingDelivery(deliveryId);
        }
        return;
      }
      
      // Verify the delivery is still in progress
      try {
        final routeDoc = await _firestore.collection('delivery_routes').doc(_activeDeliveryId!).get();
        if (routeDoc.exists && routeDoc.data()?['status'] == 'in_progress') {
          // If tracking isn't active, restart it
          if (!_isTracking || _positionStream == null) {
            debugPrint('⚠️ Tracking watchdog: restarting tracking for active delivery');
            await startTrackingDelivery(_activeDeliveryId!);
          }
        } else {
          // If delivery is no longer in progress, stop tracking
          if (_isTracking) {
            debugPrint('Delivery is no longer in progress, stopping tracking');
            await stopTrackingDelivery();
          }
        }
      } catch (e) {
        debugPrint('Error in tracking watchdog: $e');
      }
    });
  }
  
  // Watchdog to check for location services availability
  void _startLocationServicesWatchdog() {
    // Check every 2 minutes for location services
    Timer.periodic(const Duration(minutes: 2), (_) async {
      try {
        // Only run recovery if we have an active delivery
        if (_activeDeliveryId == null) return;
        
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint('Location services still disabled');
          return;
        }
        
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          debugPrint('Location permissions still denied');
          return;
        }
        
        // If services are now available but tracking isn't active, restart
        if (!_isTracking && _activeDeliveryId != null) {
          debugPrint('🔄 Location services now available, restarting tracking');
          await startTrackingDelivery(_activeDeliveryId!);
        }
      } catch (e) {
        debugPrint('Error checking location services: $e');
      }
    });
  }
  
  // Save active delivery ID to preferences for recovery
  Future<void> _saveActiveDelivery(String deliveryId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_delivery_id', deliveryId);
      await prefs.setBool('is_tracking_active', true);
      await prefs.setInt('last_tracking_timestamp', DateTime.now().millisecondsSinceEpoch);
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
          debugPrint('🔄 Recovering active delivery tracking: $deliveryId');
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
      
      // First try to find deliveries where this user is explicitly the driver
      final snapshot = await _firestore
          .collection('delivery_routes')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'in_progress')
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final deliveryId = snapshot.docs.first.id;
        debugPrint('Found active delivery for driver: $deliveryId');
        return deliveryId;
      }
      
      // If not found, check if this user is assigned to any active deliveries
      // by using a "currentDriver" field that might be different from the original driver
      final assignedSnapshot = await _firestore
          .collection('delivery_routes')
          .where('currentDriver', isEqualTo: user.uid)
          .where('status', isEqualTo: 'in_progress')
          .limit(1)
          .get();
          
      if (assignedSnapshot.docs.isNotEmpty) {
        final deliveryId = assignedSnapshot.docs.first.id;
        debugPrint('Found active delivery for assigned current driver: $deliveryId');
        return deliveryId;
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
    _trackingWatchdog?.cancel();
    _locationRetryTimer?.cancel();
    super.dispose();
  }
}