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
      
      // Update delivery status to in_progress if it's not already
      if (routeDoc.data()?['status'] != 'in_progress') {
        await _deliveryService.updateRouteStatus(deliveryId, 'in_progress');
      }
      
      // Get current position first with high accuracy
      debugPrint('Getting initial position for delivery tracking...');
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      
      // Update initial position immediately
      await _updatePosition(_currentPosition!, forceUpdate: true);
      
      // Start position stream with optimized settings
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters of movement
          timeLimit: Duration(seconds: 15),
        ),
      ).listen(_onPositionUpdate, onError: _handlePositionError);
      
      // Save active delivery to preferences for recovery
      await _saveActiveDelivery(deliveryId);
      
      // Start periodic updates for background tracking
      _startPeriodicUpdates();
      
      // Ensure watchdog is running
      _startTrackingWatchdog();
      
      debugPrint('🚚 Started tracking delivery: $deliveryId');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error starting location tracking: $e');
      // Don't clear the active delivery ID if we had an error - gives us a chance to recover
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
      
      // Schedule recovery attempt
      Future.delayed(const Duration(seconds: 15), () async {
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

  // Handler for position updates
  void _onPositionUpdate(Position position) async {
    // Reset error count on successful update
    _errorCount = 0;
    _currentPosition = position;
    
    // Update Firestore with new position
    await _updatePosition(position);
    
    notifyListeners();
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
      // Standard GPS speed is in m/s, but it can sometimes be unreliable
      // So we calculate a more accurate speed based on consecutive positions
      double? speed = position.speed;
      
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
  
  // Start periodic background updates
  void _startPeriodicUpdates() {
    _updateTimer?.cancel();
    
    // Update every 30 seconds even if position hasn't changed significantly
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_activeDeliveryId == null) return;
      
      // Force tracking to be active for in-progress deliveries
      if (!_isTracking) {
        final routeDoc = await _firestore.collection('delivery_routes').doc(_activeDeliveryId!).get();
        if (routeDoc.exists && routeDoc.data()?['status'] == 'in_progress') {
          debugPrint('⚠️ Delivery is in progress but tracking was inactive - restarting tracking');
          await startTrackingDelivery(_activeDeliveryId!);
          return;
        }
      }
      
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        
        _currentPosition = position;
        await _updatePosition(position, forceUpdate: true);
        notifyListeners();
      } catch (e) {
        debugPrint('Error in periodic update: $e');
        _handleTrackingError();
      }
    });
  }
  
  // Watchdog to ensure tracking stays active for in-progress deliveries
  void _startTrackingWatchdog() {
    _trackingWatchdog?.cancel();
    
    // Check every 2 minutes that tracking is active for in-progress deliveries
    _trackingWatchdog = Timer.periodic(const Duration(minutes: 2), (_) async {
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
      
      final snapshot = await _firestore
          .collection('delivery_routes')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'in_progress')
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final deliveryId = snapshot.docs.first.id;
        debugPrint('Found active delivery: $deliveryId');
        return deliveryId;
      }
      return null;
    } catch (e) {
      debugPrint('Error checking for active deliveries: $e');
      return null;
    }
  }
  
  // Get current progress of the active delivery
  Future<double> getDeliveryProgress() async {
    if (_activeDeliveryId == null) return 0.0;
    
    try {
      final doc = await _firestore.collection('delivery_routes').doc(_activeDeliveryId!).get();
      if (!doc.exists) return 0.0;
      
      final data = doc.data()!;
      
      // If there's a precalculated progress value, use it
      if (data['metadata'] != null && 
          data['metadata']['routeDetails'] != null && 
          data['metadata']['routeDetails']['progress'] != null) {
        return (data['metadata']['routeDetails']['progress'] as num).toDouble();
      }
      
      // Otherwise estimate based on remaining distance vs total
      if (data['metadata'] != null && 
          data['metadata']['routeDetails'] != null) {
        final remainingDistance = data['metadata']['routeDetails']['remainingDistance'];
        final totalDistance = data['metadata']['routeDetails']['totalDistance'];
        
        if (remainingDistance != null && totalDistance != null) {
          final progress = 1.0 - (remainingDistance / totalDistance);
          return progress.clamp(0.0, 1.0);
        }
      }
      
      // If we can't calculate, return 0 for pending or 0.5 for in progress
      return data['status'] == 'in_progress' ? 0.5 : 0.0;
    } catch (e) {
      debugPrint('Error getting delivery progress: $e');
      return _isTracking ? 0.5 : 0.0; // Default to 50% if tracking active
    }
  }
  
  @override
  void dispose() {
    _positionStream?.cancel();
    _updateTimer?.cancel();
    _trackingWatchdog?.cancel();
    super.dispose();
  }
}