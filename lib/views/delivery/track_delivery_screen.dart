import 'dart:async'; // Importing dart async library for asynchronous operations
import 'package:cateredtoyou/models/delivery_route_model.dart'; // Importing the delivery route model
import 'package:cateredtoyou/views/delivery/widgets/delivery_info_card.dart'; // Importing the delivery info card widget
import 'package:cateredtoyou/views/delivery/widgets/driver_contact_sheet.dart'; // Importing the driver contact sheet widget
import 'package:cateredtoyou/views/delivery/widgets/map_style.dart'; // Importing the map style widget
import 'package:flutter/material.dart'; // Importing Flutter material design library
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Importing Google Maps Flutter package
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Cloud Firestore package
import 'package:http/http.dart' as http; // Importing HTTP package for making network requests
import 'dart:convert'; // Importing dart convert library for JSON encoding and decoding
import 'package:url_launcher/url_launcher.dart'; // Importing URL launcher package for launching URLs

class TrackDeliveryScreen extends StatefulWidget {
  final DeliveryRoute route; // Defining a final variable for the delivery route

  const TrackDeliveryScreen({super.key, required this.route}); // Constructor for the TrackDeliveryScreen widget

  @override
  State<TrackDeliveryScreen> createState() => _TrackDeliveryScreenState(); // Creating the state for the TrackDeliveryScreen widget
}

class _TrackDeliveryScreenState extends State<TrackDeliveryScreen> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>(); // Completer for Google Map controller
  late StreamSubscription<DocumentSnapshot> _routeSubscription; // Subscription for route updates from Firestore
  final Set<Marker> _markers = {}; // Set of markers for the map
  final Set<Polyline> _polylines = {}; // Set of polylines for the map
  DeliveryRoute? _currentRoute; // Current delivery route
  bool _isLoading = true; // Loading state
  Timer? _routeUpdateTimer; // Timer for periodic route updates
  List<LatLng> _routePoints = []; // List of route points
  Map<String, dynamic>? _routeDetails; // Route details

  static const String googleMapsApiKey = 'AIzaSyCFK5EBD3_mQrzVAAGqRl3P1zOCI0Erinc'; // Google Maps API key

  @override
  void initState() {
    super.initState();
    debugPrint('Initializing TrackDeliveryScreen'); // Debug print for initialization
    try {
      _setupRouteSubscription(); // Setting up route subscription
      _setupRouteUpdates(); // Setting up periodic route updates
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('Post frame callback - updating route details'); // Debug print for post frame callback
        _updateRouteDetails(); // Updating route details
      });
    } catch (e) {
      debugPrint('Error in initState: $e'); // Debug print for error in initialization
      setState(() => _isLoading = false); // Setting loading state to false on error
    }
  }

  @override
  void dispose() {
    _routeSubscription.cancel(); // Canceling route subscription
    _routeUpdateTimer?.cancel(); // Canceling route update timer
    super.dispose();
  }

  void _setupRouteSubscription() {
    debugPrint('Setting up route subscription...'); // Debug print for setting up route subscription
    _routeSubscription = FirebaseFirestore.instance
        .collection('delivery_routes')
        .doc(widget.route.id)
        .snapshots()
        .listen((snapshot) async {
      debugPrint('Received route update from Firestore'); // Debug print for receiving route update
      if (!mounted || !snapshot.exists) {
        debugPrint('Route does not exist or widget not mounted'); // Debug print for route not existing or widget not mounted
        return;
      }

      try {
        final newRoute = DeliveryRoute.fromMap(
          snapshot.data()!,
          snapshot.id,
        );

        debugPrint('New route data received: ${newRoute.status}'); // Debug print for new route data received
        debugPrint('Waypoints: ${newRoute.waypoints.length}'); // Debug print for number of waypoints

        setState(() {
          _currentRoute = newRoute; // Setting current route
          _isLoading = false; // Setting loading state to false
        });

        await _updateRouteDetails(); // Updating route details
        _updateMapMarkers(); // Updating map markers
      } catch (e) {
        debugPrint('Error processing route update: $e'); // Debug print for error processing route update
        setState(() => _isLoading = false); // Setting loading state to false on error
      }
    }, onError: (error) {
      debugPrint('Error in route subscription: $error'); // Debug print for error in route subscription
      setState(() => _isLoading = false); // Setting loading state to false on error
    });
  }

  void _setupRouteUpdates() {
    _routeUpdateTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) {
        if (_currentRoute?.status == 'in_progress') {
          _updateRouteDetails(); // Updating route details every 2 minutes if delivery is in progress
        }
      },
    );
  }

  Future<void> _updateRouteDetails() async {
    if (_currentRoute == null || _currentRoute!.waypoints.length < 2) {
      debugPrint('No route or insufficient waypoints'); // Debug print for no route or insufficient waypoints
      return;
    }

    try {
      debugPrint('Starting route update...'); // Debug print for starting route update
      final origin = _currentRoute!.waypoints.first; // Getting origin waypoint
      final destination = _currentRoute!.waypoints.last; // Getting destination waypoint

      debugPrint('Origin: ${origin.latitude},${origin.longitude}'); // Debug print for origin coordinates
      debugPrint('Destination: ${destination.latitude},${destination.longitude}'); // Debug print for destination coordinates

      final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round(); // Getting current timestamp

      final response = await http.get(
        Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
          'origin': '${origin.latitude},${origin.longitude}', // Setting origin for API request
          'destination': '${destination.latitude},${destination.longitude}', // Setting destination for API request
          'key': googleMapsApiKey, // Setting API key
          'departure_time': timestamp.toString(), // Setting departure time
          'mode': 'driving', // Setting mode of transportation
          'units': 'metric', // Setting units to metric
          'traffic_model': 'best_guess', // Setting traffic model
          'alternatives': 'false', // Setting alternatives to false
        }),
      );

      debugPrint('API Response Status: ${response.statusCode}'); // Debug print for API response status
      debugPrint('API Response Body: ${response.body}'); // Debug print for API response body

      if (response.statusCode == 200) {
        final data = json.decode(response.body); // Decoding API response
        if (data['status'] == 'OK') {
          final route = data['routes'][0]; // Getting route from response
          final leg = route['legs'][0]; // Getting leg from route

          final points = _decodePolyline(route['overview_polyline']['points']); // Decoding polyline points
          debugPrint('Decoded ${points.length} route points'); // Debug print for number of decoded route points

          if (mounted) {
            setState(() {
              _routeDetails = {
                'distance': leg['distance']['text'], // Setting distance
                'duration': leg['duration']['text'], // Setting duration
                'duration_value': leg['duration']['value'], // Setting duration value
                'duration_in_traffic': leg['duration_in_traffic']['text'], // Setting duration in traffic
                'duration_in_traffic_value': leg['duration_in_traffic']['value'], // Setting duration in traffic value
                'start_address': leg['start_address'], // Setting start address
                'end_address': leg['end_address'], // Setting end address
                'steps': leg['steps'], // Setting steps
              };
              _routePoints = points; // Setting route points
            });

            await Future.microtask(() => _updateMapPolylines()); // Updating map polylines

            await FirebaseFirestore.instance
                .collection('delivery_routes')
                .doc(_currentRoute!.id)
                .update({
              'metadata.routeDetails': {
                'distance': leg['distance']['text'], // Updating distance in Firestore
                'duration': leg['duration']['text'], // Updating duration in Firestore
                'duration_in_traffic': leg['duration_in_traffic']['text'], // Updating duration in traffic in Firestore
                'updated_at': FieldValue.serverTimestamp(), // Updating timestamp in Firestore
                'traffic_status': _getTrafficStatus(
                  leg['duration']['value'],
                  leg['duration_in_traffic']['value'],
                ), // Updating traffic status in Firestore
              },
            });

            await Future.delayed(const Duration(milliseconds: 300)); // Delaying for 300 milliseconds
            await _centerMapOnDelivery(); // Centering map on delivery
          }
        } else {
          debugPrint('Google Maps API Error: ${data['status']}'); // Debug print for Google Maps API error
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error updating route details: $e'); // Debug print for error updating route details
      debugPrint('Stack trace: $stackTrace'); // Debug print for stack trace
    }
  }

  String _getTrafficStatus(int normalDuration, int trafficDuration) {
    final delayFactor = trafficDuration / normalDuration; // Calculating delay factor

    if (delayFactor > 1.5) {
      return 'heavy'; // Returning heavy traffic status
    } else if (delayFactor > 1.2) {
      return 'moderate'; // Returning moderate traffic status
    } else {
      return 'light'; // Returning light traffic status
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = []; // List to store decoded points
    int index = 0, len = encoded.length; // Initializing index and length
    int lat = 0, lng = 0; // Initializing latitude and longitude

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63; // Decoding latitude
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63; // Decoding longitude
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5)); // Adding decoded point to list
    }
    return points; // Returning list of decoded points
  }

  /// Updates the map markers based on the current route.
  void _updateMapMarkers() {
    if (_currentRoute == null) return; // Return if there is no current route.

    setState(() {
      _markers.clear(); // Clear existing markers.

      // Add pickup marker
      _markers.add(Marker(
        markerId: const MarkerId('pickup'), // Unique ID for the pickup marker.
        position: LatLng(
          _currentRoute!.waypoints.first.latitude, // Latitude of the pickup location.
          _currentRoute!.waypoints.first.longitude, // Longitude of the pickup location.
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen), // Green marker for pickup.
        infoWindow: InfoWindow(
          title: 'Pickup Location', // Title for the info window.
          snippet: _currentRoute!.metadata?['pickupAddress'] ?? '', // Snippet for the info window.
        ),
      ));

      // Add destination marker
      _markers.add(Marker(
        markerId: const MarkerId('destination'), // Unique ID for the destination marker.
        position: LatLng(
          _currentRoute!.waypoints.last.latitude, // Latitude of the destination location.
          _currentRoute!.waypoints.last.longitude, // Longitude of the destination location.
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed), // Red marker for destination.
        infoWindow: InfoWindow(
          title: 'Delivery Location', // Title for the info window.
          snippet: _currentRoute!.metadata?['deliveryAddress'] ?? '', // Snippet for the info window.
        ),
      ));

      // Add driver marker if location available
      if (_currentRoute!.currentLocation != null) {
        _markers.add(Marker(
          markerId: const MarkerId('driver'), // Unique ID for the driver marker.
          position: LatLng(
            _currentRoute!.currentLocation!.latitude, // Latitude of the driver's current location.
            _currentRoute!.currentLocation!.longitude, // Longitude of the driver's current location.
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue), // Blue marker for driver.
          rotation: _currentRoute!.currentHeading ?? 0, // Rotation of the marker based on the driver's heading.
          infoWindow: InfoWindow(
            title: 'Driver Location', // Title for the info window.
            snippet: 'Last updated: ${_formatLastUpdate()}', // Snippet for the info window.
          ),
          zIndex: 2, // Ensures the driver marker is above other markers.
        ));
      }
    });
  }

  /// Updates the map polylines based on the current route.
  void _updateMapPolylines() {
    if (_currentRoute == null) return; // Return if there is no current route.

    debugPrint('Updating map polylines with ${_routePoints.length} points'); // Log the number of route points.

    setState(() {
      _polylines.clear(); // Clear existing polylines.

      if (_routePoints.isNotEmpty) {
        // Get traffic color based on duration
        Color routeColor = _getTrafficColor(); // Determine the color based on traffic.

        // Main route polyline
        _polylines.add(Polyline(
          polylineId: const PolylineId('route'), // Unique ID for the main route polyline.
          points: _routePoints, // Points that make up the polyline.
          color: routeColor, // Color of the polyline.
          width: 8, // Increased width for better visibility.
          startCap: Cap.roundCap, // Rounded start cap.
          endCap: Cap.roundCap, // Rounded end cap.
          geodesic: true, // Use geodesic lines.
        ));

        // Driver progress polyline if available
        if (_currentRoute!.currentLocation != null) {
          _polylines.add(Polyline(
            polylineId: const PolylineId('progress'), // Unique ID for the progress polyline.
            points: [
              LatLng(
                _currentRoute!.currentLocation!.latitude, // Latitude of the driver's current location.
                _currentRoute!.currentLocation!.longitude, // Longitude of the driver's current location.
              ),
              _routePoints.first, // First point of the route.
            ],
            color: Theme.of(context).colorScheme.primary, // Color of the progress polyline.
            width: 8, // Width of the polyline.
            startCap: Cap.roundCap, // Rounded start cap.
            endCap: Cap.roundCap, // Rounded end cap.
          ));
        }
      }
    });
  }

  /// Determines the color of the route based on traffic conditions.
  Color _getTrafficColor() {
    if (_routeDetails == null) return Colors.blue; // Default color if no route details.

    // Get durations
    final normalDuration = _routeDetails!['duration_value'] ?? 0; // Normal duration of the route.
    final trafficDuration = _routeDetails!['duration_in_traffic_value'] ?? 0; // Duration of the route with traffic.

    // Calculate delay factor
    final delayFactor = trafficDuration / normalDuration; // Factor to determine traffic severity.

    if (delayFactor > 1.5) {
      return Colors.red; // Heavy traffic
    } else if (delayFactor > 1.2) {
      return Colors.orange; // Moderate traffic
    } else {
      return Colors.green; // Light traffic
    }
  }

  /// Formats the last update time of the driver's location.
  String _formatLastUpdate() {
    if (_currentRoute == null) return ''; // Return empty string if no current route.

    final now = DateTime.now(); // Current time.
    final lastUpdate = _currentRoute!.updatedAt; // Last update time.
    final difference = now.difference(lastUpdate); // Difference between now and last update.

    if (difference.inMinutes < 1) {
      return 'Just now'; // If updated less than a minute ago.
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago'; // If updated less than an hour ago.
    } else {
      return '${difference.inHours}h ${difference.inMinutes % 60}m ago'; // If updated more than an hour ago.
    }
  }

  /// Centers the map on the delivery route.
  Future<void> _centerMapOnDelivery() async {
    if (_currentRoute == null) return; // Return if there is no current route.

    final bounds = await _calculateBounds(); // Calculate the bounds of the route.
    final controller = await _controller.future; // Get the map controller.

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50), // Animate the camera to fit the bounds.
    );
  }

  /// Calculates the bounds of the route.
  Future<LatLngBounds> _calculateBounds() async {
    final points = [..._currentRoute!.waypoints]; // Get all waypoints.
    if (_currentRoute!.currentLocation != null) {
      points.add(_currentRoute!.currentLocation!); // Add current location if available.
    }

    double minLat = points.first.latitude; // Initialize min latitude.
    double maxLat = points.first.latitude; // Initialize max latitude.
    double minLng = points.first.longitude; // Initialize min longitude.
    double maxLng = points.first.longitude; // Initialize max longitude.

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude; // Update min latitude.
      maxLat = maxLat > point.latitude ? maxLat : point.latitude; // Update max latitude.
      minLng = minLng < point.longitude ? minLng : point.longitude; // Update min longitude.
      maxLng = maxLng > point.longitude ? maxLng : point.longitude; // Update max longitude.
    }

    // Add padding
    const padding = 0.01; // Padding for the bounds.
    return LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding), // Southwest corner of the bounds.
      northeast: LatLng(maxLat + padding, maxLng + padding), // Northeast corner of the bounds.
    );
  }

  /// Shows the driver details in a bottom sheet.
  Future<void> _showDriverDetails(BuildContext context) async {
    if (_currentRoute == null) return; // Return if there is no current route.

    final driverDetails = await _loadDriverDetails(); // Load driver details.
    if (!mounted) return; // Return if the widget is not mounted.

    if (driverDetails == null) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not load driver details'), // Show error message.
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
      }
      return;
    }

    if (!mounted) return; // Return if the widget is not mounted.

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => _buildDriverDetailsSheet(driverDetails), // Show driver details sheet.
        );
      }
    });
  }

  /// Shows the contact driver sheet.
  Future<void> _contactDriver(BuildContext context) async {
    if (_currentRoute == null) return; // Return if there is no current route.

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DriverContactSheet(
        driverId: _currentRoute!.driverId, // Driver ID.
        onContactMethod: _launchPhone, // Callback for contact method.
      ),
    );
  }

  /// Launches the phone dialer or messaging app.
  Future<void> _launchPhone(String phone, String scheme) async {
    final uri = Uri(scheme: scheme, path: phone); // Create URI for the phone number.

    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Could not ${scheme == 'tel' ? 'call' : 'message'} driver'), // Show error message.
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Loads the driver details from Firestore.
  Future<Map<String, dynamic>?> _loadDriverDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentRoute!.driverId)
          .get(); // Get driver document from Firestore.

      return doc.exists ? doc.data() : null; // Return driver data if exists.
    } catch (e) {
      debugPrint('Error loading driver details: $e'); // Log error.
      return null;
    }
  }

  /// Builds the route information widget.
  Widget _buildRouteInfo(BuildContext context) {
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), // Padding for the container.
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Margin for the container.
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest, // Background color.
            borderRadius: BorderRadius.circular(12), // Border radius.
            border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.5))), // Border color.
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Distance
              Row(
                children: [
                  Icon(Icons.straighten,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant), // Icon for distance.
                  const SizedBox(width: 8),
                  Text(
                    'Distance: ${_routeDetails?['distance'] ?? 'Calculating...'}', // Distance text.
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Normal duration
              Row(
                children: [
                  Icon(Icons.timer_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant), // Icon for normal duration.
                  const SizedBox(width: 8),
                  Text(
                    'Normal time: ${_routeDetails?['duration'] ?? 'Calculating...'}', // Normal duration text.
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Traffic duration
              Row(
                children: [
                  Icon(Icons.traffic, size: 20, color: _getTrafficColor()), // Icon for traffic duration.
                  const SizedBox(width: 8),
                  Text(
                    'With traffic: ${_routeDetails?['duration_in_traffic'] ?? 'Calculating...'}', // Traffic duration text.
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ]));
  }

  /// Builds the driver details sheet.
  Widget _buildDriverDetailsSheet(Map<String, dynamic> driver) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16), // Padding for the sheet.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primary, // Background color for avatar.
              child: Text(
                '${driver['firstName'][0]}${driver['lastName'][0]}', // Initials of the driver.
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary, // Text color.
                    ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${driver['firstName']} ${driver['lastName']}', // Full name of the driver.
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (driver['phone'] != null) ...[
              const SizedBox(height: 8),
              Text(
                driver['phone'], // Phone number of the driver.
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary, // Text color.
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds the main widget for the delivery tracking screen.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title:
              Text(_currentRoute?.metadata?['eventName'] ?? 'Track Delivery'), // Title of the app bar.
          actions: [
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: _centerMapOnDelivery, // Center the map on delivery.
              tooltip: 'Center on delivery',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator()) // Show loading indicator if loading.
            : Stack(
                children: [
                  Positioned.fill(
                      child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        _currentRoute!.waypoints.first.latitude, // Initial latitude.
                        _currentRoute!.waypoints.first.longitude, // Initial longitude.
                      ),
                      zoom: 15,
                      tilt: 45.0,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      debugPrint('Map created'); // Log map creation.
                      try {
                        controller.setMapStyle(
                            MapStyle.mapStyle); // Temporary deprecation fix
                        _controller.complete(controller); // Complete the controller future.
                        debugPrint('Map style set successfully'); // Log success.
                      } catch (e) {
                        debugPrint('Error setting map style: $e'); // Log error.
                      }
                    },
                    markers: _markers, // Set markers on the map.
                    polylines: _polylines, // Set polylines on the map.
                    myLocationEnabled: true, // Enable my location.
                    compassEnabled: true, // Enable compass.
                    trafficEnabled: true, // Enable traffic.
                    mapToolbarEnabled: false, // Disable map toolbar.
                    zoomControlsEnabled: false, // Disable zoom controls.
                    buildingsEnabled: true, // Enable buildings.
                    padding: const EdgeInsets.only(bottom: 280), // Padding for the map.
                    mapType: MapType.normal, // Set map type to normal.
                  )),
                  if (_currentRoute != null && _routeDetails != null)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: _buildRouteInfo(context), // Show route info.
                    ),
                  if (_currentRoute != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: DeliveryInfoCard(
                        route: _currentRoute!,
                        onDriverInfoTap: () => _showDriverDetails(context), // Show driver details.
                        onContactDriverTap: () => _contactDriver(context), // Contact driver.
                      ),
                    ),
                ],
              ));
  }
}
