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
import 'package:cateredtoyou/models/delivery_route_model.dart';
import 'package:cateredtoyou/views/delivery/widgets/delivery_map.dart';
import 'package:cateredtoyou/views/delivery/widgets/delivery_info_card.dart';
import 'package:cateredtoyou/views/delivery/widgets/driver_contact_sheet.dart';
import 'package:cateredtoyou/views/delivery/widgets/loaded_items_section.dart';

class TrackDeliveryScreen extends StatefulWidget {
  final DeliveryRoute route;

  const TrackDeliveryScreen({
    super.key,
    required this.route,
  });

  @override
  State<TrackDeliveryScreen> createState() => _TrackDeliveryScreenState();
}

class _TrackDeliveryScreenState extends State<TrackDeliveryScreen> {
  late StreamSubscription<DocumentSnapshot> _routeSubscription;
  final MapController _mapController = MapController();

  DeliveryRoute? _currentRoute;
  List<LatLng> _routePoints = [];
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];

  bool _isLoading = true;
  Timer? _routeUpdateTimer;
  bool _isFirstLoad = true;
  bool _showInfoCard = true; // Track whether to show or hide the info card

  // Location tracking status variables
  bool _isUpdatingLocation = false;
  bool _locationUpdatedRecently = false;
  String _lastUpdateTime = '';
  DateTime? _lastLocationUpdateTime;

  // Animation variables
  LatLng? _animatedDriverPosition;
  Timer? _animationTimer;
  Timer? _visualRefreshTimer;

  // Constants
  static const String osmRoutingUrl =
      'https://router.project-osrm.org/route/v1/driving/';
  static const double _defaultZoom = 13.0;

  @override
  void initState() {
    super.initState();
    _currentRoute = widget.route;
    
    // Immediately calculate and populate route metrics for initial view
    _calculateRouteMetrics(widget.route);
    
    _setupRouteSubscription();
    _fetchRouteDetails();
    _setupRefreshTimer();
  }

  @override
  void dispose() {
    _routeSubscription.cancel();
    _routeUpdateTimer?.cancel();
    _animationTimer?.cancel();
    _visualRefreshTimer?.cancel();
    super.dispose();
  }

  void _setupRouteSubscription() {
    _routeSubscription = FirebaseFirestore.instance
        .collection('delivery_routes')
        .doc(widget.route.id)
        .snapshots()
        .listen(_handleRouteUpdate);
  }

  void _setupRefreshTimer() {
    // Main update timer for data refresh - every 30 seconds
    _routeUpdateTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateDeliveryMetrics(),
    );
    
    // Visual refresh timer for smoother animations - every 500ms
    _visualRefreshTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        if (mounted && _currentRoute?.status == 'in_progress') {
          setState(() {
            // This triggers a rebuild, keeping animations smoother
            // No need to do any heavy work here
          });
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
        final totalDistance = await _calculateTotalRouteDistance(route.waypoints);
        
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
            'metadata.routeDetails.lastCalculated': FieldValue.serverTimestamp(),
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
        
        final url = '$osmRoutingUrl${startPoint.longitude},${startPoint.latitude};'
                    '${endPoint.longitude},${endPoint.latitude}?overview=false';
        
        final response = await http.get(Uri.parse(url));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['code'] == 'Ok') {
            totalDistance += data['routes'][0]['distance'] as num;
          } else {
            // Fallback to straight-line distance if routing fails
            totalDistance += _calculateStraightLineDistance(
              startPoint.latitude, startPoint.longitude,
              endPoint.latitude, endPoint.longitude
            ) * 1000; // Convert km to meters
          }
        } else {
          // Fallback to straight-line distance if API request fails
          totalDistance += _calculateStraightLineDistance(
            startPoint.latitude, startPoint.longitude,
            endPoint.latitude, endPoint.longitude
          ) * 1000; // Convert km to meters
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
        
        totalDistance += _calculateStraightLineDistance(
          startPoint.latitude, startPoint.longitude,
          endPoint.latitude, endPoint.longitude
        ) * 1000; // Convert km to meters
      }
      
      return totalDistance;
    }
  }

  double _calculateStraightLineDistance(
    double lat1, double lon1, 
    double lat2, double lon2
  ) {
    const double earthRadiusKm = 6371;
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = 
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) * 
      sin(dLon / 2) * sin(dLon / 2);
      
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }
  
  double _degreesToRadians(double degrees) {
    return degrees * (3.14159 / 180);
  }
  
  double sin(double rad) => math.sin(rad);
  double cos(double rad) => math.cos(rad);
  double atan2(double y, double x) => math.atan2(y, x);
  double sqrt(double value) => value <= 0 ? 0 : math.sqrt(value);

  void _handleRouteUpdate(DocumentSnapshot snapshot) async {
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

        // Set up smooth animation of the driver marker
        _setupSmoothMarkerAnimation(
          _currentRoute?.currentLocation, 
          newRoute.currentLocation!
        );

        // Reset "recently updated" after 10 seconds
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) {
            setState(() {
              _locationUpdatedRecently = false;
            });
          }
        });

        // Log the update for testing/debugging
        debugPrint(
            '🚚 DRIVER LOCATION UPDATED: ${newRoute.currentLocation?.latitude}, ${newRoute.currentLocation?.longitude}');

        // Update route details and ETA based on new location
        try {
          await _calculateUpdatedETA(newRoute);
        } catch (e) {
          debugPrint('Error calculating ETA: $e');
        }
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
        // Only auto-center if we're not already animating (for smoother experience)
        if (_animationTimer == null) {
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

  void _setupSmoothMarkerAnimation(GeoPoint? oldLocation, GeoPoint newLocation) {
    // Cancel any existing animation
    _animationTimer?.cancel();

    // If this is the first location update, just set the position directly
    if (oldLocation == null) {
      _animatedDriverPosition = LatLng(newLocation.latitude, newLocation.longitude);
      return;
    }

    // Set up animation parameters
    final startLat = oldLocation.latitude;
    final startLng = oldLocation.longitude;
    final endLat = newLocation.latitude;
    final endLng = newLocation.longitude;
    
    // Calculate distance to determine animation duration
    final distance = _calculateStraightLineDistance(
      startLat, startLng, endLat, endLng
    );
    
    // Set animation duration based on distance (longer for larger jumps)
    // but keep it under 2 seconds for responsiveness
    final animationDuration = (distance > 0.5) 
        ? Duration(milliseconds: 1500) 
        : Duration(milliseconds: (distance * 2000).clamp(300, 1000).toInt());
    
    // Number of animation steps (more for smoother animation)
    const steps = 20;
    final stepDuration = Duration(milliseconds: animationDuration.inMilliseconds ~/ steps);
    
    // Initialize with start position
    _animatedDriverPosition = LatLng(startLat, startLng);
    int currentStep = 0;
    
    // Create animation timer
    _animationTimer = Timer.periodic(stepDuration, (timer) {
      currentStep++;
      
      if (currentStep >= steps) {
        // Animation complete - set final position
        if (mounted) {
          setState(() {
            _animatedDriverPosition = LatLng(endLat, endLng);
          });
        }
        timer.cancel();
        _animationTimer = null;
        return;
      }
      
      // Calculate intermediate position using easeInOut curve for smoother motion
      final progress = _easeInOut(currentStep / steps);
      final lat = startLat + (endLat - startLat) * progress;
      final lng = startLng + (endLng - startLng) * progress;
      
      if (mounted) {
        setState(() {
          _animatedDriverPosition = LatLng(lat, lng);
          _updateMapMarkers(); // Update markers with new animated position
        });
      }
    });
  }

  // Easing function for smoother animation
  double _easeInOut(double t) {
    return t < 0.5 
        ? 4 * t * t * t 
        : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1;
  }

  Future<void> _calculateUpdatedETA(DeliveryRoute route) async {
    if (route.currentLocation == null || route.waypoints.isEmpty) return;
    
    try {
      final currentLoc = route.currentLocation!;
      final destination = route.waypoints.last;

      // Get route details from OSRM API
      final url = '$osmRoutingUrl${currentLoc.longitude},${currentLoc.latitude};'
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
          final totalDistance = route.metadata?['routeDetails']?['totalDistance'] as num?;
          
          if (totalDistance != null && totalDistance > 0) {
            // Safe progress calculation
            final rawProgress = 1.0 - (remainingDistance / totalDistance);
            // Check for valid numerical values to avoid NaN/Infinity
            progress = rawProgress.isFinite && !rawProgress.isNaN ? 
                rawProgress.clamp(0.0, 1.0) : 0.5;
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
            'metadata.routeDetails.estimatedArrival': Timestamp.fromDate(finalETA),
            'metadata.routeDetails.progress': progress,
            'metadata.routeDetails.currentSpeed': currentSpeed,
            'metadata.routeDetails.lastUpdated': FieldValue.serverTimestamp(),
          });
          
          // Log the update
          debugPrint('📊 Updated ETA: ${DateFormat('h:mm a').format(finalETA)}, '
                   'Distance: ${(remainingDistance / 1609.344).toStringAsFixed(2)} miles, '
                   'Progress: ${(progress * 100).toStringAsFixed(1)}%');
        }
      }
    } catch (e) {
      debugPrint('Error updating ETA details: $e');
      // Don't rethrow, just log - we don't want to break the UI for ETA updates
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

    // Add delivery marker
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

    // Use animated position for the driver marker if available
    if (_animatedDriverPosition != null || _currentRoute!.currentLocation != null) {
      // Determine which position to use (animated or actual)
      final markerPos = _animatedDriverPosition ?? 
                       LatLng(
                         _currentRoute!.currentLocation!.latitude,
                         _currentRoute!.currentLocation!.longitude
                       );
      
      markers.add(
        Marker(
          point: markerPos,
          width: 60,
          height: 60,
          child: Stack(
            children: [
              Transform.rotate(
                angle: (_currentRoute!.currentHeading ?? 0) * (3.14159 / 180),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha((0.4 * 255).toInt()),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.navigation,
                    color: Colors.blue,
                    size: 34,
                  ),
                ),
              ),
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Text(
                  'Driver',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    backgroundColor: Colors.white,
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
        driverId: _currentRoute!.driverId,
        onContactMethod: _handleContactMethod,
      ),
    );
  }

  Future<void> _handleContactMethod(String phone, String scheme) async {
    final uri = Uri(scheme: scheme, path: phone);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Could not ${scheme == 'tel' ? 'call' : 'message'} driver'),
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open navigation app')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentRoute?.metadata?['eventName'] ?? 'Track Delivery'),
        actions: [
          // Add visibility toggle to the app bar for consistency
          IconButton(
            icon: Icon(_showInfoCard ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() {
                _showInfoCard = !_showInfoCard;
              });
            },
            tooltip: _showInfoCard ? 'Hide Details' : 'Show Details',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _performInitialMapPreview,
            tooltip: 'View entire route',
          ),
          IconButton(
            icon: const Icon(Icons.navigation),
            onPressed: _openGoogleMapsNavigation,
            tooltip: 'Open in Google Maps',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
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
                ),

                // Position the loaded items section at the top with proper padding
                if (_showInfoCard &&
                    _currentRoute != null &&
                    _currentRoute!.metadata != null &&
                    _currentRoute!.metadata!['loadedItems'] != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 16,
                    child: LoadedItemsSection(
                      items: List<Map<String, dynamic>>.from(
                          _currentRoute!.metadata!['loadedItems']),
                      allItemsLoaded:
                          _currentRoute!.metadata!['vehicleHasAllItems'] ??
                              false,
                    ),
                  ),

                // DeliveryInfoCard at the bottom - only show if not hidden
                if (_showInfoCard && _currentRoute != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: DeliveryInfoCard(
                      route: _currentRoute!,
                      onDriverInfoTap: _showDriverContactSheet,
                      onContactDriverTap: _showDriverContactSheet,
                    ),
                  ),

                // Add location update indicator (when tracking is active)
                if (_currentRoute?.currentLocation != null &&
                    _currentRoute?.status == 'in_progress')
                  Positioned(
                    left: 16,
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha((0.7 * 255).toInt()),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isUpdatingLocation
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.green,
                                  ),
                                )
                              : Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _locationUpdatedRecently
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                          const SizedBox(width: 8),
                          Text(
                            _locationUpdatedRecently
                                ? 'Live Tracking'
                                : 'Last update: $_lastUpdateTime',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: _currentRoute?.currentLocation != null
          ? FloatingActionButton(
              mini: true,
              onPressed: _centerOnDriver,
              child: const Icon(Icons.gps_fixed),
            )
          : null,
    );
  }
}