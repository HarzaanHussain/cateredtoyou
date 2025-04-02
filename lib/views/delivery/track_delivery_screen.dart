import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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
   bool _showInfoCard = true; 
  
  // Constants
  static const String osmRoutingUrl = 'https://router.project-osrm.org/route/v1/driving/';
  static const double _defaultZoom = 13.0;
  static const double _routePreviewZoom = 11.0;
  static const Duration _animationDuration = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    _currentRoute = widget.route;
    _setupRouteSubscription();
    _fetchRouteDetails();
    _setupRefreshTimer();
  }

  @override
  void dispose() {
    _routeSubscription.cancel();
    _routeUpdateTimer?.cancel();
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
    _routeUpdateTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _updateDeliveryMetrics(),
    );
  }

  void _handleRouteUpdate(DocumentSnapshot snapshot) async {
    if (!mounted || !snapshot.exists) return;
    
    try {
      final newRoute = DeliveryRoute.fromMap(
        snapshot.data() as Map<String, dynamic>, 
        snapshot.id
      );
      
      final locationChanged = newRoute.currentLocation?.latitude != 
                              _currentRoute?.currentLocation?.latitude ||
                              newRoute.currentLocation?.longitude != 
                              _currentRoute?.currentLocation?.longitude;
      
      setState(() {
        _currentRoute = newRoute;
        _isLoading = false;
      });

      _updateDeliveryMetrics();
      
      // Only recalculate route if location changed significantly
      if (locationChanged) {
        await _fetchRouteDetails();
      }
      
      _updateMapMarkers();
      
      // If this is a new delivery that just started, fit map to show route
      if (_isFirstLoad) {
        _isFirstLoad = false;
        _performInitialMapPreview();
      } else if (locationChanged && _currentRoute?.status == 'in_progress') {
        _centerOnDriver();
      }
    } catch (e) {
      debugPrint('Error processing route update: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateDeliveryMetrics() {
    if (_currentRoute == null || !mounted) return;
    
    // Update progress metrics if needed
    setState(() {});
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
          final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
          final routePoints = coordinates
              .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
              .toList();
          
          return routePoints;
        }
      }
      
      // If API fails, create a direct line between points
      return points.map((point) => LatLng(point.latitude, point.longitude)).toList();
    } catch (e) {
      debugPrint('Error calculating route points: $e');
      // Fall back to direct line between points
      return points.map((point) => LatLng(point.latitude, point.longitude)).toList();
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
    
    // Add driver location marker if available
    if (_currentRoute!.currentLocation != null) {
      final currentLocation = _currentRoute!.currentLocation!;
      markers.add(
        Marker(
          point: LatLng(
            currentLocation.latitude,
            currentLocation.longitude,
          ),
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
    if (_currentRoute?.currentLocation == null) return;
    
    final location = _currentRoute!.currentLocation!;
    _mapController.move(
      LatLng(location.latitude, location.longitude),
      _defaultZoom,
    );
  }

  Future<void> _updateProgressDetails() async {
    if (_currentRoute?.currentLocation == null) {
      return;
    }

    try {
      final currentLoc = _currentRoute!.currentLocation!;
      final destination = _currentRoute!.waypoints.last;

      final url = '$osmRoutingUrl${currentLoc.longitude},${currentLoc.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=false';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok') {
          final remainingDistance = data['routes'][0]['distance'] as double;
          
          // Calculate estimated time based on distance and average speed
          // If we have current speed, use it. Otherwise, use a reasonable default
          final currentSpeed = _currentRoute!.metadata?['currentSpeed'] ?? 12.0; // Default to ~27 mph
          final estimatedTimeInSeconds = (remainingDistance / currentSpeed).round();

          // Calculate progress as percentage of completion
          final totalDistance = _currentRoute!.metadata?['routeDetails']?['totalDistance'] as num? ?? 0;
          double progress = 0.0;
          if (totalDistance > 0) {
            progress = 1.0 - (remainingDistance / totalDistance);
            progress = progress.clamp(0.0, 1.0); // Ensure progress is between 0 and 1
          }

          await FirebaseFirestore.instance
              .collection('delivery_routes')
              .doc(_currentRoute!.id)
              .update({
            'metadata.routeDetails.remainingDistance': remainingDistance,
            'metadata.routeDetails.estimatedTimeRemaining': estimatedTimeInSeconds,
            'metadata.routeDetails.progress': progress,
            'metadata.routeDetails.lastUpdated': FieldValue.serverTimestamp(),
            'metadata.routeDetails.currentSpeed': currentSpeed,
          });
        }
      }
    } catch (e) {
      debugPrint('Error updating progress details: $e');
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
            content: Text('Could not ${scheme == 'tel' ? 'call' : 'message'} driver'),
          ),
        );
      }
    }
  }

  // Helper to get Google Maps directions
  void _openGoogleMapsNavigation() async {
    if (_currentRoute == null || _currentRoute!.waypoints.length < 2) return;
    
    final destination = _currentRoute!.waypoints.last;
    final url = 'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}&travelmode=driving';
    
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
                if (_showInfoCard && _currentRoute != null &&
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
                  
                // Toggle button to show/hide info card
                Positioned(
                  right: 16,
                  bottom: _showInfoCard ? null : 16, // When card is visible, button goes at top
                  top: _showInfoCard ? 16 : null, // When card is hidden, button goes at bottom
                  child: FloatingActionButton(
                    heroTag: 'toggleInfoCard',
                    mini: true,
                    onPressed: () {
                      setState(() {
                        _showInfoCard = !_showInfoCard;
                      });
                    },
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    child: Icon(
                      _showInfoCard ? Icons.visibility_off : Icons.visibility,
                      color: Theme.of(context).colorScheme.primary,
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