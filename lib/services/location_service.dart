import 'dart:async';
import 'dart:math' as math;
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
  Timer? _backgroundFetchTimer;

  // For faster updates and optimized performance
  final int _uiUpdateIntervalMs = 100; // Very frequent UI refresh (100ms)
// Update Firebase every 1 second (was 3000)
  final int _backgroundFetchIntervalMs =
      3000; // Fetch position even if stream fails

  // Position prediction for smoother tracking
  Position? _lastValidPosition;
  double _currentSpeed = 0.0; // in m/s
  double _currentHeading = 0.0; // in degrees
  DateTime? _lastPositionTimestamp;

  // Enhanced error handling and recovery
  int _errorCount = 0;
  bool _isRecovering = false;
  bool _useHighAccuracy = true;
  bool _hasFrontendObservers = false;

  // Expose read-only properties
  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  String? get activeDeliveryId => _activeDeliveryId;
  double get currentSpeed => _currentSpeed;
  double get currentHeading => _currentHeading;

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

  // Register front-end observers to optimize performance
  void registerFrontendObserver() {
    _hasFrontendObservers = true;
    notifyListeners(); // Initial notification
  }

  void unregisterFrontendObserver() {
    _hasFrontendObservers = false;
  }

  // Start tracking location for a delivery with enhanced performance
  Future<bool> startTrackingDelivery(String deliveryId) async {
    try {
      await stopTrackingDelivery(completed: false, clearDeliveryId: false);

      final routeDoc =
          await _firestore.collection('delivery_routes').doc(deliveryId).get();
      if (!routeDoc.exists) {
        debugPrint('Delivery route not found: $deliveryId');
        return false;
      }

      _activeDeliveryId = deliveryId;
      _isTracking = true;
      _errorCount = 0;
// Reset last update time

      // Update delivery status to in_progress if it's not already
      if (routeDoc.data()?['status'] != 'in_progress') {
        await _deliveryService.updateRouteStatus(deliveryId, 'in_progress');
      }

      // Start with high accuracy to get precise initial position
      _useHighAccuracy = true;
      debugPrint('Getting initial position for delivery tracking...');

      // Try to get current position with high accuracy first
      try {
        _currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );

        // Save last valid position and timestamp
        _lastValidPosition = _currentPosition;
        _lastPositionTimestamp = DateTime.now();

        // Extract speed and heading or set defaults
        _currentSpeed = _currentPosition!.speed > 0
            ? _currentPosition!.speed
            : 4.0; // ~9mph default
        _currentHeading =
            _currentPosition!.heading >= 0 ? _currentPosition!.heading : 0.0;

        // Update initial position immediately
        await _updatePosition(_currentPosition!, forceUpdate: true);
      } catch (e) {
        debugPrint('Error getting current position, trying last known: $e');
        final lastKnownPosition = await Geolocator.getLastKnownPosition();
        if (lastKnownPosition != null) {
          _currentPosition = lastKnownPosition;
          _lastValidPosition = lastKnownPosition;
          _lastPositionTimestamp = DateTime.now();
          await _updatePosition(_currentPosition!, forceUpdate: true);
        }
      }

      // Start position stream with optimized settings
      _startPositionStream();

      // Also start the background position fetching as a fallback
      _startBackgroundPositionFetching();

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

  // Start position stream with optimal settings for tracking
  void _startPositionStream() {
    _positionStream?.cancel();

    final accuracy =
        _useHighAccuracy ? LocationAccuracy.high : LocationAccuracy.medium;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: 2, // Update every 2 meters
        timeLimit: const Duration(seconds: 5),
      ),
    ).listen(_onPositionUpdate, onError: _handlePositionError);

    debugPrint('Started position stream with accuracy: $accuracy');
  }

  // Start background position fetching as a fallback
  void _startBackgroundPositionFetching() {
    _backgroundFetchTimer?.cancel();

    _backgroundFetchTimer = Timer.periodic(
      Duration(milliseconds: _backgroundFetchIntervalMs),
      (_) async {
        // Only fetch if we're actively tracking
        if (!_isTracking || _activeDeliveryId == null) return;

        // If the stream hasn't provided updates recently, try direct fetching
        if (_lastPositionTimestamp != null) {
          final timeSinceLastUpdate =
              DateTime.now().difference(_lastPositionTimestamp!);
          if (timeSinceLastUpdate.inSeconds >= 5) {
            try {
              final position = await Geolocator.getCurrentPosition(
                locationSettings: LocationSettings(
                  accuracy: _useHighAccuracy
                      ? LocationAccuracy.high
                      : LocationAccuracy.low,
                  timeLimit: const Duration(seconds: 3),
                ),
              );

              _onPositionUpdate(position);
              debugPrint('✅ Background position fetch successful');
            } catch (e) {
              debugPrint('❌ Error in background position fetch: $e');

              // Try with lower accuracy if we keep failing
              if (_errorCount > 2 && _useHighAccuracy) {
                _useHighAccuracy = false;
                _startPositionStream(); // Restart stream with lower accuracy
                debugPrint('⚠️ Switched to lower accuracy tracking');
              }
            }
          }
        }
      },
    );
  }

  // Handle position stream errors
  void _handlePositionError(dynamic error) {
    debugPrint('❌ Position stream error: $error');
    _handleTrackingError();
  }

  // Handle general tracking errors with improved recovery logic
  void _handleTrackingError() {
    _errorCount++;

    // Quick recovery for first few errors
    if (_errorCount <= 2) {
      // Just retry the position stream with current settings
      _startPositionStream();
      return;
    }

    // If we're having persistent issues and using high accuracy, switch to balanced
    if (_errorCount >= 3 && _useHighAccuracy) {
      _useHighAccuracy = false;
      _startPositionStream();
      debugPrint('⚠️ Reduced location accuracy due to errors');
      return;
    }

    // More serious recovery needed
    if (_errorCount >= 5 && !_isRecovering) {
      _isRecovering = true;

      // Cancel existing retry timer
      _locationRetryTimer?.cancel();

      // Schedule recovery attempt
      _locationRetryTimer = Timer(const Duration(seconds: 3), () async {
        debugPrint('🔄 Attempting to recover tracking...');
        if (_activeDeliveryId != null) {
          // Full restart of tracking
          await stopTrackingDelivery(completed: false, clearDeliveryId: false);
          await startTrackingDelivery(_activeDeliveryId!);
        }
        _isRecovering = false;
      });
    }

    // If error count is extremely high, try to use last known position
    if (_errorCount >= 10 && _lastValidPosition != null) {
      // Create a slightly modified position to show movement
      _createEstimatedPosition();
    }
  }

  // Create an estimated position when real updates fail
  void _createEstimatedPosition() {
     debugPrint('⚠️ Position estimation disabled to prevent drift');
  return;
   
  }

  // Stop tracking location
  Future<void> stopTrackingDelivery(
      {bool completed = false, bool clearDeliveryId = true}) async {
    try {
      _isTracking = false;

      await _positionStream?.cancel();
      _positionStream = null;

      _updateTimer?.cancel();
      _updateTimer = null;

      _backgroundFetchTimer?.cancel();
      _backgroundFetchTimer = null;

      _locationRetryTimer?.cancel();

      // Mark delivery as completed if requested
      if (completed && _activeDeliveryId != null) {
        await _deliveryService.updateRouteStatus(
            _activeDeliveryId!, 'completed');
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

  // Handler for position updates with enhanced processing
 void _onPositionUpdate(Position position, {bool isEstimated = false}) async {
  if (!_isTracking || _activeDeliveryId == null) return;
  
  // Only perform basic range validation
  if (position.latitude < -90 || position.latitude > 90 ||
      position.longitude < -180 || position.longitude > 180) {
    debugPrint('⚠️ Position outside valid range, ignoring');
    return;
  }
  
  // Update tracking data
  _lastValidPosition = position;
  _lastPositionTimestamp = DateTime.now();
  _currentPosition = position;
  
  // Process speed and heading
  if (position.heading >= 0) {
    _currentHeading = position.heading;
  }
  
  if (position.speed > 0) {
    _currentSpeed = position.speed;
  }
  
  // Always notify listeners for UI updates
  notifyListeners();
  
  // ALWAYS update Firebase immediately with every position change
  await _updatePosition(position, forceUpdate: true);
  
  debugPrint('📍 Position updated: ${position.latitude}, ${position.longitude}');
}

  // Validate position data to ensure it's reasonable

  // Process speed and heading from position data

  // Update position in Firestore
  Future<void> _updatePosition(Position position, {bool forceUpdate = false}) async {
  if (_activeDeliveryId == null) return;
  
  try {
    // Skip updates if we're not actively tracking unless forced
    if (!_isTracking && !forceUpdate) return;
    
    // Convert position to GeoPoint
    final location = GeoPoint(position.latitude, position.longitude);
    
    // Use processed speed and heading values
    double speed = _currentSpeed;
    double heading = _currentHeading;
    
    // Always update delivery route with new location
    await _deliveryService.updateDriverLocation(
      _activeDeliveryId!,
      location,
      heading: heading,
      speed: speed,
    );
    
    debugPrint('📍 Firestore position updated: ${position.latitude}, ${position.longitude}');
  } catch (e) {
    debugPrint('❌ Error updating position: $e');
  }
}

  // Start very frequent UI updates
  void _startFrequentUpdates() {
    _updateTimer?.cancel();

    // Update UI very frequently for smooth animation
    _updateTimer =
        Timer.periodic(Duration(milliseconds: _uiUpdateIntervalMs), (_) async {
      if (_activeDeliveryId == null || !_isTracking || !_hasFrontendObservers) {
        return;
      }

      // Simply notify listeners to refresh UI with current position
      notifyListeners();
    });
  }

  // Watchdog to ensure tracking stays active for in-progress deliveries
  void _startTrackingWatchdog() {
    _trackingWatchdog?.cancel();

    // Check every 20 seconds that tracking is active
    _trackingWatchdog = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (_activeDeliveryId == null) {
        // Check if there's an active delivery we should be tracking
        final deliveryId = await checkForActiveDelivery();
        if (deliveryId != null) {
          debugPrint(
              '⚠️ Found active delivery that was not being tracked: $deliveryId');
          await startTrackingDelivery(deliveryId);
        }
        return;
      }

      // Verify the delivery is still in progress
      try {
        final routeDoc = await _firestore
            .collection('delivery_routes')
            .doc(_activeDeliveryId!)
            .get();
        if (routeDoc.exists && routeDoc.data()?['status'] == 'in_progress') {
          // If tracking isn't active, restart it
          if (!_isTracking || _positionStream == null) {
            debugPrint(
                '⚠️ Tracking watchdog: restarting tracking for active delivery');
            await startTrackingDelivery(_activeDeliveryId!);
          }

          // If it's been too long since the last update, try background fetch
          if (_lastPositionTimestamp != null &&
              DateTime.now().difference(_lastPositionTimestamp!).inSeconds >
                  30) {
            try {
              final position = await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.medium,
                  timeLimit: Duration(seconds: 3),
                ),
              );

              _onPositionUpdate(position);
              debugPrint('✅ Watchdog triggered position update');
            } catch (e) {
              debugPrint('❌ Watchdog position update failed: $e');
            }
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
    // Check every 1 minute for location services
    Timer.periodic(const Duration(minutes: 1), (_) async {
      try {
        // Only run recovery if we have an active delivery
        if (_activeDeliveryId == null) return;

        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint('Location services still disabled');
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
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
      await prefs.setInt(
          'last_tracking_timestamp', DateTime.now().millisecondsSinceEpoch);
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
      final lastTimestamp = prefs.getInt('last_tracking_timestamp');

      if (deliveryId != null && isActive) {
        // Check if delivery is still in progress and not too old (within last 3 hours)
        final isRecent = lastTimestamp != null &&
            DateTime.now().millisecondsSinceEpoch - lastTimestamp <
                3 * 60 * 60 * 1000;

        if (isRecent) {
          final doc = await _firestore
              .collection('delivery_routes')
              .doc(deliveryId)
              .get();
          if (doc.exists && doc.data()?['status'] == 'in_progress') {
            debugPrint('🔄 Recovering active delivery tracking: $deliveryId');
            // Resume tracking
            await startTrackingDelivery(deliveryId);
          } else {
            // Clear saved delivery if it's no longer active
            await _clearActiveDelivery();
          }
        } else {
          // Clear saved delivery if it's too old
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
        debugPrint(
            'Found active delivery for assigned current driver: $deliveryId');
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
    _backgroundFetchTimer?.cancel();
    super.dispose();
  }
}

// Math helpers for position calculations
class Math {
  static double sin(double rad) => math.sin(rad);
  static double cos(double rad) => math.cos(rad);
}
