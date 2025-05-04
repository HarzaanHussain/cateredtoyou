import 'dart:async'; 
import 'dart:math' as math;
import 'package:cateredtoyou/models/delivery_route_model.dart';
import 'package:cateredtoyou/models/user_model.dart';
import 'package:cateredtoyou/models/vehicle_model.dart';
import 'package:cateredtoyou/services/staff_service.dart';
import 'package:cateredtoyou/services/vehicle_service.dart';
import 'package:cateredtoyou/views/delivery/widgets/delivery_map.dart';
import 'package:cateredtoyou/views/delivery/widgets/delivery_map_controller.dart';
import 'package:cateredtoyou/widgets/bottom_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cateredtoyou/services/delivery_route_service.dart';
import 'package:cateredtoyou/services/organization_service.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/services/manifest_service.dart';

class DeliveryFormScreen extends StatefulWidget {
  const DeliveryFormScreen({super.key});

  @override
  State<DeliveryFormScreen> createState() => _DeliveryFormScreenState();
}

class _DeliveryFormScreenState extends State<DeliveryFormScreen> with AutomaticKeepAliveClientMixin {
  // Override to keep state alive when navigating
  @override
  bool get wantKeepAlive => true;
  
  // Controllers
  final _formKey = GlobalKey<FormState>();
  DeliveryMapController? _mapController;
  late final TextEditingController _pickupAddressController;
  late final TextEditingController _deliveryAddressController;
  late final TextEditingController _notesController;
  final _pickupAddressKey = GlobalKey();
  final _deliveryAddressKey = GlobalKey();

  // Form Fields
  String? _selectedEventId;
  String? _selectedVehicleId;
  String? _selectedDriverId;
  DateTime? _startTime;
  DateTime? _estimatedEndTime;
  DateTime? _eventStartDate;
  DateTime? _eventEndDate;

  // Manifest Data
  Manifest? _manifest;
  List<ManifestItem> _loadedItems = [];
  bool _isLoadingManifest = false;
  String? _manifestError;
  bool _vehicleHasAllItems = false;
  
  // Vehicle filtering
  Map<String, List<ManifestItem>> _vehicleAssignments = {};
  bool _filterToManifestVehicles = true;

  // Location Data
  LatLng? _pickupLocation;
  LatLng? _deliveryLocation;
  LatLng? _currentLocation;
  List<LatLng> _routePoints = [];
  Map<String, dynamic>? _routeDetails;

  // UI State
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedEventName;
  Timer? _debounceTimer;
  bool _mapInitialized = false;
  bool _isRetryingRoute = false;
  int _routeAttempts = 0;
  
  // Constants
  static const String osmRoutingUrl = 'https://router.project-osrm.org/route/v1/driving/';
  static const LatLng defaultLocation = LatLng(34.2381, -118.5267);
  static const int maxRouteAttempts = 3;
  static const Duration routeTimeout = Duration(seconds: 7);

  // Flag to check if the widget is still mounted
  bool _isMounted = true;

  // HTTP client with timeout
  final http.Client _httpClient = http.Client();

  @override
  void initState() {
    super.initState();
    _createMapController();
    _initializeControllers();
    
    // Only initialize location on mobile, not web (due to permission issues)
    if (!kIsWeb) {
      _initializeLocation();
    } else {
      // On web, just set default location
      _currentLocation = defaultLocation;
      _pickupLocation = defaultLocation;
    }
    _loadLastKnownLocation();
  }

  // Create map controller separately to handle errors better
  void _createMapController() {
    try {
      _mapController = DeliveryMapController();
    } catch (e) {
      debugPrint('Error creating map controller: $e');
    }
  }

  @override
  void dispose() {
    _isMounted = false;
    _pickupAddressController.dispose();
    _deliveryAddressController.dispose();
    _notesController.dispose();
    
    // Cancel any pending operations before disposing
    _debounceTimer?.cancel();
    _httpClient.close();
    
    // Safely dispose map controller
    if (_mapController != null) {
      try {
        Future.microtask(() {
          _mapController?.dispose();
          _mapController = null;
        });
      } catch (e) {
        debugPrint('Error during map controller disposal: $e');
      }
    }
    
    super.dispose();
  }

  void _initializeControllers() {
    _pickupAddressController = TextEditingController();
    _deliveryAddressController = TextEditingController();
    _notesController = TextEditingController();
  }

  Future<void> _loadLastKnownLocation() async {
    if (!_isMounted) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('last_known_lat');
      final lng = prefs.getDouble('last_known_lng');

      if (lat != null && lng != null && _isMounted) {
        setState(() {
          _currentLocation = LatLng(lat, lng);
        });
      }
    } catch (e) {
      _handleError('Error loading last location', e);
    }
  }

  Future<void> _initializeLocation() async {
    if (!_isMounted) return;
    
    try {
      // Skip geolocation entirely on web
      if (kIsWeb) {
        setState(() {
          _currentLocation = defaultLocation;
          _pickupLocation = defaultLocation;
        });
        return;
      }
      
      final status = await Geolocator.checkPermission();
      if (status == LocationPermission.denied) {
        final requestStatus = await Geolocator.requestPermission();
        if (requestStatus == LocationPermission.denied) {
          _handleLocationPermissionDenied();
          return;
        }
      }

      if (status == LocationPermission.deniedForever) {
        _handleLocationPermissionDenied(permanent: true);
        return;
      }

      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );

        final location = LatLng(position.latitude, position.longitude);

        if (_isMounted) {
          setState(() {
            _currentLocation = location;
            _pickupLocation = location;
          });

          await _saveCurrentLocation(location);
          await _getAddressFromCoordinates(location, true);
          _safeUpdateMapCamera(location);
        }
      } catch (e) {
        debugPrint('Precise location failed, trying last known: $e');
        await _tryLastKnownPosition();
      }
    } catch (e) {
      debugPrint('Error getting current position: $e');
      await _tryLastKnownPosition();
    }
  }

  void _handleLocationPermissionDenied({bool permanent = false}) {
    if (!_isMounted) return;
    
    final message = permanent
        ? 'Location permission permanently denied. Please enable in settings.'
        : 'Location permission is required for better experience';
        
    final SnackBar snackBar = SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      action: permanent
          ? SnackBarAction(
              label: 'Settings',
              onPressed: () => Geolocator.openAppSettings(),
            )
          : null,
    );
    
    // Queue snackbar to show after build
    Future.microtask(() {
      if (_isMounted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    });
    
    setState(() {
      _currentLocation = defaultLocation;
    });
    _safeUpdateMapCamera(defaultLocation);
  }

  Future<void> _saveCurrentLocation(LatLng location) async {
    if (!_isMounted) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_known_lat', location.latitude);
      await prefs.setDouble('last_known_lng', location.longitude);
    } catch (e) {
      _handleError('Error saving location', e);
    }
  }

  Future<void> _tryLastKnownPosition() async {
    if (!_isMounted) return;
    
    try {
      if (kIsWeb) {
        setState(() {
          _currentLocation = defaultLocation;
          _pickupLocation = defaultLocation;
        });
        _safeUpdateMapCamera(defaultLocation);
        return;
      }
      
      final position = await Geolocator.getLastKnownPosition();
      if (position != null && _isMounted) {
        final location = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentLocation = location;
          _pickupLocation = location;
        });
        await _getAddressFromCoordinates(location, true);
        _safeUpdateMapCamera(location);
      } else {
        setState(() {
          _currentLocation = defaultLocation;
        });
        _safeUpdateMapCamera(defaultLocation);
      }
    } catch (e) {
      _handleError('Error getting last position', e);
      setState(() {
        _currentLocation = defaultLocation;
      });
      _safeUpdateMapCamera(defaultLocation);
    }
  }

  void _handleError(String message, dynamic error) {
    debugPrint('$message: $error');
    if (_isMounted) {
      setState(() {
        _errorMessage = '$message: ${error.toString()}';
        _isLoading = false;
      });
    }
  }

  // Safely update map camera with proper error handling
  void _safeUpdateMapCamera(LatLng target) {
    if (!_isMounted || _mapController == null) return;
    
    try {
      _mapController!.moveCamera(target);
    } catch (e) {
      debugPrint('Error updating map camera: $e');
    }
  }

  Future<void> _getAddressFromCoordinates(LatLng location, bool isPickup) async {
    if (!_isMounted) return;
    
    try {
      final response = await _httpClient.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}',
        ),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'CateredToYou/1.0',
        },
      ).timeout(const Duration(seconds: 7));

      if (!_isMounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['display_name'];
        setState(() {
          if (isPickup) {
            _pickupAddressController.text = address;
          } else {
            _deliveryAddressController.text = address;
          }
        });
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
      // Don't show error to user, just silently fail
      // This is a minor error that doesn't need to block the user
    }
  }

  Future<void> _searchAddress(String query, bool isPickup) async {
    if (query.length < 3) return;
    if (!_isMounted) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        setState(() => _isLoading = true);

        final response = await _httpClient.get(
          Uri.parse(
            'https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=5&countrycodes=us',
          ),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'CateredToYou/1.0',
          },
        ).timeout(const Duration(seconds: 7));

        if (!_isMounted) return;

        if (response.statusCode == 200) {
          final results = json.decode(response.body) as List;
          if (results.isNotEmpty) {
            await _showAddressSuggestions(results, isPickup);
          } else {
            _showAddressSearchError("No locations found for this address");
          }
        }
      } catch (e) {
        _handleError('Error searching address', e);
      } finally {
        if (_isMounted) {
          setState(() => _isLoading = false);
        }
      }
    });
  }
  
  void _showAddressSearchError(String message) {
    if (!_isMounted) return;
    
    final snackBar = SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    );
    
    // Queue snackbar to show after build
    Future.microtask(() {
      if (_isMounted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    });
  }

  Future<void> _showAddressSuggestions(List results, bool isPickup) async {
    if (!_isMounted) return;

    final RenderBox? textFieldBox = isPickup
        ? _pickupAddressKey.currentContext?.findRenderObject() as RenderBox?
        : _deliveryAddressKey.currentContext?.findRenderObject() as RenderBox?;

    if (textFieldBox == null) {
      await _showAddressSuggestionsBottomSheet(results, isPickup);
      return;
    }

    final textFieldPosition = textFieldBox.localToGlobal(Offset.zero);
    final textFieldSize = textFieldBox.size;

    final offset = Offset(0, textFieldSize.height + 5);
    final position = textFieldPosition + offset;

    // Make sure we're still mounted before showing menu
    if (!_isMounted) return;
    
    if (!mounted) return;
    
    final selected = await showMenu<Map<String, dynamic>>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + textFieldSize.width,
        position.dy + 20.0,
      ),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      constraints: BoxConstraints(
        maxWidth: textFieldSize.width,
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      items: results.map<PopupMenuItem<Map<String, dynamic>>>((result) {
        return PopupMenuItem<Map<String, dynamic>>(
          value: result,
          padding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatAddressForDisplay(result['display_name']),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  result['display_name'],
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );

    if (selected != null && _isMounted) {
      _processSelectedAddress(selected, isPickup);
    }
  }

  String _formatAddressForDisplay(String fullAddress) {
    final parts = fullAddress.split(',');
    if (parts.isEmpty) return fullAddress;
    return parts[0].trim();
  }

  void _processSelectedAddress(Map<String, dynamic> selected, bool isPickup) {
    if (!_isMounted) return;
    
    final latLng = LatLng(
      double.parse(selected['lat']),
      double.parse(selected['lon']),
    );

    setState(() {
      if (isPickup) {
        _pickupLocation = latLng;
        _pickupAddressController.text = selected['display_name'];
      } else {
        _deliveryLocation = latLng;
        _deliveryAddressController.text = selected['display_name'];
      }
    });

    _safeUpdateMapMarkersAndPolylines();

    if (_pickupLocation != null && _deliveryLocation != null) {
      _getRouteDetails();
    }

    _safeUpdateMapBounds();
  }

  Future<void> _showAddressSuggestionsBottomSheet(List results, bool isPickup) async {
    if (!_isMounted) return;
    if (!mounted) return;
    
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha((0.4 * 255).toInt()),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Select Address',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(),
            Flexible(
              child: ListView.builder(
                itemCount: results.length,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  final result = results[index];
                  return ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(
                      _formatAddressForDisplay(result['display_name']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      result['display_name'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.pop(context, result),
                  );
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );

    if (selected != null && _isMounted) {
      _processSelectedAddress(selected, isPickup);
    }
  }

  // Improved route calculation with better error handling and retry logic
  Future<void> _getRouteDetails() async {
    if (!_isMounted) return;
    if (_pickupLocation == null || _deliveryLocation == null) return;
    if (_mapController == null) return;

    setState(() {
      _isLoading = true;
      _routeAttempts++;
      _isRetryingRoute = _routeAttempts > 1;
    });

    try {
      // If we've already tried multiple times, just use the direct route
      if (_routeAttempts >= maxRouteAttempts) {
        _createFallbackRouteDetails(showSnackbar: true);
        return;
      }

      final url = '$osmRoutingUrl${_pickupLocation!.longitude},${_pickupLocation!.latitude};'
          '${_deliveryLocation!.longitude},${_deliveryLocation!.latitude}'
          '?overview=full&geometries=geojson&steps=true';
          
      // Use the HTTP client with a longer timeout (7 seconds instead of 5)
      final response = await _httpClient.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(routeTimeout);
      
      if (!_isMounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok') {
          final route = data['routes'][0];

          // Extract route points from GeoJSON geometry
          final coordinates = route['geometry']['coordinates'] as List;
          final points = coordinates.map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble())).toList();

          // Calculate estimated time with traffic
          final baseDuration = route['duration'] as num;
          final distance = route['distance'] as num;
          final trafficFactor = 1.3; // Assume 30% more time during traffic
          final durationWithTraffic = baseDuration * trafficFactor;

          if (_isMounted) {
            setState(() {
              _routeDetails = {
                'distance': distance,
                'formattedDistance': '${(distance * 0.000621371).toStringAsFixed(1)} miles',
                'duration': baseDuration,
                'formattedDuration': '${(baseDuration / 60).toStringAsFixed(0)} min',
                'durationWithTraffic': durationWithTraffic,
                'formattedDurationWithTraffic': '${(durationWithTraffic / 60).toStringAsFixed(0)} min',
                'totalDistance': distance,
                'totalDuration': baseDuration,
              };
              _routePoints = points.cast<LatLng>();
              _isLoading = false;
              _routeAttempts = 0; // Reset attempt counter on success
            });

            _safeUpdateMapMarkersAndPolylines();
            _updateRouteTimesBasedOnSelection();
            _safeUpdateMapBounds();
          }
        } else {
          // API returned error - use fallback
          _createFallbackRouteDetails();
        }
      } else {
        // Bad response code - use fallback
        _createFallbackRouteDetails();
      }
    } catch (e) {
      debugPrint('Error getting route details: $e');
      _createFallbackRouteDetails();
    } finally {
      if (_isMounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Improved fallback route calculation
  void _createFallbackRouteDetails({bool showSnackbar = false}) {
    if (!_isMounted || _pickupLocation == null || _deliveryLocation == null) return;
    
    try {
      // Calculate straight-line distance between points using Haversine formula
      final earthRadius = 6371000; // meters
      final lat1 = _pickupLocation!.latitude * (math.pi / 180);
      final lat2 = _deliveryLocation!.latitude * (math.pi / 180);
      final lon1 = _pickupLocation!.longitude * (math.pi / 180);
      final lon2 = _deliveryLocation!.longitude * (math.pi / 180);
      
      final dLat = lat2 - lat1;
      final dLon = lon2 - lon1;
      
      final a = math.sin(dLat/2) * math.sin(dLat/2) +
                math.cos(lat1) * math.cos(lat2) * 
                math.sin(dLon/2) * math.sin(dLon/2);
      final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
      final distance = earthRadius * c; // in meters
      
      // Account for winding roads by multiplying by a factor
      // Typically, real routes are 20-30% longer than direct distance
      final estimatedRealDistance = distance * 1.3; 
      
      // Estimate duration based on average speed of 30 mph (13.4 m/s)
      final averageSpeed = 13.4; // m/s
      final baseDuration = estimatedRealDistance / averageSpeed; // seconds
      final trafficFactor = 1.3;
      final durationWithTraffic = baseDuration * trafficFactor;
      
      // Generate intermediate points for a more realistic line
      final intermediatePoints = _generateIntermediatePoints(
        _pickupLocation!, 
        _deliveryLocation!,
        distance
      );
      
      setState(() {
        _routeDetails = {
          'distance': estimatedRealDistance,
          'formattedDistance': '${(estimatedRealDistance * 0.000621371).toStringAsFixed(1)} miles (est.)',
          'duration': baseDuration,
          'formattedDuration': '${(baseDuration / 60).toStringAsFixed(0)} min (est.)',
          'durationWithTraffic': durationWithTraffic,
          'formattedDurationWithTraffic': '${(durationWithTraffic / 60).toStringAsFixed(0)} min (est.)',
          'totalDistance': estimatedRealDistance,
          'totalDuration': baseDuration,
          'isEstimate': true
        };
        _routePoints = intermediatePoints;
        _isLoading = false;
      });
      
      _safeUpdateMapMarkersAndPolylines();
      _updateRouteTimesBasedOnSelection();
      _safeUpdateMapBounds();
      
      if (showSnackbar && _isMounted && mounted) {
        // Queue the snackbar for after the build
        Future.microtask(() {
          if (_isMounted && mounted) {
            if (_isMounted && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Route service unavailable. Using estimated route instead.'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 4),
                ),
              );
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error creating fallback route: $e');
      if (_isMounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  // Generate intermediate points between two locations to create a more natural-looking route
  List<LatLng> _generateIntermediatePoints(LatLng start, LatLng end, double distance) {
    final points = <LatLng>[start];
    
    // Add more intermediate points for longer distances
    final numPoints = (distance / 5000).ceil().clamp(2, 10);
    
    // Generate slightly off-direct-line points
    final random = math.Random(DateTime.now().millisecondsSinceEpoch);
    
    for (int i = 1; i < numPoints; i++) {
      final ratio = i / numPoints;
      
      // Base intermediate point
      final lat = start.latitude + (end.latitude - start.latitude) * ratio;
      final lng = start.longitude + (end.longitude - start.longitude) * ratio;
      
      // Add some randomness for a more realistic path
      // The maximum deviation is proportional to the distance and decreases as we approach the destination
      final maxDeviation = 0.005 * (1 - ratio); // degrees
      final latJitter = (random.nextDouble() - 0.5) * maxDeviation;
      final lngJitter = (random.nextDouble() - 0.5) * maxDeviation;
      
      points.add(LatLng(lat + latJitter, lng + lngJitter));
    }
    
    points.add(end);
    return points;
  }

  // Safe version of the method to update route times
  void _updateRouteTimesBasedOnSelection() {
    if (!_isMounted || _routeDetails == null) return;
    
    try {
      final durationInSeconds = (_routeDetails!['durationWithTraffic'] as num).toDouble();
      final durationInMillis = (durationInSeconds * 1000).toInt();
      
      // If start time is set but end time isn't, calculate end time
      if (_startTime != null && _estimatedEndTime == null) {
        setState(() {
          _estimatedEndTime = _startTime!.add(Duration(milliseconds: durationInMillis));
        });
      } 
      // If end time is set but start time isn't, calculate start time
      else if (_estimatedEndTime != null && _startTime == null) {
        setState(() {
          _startTime = _estimatedEndTime!.subtract(Duration(milliseconds: durationInMillis));
        });
      }
    } catch (e) {
      debugPrint('Error updating route times: $e');
    }
  }

  void _safeUpdateMapMarkersAndPolylines() {
    if (!_isMounted || _mapController == null) return;
    
    try {
      final markers = <Marker>[];

      if (_pickupLocation != null) {
        markers.add(_createCompactMarker(
          point: _pickupLocation!,
          color: Colors.green,
          title: 'Pickup',
        ));
      }

      if (_deliveryLocation != null) {
        markers.add(_createCompactMarker(
          point: _deliveryLocation!,
          color: Colors.red,
          title: 'Delivery',
        ));
      }

      final polylines = <Polyline>[];
      if (_routePoints.isNotEmpty) {
        polylines.add(Polyline(
          points: _routePoints,
          color: Theme.of(context).colorScheme.primary,
          strokeWidth: 4.0,
        ));
      }

      _mapController!.updateMarkers(markers);
      _mapController!.updatePolylines(polylines);
    } catch (e) {
      debugPrint('Error updating map markers/polylines: $e');
    }
  }

  // Create a compact marker with less height to prevent overflow
  Marker _createCompactMarker({
    required LatLng point,
    required Color color,
    required String title,
  }) {
    return Marker(
      width: 100, // Wider to prevent horizontal overflow
      height: 40, // Lower height to prevent vertical overflow
      point: point,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withAlpha((0.9 * 255).toInt()),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.2 * 255).toInt()),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.location_on, color: Colors.white, size: 16),
          ),
          Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.1 * 255).toInt()),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _safeUpdateMapBounds() {
    if (!_isMounted || _mapController == null) return;
    if (_pickupLocation == null || _deliveryLocation == null) return;

    try {
      final points = [_pickupLocation!, _deliveryLocation!];
      if (_currentLocation != null) {
        points.add(_currentLocation!);
      }

      _mapController!.fitBounds(
        points,
        padding: const EdgeInsets.all(50),
      );
    } catch (e) {
      debugPrint('Error updating map bounds: $e');
    }
  }

  Future<void> _fetchManifestForEvent(String eventId) async {
    if (!_isMounted) return;
    
    setState(() {
      _isLoadingManifest = true;
      _manifestError = null;
      _loadedItems = [];
      _vehicleAssignments = {};
    });

    try {
      debugPrint('Fetching manifest for event: $eventId');
      final manifestService = Provider.of<ManifestService>(context, listen: false);

      // Check if manifest exists for this event
      final exists = await manifestService.doesManifestExist(eventId);
      if (!exists) {
        if (_isMounted) {
          setState(() {
            _isLoadingManifest = false;
            _manifestError = 'No manifest found for this event';
            _manifest = null;
          });
        }
        return;
      }

      // Get manifest stream for the event
      final manifestStream = manifestService.getManifestByEventId(eventId);
      final manifest = await manifestStream.first;
      
      debugPrint('Found manifest for event: $eventId');

      if (_isMounted) {
        setState(() {
          _manifest = manifest;
          _isLoadingManifest = false;

          if (manifest == null) {
            _manifestError = 'Error loading manifest';
          } else {
            // Process vehicle assignments
            _processVehicleAssignments(manifest);
          }
        });

        // If both manifest and vehicle are selected, check loaded items
        if (_manifest != null && _selectedVehicleId != null) {
          _checkLoadedItems();
        }
      }
    } catch (e) {
      if (_isMounted) {
        setState(() {
          _isLoadingManifest = false;
          _manifestError = 'Error: ${e.toString()}';
          _manifest = null;
        });
      }
    }
  }
  
  // Process which vehicles have items assigned in manifest
  void _processVehicleAssignments(Manifest manifest) {
    final vehicleMap = <String, List<ManifestItem>>{};
    
    // Group items by vehicle
    for (final item in manifest.items) {
      if (item.vehicleId != null) {
        if (!vehicleMap.containsKey(item.vehicleId)) {
          vehicleMap[item.vehicleId!] = [];
        }
        vehicleMap[item.vehicleId]!.add(item);
      }
    }
    
    setState(() {
      _vehicleAssignments = vehicleMap;
      
      // If selected vehicle is no longer valid, reset it
      if (_selectedVehicleId != null && 
          _filterToManifestVehicles && 
          _vehicleAssignments.isNotEmpty &&
          !_vehicleAssignments.containsKey(_selectedVehicleId)) {
        _selectedVehicleId = null;
        _loadedItems = [];
        _vehicleHasAllItems = false;
      }
    });
  }

  void _checkLoadedItems() {
    if (!_isMounted) return;
    if (_manifest == null || _selectedVehicleId == null) return;

    final vehicleId = _selectedVehicleId!;

    // Filter items assigned to this vehicle and loaded
    final itemsForVehicle = _manifest!.items.where((item) => item.vehicleId == vehicleId).toList();
    final loadedItems = itemsForVehicle.where((item) => item.loadingStatus == LoadingStatus.loaded).toList();

    setState(() {
      _loadedItems = loadedItems;
      // Check if all assigned items are loaded
      _vehicleHasAllItems = loadedItems.length == itemsForVehicle.length && itemsForVehicle.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // For AutomaticKeepAliveClientMixin
    
    // Determine if on small screen (mobile)
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Delivery'),
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12.0 : 16.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) _buildErrorCard(),
                      _buildEventSection(),
                      const SizedBox(height: 16),
                      _buildLocationSection(isSmallScreen),
                      const SizedBox(height: 16),
                      if (_routeDetails != null) _buildRouteDetailsCard(isSmallScreen),
                      if (_routeDetails != null) const SizedBox(height: 16),
                      _buildDeliveryDetailsSection(),
                      if (_manifest != null && _loadedItems.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildLoadedItemsSection(),
                      ],
                      const SizedBox(height: 16),
                      _buildNotesSection(),
                      const SizedBox(height: 24),
                      _buildSubmitButton(),
                      // Add extra padding at the bottom for safety
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const BottomToolbar(),
    );
  }

  Widget _buildLocationSection(bool isSmallScreen) {
    return Card(
      elevation: 2.0,
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Delivery Locations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildAddressInput(
              controller: _pickupAddressController,
              label: 'Pickup Location',
              hint: 'Enter pickup address',
              isPickup: true,
            ),
            const SizedBox(height: 16),
            _buildAddressInput(
              controller: _deliveryAddressController,
              label: 'Delivery Location',
              hint: 'Enter delivery address',
              isPickup: false,
            ),
            const SizedBox(height: 16),
            _buildMapSection(isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteDetailsCard(bool isSmallScreen) {
    if (_routeDetails == null) return const SizedBox.shrink();
    
    final isEstimate = _routeDetails!['isEstimate'] == true;
    
    return Card(
      elevation: 2.0,
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isEstimate ? Icons.info_outline : Icons.route, 
                     color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  isEstimate ? 'Estimated Route Details' : 'Route Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            if (isEstimate)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    Text(
                      'Using direct route calculation',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                    if (_isRetryingRoute) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _routeAttempts = 0;
                          });
                          _getRouteDetails();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 16),
            _buildRouteDetailRow(
              icon: Icons.straighten,
              label: 'Total Distance:',
              value: _routeDetails!['formattedDistance'] ?? 'N/A',
            ),
            const SizedBox(height: 8),
            _buildRouteDetailRow(
              icon: Icons.timer,
              label: 'Normal Duration:',
              value: _routeDetails!['formattedDuration'] ?? 'N/A',
            ),
            const SizedBox(height: 8),
            _buildRouteDetailRow(
              icon: Icons.traffic,
              label: 'With Traffic:',
              value: _routeDetails!['formattedDurationWithTraffic'] ?? 'N/A',
              color: Theme.of(context).colorScheme.error,
            ),
            if (_startTime != null && _estimatedEndTime != null) ...[
              const Divider(height: 24),
              _buildRouteDetailRow(
                icon: Icons.schedule,
                label: 'Travel Window:',
                value: '${DateFormat('h:mm a').format(_startTime!)} - ${DateFormat('h:mm a').format(_estimatedEndTime!)}',
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRouteDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: color),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isPickup,
  }) {
    final key = isPickup ? _pickupAddressKey : _deliveryAddressKey;

    return TextFormField(
      key: key,
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.location_on),
        border: const OutlineInputBorder(),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.clear();
                  setState(() {
                    if (isPickup) {
                      _pickupLocation = null;
                    } else {
                      _deliveryLocation = null;
                    }
                    _safeUpdateMapMarkersAndPolylines();
                  });
                },
              )
            : null,
      ),
      onChanged: (value) {
        if (value.length > 3) {
          _searchAddress(value, isPickup);
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return isPickup ? 'Please enter pickup location' : 'Please enter delivery location';
        }
        return null;
      },
    );
  }

  Widget _buildMapSection(bool isSmallScreen) {
    // Responsive map height based on screen size
    final mapHeight = isSmallScreen ? 220.0 : 300.0;
    
    return SizedBox(
      height: mapHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_mapController != null) DeliveryMap(
              mapController: _mapController!.mapController,
              markers: _mapController!.markers,
              polylines: _mapController!.polylines,
              initialPosition: _currentLocation ?? defaultLocation,
              isLoading: _isLoading,
              // Set retinaMode parameter to fix the warning
              onMapTap: (tapPosition, point) async {
                if (_pickupLocation == null) {
                  setState(() => _pickupLocation = point);
                  await _getAddressFromCoordinates(point, true);
                } else if (_deliveryLocation == null) {
                  setState(() => _deliveryLocation = point);
                  await _getAddressFromCoordinates(point, false);
                }
                _safeUpdateMapMarkersAndPolylines();
                if (_pickupLocation != null && _deliveryLocation != null) {
                  await _getRouteDetails();
                  _safeUpdateMapBounds();
                }
              },
              onMapReady: () {
                if (_currentLocation != null && !_mapInitialized && _mapController != null) {
                  _safeUpdateMapCamera(_currentLocation!);
                  _mapInitialized = true;
                }
              },
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_currentLocation != null)
                      FloatingActionButton.small(
                        heroTag: 'my_location',
                        onPressed: () => _safeUpdateMapCamera(_currentLocation!),
                        child: const Icon(Icons.my_location),
                      ),
                    if (_pickupLocation != null && _deliveryLocation != null) ...[
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'fit_bounds',
                        onPressed: _safeUpdateMapBounds,
                        child: const Icon(Icons.route),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withAlpha((0.3 * 255).toInt()),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryDetailsSection() {
    return Card(
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildVehicleSection(),
            const SizedBox(height: 16),
            _buildDriverDropdown(),
            const SizedBox(height: 16),
            _buildTimePickers(),
          ],
        ),
      ),
    );
  }
  
  // Enhanced vehicle section with manifest integration
  Widget _buildVehicleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Manifest vehicle filter toggle when manifest is loaded
        if (_manifest != null && _vehicleAssignments.isNotEmpty) 
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_vehicleAssignments.length} vehicles with loaded items',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(
                  height: 24,
                  child: Switch(
                    value: _filterToManifestVehicles,
                    onChanged: (value) {
                      setState(() {
                        _filterToManifestVehicles = value;
                        // Clear selection if not in filtered vehicles
                        if (value && _selectedVehicleId != null && 
                            !_vehicleAssignments.containsKey(_selectedVehicleId)) {
                          _selectedVehicleId = null;
                          _loadedItems = [];
                          _vehicleHasAllItems = false;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Show only loaded vehicles',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          
        _buildVehicleDropdown(),
      ],
    );
  }

  Widget _buildLoadedItemsSection() {
    return Card(
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _vehicleHasAllItems ? Icons.check_circle : Icons.info_outline,
                  color: _vehicleHasAllItems ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Manifest Items for Delivery',
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _vehicleHasAllItems ? 'All items are loaded and ready for delivery' : 'Some items may not be loaded yet',
              style: TextStyle(
                color: _vehicleHasAllItems ? Colors.green : Colors.orange,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            // Put a maximum height constraint and add scrolling for many items
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: _loadedItems.map((item) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.inventory_2, color: Colors.green),
                        title: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Quantity: ${item.quantity}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade700),
                          ),
                          child: const Text(
                            'LOADED',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventSection() {
    final orgService = context.read<OrganizationService>();

    return FutureBuilder<String?>(
      future: orgService.getCurrentUserOrganization().then((org) => org?.id),
      builder: (context, orgSnapshot) {
        if (!orgSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return Card(
          elevation: 2.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Event Selection',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('events')
                      .where('organizationId', isEqualTo: orgSnapshot.data)
                      .where('status', whereIn: ['confirmed', 'in_progress']).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final events = snapshot.data!.docs;
                    
                    if (events.isEmpty) {
                      return const Text('No events available. Create an event first.');
                    }

                    return DropdownButtonFormField<String>(
                      value: _selectedEventId,
                      decoration: const InputDecoration(
                        labelText: 'Select Event',
                        hintText: 'Choose an event for delivery',
                        prefixIcon: Icon(Icons.event),
                        border: OutlineInputBorder(),
                      ),
                      items: events.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(
                            data['name'] ?? 'Unnamed Event',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _handleEventSelection(value);
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select an event';
                        }
                        return null;
                      },
                      isExpanded: true, // Ensure the dropdown uses all available width
                    );
                  },
                ),

                // Display manifest status
                if (_isLoadingManifest)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Row(
                      children: const [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Loading manifest...'),
                      ],
                    ),
                  )
                else if (_manifestError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      _manifestError!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  )
                else if (_manifest != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Manifest loaded: ${_manifest!.items.length} items',
                          style: const TextStyle(color: Colors.green),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleEventSelection(String value) async {
    try {
      setState(() => _isLoading = true);
      debugPrint('Fetching manifest for event: $value');

      final eventDoc = await FirebaseFirestore.instance.collection('events').doc(value).get();

      if (eventDoc.exists && _isMounted) {
        final data = eventDoc.data()!;
        final startDate = (data['startDate'] as Timestamp).toDate();
        final endDate = (data['endDate'] as Timestamp).toDate();
        final location = data['location'] as String?;

        setState(() {
          _selectedEventId = value;
          _selectedEventName = data['name'];
          _eventStartDate = startDate;
          _eventEndDate = endDate;

          if (location != null && location.isNotEmpty) {
            _deliveryAddressController.text = location;
            // this triggers a search to get the coordinates of this address for the map
            _searchLocationFromEventAddress(location);
          }

          // Reset time selections when event changes
          _startTime = null;
          _estimatedEndTime = null;

          // Reset manifest data
          _manifest = null;
          _loadedItems = [];
          _vehicleAssignments = {};
        });

        if (_isMounted && mounted) {
          // Queue snackbar for after build
          Future.microtask(() {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Event: ${DateFormat('MMM d, h:mm a').format(startDate)} - ' '${DateFormat('MMM d, h:mm a').format(endDate)}'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          });
        }

        // Fetch manifest for this event
        await _fetchManifestForEvent(value);
      }
    } catch (e) {
      _handleError('Error loading event details', e);
    } finally {
      if (_isMounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _searchLocationFromEventAddress(String address) async {
    if (!_isMounted) return;
    
    try {
      final response = await _httpClient.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(address)}&limit=1&countrycodes=us',
        ),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'CateredToYou/1.0',
        },
      ).timeout(const Duration(seconds: 7));
      
      if (!_isMounted) return;
      
      if (response.statusCode == 200) {
        final results = json.decode(response.body) as List;
        if (results.isNotEmpty) {
          final result = results.first;
          final latlng = LatLng(
            double.parse(result['lat']),
            double.parse(result['lon']),
          );

          if (_isMounted) {
            setState(() {
              _deliveryLocation = latlng;
            });

            _safeUpdateMapMarkersAndPolylines();
            if (_pickupLocation != null && _deliveryLocation != null) {
              await _getRouteDetails();
              _safeUpdateMapBounds();
            }
          }
        }
      }
    } catch (e) {
      // Don't show this error to user - just silently create a direct estimate if needed
      debugPrint("Error getting coordinates for event location: $e");
      // If we fail, try to create a direct estimate with whatever locations we have
      if (_pickupLocation != null && _deliveryLocation != null) {
        _createFallbackRouteDetails();
      }
    }
  }

  // Enhanced vehicle dropdown with manifest integration - FIX FOR DUPLICATE KEY ERROR
  Widget _buildVehicleDropdown() {
    return Consumer<VehicleService>(
      builder: (context, vehicleService, _) {
        return StreamBuilder<List<Vehicle>>(
          stream: vehicleService.getVehicles(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // Get available vehicles
            List<Vehicle> availableVehicles = snapshot.data!.where((vehicle) => 
              vehicle.status == VehicleStatus.available
            ).toList();

            // Apply manifest vehicle filter if enabled
            if (_filterToManifestVehicles && _vehicleAssignments.isNotEmpty) {
              availableVehicles = availableVehicles.where((vehicle) => 
                _vehicleAssignments.containsKey(vehicle.id)
              ).toList();
            }

            // Check if currently selected vehicle is in the available list
            if (_selectedVehicleId != null) {
              final stillAvailable = availableVehicles.any((v) => v.id == _selectedVehicleId);
              if (!stillAvailable) {
                // Clear selection if vehicle is no longer available
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_isMounted) {
                    setState(() {
                      _selectedVehicleId = null;
                      _loadedItems = [];
                      _vehicleHasAllItems = false;
                    });
                  }
                });
              }
            }
            
            // Check if we need to show empty state
            if (availableVehicles.isEmpty) {
              return Card(
                color: Theme.of(context).colorScheme.errorContainer.withAlpha((0.5 * 255).toInt()),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No available vehicles',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_filterToManifestVehicles && _vehicleAssignments.isEmpty) 
                        const Text(
                          'No vehicles have items loaded from manifest. Try turning off the filter.',
                          style: TextStyle(fontSize: 13),
                        )
                      else
                        const Text(
                          'No vehicles are available for this delivery. Check vehicle status.',
                          style: TextStyle(fontSize: 13),
                        ),
                      if (_filterToManifestVehicles) 
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _filterToManifestVehicles = false;
                            });
                          },
                          child: const Text('Show all vehicles'),
                        ),
                    ],
                  ),
                ),
              );
            }

            // Create the dropdown with proper items
            return DropdownButtonFormField<String>(
              value: _selectedVehicleId,
              decoration: const InputDecoration(
                labelText: 'Select Vehicle',
                hintText: 'Choose a vehicle',
                prefixIcon: Icon(Icons.local_shipping),
                border: OutlineInputBorder(),
              ),
              items: availableVehicles.map((vehicle) {
                final hasItems = _vehicleAssignments.containsKey(vehicle.id);
                final itemCount = hasItems ? _vehicleAssignments[vehicle.id]!.length : 0;
                
                return DropdownMenuItem<String>(
                  value: vehicle.id,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${vehicle.make} ${vehicle.model} - ${vehicle.licensePlate}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasItems) 
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Text(
                            '$itemCount items',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                // Make sure we don't set an invalid value
                final isValidSelection = availableVehicles.any((v) => v.id == value);
                if (isValidSelection) {
                  setState(() {
                    _selectedVehicleId = value;
                    // Check for loaded items in this vehicle if manifest is available
                    if (_manifest != null && _selectedVehicleId != null) {
                      _checkLoadedItems();
                    }
                  });
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a vehicle';
                }
                return null;
              },
              isExpanded: true,
            );
          },
        );
      },
    );
  }

  Widget _buildDriverDropdown() {
    return Consumer<StaffService>(
      builder: (context, staffService, _) {
        return StreamBuilder<List<UserModel>>(
          stream: staffService.getStaffMembers(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final drivers = snapshot.data!.where((staff) => staff.employmentStatus == 'active').toList();

            if (drivers.isEmpty) {
              return const Text('No available staff members');
            }

            // Check if currently selected driver is still available
            if (_selectedDriverId != null) {
              final stillAvailable = drivers.any((d) => d.uid == _selectedDriverId);
              if (!stillAvailable) {
                // Clear selection if driver is no longer available
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_isMounted) {
                    setState(() {
                      _selectedDriverId = null;
                    });
                  }
                });
              }
            }

            return DropdownButtonFormField<String>(
              value: _selectedDriverId,
              decoration: const InputDecoration(
                labelText: 'Select Driver',
                hintText: 'Choose a driver',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              items: drivers.map((driver) {
                return DropdownMenuItem(
                  value: driver.uid,
                  child: Text(
                    '${driver.firstName} ${driver.lastName}${driver.role == 'driver' ? ' (Driver)' : ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                // Make sure we don't set an invalid value
                final isValidSelection = drivers.any((d) => d.uid == value);
                if (isValidSelection) {
                  setState(() => _selectedDriverId = value);
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a driver';
                }
                return null;
              },
              isExpanded: true,
            );
          },
        );
      },
    );
  }

  Widget _buildTimePickers() {
    // Use a more compact layout for time selection
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery Schedule',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _selectStartTime(),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Start Time',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _startTime != null ? DateFormat('h:mm a').format(_startTime!) : 'Select',
                        style: TextStyle(
                          color: _startTime != null ? null : Colors.black54,
                        ),
                      ),
                      const Icon(Icons.access_time, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () => _selectEndTime(),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'End Time',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _estimatedEndTime != null ? DateFormat('h:mm a').format(_estimatedEndTime!) : 'Select',
                        style: TextStyle(
                          color: _estimatedEndTime != null ? null : Colors.black54,
                        ),
                      ),
                      const Icon(Icons.access_time, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Card(
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Additional Notes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Enter any special instructions or notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _errorMessage = null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Creating Delivery...'),
                ],
              )
            : const Text('Create Delivery'),
      ),
    );
  }

  Future<void> _selectStartTime() async {
    if (!_isMounted) return;
    if (!mounted) return;
    
    if (_eventStartDate == null || _eventEndDate == null) {
      // Queue for after build
      Future.microtask(() {
        if (_isMounted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select an event first'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
      return;
    }

    // Calculate valid date range
    final DateTime firstValidDate = _eventStartDate!.subtract(const Duration(days: 7));
    final DateTime lastValidDate = _eventEndDate!;
    final DateTime initialDate = DateTime.now().isAfter(firstValidDate) ? DateTime.now() : firstValidDate;

    // First select date
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstValidDate,
      lastDate: lastValidDate,
    );

    if (selectedDate == null || !_isMounted || !mounted) return;

    // Then select time
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time != null && _isMounted) {
      final selectedDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        time.hour,
        time.minute,
      );

      setState(() {
        _startTime = selectedDateTime;
      });
      
      // Automatically update estimated end time based on route details
      if (_routeDetails != null) {
        final durationInSeconds = (_routeDetails!['durationWithTraffic'] as num).toDouble();
        final durationInMillis = (durationInSeconds * 1000).toInt();
        
        setState(() {
          _estimatedEndTime = _startTime!.add(Duration(milliseconds: durationInMillis));
        });
      }
    }
  }

  Future<void> _selectEndTime() async {
    if (!_isMounted) return;
    if (!mounted) return;
    
    if (_eventStartDate == null || _eventEndDate == null) {
      // Queue for after build
      Future.microtask(() {
        if (_isMounted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select an event first'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
      return;
    }

    // First select date
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _estimatedEndTime ?? _eventStartDate!,
      firstDate: _eventStartDate!,
      lastDate: _eventEndDate!.add(const Duration(days: 1)),
    );

    if (selectedDate == null || !_isMounted || !mounted) return;

    // Then select time
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _estimatedEndTime != null
          ? TimeOfDay.fromDateTime(_estimatedEndTime!)
          : TimeOfDay.fromDateTime(_eventStartDate!.add(const Duration(hours: 1))),
    );

    if (time != null && _isMounted) {
      final selectedDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        time.hour,
        time.minute,
      );

      setState(() {
        _estimatedEndTime = selectedDateTime;
      });
      
      // If we have route details and the start time is not set, calculate it
      if (_routeDetails != null && _startTime == null) {
        final durationInSeconds = (_routeDetails!['durationWithTraffic'] as num).toDouble();
        final durationInMillis = (durationInSeconds * 1000).toInt();
        
        final calculatedStartTime = _estimatedEndTime!.subtract(Duration(milliseconds: durationInMillis));
        
        // Ensure the calculated start time isn't before the valid range
        if (calculatedStartTime.isAfter(_eventStartDate!.subtract(const Duration(days: 7)))) {
          setState(() {
            _startTime = calculatedStartTime;
          });
          
          // Show confirmation to the user
          // Queue for after build
          Future.microtask(() {
            if (_isMounted && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Start time set to ${DateFormat('h:mm a').format(_startTime!)} based on travel time'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          });
        } else {
          // Show an error if the calculated start time is too early
          // Queue for after build
          Future.microtask(() {
            if (_isMounted && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Unable to set start time automatically. Please select manually.'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Theme.of(context).colorScheme.error,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          });
        }
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_isMounted) return;
    if (!mounted) return;
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final deliveryService = context.read<DeliveryRouteService>();
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw 'User not authenticated';
      }

      // Convert LatLng to GeoPoint for Firestore
      final List<GeoPoint> waypoints = [
        GeoPoint(_pickupLocation!.latitude, _pickupLocation!.longitude),
        GeoPoint(_deliveryLocation!.latitude, _deliveryLocation!.longitude),
      ];

      // Extract raw route details for backend calculations
      final routeMetrics = _routeDetails != null ? {
        'totalDistance': _routeDetails!['distance'],
        'originalDuration': _routeDetails!['duration'],
        'durationWithTraffic': _routeDetails!['durationWithTraffic'],
      } : null;

      // Flatten nested structures to avoid array issues
      final metadata = {
        'notes': _notesController.text.trim(),
        'eventName': _selectedEventName,
        'pickupAddress': _pickupAddressController.text,
        'deliveryAddress': _deliveryAddressController.text,
        'distance': _routeDetails?['formattedDistance'],
        'estimatedDuration': _routeDetails?['formattedDuration'],
        'trafficDuration': _routeDetails?['formattedDurationWithTraffic'],
        'routeDetails': routeMetrics,
        'createdBy': currentUser.uid,
        'updatedBy': currentUser.uid,
        'status': 'pending',
        'eventStartDate': _eventStartDate?.millisecondsSinceEpoch,
        'eventEndDate': _eventEndDate?.millisecondsSinceEpoch,
        'lastUpdated': FieldValue.serverTimestamp(),
        'vehicleHasAllItems': _vehicleHasAllItems,
        'loadedItemsCount': _loadedItems.length,
        'loadedItems': _loadedItems
            .map((item) => {
                  'id': item.id,
                  'name': item.name,
                  'quantity': item.quantity,
                  'menuItemId': item.menuItemId,
                })
            .toList(),
      };

      // Create delivery route and get the created route object
      final DeliveryRoute createdRoute = await deliveryService.createDeliveryRoute(
        eventId: _selectedEventId!,
        vehicleId: _selectedVehicleId!,
        driverId: _selectedDriverId!,
        startTime: _startTime!,
        estimatedEndTime: _estimatedEndTime!,
        waypoints: waypoints,
        metadata: metadata,
      );

      await deliveryService.initializeRouteMetrics(createdRoute.id);

      if (_isMounted && mounted) {
        // Queue snackbar for after build
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery route created successfully'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }

      if (_isMounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_isMounted && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final router = GoRouter.of(context);

              if (router.canPop()) {
                router.pop();
              } else {
                router.go('/deliveries');
              }
            });
          }
        });
      }
    } catch (e) {
      if (_isMounted) {
        setState(() {
          _errorMessage = 'Error creating delivery route: $e';
          _isLoading = false;
        });
      }
    }
  }

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) return false;

    if (_selectedEventId == null) {
      _setError('Please select an event');
      return false;
    }

    if (_selectedVehicleId == null) {
      _setError('Please select a vehicle');
      return false;
    }

    if (_selectedDriverId == null) {
      _setError('Please select a driver');
      return false;
    }

    if (_pickupLocation == null) {
      _setError('Please select a pickup location');
      return false;
    }

    if (_deliveryLocation == null) {
      _setError('Please select a delivery location');
      return false;
    }

    if (_startTime == null) {
      _setError('Please select a start time');
      return false;
    }

    if (_estimatedEndTime == null) {
      _setError('Please select an estimated end time');
      return false;
    }

    if (_startTime!.isAfter(_estimatedEndTime!)) {
      _setError('Start time must be before end time');
      return false;
    }

    if (_routeDetails == null) {
      _setError('Unable to calculate route details. Please try again.');
      return false;
    }

    return true;
  }

  void _setError(String message) {
    if (!_isMounted) return;
    if (!mounted) return;
    
    setState(() => _errorMessage = message);
    
    // Queue snackbar for after build
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}