import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cateredtoyou/models/delivery_route_model.dart';
import 'package:cateredtoyou/views/delivery/widgets/delivery_map.dart';
import 'package:cateredtoyou/views/delivery/widgets/delivery_info_card.dart';
import 'package:cateredtoyou/views/delivery/widgets/driver_contact_sheet.dart';
import 'package:cateredtoyou/views/delivery/widgets/reassign_driver_dialog.dart';
import 'package:cateredtoyou/utils/permission_helpers.dart';
import 'package:cateredtoyou/services/delivery_route_service.dart';
import 'package:cateredtoyou/services/location_service.dart';

class DragController {
  double dragStart = 0.0;
  double initialHeight = 120.0; // Min panel height
  double currentHeight = 120.0;

  void startDrag(DragStartDetails details) {
    dragStart = details.globalPosition.dy;
    initialHeight = currentHeight;
  }

  void updateDrag(DragUpdateDetails details) {
    final delta = dragStart - details.globalPosition.dy;
    currentHeight = (initialHeight + delta).clamp(120.0, 500.0);
  }

  void endDrag(DragEndDetails details) {
    // Snap to min or max height based on velocity and current position
    if (details.velocity.pixelsPerSecond.dy.abs() > 200) {
      // Fast drag
      currentHeight = details.velocity.pixelsPerSecond.dy > 0 ? 120.0 : 500.0;
    } else {
      // Slow drag - snap to nearest
      currentHeight = currentHeight > (120.0 + 500.0) / 2 ? 500.0 : 120.0;
    }
  }
}

class TrackDeliveryScreen extends StatefulWidget {
  final DeliveryRoute route;

  const TrackDeliveryScreen({
    super.key,
    required this.route,
  });

  @override
  State<TrackDeliveryScreen> createState() => _TrackDeliveryScreenState();
}

class _TrackDeliveryScreenState extends State<TrackDeliveryScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late StreamSubscription<DocumentSnapshot> _routeSubscription;
  final MapController _mapController = MapController();

  DeliveryRoute? _currentRoute;
  List<LatLng> _routePoints = [];
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  final List<LatLng> _recentPositions = [];

  bool _isLoading = true;
  Timer? _routeUpdateTimer;
  bool _isFirstLoad = true;
  bool _isInfoExpanded = false; // Track if info panel is expanded
  bool _isManagementUser = false;
  bool _isActiveDriver = false;

  // Action feedback states
  bool _isProcessingAction = false;
  String? _actionFeedback;
  bool _isActionSuccess = false;

  // Location tracking status variables
  bool _isUpdatingLocation = false;
  bool _locationUpdatedRecently = false;
  String _lastUpdateTime = '';
  DateTime? _lastLocationUpdateTime;

  // Enhanced animation variables
  LatLng? _animatedDriverPosition;
  LatLng? _previousDriverPosition;
  AnimationController? _animationController;
  Timer? _predictionTimer;
  Timer? _visualRefreshTimer;

  // Pulse animation for marker
  AnimationController? _pulseController;

  // Panel controller animation
  AnimationController? _panelController;

  // Constants
  static const String osmRoutingUrl =
      'https://router.project-osrm.org/route/v1/driving/';
  static const double _defaultZoom = 13.0;
  static const int _maxRecentPositions = 10;
  static const double _minPanelHeight = 120.0; // collapsed height
  static const double _maxPanelHeight = 500.0; // expanded height

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentRoute = widget.route;

    // Set up animation controllers
    _setupAnimationControllers();

    // Immediately calculate and populate route metrics for initial view
    _calculateRouteMetrics(widget.route);

    _setupRouteSubscription();
    _fetchRouteDetails();
    _setupRefreshTimer();
    _checkUserPermissions();

    // Start predictive updates immediately
    _startPredictiveUpdates();
  }

  void _setupAnimationControllers() {
    // Main animation controller for position transitions
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Pulse animation for recently updated position
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Panel slide animation
    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Listen to animation updates to refresh the UI
    _animationController!.addListener(() {
      if (mounted) {
        setState(() {
          // Calculate the animated position based on animation progress
          _updateAnimatedPosition();
        });
      }
    });

    _pulseController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController!.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _pulseController!.forward();
      }
    });

    // Start pulse animation
    _pulseController!.forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeSubscription.cancel();
    _routeUpdateTimer?.cancel();
    _predictionTimer?.cancel();
    _visualRefreshTimer?.cancel();
    _animationController?.dispose();
    _pulseController?.dispose();
    _panelController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app resumes, refresh data and restart animations
    if (state == AppLifecycleState.resumed) {
      _refreshData();

      // Restart animation controllers if needed
      if (_animationController?.isAnimating == false) {
        _animationController?.reset();
      }

      if (_pulseController?.isAnimating == false) {
        _pulseController?.forward();
      }
    }
  }

  // Start predictive updates for smoother animation
  void _startPredictiveUpdates() {
    _predictionTimer?.cancel();
    return;
  }

  // Update trail positions for visual effect
  void _updateTrailPositions(LatLng newPosition) {
    _recentPositions.add(newPosition);
    if (_recentPositions.length > _maxRecentPositions) {
      _recentPositions.removeAt(0);
    }
  }

  // Manual refresh function
  Future<void> _refreshData() async {
    if (_currentRoute == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Force a refresh by directly fetching the document
      final docSnapshot = await FirebaseFirestore.instance
          .collection('delivery_routes')
          .doc(_currentRoute!.id)
          .get();

      if (docSnapshot.exists) {
        await _handleRouteUpdate(docSnapshot);
      }

      // Also re-fetch route details
      await _fetchRouteDetails();
      await _checkUserPermissions();
    } catch (e) {
      debugPrint('Error refreshing data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkUserPermissions() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() {
        _isManagementUser = false;
        _isActiveDriver = false;
      });
      return;
    }

    final isManager = await isManagementUser(context);
    final isDriver = userId == _currentRoute?.currentDriver ||
        userId == _currentRoute?.driverId;

    if (mounted) {
      setState(() {
        _isManagementUser = isManager;
        _isActiveDriver = isDriver;
      });
    }
  }

  void _setupRouteSubscription() {
    _routeSubscription = FirebaseFirestore.instance
        .collection('delivery_routes')
        .doc(widget.route.id)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        _handleRouteUpdate(snapshot);
      }
    }, onError: (error) {
      debugPrint('Error in route subscription: $error');
      _showSnackBar('Error getting updates. Pull down to refresh.',
          isError: true);
    });
  }

  void _setupRefreshTimer() {
    // Main update timer for data refresh - every 15 seconds
    _routeUpdateTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _updateDeliveryMetrics(),
    );

    // Visual refresh timer for smoother animations - every 100ms for fluid updates
    _visualRefreshTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) {
        if (mounted && _currentRoute?.status == 'in_progress') {
          // Force map marker refresh for smooth animation
          _updateMapMarkers();
          setState(() {});
        }
      },
    );
  }

  Future<void> _calculateRouteMetrics(DeliveryRoute route) async {
    // Only calculate metrics if they don't already exist
    if (route.metadata == null ||
        route.metadata!['routeDetails'] == null ||
        route.metadata!['routeDetails']['totalDistance'] == null) {
      try {
        // Calculate total route distance and estimated journey time
        final totalDistance =
            await _calculateTotalRouteDistance(route.waypoints);

        // Simple estimation of journey time (assuming 30 mph average)
        final averageSpeedMps = 13.4; // 30 mph in meters per second
        final estimatedDuration = (totalDistance / averageSpeedMps).round();

        // If route hasn't started yet, update its metadata with calculations
        if (route.status == 'pending') {
          await FirebaseFirestore.instance
              .collection('delivery_routes')
              .doc(route.id)
              .update({
            'metadata.routeDetails.totalDistance': totalDistance,
            'metadata.routeDetails.estimatedDuration': estimatedDuration,
            'metadata.routeDetails.lastCalculated':
                FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        debugPrint('Error calculating initial route metrics: $e');
      }
    }
  }

  Future<double> _calculateTotalRouteDistance(List<GeoPoint> waypoints) async {
    if (waypoints.length < 2) return 0;

    try {
      double totalDistance = 0;

      // Try to get accurate distance via routing API
      for (int i = 0; i < waypoints.length - 1; i++) {
        final startPoint = waypoints[i];
        final endPoint = waypoints[i + 1];

        final url =
            '$osmRoutingUrl${startPoint.longitude},${startPoint.latitude};'
            '${endPoint.longitude},${endPoint.latitude}?overview=false';

        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['code'] == 'Ok') {
            totalDistance += data['routes'][0]['distance'] as num;
          } else {
            // Fallback to straight-line distance if routing fails
            totalDistance += _calculateStraightLineDistance(
                    startPoint.latitude,
                    startPoint.longitude,
                    endPoint.latitude,
                    endPoint.longitude) *
                1000; // Convert km to meters
          }
        } else {
          // Fallback to straight-line distance if API request fails
          totalDistance += _calculateStraightLineDistance(startPoint.latitude,
                  startPoint.longitude, endPoint.latitude, endPoint.longitude) *
              1000; // Convert km to meters
        }
      }

      return totalDistance;
    } catch (e) {
      debugPrint('Error calculating total route distance: $e');

      // Fallback to simple distance calculation
      double totalDistance = 0;
      for (int i = 0; i < waypoints.length - 1; i++) {
        final startPoint = waypoints[i];
        final endPoint = waypoints[i + 1];

        totalDistance += _calculateStraightLineDistance(startPoint.latitude,
                startPoint.longitude, endPoint.latitude, endPoint.longitude) *
            1000; // Convert km to meters
      }

      return totalDistance;
    }
  }

  double _calculateStraightLineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371.0; // Earth's radius in kilometers

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  double sin(double rad) => math.sin(rad);
  double cos(double rad) => math.cos(rad);
  double atan2(double y, double x) => math.atan2(y, x);
  double sqrt(double value) => value <= 0 ? 0 : math.sqrt(value);

  Future<void> _handleRouteUpdate(DocumentSnapshot snapshot) async {
    if (!mounted || !snapshot.exists) return;

    try {
      setState(() => _isUpdatingLocation = true);

      // Safely parse the document data with null safety checks
      final data = snapshot.data() as Map<String, dynamic>;
      final Map<String, dynamic> safeData = Map.from(data);

      // Handle potentially null Timestamp fields safely
      if (safeData['createdAt'] == null) {
        safeData['createdAt'] = Timestamp.now();
      }
      if (safeData['updatedAt'] == null) {
        safeData['updatedAt'] = Timestamp.now();
      }
      if (safeData['startTime'] == null) {
        safeData['startTime'] = Timestamp.now();
      }
      if (safeData['estimatedEndTime'] == null) {
        safeData['estimatedEndTime'] = Timestamp.now();
      }

      // Create route object with the sanitized data
      final newRoute = DeliveryRoute.fromMap(safeData, snapshot.id);

      // Check if the status changed
      final statusChanged = _currentRoute?.status != newRoute.status;
      if (statusChanged && newRoute.status == 'completed') {
        _showSnackBar('Delivery completed successfully!', isError: false);

        // If delivery is completed, check if we need to update permissions
        await _checkUserPermissions();
      }

      final locationChanged = newRoute.currentLocation?.latitude !=
              _currentRoute?.currentLocation?.latitude ||
          newRoute.currentLocation?.longitude !=
              _currentRoute?.currentLocation?.longitude;

      if (locationChanged && newRoute.currentLocation != null) {
        // Location was updated - update the tracking indicators
        _lastLocationUpdateTime = DateTime.now();
        _locationUpdatedRecently = true;
        _lastUpdateTime =
            DateFormat('h:mm:ss a').format(_lastLocationUpdateTime!);

        // Save previous position for animation
        if (_currentRoute?.currentLocation != null) {
          _previousDriverPosition = LatLng(
            _currentRoute!.currentLocation!.latitude,
            _currentRoute!.currentLocation!.longitude,
          );
        }

        // Setup enhanced animation
        _setupEnhancedAnimation(
            _previousDriverPosition,
            LatLng(
              newRoute.currentLocation!.latitude,
              newRoute.currentLocation!.longitude,
            ));

        // Reset "recently updated" after 10 seconds
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) {
            setState(() {
              _locationUpdatedRecently = false;
            });
          }
        });

        // Update route details and ETA based on new location
        try {
          await _calculateUpdatedETA(newRoute);
        } catch (e) {
          debugPrint('Error calculating ETA: $e');
        }
      }

      // Check if we need to update permission states
      if (_currentRoute?.currentDriver != newRoute.currentDriver) {
        await _checkUserPermissions();
      }

      setState(() {
        _currentRoute = newRoute;
        _isLoading = false;
        _isUpdatingLocation = false;
      });

      _updateDeliveryMetrics();

      // Only recalculate route if location changed significantly
      if (locationChanged && newRoute.currentLocation != null) {
        await _fetchRouteDetails();
      }

      _updateMapMarkers();

      // If this is a new delivery that just started, fit map to show route
      if (_isFirstLoad) {
        _isFirstLoad = false;
        _performInitialMapPreview();
      } else if (locationChanged && _currentRoute?.status == 'in_progress') {
        // Center on driver for significant location changes
        if (!_animationController!.isAnimating) {
          _centerOnDriver();
        }
      }
    } catch (e) {
      debugPrint('Error processing route update: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUpdatingLocation = false;
        });
      }
    }
  }

  void _setupEnhancedAnimation(LatLng? oldPosition, LatLng newPosition) {
    // If no previous position, just set directly
    if (oldPosition == null) {
      _animatedDriverPosition = newPosition;
      _updateTrailPositions(newPosition);
      return;
    }

    // Reset animation controller to prevent continuous animations
    _animationController?.reset();

    // Turn off pulse effect - can cause issues with position display
    _pulseController?.reset();
    _pulseController?.stop();

    // Set position directly instead of animating (prevents drift)
    _animatedDriverPosition = newPosition;
    _previousDriverPosition = newPosition;

    // Add position to trail immediately
    _updateTrailPositions(newPosition);

    // Update markers immediately
    _updateMapMarkers();

    debugPrint(
        '📍 Position set directly: ${newPosition.latitude}, ${newPosition.longitude}');
  }

  // Update animated position based on animation progress
  void _updateAnimatedPosition() {
    // Directly use current location to prevent drift
    if (_currentRoute?.currentLocation != null) {
      _animatedDriverPosition = LatLng(
        _currentRoute!.currentLocation!.latitude,
        _currentRoute!.currentLocation!.longitude,
      );
    }
  }

  Future<void> _calculateUpdatedETA(DeliveryRoute route) async {
    if (route.currentLocation == null || route.waypoints.isEmpty) return;

    try {
      final currentLoc = route.currentLocation!;
      final destination = route.waypoints.last;

      // Get route details from OSRM API
      final url =
          '$osmRoutingUrl${currentLoc.longitude},${currentLoc.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=false';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok') {
          // Get remaining distance in meters
          final remainingDistance = data['routes'][0]['distance'] as num;

          // Get remaining duration in seconds (accounting for traffic with a 1.2 multiplier)
          final baseDuration = data['routes'][0]['duration'] as num;
          // Ensure baseDuration is not zero to avoid division by zero
          final safeDuration = baseDuration > 0 ? baseDuration : 60;
          final trafficMultiplier = 1.2;
          final remainingDuration = (safeDuration * trafficMultiplier).round();

          // Calculate new ETA
          final now = DateTime.now();
          final newETA = now.add(Duration(seconds: remainingDuration));

          // Ensure ETA is never earlier than "now + 1 minute" to prevent negative times
          final minETA = now.add(const Duration(minutes: 1));
          final finalETA = newETA.isBefore(minETA) ? minETA : newETA;

          // Calculate speed in meters per second (use current speed if available or estimate from route)
          // Avoid division by zero by checking baseDuration
          final currentSpeed = route.metadata?['currentSpeed'] as num? ??
              (remainingDistance / safeDuration);

          // Calculate progress percentage
          double progress = 0.0;

          // Try to get total distance from metadata or calculate it
          final totalDistance =
              route.metadata?['routeDetails']?['totalDistance'] as num?;

          if (totalDistance != null && totalDistance > 0) {
            // Safe progress calculation
            final rawProgress = 1.0 - (remainingDistance / totalDistance);
            // Check for valid numerical values to avoid NaN/Infinity
            progress = rawProgress.isFinite && !rawProgress.isNaN
                ? rawProgress.clamp(0.0, 1.0)
                : 0.5;
          } else {
            // Fallback to basic calculation - assume we're halfway
            progress = 0.5;
          }

          // Update Firestore with new calculations
          await FirebaseFirestore.instance
              .collection('delivery_routes')
              .doc(route.id)
              .update({
            'estimatedEndTime': Timestamp.fromDate(finalETA),
            'metadata.routeDetails.remainingDistance': remainingDistance,
            'metadata.routeDetails.remainingDuration': remainingDuration,
            'metadata.routeDetails.estimatedArrival':
                Timestamp.fromDate(finalETA),
            'metadata.routeDetails.progress': progress,
            'metadata.routeDetails.currentSpeed': currentSpeed,
            'metadata.routeDetails.lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint('Error updating ETA details: $e');
    }
  }

  void _updateDeliveryMetrics() {
    if (_currentRoute == null || !mounted) return;

    // For pending deliveries, we still want to calculate some basic metrics
    if (_currentRoute!.status == 'pending') {
      _updatePendingDeliveryMetrics();
    }

    // Update progress metrics if needed
    setState(() {});
  }

  void _updatePendingDeliveryMetrics() async {
    try {
      // Check if we need to calculate basic metrics
      if (_currentRoute!.metadata == null ||
          _currentRoute!.metadata!['routeDetails'] == null ||
          _currentRoute!.metadata!['routeDetails']['totalDistance'] == null) {
        // Calculate and update total route distance for pending deliveries
        await _calculateRouteMetrics(_currentRoute!);
      }
    } catch (e) {
      debugPrint('Error updating pending delivery metrics: $e');
    }
  }

  Future<void> _fetchRouteDetails() async {
    if (_currentRoute == null || _currentRoute!.waypoints.length < 2) return;

    try {
      // If driver is en route, use current location as start point for better accuracy
      List<GeoPoint> routePoints = [];

      if (_currentRoute!.status == 'in_progress' &&
          _currentRoute!.currentLocation != null) {
        routePoints = [
          _currentRoute!.currentLocation!,
          _currentRoute!.waypoints.last,
        ];
      } else {
        routePoints = _currentRoute!.waypoints;
      }

      final fetchedPoints = await _calculateRoutePoints(routePoints);

      if (mounted) {
        setState(() {
          _routePoints = fetchedPoints;
          _polylines = [
            MapMarkerHelper.createRoute(
              points: _routePoints,
              color: Theme.of(context).colorScheme.primary,
              width: 5.0,
            ),
          ];
        });
      }
    } catch (e) {
      debugPrint('Error fetching route details: $e');
    }
  }

  Future<List<LatLng>> _calculateRoutePoints(List<GeoPoint> points) async {
    if (points.length < 2) return [];

    try {
      final origin = points.first;
      final destination = points.last;

      final url = '$osmRoutingUrl${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=full&geometries=geojson&steps=true';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok') {
          final coordinates =
              data['routes'][0]['geometry']['coordinates'] as List;
          final routePoints = coordinates
              .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
              .toList();

          return routePoints;
        }
      }

      // If API fails, create a direct line between points
      return points
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
    } catch (e) {
      debugPrint('Error calculating route points: $e');
      // Fall back to direct line between points
      return points
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
    }
  }

  void _updateMapMarkers() {
    if (!mounted || _currentRoute == null) return;

    final markers = <Marker>[];

    // Add pickup marker
    if (_currentRoute!.waypoints.isNotEmpty) {
      markers.add(MapMarkerHelper.createMarker(
        point: LatLng(
          _currentRoute!.waypoints.first.latitude,
          _currentRoute!.waypoints.first.longitude,
        ),
        id: 'pickup',
        color: Colors.green,
        icon: Icons.store,
        title: 'Pickup',
      ));
    }

    // Add delivery marker
    if (_currentRoute!.waypoints.length > 1) {
      markers.add(MapMarkerHelper.createMarker(
        point: LatLng(
          _currentRoute!.waypoints.last.latitude,
          _currentRoute!.waypoints.last.longitude,
        ),
        id: 'delivery',
        color: Colors.red,
        icon: Icons.location_on,
        title: 'Delivery',
      ));
    }

    if (_currentRoute!.currentLocation != null) {
      final markerPos = LatLng(_currentRoute!.currentLocation!.latitude,
          _currentRoute!.currentLocation!.longitude);

      final heading = _currentRoute!.currentHeading ?? 0.0;

      markers.add(
        Marker(
          point: markerPos,
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Driver icon with proper rotation
              Transform.rotate(
                angle: heading * (math.pi / 180),
                child: Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha((0.8 * 255).toInt()),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.3 * 255).toInt()),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.navigation,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),

              // Label below
              Positioned(
                bottom: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.2 * 255).toInt()),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Driver',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  void _performInitialMapPreview() {
    if (_routePoints.isEmpty) return;

    // Add current position to points if available
    final pointsToShow = List<LatLng>.from(_routePoints);
    if (_currentRoute?.currentLocation != null) {
      final currentLoc = _currentRoute!.currentLocation!;
      pointsToShow.add(LatLng(currentLoc.latitude, currentLoc.longitude));
    }

    // Calculate bounds to fit all points
    final bounds = MapBoundsHelper.calculateBounds(pointsToShow);

    // Fit the map to show the entire route
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  void _centerOnDriver() {
    // Use animated position if available, otherwise use actual position
    if (_animatedDriverPosition != null) {
      _mapController.move(
        _animatedDriverPosition!,
        _defaultZoom,
      );
    } else if (_currentRoute?.currentLocation != null) {
      final location = _currentRoute!.currentLocation!;
      _mapController.move(
        LatLng(location.latitude, location.longitude),
        _defaultZoom,
      );
    }
  }

  void _showDriverContactSheet() {
    if (_currentRoute == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DriverContactSheet(
        driverId: (_currentRoute!.currentDriver != null &&
                _currentRoute!.currentDriver!.isNotEmpty)
            ? _currentRoute!.currentDriver!
            : _currentRoute!.driverId,
        onContactMethod: _handleContactMethod,
      ),
    );
  }

  Future<void> _handleContactMethod(String phone, String scheme) async {
    final uri = Uri(scheme: scheme, path: phone);
    if (!await launchUrl(uri)) {
      if (mounted) {
        _showSnackBar(
            'Could not ${scheme == 'tel' ? 'call' : 'message'} driver',
            isError: true);
      }
    }
  }

  // Helper to get Google Maps directions
  void _openGoogleMapsNavigation() async {
    if (_currentRoute == null || _currentRoute!.waypoints.length < 2) return;

    final destination = _currentRoute!.waypoints.last;
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}&travelmode=driving';

    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        _showSnackBar('Could not open navigation app', isError: true);
      }
    }
  }

  Future<void> _showReassignDialog() async {
    final result = await showDialog(
      context: context,
      builder: (context) => ReassignDriverDialog(route: _currentRoute!),
    );

    if (result == true) {
      // Driver was successfully reassigned, refresh data
      await _refreshData();
      await _checkUserPermissions();
    }
  }

  Future<void> _showDeleteDialog() async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this delivery?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isProcessingAction = true;
        _actionFeedback = 'Deleting delivery...';
      });

      try {
        final deliveryService =
            Provider.of<DeliveryRouteService>(context, listen: false);
        await deliveryService.cancelRoute(_currentRoute!.id,
            reason: reasonController.text);

        if (mounted) {
          setState(() {
            _isProcessingAction = false;
            _actionFeedback = 'Delivery deleted successfully';
            _isActionSuccess = true;
          });

          _showSnackBar('Delivery deleted', isError: false);

          // Pop back to previous screen after a short delay
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.of(context)
                  .pop(true); // Return true to indicate changes
            }
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isProcessingAction = false;
            _actionFeedback = 'Error: ${e.toString()}';
            _isActionSuccess = false;
          });

          _showSnackBar('Error: ${e.toString()}', isError: true);
        }
      }
    }
  }

  Future<void> _startDelivery() async {
    if (_isProcessingAction) return;

    setState(() {
      _isProcessingAction = true;
      _actionFeedback = 'Starting delivery...';
      _isActionSuccess = false;
    });

    try {
      final deliveryService =
          Provider.of<DeliveryRouteService>(context, listen: false);
      final locationService =
          Provider.of<LocationService>(context, listen: false);

      // Update status in Firestore
      await deliveryService.updateRouteStatus(_currentRoute!.id, 'in_progress');

      // Start location tracking
      await locationService.startTrackingDelivery(_currentRoute!.id);

      if (mounted) {
        setState(() {
          _isProcessingAction = false;
          _actionFeedback = 'Delivery started successfully';
          _isActionSuccess = true;
        });

        _showSnackBar('Delivery started successfully', isError: false);

        // Force refresh
        await _refreshData();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
          _actionFeedback = 'Error: ${e.toString()}';
          _isActionSuccess = false;
        });

        _showSnackBar('Error starting delivery: $e', isError: true);
      }
    }
  }

  Future<void> _completeDelivery() async {
    if (_isProcessingAction) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Delivery'),
        content: const Text(
            'Are you sure you want to mark this delivery as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isProcessingAction = true;
      _actionFeedback = 'Completing delivery...';
      _isActionSuccess = false;
    });

    try {
      final deliveryService =
          Provider.of<DeliveryRouteService>(context, listen: false);
      final locationService =
          Provider.of<LocationService>(context, listen: false);

      // Update status in Firestore
      await deliveryService.updateRouteStatus(_currentRoute!.id, 'completed');

      // Stop location tracking
      if (locationService.activeDeliveryId == _currentRoute!.id) {
        await locationService.stopTrackingDelivery(completed: true);
      }

      if (mounted) {
        setState(() {
          _isProcessingAction = false;
          _actionFeedback = 'Delivery completed successfully';
          _isActionSuccess = true;
        });

        _showSnackBar('Delivery completed successfully', isError: false);

        // Force refresh
        await _refreshData();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
          _actionFeedback = 'Error: ${e.toString()}';
          _isActionSuccess = false;
        });

        _showSnackBar('Error completing delivery: $e', isError: true);
      }
    }
  }

  void _toggleInfoPanel() {
    setState(() {
      _isInfoExpanded = !_isInfoExpanded;
      if (_isInfoExpanded) {
        _panelController?.forward();
      } else {
        _panelController?.reverse();
      }
    });
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // Build the expandable mini status card for the collapsed state
  Widget _buildMiniStatusCard() {
    if (_currentRoute == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final status = _currentRoute!.status;

    // Get status color
    Color statusColor;
    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'in_progress':
        statusColor = Colors.blue;
        break;
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    // Format ETA
    final etaText =
        DateFormat('h:mm a').format(_currentRoute!.estimatedEndTime);

    // Get remaining time
    String remainingTime = '';
    if (status == 'in_progress') {
      final now = DateTime.now();
      final difference = _currentRoute!.estimatedEndTime.difference(now);

      if (difference.isNegative) {
        remainingTime = 'Delayed';
      } else if (difference.inHours > 0) {
        remainingTime =
            '${difference.inHours}h ${difference.inMinutes.remainder(60)}m';
      } else {
        remainingTime = '${difference.inMinutes}m';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).toInt()),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pull handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha((0.3 * 255).toInt()),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Status row
          Row(
            children: [
              // Status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha((0.1 * 255).toInt()),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: statusColor.withAlpha((0.3 * 255).toInt())),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      status == 'pending'
                          ? Icons.schedule
                          : status == 'in_progress'
                              ? Icons.local_shipping
                              : status == 'completed'
                                  ? Icons.check_circle
                                  : Icons.cancel,
                      color: statusColor,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      status == 'pending'
                          ? 'Scheduled'
                          : status == 'in_progress'
                              ? 'In Progress'
                              : status == 'completed'
                                  ? 'Delivered'
                                  : 'Cancelled',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // ETA or completion info
              Expanded(
                child: status == 'in_progress'
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ETA: $etaText',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            remainingTime,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      )
                    : status == 'completed'
                        ? Text(
                            'Delivered at ${_currentRoute!.actualEndTime != null ? DateFormat("h:mm a").format(_currentRoute!.actualEndTime!) : etaText}',
                            style: theme.textTheme.bodyMedium,
                          )
                        : status == 'pending'
                            ? Text(
                                'Scheduled for ${DateFormat("h:mm a").format(_currentRoute!.startTime)}',
                                style: theme.textTheme.bodyMedium,
                              )
                            : const Text(
                                'Delivery cancelled',
                                style: TextStyle(color: Colors.red),
                              ),
              ),

              // Action button
              IconButton(
                icon: Icon(
                  _isInfoExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  color: theme.colorScheme.primary,
                ),
                onPressed: _toggleInfoPanel,
                tooltip: _isInfoExpanded ? 'Show less' : 'Show more',
              ),
            ],
          ),

          // Progress bar
          if (status == 'in_progress' || status == 'completed')
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: LinearProgressIndicator(
                value: status == 'completed'
                    ? 1.0
                    : (_currentRoute!.metadata?['routeDetails']?['progress']
                                as num?)
                            ?.toDouble() ??
                        0.5,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  status == 'completed'
                      ? Colors.green
                      : theme.colorScheme.primary,
                ),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }

  // Compact grid action button with text below
  Widget _buildGridActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final isDisabled = onPressed == null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha((0.1 * 255).toInt()),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentRoute?.metadata?['eventName'] ?? 'Track Delivery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _performInitialMapPreview,
            tooltip: 'View entire route',
          ),
          if (_currentRoute?.status == 'in_progress')
            IconButton(
              icon: const Icon(Icons.navigation),
              onPressed: _openGoogleMapsNavigation,
              tooltip: 'Open in Google Maps',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  // Base layer: The map
                  DeliveryMap(
                    mapController: _mapController,
                    markers: _markers,
                    polylines: _polylines,
                    initialPosition: _currentRoute?.currentLocation != null
                        ? LatLng(
                            _currentRoute!.currentLocation!.latitude,
                            _currentRoute!.currentLocation!.longitude,
                          )
                        : LatLng(
                            _currentRoute!.waypoints.first.latitude,
                            _currentRoute!.waypoints.first.longitude,
                          ),
                    isLoading: _isLoading,
                    // Make map options more visible by ensuring proper width
                    showMapTypeButton: true,
                    showZoomButtons: true,
                  ),

                  // Live tracking indicator - always visible and minimal
                  if (_currentRoute?.currentLocation != null &&
                      _currentRoute?.status == 'in_progress')
                    Positioned(
                      top: 16,
                      left: 16,
                      child: SafeArea(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha((0.8 * 255).toInt()),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withAlpha((0.2 * 255).toInt()),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _isUpdatingLocation
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.blue,
                                      ),
                                    )
                                  : Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _locationUpdatedRecently
                                            ? Colors.blue
                                            : Colors.orange,
                                        boxShadow: [
                                          BoxShadow(
                                            color: _locationUpdatedRecently
                                                ? Colors.blue.withAlpha(
                                                    (0.5 * 255).toInt())
                                                : Colors.orange.withAlpha(
                                                    (0.5 * 255).toInt()),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                              const SizedBox(width: 8),
                              Text(
                                _locationUpdatedRecently
                                    ? 'Live Tracking'
                                    : 'Last update: $_lastUpdateTime',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Completion status overlay
                  if (_currentRoute != null &&
                      (_currentRoute!.status == 'completed' ||
                          _currentRoute!.status == 'cancelled'))
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: SafeArea(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: _currentRoute!.status == 'completed'
                                ? Colors.green.withAlpha((0.9 * 255).toInt())
                                : Colors.red.withAlpha((0.9 * 255).toInt()),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withAlpha((0.2 * 255).toInt()),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _currentRoute!.status == 'completed'
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _currentRoute!.status == 'completed'
                                          ? 'Delivery Completed'
                                          : 'Delivery Cancelled',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (_currentRoute!.actualEndTime != null)
                                      Text(
                                        'on ${DateFormat('MMM d, yyyy').format(_currentRoute!.actualEndTime!)} at ${DateFormat('h:mm a').format(_currentRoute!.actualEndTime!)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Bottom panels (sliding up)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      height:
                          _isInfoExpanded ? _maxPanelHeight : _minPanelHeight,
                      child: Column(
                        children: [
                          // Mini status card (always visible)
                          GestureDetector(
                            onTap: _toggleInfoPanel,
                            child: _buildMiniStatusCard(),
                          ),

                          // Expanded content (conditionally visible)
                          if (_isInfoExpanded)
                            Expanded(
                              child: Container(
                                color: Theme.of(context).colorScheme.surface,
                                child: SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Delivery Info Card
                                      if (_currentRoute != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              left: 16,
                                              right: 16,
                                              bottom: 16,
                                              top: 8),
                                          child: DeliveryInfoCard(
                                            route: _currentRoute!,
                                            onDriverInfoTap:
                                                _showDriverContactSheet,
                                            onContactDriverTap:
                                                _showDriverContactSheet,
                                          ),
                                        ),

                                      // Management actions
                                      if ((_isManagementUser ||
                                              _isActiveDriver) &&
                                          _currentRoute != null &&
                                          (_currentRoute!.status == 'pending' ||
                                              _currentRoute!.status ==
                                                  'in_progress'))
                                        Container(
                                          margin: const EdgeInsets.only(
                                            left: 16,
                                            right: 16,
                                            bottom: 16,
                                          ),
                                          child: Card(
                                            elevation: 4,
                                            clipBehavior: Clip.antiAlias,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Header
                                                Container(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primaryContainer,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16,
                                                      vertical: 12),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .admin_panel_settings,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onPrimaryContainer,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'Delivery Actions',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleMedium
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Theme.of(
                                                                      context)
                                                                  .colorScheme
                                                                  .onPrimaryContainer,
                                                            ),
                                                      ),
                                                      const Spacer(),
                                                      if (_isProcessingAction)
                                                        SizedBox(
                                                          width: 16,
                                                          height: 16,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .onPrimaryContainer,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),

                                                // Feedback area
                                                if (_actionFeedback != null)
                                                  Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 16,
                                                        vertical: 8),
                                                    color: _isActionSuccess
                                                        ? Colors.green
                                                            .withAlpha((0.1 *
                                                                    255)
                                                                .toInt())
                                                        : _isProcessingAction
                                                            ? Colors.blue
                                                                .withAlpha(
                                                                    (0.1 * 255)
                                                                        .toInt())
                                                            : Colors.red
                                                                .withAlpha((0.1 *
                                                                        255)
                                                                    .toInt()),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          _isActionSuccess
                                                              ? Icons
                                                                  .check_circle
                                                              : _isProcessingAction
                                                                  ? Icons
                                                                      .hourglass_top
                                                                  : Icons.error,
                                                          size: 16,
                                                          color: _isActionSuccess
                                                              ? Colors.green
                                                              : _isProcessingAction
                                                                  ? Colors.blue
                                                                  : Colors.red,
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            _actionFeedback!,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: _isActionSuccess
                                                                  ? Colors.green
                                                                  : _isProcessingAction
                                                                      ? Colors.blue
                                                                      : Colors.red,
                                                            ),
                                                          ),
                                                        ),
                                                        if (_actionFeedback !=
                                                                null &&
                                                            !_isProcessingAction)
                                                          IconButton(
                                                            icon: const Icon(
                                                                Icons.close,
                                                                size: 14),
                                                            onPressed: () {
                                                              setState(() {
                                                                _actionFeedback =
                                                                    null;
                                                              });
                                                            },
                                                            color:
                                                                _isActionSuccess
                                                                    ? Colors
                                                                        .green
                                                                    : Colors
                                                                        .red,
                                                            padding:
                                                                EdgeInsets.zero,
                                                            constraints:
                                                                const BoxConstraints(),
                                                            visualDensity:
                                                                VisualDensity
                                                                    .compact,
                                                          ),
                                                      ],
                                                    ),
                                                  ),

                                                // Action buttons
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(16),
                                                  child: LayoutBuilder(
                                                    builder:
                                                        (context, constraints) {
                                                      // Responsive grid based on available width
                                                      final crossCount =
                                                          constraints.maxWidth >
                                                                  600
                                                              ? 6
                                                              : constraints
                                                                          .maxWidth >
                                                                      400
                                                                  ? 3
                                                                  : 2;

                                                      return GridView(
                                                        shrinkWrap: true,
                                                        physics:
                                                            const NeverScrollableScrollPhysics(),
                                                        gridDelegate:
                                                            SliverGridDelegateWithFixedCrossAxisCount(
                                                          crossAxisCount:
                                                              crossCount,
                                                          crossAxisSpacing: 8,
                                                          mainAxisSpacing: 16,
                                                          childAspectRatio: 1.0,
                                                        ),
                                                        children: [
                                                          // Driver-specific actions
                                                          if (_isActiveDriver) ...[
                                                            if (_currentRoute!
                                                                    .status ==
                                                                'pending')
                                                              _buildGridActionButton(
                                                                icon: Icons
                                                                    .play_arrow,
                                                                label: 'Start',
                                                                color: Colors
                                                                    .green,
                                                                onPressed:
                                                                    !_isProcessingAction
                                                                        ? _startDelivery
                                                                        : null,
                                                              ),
                                                            if (_currentRoute!
                                                                    .status ==
                                                                'in_progress')
                                                              _buildGridActionButton(
                                                                icon: Icons
                                                                    .check_circle,
                                                                label:
                                                                    'Complete',
                                                                color: Colors
                                                                    .green,
                                                                onPressed:
                                                                    !_isProcessingAction
                                                                        ? _completeDelivery
                                                                        : null,
                                                              ),
                                                            if (_currentRoute!
                                                                    .status ==
                                                                'in_progress')
                                                              _buildGridActionButton(
                                                                icon: Icons
                                                                    .navigation,
                                                                label:
                                                                    'Navigate',
                                                                color:
                                                                    Colors.blue,
                                                                onPressed:
                                                                    !_isProcessingAction
                                                                        ? _openGoogleMapsNavigation
                                                                        : null,
                                                              ),
                                                          ],

                                                          // Management-specific actions
                                                          if (_isManagementUser) ...[
                                                            _buildGridActionButton(
                                                              icon: Icons
                                                                  .swap_horiz,
                                                              label: 'Reassign',
                                                              color:
                                                                  Colors.orange,
                                                              onPressed:
                                                                  !_isProcessingAction
                                                                      ? _showReassignDialog
                                                                      : null,
                                                            ),
                                                            _buildGridActionButton(
                                                              icon:
                                                                  Icons.delete,
                                                              label: 'Delete',
                                                              color: Theme.of(
                                                                      context)
                                                                  .colorScheme
                                                                  .error,
                                                              onPressed:
                                                                  !_isProcessingAction
                                                                      ? _showDeleteDialog
                                                                      : null,
                                                            ),
                                                          ],

                                                          // Contact driver action
                                                          _buildGridActionButton(
                                                            icon: Icons.phone,
                                                            label:
                                                                'Contact Driver',
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .secondary,
                                                            onPressed:
                                                                !_isProcessingAction
                                                                    ? _showDriverContactSheet
                                                                    : null,
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // FAB for centering on driver
                  if (_currentRoute?.currentLocation != null)
                    Positioned(
                      right: 16,
                      bottom: _isInfoExpanded
                          ? _maxPanelHeight + 16
                          : _minPanelHeight + 16,
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: _centerOnDriver,
                        child: const Icon(Icons.gps_fixed),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}