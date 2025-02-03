import 'dart:math'; // Importing the math library for mathematical functions.
import 'package:cateredtoyou/services/delivery_route_service.dart'; // Importing the delivery route service.
import 'package:cateredtoyou/services/organization_service.dart'; // Importing the organization service.
import 'package:firebase_auth/firebase_auth.dart'; // Importing Firebase authentication.
import 'package:flutter/foundation.dart' show kIsWeb; // Importing Flutter foundation to check if the platform is web.
import 'package:flutter/material.dart'; // Importing Flutter material design library.
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Importing Google Maps Flutter package.
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Cloud Firestore for database operations.
import 'package:provider/provider.dart'; // Importing Provider for state management.
import 'package:go_router/go_router.dart'; // Importing GoRouter for navigation.
import 'package:http/http.dart' as http; // Importing HTTP package for making network requests.
import 'dart:convert'; // Importing Dart convert library for JSON encoding and decoding.
import 'dart:async'; // Importing Dart async library for asynchronous programming.
import 'package:geolocator/geolocator.dart'; // Importing Geolocator for location services.
import 'package:intl/intl.dart'; // Importing Intl for date and time formatting.
import 'package:shared_preferences/shared_preferences.dart'; // Importing SharedPreferences for local storage.

class DeliveryFormScreen extends StatefulWidget {
  const DeliveryFormScreen({super.key}); // Constructor for the DeliveryFormScreen widget.

  @override
  State<DeliveryFormScreen> createState() => _DeliveryFormScreenState(); // Creating the state for the DeliveryFormScreen widget.
}

class _DeliveryFormScreenState extends State<DeliveryFormScreen> {
  final _formKey = GlobalKey<FormState>(); // Key for the form.

  // Text Controllers
  late final TextEditingController _pickupAddressController; // Controller for the pickup address text field.
  late final TextEditingController _deliveryAddressController; // Controller for the delivery address text field.
  late final TextEditingController _notesController; // Controller for the notes text field.

  // Form Fields
  String? _selectedEventId; // Selected event ID.
  String? _selectedVehicleId; // Selected vehicle ID.
  String? _selectedDriverId; // Selected driver ID.
  DateTime? _startTime; // Start time for the delivery.
  DateTime? _estimatedEndTime; // Estimated end time for the delivery.
  DateTime? _eventStartDate; // Event start date.
  DateTime? _eventEndDate; // Event end date.

  // Location Data
  LatLng? _pickupLocation; // Pickup location coordinates.
  LatLng? _deliveryLocation; // Delivery location coordinates.
  LatLng? _currentLocation; // Current location coordinates.
  List<LatLng> _routePoints = []; // List of route points.
  Map<String, dynamic>? _routeDetails; // Route details.

  // UI State
  bool _isLoading = false; // Loading state.
  String? _errorMessage; // Error message.
  String? _selectedEventName; // Selected event name.
  GoogleMapController? _mapController; // Google Map controller.
  final Set<Marker> _markers = {}; // Set of map markers.
  final Set<Polyline> _polylines = {}; // Set of map polylines.
  Timer? _debounceTimer; // Timer for debouncing.
  bool _mapInitialized = false; // Map initialization state.

  // Platform-specific flags
  final bool _isWebPlatform = kIsWeb; // Flag to check if the platform is web.
  bool _locationPermissionChecked = false; // Flag to check if location permission is checked.

  // Constants
  static const String googleMapsApiKey = 'AIzaSyCFK5EBD3_mQrzVAAGqRl3P1zOCI0Erinc'; // Replace with your API key.
  static const LatLng defaultLocation = LatLng(34.2381, -118.5267); // Default location coordinates.

  @override
  void initState() {
    super.initState();
    _initializeControllers(); // Initialize text controllers.
    _initializeLocation(); // Initialize location services.
    _loadLastKnownLocation(); // Load the last known location.
  }

  void _initializeControllers() {
    _pickupAddressController = TextEditingController(); // Initialize pickup address controller.
    _deliveryAddressController = TextEditingController(); // Initialize delivery address controller.
    _notesController = TextEditingController(); // Initialize notes controller.
  }

  @override
  void dispose() {
    _pickupAddressController.dispose(); // Dispose pickup address controller.
    _deliveryAddressController.dispose(); // Dispose delivery address controller.
    _notesController.dispose(); // Dispose notes controller.
    _mapController?.dispose(); // Dispose map controller.
    _debounceTimer?.cancel(); // Cancel debounce timer.
    super.dispose();
  }

  Future<void> _loadLastKnownLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance(); // Get shared preferences instance.
      final lat = prefs.getDouble('last_known_lat'); // Get last known latitude.
      final lng = prefs.getDouble('last_known_lng'); // Get last known longitude.

      if (lat != null && lng != null) {
        setState(() {
          _currentLocation = LatLng(lat, lng); // Set current location.
        });
      }
    } catch (e) {
      _handleError('Error loading last location', e); // Handle error.
    }
  }

  Future<void> _saveCurrentLocation(LatLng location) async {
    try {
      final prefs = await SharedPreferences.getInstance(); // Get shared preferences instance.
      await prefs.setDouble('last_known_lat', location.latitude); // Save latitude.
      await prefs.setDouble('last_known_lng', location.longitude); // Save longitude.
    } catch (e) {
      _handleError('Error saving location', e); // Handle error.
    }
  }

  Future<void> _initializeLocation() async {
    try {
      if (!_isWebPlatform) {
        await _handleMobileLocation(); // Handle mobile location.
      } else {
        await _handleWebLocation(); // Handle web location.
      }
    } catch (e) {
      _handleError('Error initializing location', e); // Handle error.
    }
  }

  Future<void> _handleMobileLocation() async {
    if (_locationPermissionChecked) return;

    try {
      LocationPermission permission = await Geolocator.checkPermission(); // Check location permission.
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission(); // Request location permission.
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );

        final location = LatLng(position.latitude, position.longitude);

        if (mounted) {
          setState(() {
            _currentLocation = location; // Set current location.
            _pickupLocation = location; // Set pickup location.
          });

          await _saveCurrentLocation(location); // Save current location.
          await _getAddressFromCoordinates(location, true); // Get address from coordinates.
          _updateMapCamera(location); // Update map camera.
        }
      } else {
        _handleLocationPermissionDenied(); // Handle location permission denied.
      }
    } catch (e) {
      debugPrint('Error getting current position: $e');
      await _tryLastKnownPosition(); // Try last known position.
    }

    _locationPermissionChecked = true; // Set location permission checked.
  }

  void _handleLocationPermissionDenied() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required for better experience'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
      setState(() {
        _currentLocation = defaultLocation; // Set default location.
      });
      _updateMapCamera(defaultLocation); // Update map camera.
    }
  }

  Future<void> _handleWebLocation() async {
    setState(() {
      _currentLocation = _currentLocation ?? defaultLocation; // Set current location or default location.
    });
    _updateMapCamera(_currentLocation!); // Update map camera.
  }

  Future<void> _tryLastKnownPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition(); // Get last known position.
      if (position != null && mounted) {
        final location = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentLocation = location; // Set current location.
          _pickupLocation = location; // Set pickup location.
        });
        await _getAddressFromCoordinates(location, true); // Get address from coordinates.
        _updateMapCamera(location); // Update map camera.
      }
    } catch (e) {
      _handleError('Error getting last position', e); // Handle error.
      // Fall back to default location
      setState(() {
        _currentLocation = defaultLocation; // Set default location.
      });
      _updateMapCamera(defaultLocation); // Update map camera.
    }
  }

  Future<void> _searchAddress(String query, bool isPickup) async {
    if (query.length < 3) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final response = await http.get(
          Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
            'input': query,
            'key': googleMapsApiKey,
            'components': 'country:us',
            'types': 'address',
            'sessiontoken': _generateSearchSessionToken(), // Add session token.
          }),
        );

        if (!mounted) return;

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK') {
            await _showAddressSuggestions(data['predictions'] as List, isPickup); // Show address suggestions.
          } else {
            _handleError('Error fetching addresses', data['status']); // Handle error.
          }
        }
      } catch (e) {
        _handleError('Error searching address', e); // Handle error.
      }
    });
  }

  // Add this function to generate session tokens
  String _generateSearchSessionToken() {
    return DateTime.now().millisecondsSinceEpoch.toString(); // Generate session token.
  }

  Future<void> _showAddressSuggestions(List predictions, bool isPickup) async {
    if (!mounted) return;

    final placeId = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => ListView.builder(
        itemCount: predictions.length,
        itemBuilder: (context, index) {
          final prediction = predictions[index];
          return ListTile(
            leading: const Icon(Icons.location_on),
            title: Text(prediction['structured_formatting']['main_text']),
            subtitle: Text(prediction['structured_formatting']['secondary_text']),
            onTap: () => Navigator.pop(context, prediction['place_id']),
          );
        },
      ),
    );

    if (placeId != null) {
      await _getPlaceDetails(placeId, isPickup); // Get place details.
    }
  }

  Future<void> _getPlaceDetails(String placeId, bool isPickup) async {
    try {
      final response = await http.get(
        Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
          'place_id': placeId,
          'key': googleMapsApiKey,
          'fields': 'formatted_address,geometry',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          final latLng = LatLng(location['lat'], location['lng']);
          final address = data['result']['formatted_address'];

          setState(() {
            if (isPickup) {
              _pickupLocation = latLng; // Set pickup location.
              _pickupAddressController.text = address; // Set pickup address.
            } else {
              _deliveryLocation = latLng; // Set delivery location.
              _deliveryAddressController.text = address; // Set delivery address.
            }
          });

          _updateMapMarkersAndPolylines(); // Update map markers and polylines.

          if (_pickupLocation != null && _deliveryLocation != null) {
            await _getRouteDetails(); // Get route details.
          }

          _updateMapBounds(); // Update map bounds.
        }
      }
    } catch (e) {
      _handleError('Error getting place details', e); // Handle error.
    }
  }

  Future<void> _getAddressFromCoordinates(LatLng location, bool isPickup) async {
    try {
      final response = await http.get(
        Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
          'latlng': '${location.latitude},${location.longitude}',
          'key': googleMapsApiKey,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final address = data['results'][0]['formatted_address'];
          setState(() {
            if (isPickup) {
              _pickupAddressController.text = address; // Set pickup address.
            } else {
              _deliveryAddressController.text = address; // Set delivery address.
            }
          });
        }
      }
    } catch (e) {
      _handleError('Error getting address', e); // Handle error.
    }
  }

  Future<void> _getRouteDetails() async {
    if (_pickupLocation == null || _deliveryLocation == null) return;

    try {
      final response = await http.get(
        Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
          'origin': '${_pickupLocation!.latitude},${_pickupLocation!.longitude}',
          'destination': '${_deliveryLocation!.latitude},${_deliveryLocation!.longitude}',
          'key': googleMapsApiKey,
          'departure_time': 'now',
          'traffic_model': 'best_guess',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          setState(() {
            _routeDetails = {
              'distance': leg['distance']['text'], // Set route distance.
              'duration': leg['duration']['text'], // Set route duration.
              'duration_in_traffic': leg['duration_in_traffic']['text'], // Set route duration in traffic.
            };

            _routePoints = _decodePolyline(route['overview_polyline']['points']); // Decode polyline.
            _updateMapMarkersAndPolylines(); // Update map markers and polylines.

            if (_startTime != null) {
              final trafficDuration = leg['duration_in_traffic']['value'];
              _estimatedEndTime = _startTime!.add(Duration(seconds: trafficDuration)); // Set estimated end time.
            }
          });
        }
      }
    } catch (e) {
      _handleError('Error getting route details', e); // Handle error.
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = []; // List to store decoded points.
    int index = 0, len = encoded.length; // Initialize index and length of encoded string.
    int lat = 0, lng = 0; // Initialize latitude and longitude.

    while (index < len) {
      int b, shift = 0, result = 0; // Initialize variables for decoding.
      do {
        b = encoded.codeUnitAt(index++) - 63; // Decode character.
        result |= (b & 0x1f) << shift; // Update result with decoded value.
        shift += 5; // Increment shift.
      } while (b >= 0x20); // Continue until b is less than 0x20.
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1)); // Calculate delta latitude.
      lat += dlat; // Update latitude.

      shift = 0; // Reset shift.
      result = 0; // Reset result.
      do {
        b = encoded.codeUnitAt(index++) - 63; // Decode character.
        result |= (b & 0x1f) << shift; // Update result with decoded value.
        shift += 5; // Increment shift.
      } while (b >= 0x20); // Continue until b is less than 0x20.
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1)); // Calculate delta longitude.
      lng += dlng; // Update longitude.

      points.add(LatLng(lat / 1E5, lng / 1E5)); // Add decoded point to list.
    }
    return points; // Return list of decoded points.
  }

  void _updateMapMarkersAndPolylines() {
    setState(() {
      _markers.clear(); // Clear existing markers.
      _polylines.clear(); // Clear existing polylines.

      if (_pickupLocation != null) {
        _markers.add(Marker(
          markerId: const MarkerId('pickup'), // Marker ID for pickup location.
          position: _pickupLocation!, // Position of pickup location.
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen), // Green marker icon.
          infoWindow: const InfoWindow(title: 'Pickup Location'), // Info window for pickup location.
        ));
      }

      if (_deliveryLocation != null) {
        _markers.add(Marker(
          markerId: const MarkerId('delivery'), // Marker ID for delivery location.
          position: _deliveryLocation!, // Position of delivery location.
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed), // Red marker icon.
          infoWindow: const InfoWindow(title: 'Delivery Location'), // Info window for delivery location.
        ));
      }

      if (_routePoints.isNotEmpty) {
        _polylines.add(Polyline(
          polylineId: const PolylineId('route'), // Polyline ID for route.
          points: _routePoints, // Points of the route.
          color: Colors.blue, // Color of the polyline.
          width: 5, // Width of the polyline.
        ));
      }
    });
  }

  void _updateMapBounds() {
    if (_mapController == null) return; // Return if map controller is null.
    if (_pickupLocation == null || _deliveryLocation == null) return; // Return if pickup or delivery location is null.

    final bounds = LatLngBounds(
      southwest: LatLng(
        min(_pickupLocation!.latitude, _deliveryLocation!.latitude), // Calculate southwest latitude.
        min(_pickupLocation!.longitude, _deliveryLocation!.longitude), // Calculate southwest longitude.
      ),
      northeast: LatLng(
        max(_pickupLocation!.latitude, _deliveryLocation!.latitude), // Calculate northeast latitude.
        max(_pickupLocation!.longitude, _deliveryLocation!.longitude), // Calculate northeast longitude.
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50), // Animate camera to fit bounds with padding.
    );
  }

  void _updateMapCamera(LatLng target) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target, // Target position for the camera.
          zoom: 12, // Zoom level.
        ),
      ),
    );
  }

  void _handleError(String message, dynamic error) {
    debugPrint('$message: $error'); // Print error message to debug console.
    if (mounted) {
      setState(() {
        _errorMessage = '$message: ${error.toString()}'; // Set error message.
        _isLoading = false; // Set loading state to false.
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Delivery'), // App bar title.
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16), // Padding for the list view.
          children: [
            if (_errorMessage != null) _buildErrorCard(), // Show error card if there is an error message.
            _buildEventSection(), // Build event section.
            const SizedBox(height: 16), // Add spacing.
            _buildLocationSection(), // Build location section.
            _buildDeliveryDetailsSection(), // Build delivery details section.
            _buildNotesSection(), // Build notes section.
            const SizedBox(height: 24), // Add spacing.
            _buildSubmitButton(), // Build submit button.
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer, // Error card background color.
      child: Padding(
        padding: const EdgeInsets.all(16), // Padding for the card.
        child: Row(
          children: [
            Icon(
              Icons.error_outline, // Error icon.
              color: Theme.of(context).colorScheme.error, // Error icon color.
            ),
            const SizedBox(width: 16), // Add spacing.
            Expanded(
              child: Text(
                _errorMessage!, // Error message text.
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error, // Error message text color.
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close), // Close icon.
              onPressed: () => setState(() => _errorMessage = null), // Clear error message on press.
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16), // Padding for the card.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Align children to start.
          children: [
            Text(
              'Event Details', // Event details title.
              style: Theme.of(context).textTheme.titleLarge, // Title text style.
            ),
            const SizedBox(height: 16), // Add spacing.
            _buildEventDropdown(), // Build event dropdown.
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16), // Padding for the card.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Align children to start.
          children: [
            Text(
              'Delivery Locations', // Delivery locations title.
              style: Theme.of(context).textTheme.titleLarge, // Title text style.
            ),
            const SizedBox(height: 16), // Add spacing.
            // Pickup Location
            TextFormField(
              controller: _pickupAddressController, // Controller for pickup address.
              decoration: const InputDecoration(
                labelText: 'Pickup Location', // Label text.
                hintText: 'Enter pickup address', // Hint text.
                prefixIcon: Icon(Icons.location_on), // Prefix icon.
              ),
              onChanged: (value) {
                if (value.length > 3) {
                  _searchAddress(value, true); // Search address if input length is greater than 3.
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter pickup location'; // Validate input.
                }
                return null;
              },
            ),
            const SizedBox(height: 16), // Add spacing.
            // Delivery Location
            TextFormField(
              controller: _deliveryAddressController, // Controller for delivery address.
              decoration: const InputDecoration(
                labelText: 'Delivery Location', // Label text.
                hintText: 'Enter delivery address', // Hint text.
                prefixIcon: Icon(Icons.location_on), // Prefix icon.
              ),
              onChanged: (value) {
                if (value.length > 3) {
                  _searchAddress(value, false); // Search address if input length is greater than 3.
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter delivery location'; // Validate input.
                }
                return null;
              },
            ),
            const SizedBox(height: 16), // Add spacing.
            // Map View
            SizedBox(
              height: 300, // Height of the map view.
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12), // Rounded corners for the map view.
                child: GoogleMap(
                  onMapCreated: (controller) {
                    _mapController = controller; // Set map controller.
                    if (_currentLocation != null && !_mapInitialized) {
                      _updateMapCamera(_currentLocation!); // Update map camera if current location is available.
                      _mapInitialized = true; // Set map initialized flag.
                    }
                  },
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation ?? defaultLocation, // Initial camera position.
                    zoom: 12, // Initial zoom level.
                  ),
                  markers: _markers, // Set of markers.
                  polylines: _polylines, // Set of polylines.
                  myLocationEnabled: true, // Enable my location.
                  myLocationButtonEnabled: true, // Enable my location button.
                  compassEnabled: true, // Enable compass.
                  zoomControlsEnabled: false, // Disable zoom controls.
                ),
              ),
            ),
            if (_routeDetails != null) _buildRouteDetails(), // Build route details if available.
          ],
        ),
      ),
    );
  }

  /// Builds a widget displaying route details.
  /// 
  /// This widget shows the distance, duration, and duration in traffic for the route.
  Widget _buildRouteDetails() {
    return Padding(
      padding: const EdgeInsets.only(top: 16), // Adds padding to the top of the widget.
      child: Container(
        padding: const EdgeInsets.all(12), // Adds padding inside the container.
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest, // Sets the background color of the container.
          borderRadius: BorderRadius.circular(8), // Rounds the corners of the container.
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Aligns children to the start of the column.
          children: [
            Text(
              'Route Details',
              style: Theme.of(context).textTheme.titleMedium, // Sets the text style for the title.
            ),
            const SizedBox(height: 8), // Adds vertical space between the title and the details.
            Text('Distance: ${_routeDetails!['distance']}'), // Displays the distance of the route.
            Text('Duration: ${_routeDetails!['duration']}'), // Displays the duration of the route.
            Text('With Traffic: ${_routeDetails!['duration_in_traffic']}'), // Displays the duration with traffic.
          ],
        ),
      ),
    );
  }

  /// Builds a widget displaying delivery details section.
  /// 
  /// This widget contains dropdowns for vehicle and driver selection, and time pickers.
  Widget _buildDeliveryDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16), // Adds padding inside the card.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Aligns children to the start of the column.
          children: [
            Text(
              'Delivery Details',
              style: Theme.of(context).textTheme.titleLarge, // Sets the text style for the title.
            ),
            const SizedBox(height: 16), // Adds vertical space between the title and the dropdowns.
            _buildVehicleDropdown(), // Builds the vehicle dropdown.
            const SizedBox(height: 16), // Adds vertical space between the dropdowns.
            _buildDriverDropdown(), // Builds the driver dropdown.
            const SizedBox(height: 16), // Adds vertical space between the dropdown and the time pickers.
            _buildTimePickers(), // Builds the time pickers.
          ],
        ),
      ),
    );
  }

  /// Builds a widget displaying additional notes section.
  /// 
  /// This widget contains a text field for entering special instructions or notes.
  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16), // Adds padding inside the card.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Aligns children to the start of the column.
          children: [
            Text(
              'Additional Notes',
              style: Theme.of(context).textTheme.titleLarge, // Sets the text style for the title.
            ),
            const SizedBox(height: 16), // Adds vertical space between the title and the text field.
            TextFormField(
              controller: _notesController, // Sets the controller for the text field.
              decoration: const InputDecoration(
                hintText: 'Enter any special instructions or notes', // Sets the hint text for the text field.
                border: OutlineInputBorder(), // Adds a border around the text field.
              ),
              maxLines: 3, // Allows the text field to have up to 3 lines.
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a submit button widget.
  /// 
  /// This button submits the form when pressed, and shows a loading indicator if the form is being submitted.
  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submitForm, // Disables the button if loading, otherwise submits the form.
      child: _isLoading
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center, // Centers the loading indicator and text.
              children: [
                SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2), // Shows a loading indicator.
                ),
                SizedBox(width: 12), // Adds horizontal space between the loading indicator and the text.
                Text('Creating Delivery...'), // Shows loading text.
              ],
            )
          : const Text('Create Delivery'), // Shows the submit button text.
    );
  }

  /// Builds a dropdown widget for selecting an event.
  /// 
  /// This widget fetches the current user's organization and displays events associated with that organization.
  Widget _buildEventDropdown() {
    return Consumer<OrganizationService>(
      builder: (context, orgService, child) {
        return FutureBuilder<String?>(
          future: orgService.getCurrentUserOrganization().then((org) => org?.id), // Fetches the current user's organization ID.
          builder: (context, orgSnapshot) {
            if (!orgSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator()); // Shows a loading indicator while fetching the organization ID.
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .where('organizationId', isEqualTo: orgSnapshot.data) // Filters events by the organization ID.
                  .where('status', whereIn: ['confirmed', 'in_progress']) // Filters events by status.
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}'); // Shows an error message if there is an error.
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator()); // Shows a loading indicator while fetching events.
                }

                final events = snapshot.data!.docs; // Gets the list of events.

                return DropdownButtonFormField<String>(
                  value: _selectedEventId, // Sets the selected event ID.
                  decoration: const InputDecoration(
                    labelText: 'Select Event', // Sets the label text for the dropdown.
                    hintText: 'Choose an event for delivery', // Sets the hint text for the dropdown.
                    prefixIcon: Icon(Icons.event), // Adds an icon to the dropdown.
                  ),
                  items: events.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: doc.id, // Sets the value of the dropdown item to the event ID.
                      child: Text(data['name'] ?? 'Unnamed Event'), // Sets the text of the dropdown item to the event name.
                    );
                  }).toList(),
                  onChanged: (value) => _handleEventSelection(value), // Handles event selection.
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select an event'; // Validates that an event is selected.
                    }
                    return null;
                  },
                );
              },
            );
          },
        );
      },
    );
  }
  

  Future<void> _handleEventSelection(String? value) async {
    if (value != null) {
      final eventDoc = await FirebaseFirestore.instance
          .collection('events') // Access the 'events' collection in Firestore.
          .doc(value) // Get the document with the specified event ID.
          .get(); // Fetch the document.

      if (eventDoc.exists && mounted) {
        final data = eventDoc.data()!; // Get the data from the document.
        final startDate = (data['startDate'] as Timestamp).toDate(); // Convert the start date from Timestamp to DateTime.
        final endDate = (data['endDate'] as Timestamp).toDate(); // Convert the end date from Timestamp to DateTime.
        
        setState(() {
          _selectedEventId = value; // Set the selected event ID.
          _selectedEventName = data['name']; // Set the selected event name.
          _eventStartDate = startDate; // Set the event start date.
          _eventEndDate = endDate; // Set the event end date.
          
          // Reset times when event changes
          _startTime = null; // Reset the start time.
          _estimatedEndTime = null; // Reset the estimated end time.
        });
      }
    }
  }

  Widget _buildVehicleDropdown() {
    return Consumer<OrganizationService>(
      builder: (context, orgService, child) {
        return FutureBuilder<String?>(
          future: orgService.getCurrentUserOrganization().then((org) => org?.id), // Fetch the current user's organization ID.
          builder: (context, orgSnapshot) {
            if (!orgSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator()); // Show a loading indicator while fetching the organization ID.
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('vehicles') // Access the 'vehicles' collection in Firestore.
                  .where('organizationId', isEqualTo: orgSnapshot.data) // Filter vehicles by the organization ID.
                  .where('status', isEqualTo: 'available') // Filter vehicles by status.
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}'); // Show an error message if there is an error.
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator()); // Show a loading indicator while fetching vehicles.
                }

                final vehicles = snapshot.data!.docs; // Get the list of vehicles.

                return DropdownButtonFormField<String>(
                  value: _selectedVehicleId, // Set the selected vehicle ID.
                  decoration: const InputDecoration(
                    labelText: 'Select Vehicle', // Set the label text for the dropdown.
                    hintText: 'Choose a vehicle', // Set the hint text for the dropdown.
                    prefixIcon: Icon(Icons.local_shipping), // Add an icon to the dropdown.
                  ),
                  items: vehicles.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: doc.id, // Set the value of the dropdown item to the vehicle ID.
                      child: Text('${data['make']} ${data['model']} - ${data['licensePlate']}'), // Set the text of the dropdown item to the vehicle details.
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedVehicleId = value), // Handle vehicle selection.
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a vehicle'; // Validate that a vehicle is selected.
                    }
                    return null;
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDriverDropdown() {
    return Consumer<OrganizationService>(
      builder: (context, orgService, child) {
        return FutureBuilder<String?>(
          future: orgService.getCurrentUserOrganization().then((org) => org?.id), // Fetch the current user's organization ID.
          builder: (context, orgSnapshot) {
            if (!orgSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator()); // Show a loading indicator while fetching the organization ID.
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users') // Access the 'users' collection in Firestore.
                  .where('organizationId', isEqualTo: orgSnapshot.data) // Filter users by the organization ID.
                  .where('role', isEqualTo: 'driver') // Filter users by role.
                  .where('employmentStatus', isEqualTo: 'active') // Filter users by employment status.
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}'); // Show an error message if there is an error.
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator()); // Show a loading indicator while fetching drivers.
                }

                final drivers = snapshot.data!.docs; // Get the list of drivers.

                return DropdownButtonFormField<String>(
                  value: _selectedDriverId, // Set the selected driver ID.
                  decoration: const InputDecoration(
                    labelText: 'Select Driver', // Set the label text for the dropdown.
                    hintText: 'Choose a driver', // Set the hint text for the dropdown.
                    prefixIcon: Icon(Icons.person), // Add an icon to the dropdown.
                  ),
                  items: drivers.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: doc.id, // Set the value of the dropdown item to the driver ID.
                      child: Text('${data['firstName']} ${data['lastName']}'), // Set the text of the dropdown item to the driver details.
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedDriverId = value), // Handle driver selection.
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a driver'; // Validate that a driver is selected.
                    }
                    return null;
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTimePickers() {
    return Column(
      children: [
        ListTile(
          title: const Text('Start Time'), // Set the title for the start time picker.
          subtitle: Text(
            _startTime != null
                ? DateFormat('h:mm a').format(_startTime!) // Format the start time if it is selected.
                : 'Select start time', // Show a placeholder if the start time is not selected.
          ),
          trailing: const Icon(Icons.access_time), // Add an icon to the start time picker.
          onTap: () => _selectStartTime(), // Handle start time selection.
        ),
        const SizedBox(height: 8), // Add vertical space between the time pickers.
        ListTile(
          title: const Text('Estimated End Time'), // Set the title for the estimated end time picker.
          subtitle: Text(
            _estimatedEndTime != null
                ? DateFormat('h:mm a').format(_estimatedEndTime!) // Format the estimated end time if it is selected.
                : 'Select estimated end time', // Show a placeholder if the estimated end time is not selected.
          ),
          trailing: const Icon(Icons.access_time), // Add an icon to the estimated end time picker.
          onTap: () => _selectEndTime(), // Handle estimated end time selection.
        ),
      ],
    );
  }

  Future<void> _selectStartTime() async {
    if (_eventStartDate == null || _eventEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an event first'), // Show a message if no event is selected.
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(), // Show the current time as the initial time.
    );

    if (time != null) {
      // Create start time on event date
      final startTime = DateTime(
        _eventStartDate!.year,
        _eventStartDate!.month,
        _eventStartDate!.day,
        time.hour,
        time.minute,
      );

      // Validate time is within event window
      if (startTime.isBefore(_eventStartDate!) || 
          startTime.isAfter(_eventEndDate!)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery time must be within event duration'), // Show a message if the time is outside the event duration.
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      setState(() => _startTime = startTime); // Set the start time.

      // Update route details with new start time
      if (_pickupLocation != null && _deliveryLocation != null) {
        await _getRouteDetailsWithTime(startTime); // Fetch route details with the new start time.
      }
    }
  }

  Future<void> _getRouteDetailsWithTime(DateTime startTime) async {
    if (_pickupLocation == null || _deliveryLocation == null) return;

    try {
      final timestamp = (startTime.millisecondsSinceEpoch / 1000).round();
      
      final response = await http.get(
        Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
          'origin': '${_pickupLocation!.latitude},${_pickupLocation!.longitude}',
          'destination': '${_deliveryLocation!.latitude},${_deliveryLocation!.longitude}',
          'key': googleMapsApiKey,
          'departure_time': timestamp.toString(),
          'traffic_model': 'best_guess',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          final durationInTraffic = leg['duration_in_traffic']['value'];
          
          setState(() {
            _routeDetails = {
              'distance': leg['distance']['text'],
              'duration': leg['duration']['text'],
              'duration_in_traffic': leg['duration_in_traffic']['text'],
              'duration_value': durationInTraffic,
            };

            _routePoints = _decodePolyline(route['overview_polyline']['points']);
            _updateMapMarkersAndPolylines();

            // Automatically set estimated end time based on traffic
            _estimatedEndTime = _startTime!.add(Duration(seconds: durationInTraffic));
          });
        }
      }
    } catch (e) {
      _handleError('Error getting route details', e);
    }
  }


  Future<void> _selectEndTime() async {
    if (_startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select start time first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: _estimatedEndTime != null
          ? TimeOfDay.fromDateTime(_estimatedEndTime!)
          : TimeOfDay.fromDateTime(_startTime!.add(const Duration(hours: 1))),
    );

    if (time != null) {
      final estimatedEnd = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        time.hour,
        time.minute,
      );

      if (estimatedEnd.isBefore(_startTime!)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('End time must be after start time'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      setState(() => _estimatedEndTime = estimatedEnd);
    }
  }

  Future<void> _submitForm() async {
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

    // Create complete metadata
    final metadata = {
      'notes': _notesController.text.trim(),
      'eventName': _selectedEventName,
      'routeDetails': _routeDetails,
      'pickupAddress': _pickupAddressController.text,
      'deliveryAddress': _deliveryAddressController.text,
      'estimatedDistance': _routeDetails?['distance'],
      'estimatedDuration': _routeDetails?['duration'],
      'trafficDuration': _routeDetails?['duration_in_traffic'],
      'createdBy': currentUser.uid,
      'updatedBy': currentUser.uid,
      'status': 'pending',
      'eventStartDate': _eventStartDate?.millisecondsSinceEpoch,
      'eventEndDate': _eventEndDate?.millisecondsSinceEpoch,
    };

    // Call service to create delivery route
    await deliveryService.createDeliveryRoute(
      eventId: _selectedEventId!,
      vehicleId: _selectedVehicleId!,
      driverId: _selectedDriverId!,
      startTime: _startTime!,
      estimatedEndTime: _estimatedEndTime!,
      waypoints: waypoints,
      metadata: metadata,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery route created successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    }
  } catch (e) {
    setState(() {
      _errorMessage = 'Error creating delivery route: $e';
      _isLoading = false;
    });
  }
}

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) return false;
    
    if (_startTime == null) {
      setState(() => _errorMessage = 'Please select a start time');
      return false;
    }
    
    if (_estimatedEndTime == null) {
      setState(() => _errorMessage = 'Please select an estimated end time');
      return false;
    }

    if (_pickupLocation == null) {
      setState(() => _errorMessage = 'Please enter pickup location');
      return false;
    }

    if (_deliveryLocation == null) {
      setState(() => _errorMessage = 'Please enter delivery location');
      return false;
    }

    return true;
  }
}