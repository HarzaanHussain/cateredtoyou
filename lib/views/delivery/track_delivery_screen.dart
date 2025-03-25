import 'dart:async'; // Importing Dart's async library for handling asynchronous operations and timers.
import 'package:cateredtoyou/views/delivery/widgets/delivery_map.dart'; // Importing custom widget for displaying the delivery map.
import 'package:flutter/material.dart'; // Importing Flutter's material design library for UI components.
import 'package:flutter_map/flutter_map.dart'; // Importing Flutter Map library for map functionalities.
import 'package:latlong2/latlong.dart'; // Importing LatLng library for handling geographical coordinates.
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore library for database operations.
import 'package:url_launcher/url_launcher.dart'; // Importing URL launcher for opening URLs.
import 'package:http/http.dart'
    as http; // Importing HTTP library for making network requests.
import 'dart:convert'; // Importing Dart's convert library for JSON encoding and decoding.
import 'package:cateredtoyou/models/delivery_route_model.dart'; // Importing custom model for delivery route.
import 'package:cateredtoyou/views/delivery/widgets/delivery_info_card.dart'; // Importing custom widget for displaying delivery info card.
import 'package:cateredtoyou/views/delivery/widgets/driver_contact_sheet.dart'; // Importing custom widget for displaying driver contact sheet.
import 'package:cateredtoyou/views/delivery/widgets/loaded_items_section.dart'; // Importing custom widget for displaying loaded items section.

class TrackDeliveryScreen extends StatefulWidget {
  // Stateful widget for tracking delivery.
  final DeliveryRoute route; // Delivery route passed to the widget.

  const TrackDeliveryScreen(
      {super.key,
      required this.route}); // Constructor for initializing the widget with the delivery route.

  @override
  State<TrackDeliveryScreen> createState() =>
      _TrackDeliveryScreenState(); // Creating the state for the widget.
}

class _TrackDeliveryScreenState extends State<TrackDeliveryScreen> {
  final MapController _mapController =
      MapController(); // Controller for managing the map.
  late StreamSubscription<DocumentSnapshot>
      _routeSubscription; // Subscription for listening to route updates from Firestore.
  List<LatLng> _routePoints = []; // List to store the points of the route.
  final List<Marker> _markers = []; // List to store the markers on the map.
  DeliveryRoute? _currentRoute; // Variable to store the current route.
  bool _isLoading = true; // Flag to indicate if data is still loading.
  Timer? _routeUpdateTimer; // Timer for periodic updates.
  bool _isFirstLoad = true; // Flag to indicate if it's the first load.

  static const String osmRoutingUrl =
      'https://router.project-osrm.org/route/v1/driving/'; // URL for the routing API.
  static const double _defaultZoom = 13.0; // Default zoom level for the map.
  static const double _routePreviewZoom = 11.0; // Zoom level for route preview.
  static const Duration _animationDuration =
      Duration(milliseconds: 800); // Duration for map animations.

  @override
  void initState() {
    super.initState();
    _initializeDeliveryTracking(); // Initialize delivery tracking when the widget is created.
  }

  void _initializeDeliveryTracking() async {
    try {
      await _setupRouteSubscription(); // Set up Firestore subscription for route updates.
      _setupPeriodicUpdates(); // Set up periodic updates for the route.
      if (mounted) {
        _updateRouteDetails(); // Update route details if the widget is still mounted.
      }
    } catch (e) {
      debugPrint(
          'Error initializing delivery tracking: $e'); // Print error if initialization fails.
      if (mounted) {
        setState(() =>
            _isLoading = false); // Set loading to false if there's an error.
      }
    }
  }

  Future<void> _setupRouteSubscription() async {
    _routeSubscription = FirebaseFirestore.instance
        .collection('delivery_routes')
        .doc(widget.route.id)
        .snapshots()
        .listen(_handleRouteUpdate); // Listen to route updates from Firestore.
  }

  void _handleRouteUpdate(DocumentSnapshot snapshot) async {
    if (!mounted || !snapshot.exists) {
      return; // Return if the widget is not mounted or snapshot doesn't exist.
    }

    try {
      final newRoute = DeliveryRoute.fromMap(
          snapshot.data() as Map<String, dynamic>,
          snapshot.id); // Parse the new route from Firestore data.
      final locationChanged = newRoute.currentLocation?.latitude !=
              _currentRoute?.currentLocation?.latitude ||
          newRoute.currentLocation?.longitude !=
              _currentRoute?.currentLocation
                  ?.longitude; // Check if the location has changed.

      setState(() {
        _currentRoute = newRoute; // Update the current route.
        _isLoading = false; // Set loading to false.
      });

      if (locationChanged) {
        await _updateProgressDetails(); // Update progress details if location has changed.
      }

      await _updateRouteDetails(); // Update route details.
      _updateMapMarkers(); // Update map markers.

      if (_isFirstLoad) {
        _isFirstLoad = false; // Set first load to false.
        _performInitialMapPreview(); // Perform initial map preview.
      }
    } catch (e) {
      debugPrint(
          'Error processing route update: $e'); // Print error if processing route update fails.
      if (mounted) {
        setState(() =>
            _isLoading = false); // Set loading to false if there's an error.
      }
    }
  }

  void _setupPeriodicUpdates() {
    _routeUpdateTimer?.cancel(); // Cancel any existing timer.
    _routeUpdateTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) {
        if (_currentRoute?.status == 'in_progress') {
          _updateRouteDetails(); // Update route details periodically if the route is in progress.
        }
      },
    );
  }

  Future<void> _updateRouteDetails() async {
    if (_currentRoute == null || _currentRoute!.waypoints.length < 2) {
      return; // Return if the current route is null or has less than 2 waypoints.
    }

    try {
      final routeData =
          await _fetchRoutePoints(); // Fetch route points from the API.
      if (mounted && routeData.points.isNotEmpty) {
        setState(() => _routePoints = routeData
            .points); // Update route points if data is fetched successfully.

        await FirebaseFirestore.instance
            .collection('delivery_routes')
            .doc(_currentRoute!.id)
            .update({
          'metadata.routeDetails': {
            'totalDistance': routeData.distance,
            ...?_currentRoute?.metadata?['routeDetails'],
          }
        }); // Update route metadata in Firestore with the total distance.

        _updateMapMarkers(); // Update map markers.
      }
    } catch (e) {
      debugPrint(
          'Error updating route details: $e'); // Print error if updating route details fails.
    }
  }

  Future<void> _updateProgressDetails() async {
    if (_currentRoute?.currentLocation == null) {
      return; // Return if the current location is null.
    }

    try {
      final currentLoc =
          _currentRoute!.currentLocation!; // Get the current location.
      final destination = _currentRoute!.waypoints.last; // Get the destination.

      final url =
          '$osmRoutingUrl${currentLoc.longitude},${currentLoc.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=false'; // Construct the URL for the routing API.

      final response = await http.get(Uri.parse(url)); // Make the HTTP request.

      if (response.statusCode == 200) {
        final data = json.decode(response.body); // Decode the response.
        if (data['code'] == 'Ok') {
          final remainingDistance = data['routes'][0]['distance']
              as double; // Get the remaining distance.

          await FirebaseFirestore.instance
              .collection('delivery_routes')
              .doc(_currentRoute!.id)
              .update({
            'metadata.routeDetails.remainingDistance': remainingDistance,
            'metadata.routeDetails.lastUpdated': FieldValue.serverTimestamp(),
          }); // Update the remaining distance and last updated timestamp in Firestore.
        }
      }
    } catch (e) {
      debugPrint(
          'Error updating progress details: $e'); // Print error if updating progress details fails.
    }
  }

  Future<({List<LatLng> points, double distance})> _fetchRoutePoints() async {
    final origin = _currentRoute!.waypoints.first; // Get the origin.
    final destination = _currentRoute!.waypoints.last; // Get the destination.

    final url = '$osmRoutingUrl${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=true'; // Construct the URL for the routing API.

    final response = await http.get(Uri.parse(url)); // Make the HTTP request.

    if (response.statusCode == 200) {
      final data = json.decode(response.body); // Decode the response.
      if (data['code'] == 'Ok') {
        final coordinates = data['routes'][0]['geometry']['coordinates']
            as List; // Get the coordinates.
        final distance =
            data['routes'][0]['distance'] as double; // Get the distance.
        return (
          points: coordinates
              .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
              .toList(),
          distance: distance
        ); // Return the points and distance.
      }
    }
    throw Exception(
        'Failed to fetch route data'); // Throw an exception if fetching route data fails.
  }

  void _performInitialMapPreview() {
    if (_routePoints.isEmpty) return; // Return if route points are empty.

    final bounds =
        _calculateRouteBounds(); // Calculate the bounds of the route.
    final center = bounds.center; // Get the center of the bounds.

    _mapController.move(
        center, _routePreviewZoom); // Zoom out to show the entire route.

    Future.delayed(_animationDuration + const Duration(seconds: 1), () {
      if (mounted) {
        final targetLocation = _currentRoute?.currentLocation != null
            ? LatLng(
                _currentRoute!.currentLocation!.latitude,
                _currentRoute!.currentLocation!.longitude,
              )
            : LatLng(
                _currentRoute!.waypoints.first.latitude,
                _currentRoute!.waypoints.first.longitude,
              ); // Get the target location.

        _mapController.move(targetLocation,
            _defaultZoom); // Animate to the current location or start point.
      }
    });
  }

  LatLngBounds _calculateRouteBounds() {
    if (_routePoints.isEmpty) {
      return LatLngBounds(
        LatLng(
          _currentRoute!.waypoints.first.latitude,
          _currentRoute!.waypoints.first.longitude,
        ),
        LatLng(
          _currentRoute!.waypoints.last.latitude,
          _currentRoute!.waypoints.last.longitude,
        ),
      ); // Return bounds based on waypoints if route points are empty.
    }

    double minLat = _routePoints[0].latitude;
    double maxLat = _routePoints[0].latitude;
    double minLng = _routePoints[0].longitude;
    double maxLng = _routePoints[0].longitude;

    for (var point in _routePoints) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    const padding = 0.02; // Approximately 2km padding
    return LatLngBounds(
      LatLng(minLat - padding, minLng - padding),
      LatLng(maxLat + padding, maxLng + padding),
    ); // Calculate and return the bounds with padding.
  }

  void _updateMapMarkers() {
    if (!mounted || _currentRoute == null) {
      return; // Return if the widget is not mounted or current route is null.
    }

    setState(() {
      _markers.clear(); // Clear existing markers.

      _markers.add(MapMarkerHelper.createMarker(
        point: LatLng(
          _currentRoute!.waypoints.first.latitude,
          _currentRoute!.waypoints.first.longitude,
        ),
        id: 'pickup',
        color: Colors.green,
        icon: Icons.restaurant,
        title: 'Pick Up',
      )); // Add marker for the pickup location.

      _markers.add(MapMarkerHelper.createMarker(
        point: LatLng(
          _currentRoute!.waypoints.last.latitude,
          _currentRoute!.waypoints.last.longitude,
        ),
        id: 'delivery',
        color: Colors.red,
        icon: Icons.location_on,
        title: 'Delivery Location',
      )); // Add marker for the delivery location.

      if (_currentRoute!.currentLocation != null) {
        _markers.add(
          Marker(
            point: LatLng(
              _currentRoute!.currentLocation!.latitude,
              _currentRoute!.currentLocation!.longitude,
            ),
            width: 50,
            height: 50,
            child: Stack(
              children: [
                Transform.rotate(
                  angle: (_currentRoute!.currentHeading ?? 0) * (3.14159 / 180),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha((0.2 * 255).toInt()),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.navigation,
                      color: Colors.blue,
                      size: 30,
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
        ); // Add marker for the driver's current location with heading.
      }
    });
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
      ],
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              DeliveryMap(
                mapController: _mapController,
                markers: _markers,
                polylines: [
                  if (_routePoints.isNotEmpty)
                    MapMarkerHelper.createRoute(
                      points: _routePoints,
                      color: Theme.of(context).colorScheme.primary,
                      width: 5.0,
                    ),
                ],
                initialPosition: LatLng(
                  _currentRoute!.waypoints.first.latitude,
                  _currentRoute!.waypoints.first.longitude,
                ),
                isLoading: _isLoading,
              ),
              
              // Position the loaded items section at the top with proper padding
              if (_currentRoute != null &&
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
                        _currentRoute!.metadata!['vehicleHasAllItems'] ?? false,
                  ),
                ),
                
              // DeliveryInfoCard at the bottom
              if (_currentRoute != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DeliveryInfoCard(
                    route: _currentRoute!,
                    onDriverInfoTap: () => _showDriverContactSheet(context),
                    onContactDriverTap: () => _showDriverContactSheet(context),
                  ),
                ),
            ],
          ),
  );
}

  void _showDriverContactSheet(BuildContext context) {
    if (_currentRoute == null) return; // Return if the current route is null.

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DriverContactSheet(
        driverId: _currentRoute!.driverId,
        onContactMethod: _handleContactMethod,
      ),
    ); // Show the driver contact sheet.
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
    } // Handle the contact method (call or message) and show a snackbar if it fails.
  }

  @override
  void dispose() {
    _routeSubscription.cancel();
    _routeUpdateTimer?.cancel();
    _mapController.dispose();
    super.dispose(); // Dispose resources when the widget is destroyed.
  }
}
