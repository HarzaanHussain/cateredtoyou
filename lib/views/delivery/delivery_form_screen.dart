import 'dart:async'; // Importing the async library for using Timer and Future.
import 'package:cateredtoyou/models/user_model.dart'; // Importing the user model.
import 'package:cateredtoyou/models/vehicle_model.dart'; // Importing the vehicle model.
import 'package:cateredtoyou/services/staff_service.dart'; // Importing the staff service.
import 'package:cateredtoyou/services/vehicle_service.dart'; // Importing the vehicle service.
import 'package:cateredtoyou/views/delivery/widgets/delivery_map.dart'; // Importing the delivery map widget.
import 'package:cateredtoyou/views/delivery/widgets/delivery_map_controller.dart'; // Importing the delivery map controller.
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components.
import 'package:flutter_map/flutter_map.dart'; // Importing flutter_map for map functionalities.
import 'package:latlong2/latlong.dart'; // Importing latlong2 for handling geographical coordinates.
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing cloud_firestore for Firestore database operations.
import 'package:firebase_auth/firebase_auth.dart'; // Importing firebase_auth for authentication.
import 'package:provider/provider.dart'; // Importing provider for state management.
import 'package:go_router/go_router.dart'; // Importing go_router for navigation.
import 'package:http/http.dart'
    as http; // Importing http for making network requests.
import 'dart:convert'; // Importing convert for JSON encoding and decoding.
import 'package:geolocator/geolocator.dart'; // Importing geolocator for location services.
import 'package:intl/intl.dart'; // Importing intl for date and time formatting.
import 'package:shared_preferences/shared_preferences.dart'; // Importing shared_preferences for local storage.
import 'package:cateredtoyou/services/delivery_route_service.dart'; // Importing delivery route service.
import 'package:cateredtoyou/services/organization_service.dart'; // Importing organization service.
import 'package:cateredtoyou/models/manifest_model.dart'; // Importing manifest model for handling delivery manifests.
import 'package:cateredtoyou/services/manifest_service.dart'; // Importing manifest service for managing delivery manifests.

class DeliveryFormScreen extends StatefulWidget {
  const DeliveryFormScreen(
      {super.key}); // Constructor for the DeliveryFormScreen widget.

  @override
  State<DeliveryFormScreen> createState() =>
      _DeliveryFormScreenState(); // Creating state for the widget.
}

class _DeliveryFormScreenState extends State<DeliveryFormScreen> {
  // Controllers
  final _formKey = GlobalKey<FormState>(); // Form key for form validation.
  final DeliveryMapController _mapController =
      DeliveryMapController(); // Controller for the delivery map.
  late final TextEditingController
      _pickupAddressController; // Controller for the pickup address input.
  late final TextEditingController
      _deliveryAddressController; // Controller for the delivery address input.
  late final TextEditingController
      _notesController; // Controller for the notes input.
  final _pickupAddressKey = GlobalKey();
  final _deliveryAddressKey = GlobalKey();

  // Form Fields
  String? _selectedEventId; // Selected event ID.
  String? _selectedVehicleId; // Selected vehicle ID.
  String? _selectedDriverId; // Selected driver ID.
  DateTime? _startTime; // Selected start time.
  DateTime? _estimatedEndTime; // Estimated end time.
  DateTime? _eventStartDate; // Event start date.
  DateTime? _eventEndDate; // Event end date.

  // Manifest Data
  Manifest? _manifest;
  List<ManifestItem> _loadedItems = [];
  bool _isLoadingManifest = false;
  String? _manifestError;
  bool _vehicleHasAllItems = false;

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
  Timer? _debounceTimer; // Timer for debouncing.
  bool _mapInitialized = false; // Map initialization state.

  // Constants
  static const String osmRoutingUrl =
      'https://router.project-osrm.org/route/v1/driving/'; // URL for routing API.
  static const LatLng defaultLocation =
      LatLng(34.2381, -118.5267); // Default location coordinates.

  @override
  void initState() {
    super.initState();
    _initializeControllers(); // Initialize text controllers.
    _initializeLocation(); // Initialize location services.
    _loadLastKnownLocation(); // Load last known location from local storage.
  }

  @override
  void dispose() {
    _pickupAddressController.dispose(); // Dispose pickup address controller.
    _deliveryAddressController
        .dispose(); // Dispose delivery address controller.
    _notesController.dispose(); // Dispose notes controller.
    _mapController.dispose(); // Dispose map controller.
    _debounceTimer?.cancel(); // Cancel debounce timer if active.
    super.dispose();
  }

  void _initializeControllers() {
    _pickupAddressController =
        TextEditingController(); // Initialize pickup address controller.
    _deliveryAddressController =
        TextEditingController(); // Initialize delivery address controller.
    _notesController = TextEditingController(); // Initialize notes controller.
  }

  Future<void> _loadLastKnownLocation() async {
    try {
      final prefs = await SharedPreferences
          .getInstance(); // Get shared preferences instance.
      final lat = prefs.getDouble('last_known_lat'); // Get last known latitude.
      final lng =
          prefs.getDouble('last_known_lng'); // Get last known longitude.

      if (lat != null && lng != null) {
        setState(() {
          _currentLocation =
              LatLng(lat, lng); // Set current location from stored values.
        });
      }
    } catch (e) {
      _handleError(
          'Error loading last location', e); // Handle error if loading fails.
    }
  }

  Future<void> _initializeLocation() async {
    try {
      final status = await Geolocator
          .checkPermission(); // Check location permission status.
      if (status == LocationPermission.denied) {
        final requestStatus = await Geolocator
            .requestPermission(); // Request location permission.
        if (requestStatus == LocationPermission.denied) {
          _handleLocationPermissionDenied(); // Handle permission denied.
          return;
        }
      }

      if (status == LocationPermission.deniedForever) {
        _handleLocationPermissionDenied(
            permanent: true); // Handle permanently denied permission.
        return;
      }

      // Get current position with the newer settings approach
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, // Set high accuracy for location.
          timeLimit:
              Duration(seconds: 5), // Set time limit for location request.
        ),
      );

      final location = LatLng(position.latitude,
          position.longitude); // Create LatLng from position.

      if (mounted) {
        setState(() {
          _currentLocation = location; // Set current location.
          _pickupLocation =
              location; // Set pickup location to current location.
        });

        await _saveCurrentLocation(
            location); // Save current location to local storage.
        await _getAddressFromCoordinates(
            location, true); // Get address from coordinates.
        _updateMapCamera(location); // Update map camera to current location.
      }
    } catch (e) {
      debugPrint(
          'Error getting current position: $e'); // Print error if getting position fails.
      await _tryLastKnownPosition(); // Try to get last known position if current position fails.
    }
  }

  void _handleLocationPermissionDenied({bool permanent = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            permanent
                ? 'Location permission permanently denied. Please enable in settings.' // Message for permanently denied permission.
                : 'Location permission is required for better experience', // Message for temporarily denied permission.
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: permanent
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: () => Geolocator
                      .openAppSettings(), // Open app settings if permission is permanently denied.
                )
              : null,
        ),
      );
      setState(() {
        _currentLocation =
            defaultLocation; // Set current location to default if permission is denied.
      });
      _updateMapCamera(
          defaultLocation); // Update map camera to default location.
    }
  }

  Future<void> _saveCurrentLocation(LatLng location) async {
    try {
      final prefs = await SharedPreferences
          .getInstance(); // Get shared preferences instance.
      await prefs.setDouble('last_known_lat',
          location.latitude); // Save latitude to local storage.
      await prefs.setDouble('last_known_lng',
          location.longitude); // Save longitude to local storage.
    } catch (e) {
      _handleError('Error saving location', e); // Handle error if saving fails.
    }
  }

  Future<void> _tryLastKnownPosition() async {
    try {
      final position =
          await Geolocator.getLastKnownPosition(); // Get last known position.
      if (position != null && mounted) {
        final location = LatLng(position.latitude,
            position.longitude); // Create LatLng from position.
        setState(() {
          _currentLocation = location; // Set current location.
          _pickupLocation =
              location; // Set pickup location to last known location.
        });
        await _getAddressFromCoordinates(
            location, true); // Get address from coordinates.
        _updateMapCamera(location); // Update map camera to last known location.
      } else {
        setState(() {
          _currentLocation =
              defaultLocation; // Set current location to default if no last known position.
        });
        _updateMapCamera(
            defaultLocation); // Update map camera to default location.
      }
    } catch (e) {
      _handleError('Error getting last position',
          e); // Handle error if getting last position fails.
      setState(() {
        _currentLocation =
            defaultLocation; // Set current location to default if error occurs.
      });
      _updateMapCamera(
          defaultLocation); // Update map camera to default location.
    }
  }

  void _handleError(String message, dynamic error) {
    debugPrint('$message: $error'); // Print error message.
    if (mounted) {
      setState(() {
        _errorMessage = '$message: ${error.toString()}'; // Set error message.
        _isLoading = false; // Set loading state to false.
      });
    }
  }

  void _updateMapCamera(LatLng target) {
    _mapController.moveCamera(target); // Move map camera to target location.
  }

  Future<void> _getAddressFromCoordinates(
      LatLng location, bool isPickup) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}', // URL for reverse geocoding.
        ),
        headers: {
          'Accept': 'application/json',
          'User-Agent':
              'CateredToYou/1.0', // User-Agent header for the request.
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body); // Decode JSON response.
        final address = data['display_name']; // Get address from response.
        setState(() {
          if (isPickup) {
            _pickupAddressController.text = address; // Set pickup address.
          } else {
            _deliveryAddressController.text = address; // Set delivery address.
          }
        });
      }
    } catch (e) {
      _handleError(
          'Error getting address', e); // Handle error if getting address fails.
    }
  }

  Future<void> _searchAddress(String query, bool isPickup) async {
    if (query.length < 3) return; // Return if query is too short.

    _debounceTimer?.cancel(); // Cancel previous debounce timer.
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        setState(() => _isLoading = true); // Set loading state to true.

        final response = await http.get(
          Uri.parse(
            'https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=5&countrycodes=us', // URL for address search.
          ),
          headers: {
            'Accept': 'application/json',
            'User-Agent':
                'CateredToYou/1.0', // User-Agent header for the request.
          },
        );

        if (!mounted) return;

        if (response.statusCode == 200) {
          final results =
              json.decode(response.body) as List; // Decode JSON response.
          if (results.isNotEmpty) {
            await _showAddressSuggestions(
                results, isPickup); // Show address suggestions.
          }
        }
      } catch (e) {
        _handleError('Error searching address',
            e); // Handle error if searching address fails.
      } finally {
        if (mounted) {
          setState(() => _isLoading = false); // Set loading state to false.
        }
      }
    });
  }

  Future<void> _showAddressSuggestions(List results, bool isPickup) async {
    if (!mounted) return;

    // Find the RenderObject of the text field to position the suggestions properly
    final RenderBox? textFieldBox = isPickup
        ? _pickupAddressKey.currentContext?.findRenderObject() as RenderBox?
        : _deliveryAddressKey.currentContext?.findRenderObject() as RenderBox?;

    if (textFieldBox == null) {
      // Fallback to modal bottom sheet if we can't find the text field position
      await _showAddressSuggestionsBottomSheet(results, isPickup);
      return;
    }

    // Get the position and size of the text field
    final textFieldPosition = textFieldBox.localToGlobal(Offset.zero);
    final textFieldSize = textFieldBox.size;

    // Calculate the position for the popup
    // Position it below the text field with a small offset
    final offset = Offset(0, textFieldSize.height + 5);
    final position = textFieldPosition + offset;

    // Show a dropdown menu at the calculated position
    final selected = await showMenu<Map<String, dynamic>>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + textFieldSize.width,
        position.dy +
            20.0, // This value doesn't matter much as the menu adapts its height
      ),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // Set a reasonable limit to the menu height
      constraints: BoxConstraints(
        maxWidth: textFieldSize.width,
        maxHeight: MediaQuery.of(context).size.height *
            0.4, // Limit to 40% of screen height
      ),
      items: results.map<PopupMenuItem<Map<String, dynamic>>>((result) {
        return PopupMenuItem<Map<String, dynamic>>(
          value: result,
          padding: EdgeInsets.zero, // Remove default padding
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

    // Process the selected address
    if (selected != null) {
      _processSelectedAddress(selected, isPickup);
    }
  }

// Helper method to format an address for display
  String _formatAddressForDisplay(String fullAddress) {
    // Extract just the main part of the address (typically the first comma-separated part)
    final parts = fullAddress.split(',');
    if (parts.isEmpty) return fullAddress;
    return parts[0].trim();
  }

// Helper method to process the selected address
  void _processSelectedAddress(Map<String, dynamic> selected, bool isPickup) {
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

    _updateMapMarkersAndPolylines();

    if (_pickupLocation != null && _deliveryLocation != null) {
      _getRouteDetails();
    }

    _updateMapBounds();
  }

// Fallback method if we can't determine text field position
  Future<void> _showAddressSuggestionsBottomSheet(
      List results, bool isPickup) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height *
              0.6, // Limit to 60% of screen height
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
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withAlpha((0.4 * 255).toInt()),
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
            // Add a safe area at the bottom for notched devices
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );

    // Process the selected address
    if (selected != null) {
      _processSelectedAddress(selected, isPickup);
    }
  }

  Future<void> _getRouteDetails() async {
    if (_pickupLocation == null || _deliveryLocation == null) return;

    setState(() => _isLoading = true); // Set loading state to true.

    try {
      final url =
          '$osmRoutingUrl${_pickupLocation!.longitude},${_pickupLocation!.latitude};'
          '${_deliveryLocation!.longitude},${_deliveryLocation!.latitude}'
          '?overview=full&geometries=geojson&steps=true'; // URL for routing API.

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'}, // Accept JSON response.
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body); // Decode JSON response.
        if (data['code'] == 'Ok') {
          final route = data['routes'][0];

          // Extract route points from GeoJSON geometry
          final coordinates = route['geometry']['coordinates'] as List;
          final points = coordinates
              .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
              .toList();

          // Calculate estimated time with traffic
          final baseDuration = route['duration'] as num;
          final distance = route['distance'] as num;
          final trafficFactor = 1.3; // Assume 30% more time during traffic
          final durationWithTraffic = baseDuration * trafficFactor;

          setState(() {
            _routeDetails = {
              'distance':
                  '${(distance * 0.000621371).toStringAsFixed(1)} miles', // Convert distance to miles.
              'duration':
                  '${(baseDuration / 60).toStringAsFixed(0)} min', // Convert duration to minutes.
              'durationWithTraffic':
                  '${(durationWithTraffic / 60).toStringAsFixed(0)} min', // Convert duration with traffic to minutes.
              'steps': route['legs'][0]['steps'], // Route steps.
            };
            _routePoints = points.cast<LatLng>(); // Set route points.
          });

          _updateMapMarkersAndPolylines(); // Update map markers and polylines.

          if (_startTime != null) {
            setState(() {
              _estimatedEndTime = _startTime!.add(
                Duration(
                    seconds: durationWithTraffic
                        .round()), // Calculate estimated end time.
              );
            });
          }
        }
      }
    } catch (e) {
      _handleError('Error getting route details',
          e); // Handle error if getting route details fails.
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); // Set loading state to false.
      }
    }
  }

  void _updateMapMarkersAndPolylines() {
    final markers = <Marker>[]; // Initialize an empty list of markers.

    if (_pickupLocation != null) {
      markers.add(MapMarkerHelper.createMarker(
        point: _pickupLocation!, // Add a marker for the pickup location.
        id: 'pickup', // Set the marker ID to 'pickup'.
        color: Colors.green, // Set the marker color to green.
        icon: Icons.location_on, // Set the marker icon.
        title: 'Pickup', // Set the marker title.
      ));
    }

    if (_deliveryLocation != null) {
      markers.add(MapMarkerHelper.createMarker(
        point: _deliveryLocation!, // Add a marker for the delivery location.
        id: 'delivery', // Set the marker ID to 'delivery'.
        color: Colors.red, // Set the marker color to red.
        icon: Icons.location_on, // Set the marker icon.
        title: 'Delivery', // Set the marker title.
      ));
    }

    final polylines = <Polyline>[]; // Initialize an empty list of polylines.
    if (_routePoints.isNotEmpty) {
      polylines.add(MapMarkerHelper.createRoute(
        points: _routePoints, // Add a polyline for the route points.
        color: Theme.of(context).colorScheme.primary, // Set the polyline color.
      ));
    }

    _mapController
        .updateMarkers(markers); // Update the map with the new markers.
    _mapController
        .updatePolylines(polylines); // Update the map with the new polylines.
  }

  void _updateMapBounds() {
    if (_pickupLocation == null || _deliveryLocation == null) {
      return; // Return if either location is null.
    }

    final points = [
      _pickupLocation!,
      _deliveryLocation!
    ]; // Create a list of points with pickup and delivery locations.
    if (_currentLocation != null) {
      points.add(
          _currentLocation!); // Add the current location to the points list if it's not null.
    }

    _mapController.fitBounds(
      points, // Fit the map bounds to include all points.
      padding: const EdgeInsets.all(50), // Add padding around the bounds.
    );
  }

  Future<void> _fetchManifestForEvent(String eventId) async {
    setState(() {
      _isLoadingManifest = true;
      _manifestError = null;
      _loadedItems = [];
    });

    try {
      final manifestService =
          Provider.of<ManifestService>(context, listen: false);

      // Check if manifest exists for this event
      final exists = await manifestService.doesManifestExist(eventId);
      if (!exists) {
        setState(() {
          _isLoadingManifest = false;
          _manifestError = 'No manifest found for this event';
          _manifest = null;
        });
        return;
      }

      // Get manifest stream for the event
      final manifestStream = manifestService.getManifestByEventId(eventId);
      final manifest = await manifestStream.first;

      setState(() {
        _manifest = manifest;
        _isLoadingManifest = false;

        if (manifest == null) {
          _manifestError = 'Error loading manifest';
        }
      });

      // If both manifest and vehicle are selected, check loaded items
      if (_manifest != null && _selectedVehicleId != null) {
        _checkLoadedItems();
      }
    } catch (e) {
      setState(() {
        _isLoadingManifest = false;
        _manifestError = 'Error: ${e.toString()}';
        _manifest = null;
      });
    }
  }

  void _checkLoadedItems() {
    if (_manifest == null || _selectedVehicleId == null) return;

    final vehicleId = _selectedVehicleId!;

    // Filter items assigned to this vehicle and loaded
    final itemsForVehicle =
        _manifest!.items.where((item) => item.vehicleId == vehicleId).toList();

    final loadedItems = itemsForVehicle
        .where((item) => item.loadingStatus == LoadingStatus.loaded)
        .toList();

    setState(() {
      _loadedItems = loadedItems;
      // Check if all assigned items are loaded
      _vehicleHasAllItems = loadedItems.length == itemsForVehicle.length &&
          itemsForVehicle.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Delivery'), // Set the app bar title.
      ),
      body: Form(
        key: _formKey, // Set the form key for validation.
        child: ListView(
          padding:
              const EdgeInsets.all(16), // Add padding around the list view.
          children: [
            if (_errorMessage != null)
              _buildErrorCard(), // Show error card if there's an error message.
            _buildEventSection(), // Build the event section.
            const SizedBox(height: 16), // Add vertical spacing.
            _buildLocationSection(), // Build the location section.
            _buildDeliveryDetailsSection(), // Build the delivery details section.
            if (_manifest != null && _loadedItems.isNotEmpty)
              _buildLoadedItemsSection(),
            _buildNotesSection(), // Build the notes section.
            const SizedBox(height: 24), // Add vertical spacing.
            _buildSubmitButton(), // Build the submit button.
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16), // Add padding inside the card.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment
              .stretch, // Stretch children to fill the column width.
          children: [
            Text(
              'Delivery Locations', // Section title.
              style:
                  Theme.of(context).textTheme.titleLarge, // Set the text style.
            ),
            const SizedBox(height: 16), // Add vertical spacing.
            _buildAddressInput(
              controller:
                  _pickupAddressController, // Set the controller for the pickup address input.
              label:
                  'Pickup Location', // Set the label for the pickup address input.
              hint:
                  'Enter pickup address', // Set the hint for the pickup address input.
              isPickup: true, // Indicate that this is the pickup address input.
            ),
            const SizedBox(height: 16), // Add vertical spacing.
            _buildAddressInput(
              controller:
                  _deliveryAddressController, // Set the controller for the delivery address input.
              label:
                  'Delivery Location', // Set the label for the delivery address input.
              hint:
                  'Enter delivery address', // Set the hint for the delivery address input.
              isPickup:
                  false, // Indicate that this is the delivery address input.
            ),
            const SizedBox(height: 16), // Add vertical spacing.
            _buildMapSection(), // Build the map section.
            if (_routeDetails != null) ...[
              const SizedBox(height: 16), // Add vertical spacing.
              _buildRouteDetails(), // Build the route details section.
            ],
          ],
        ),
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
      key: key, // Add the key here
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
                    _updateMapMarkersAndPolylines();
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
          return isPickup
              ? 'Please enter pickup location'
              : 'Please enter delivery location';
        }
        return null;
      },
    );
  }

  Widget _buildMapSection() {
    return SizedBox(
      height: 300, // Set the height of the map section.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12), // Set the border radius.
        child: Stack(
          fit: StackFit.expand, // Expand the stack to fill the available space.
          children: [
            DeliveryMap(
              mapController:
                  _mapController.mapController, // Set the map controller.
              markers: _mapController.markers, // Set the markers.
              polylines: _mapController.polylines, // Set the polylines.
              initialPosition: _currentLocation ??
                  defaultLocation, // Set the initial position.
              isLoading: _isLoading, // Set the loading state.
              onMapTap: (tapPosition, point) async {
                if (_pickupLocation == null) {
                  setState(() => _pickupLocation =
                      point); // Set the pickup location on map tap.
                  await _getAddressFromCoordinates(
                      point, true); // Get the address from coordinates.
                } else if (_deliveryLocation == null) {
                  setState(() => _deliveryLocation =
                      point); // Set the delivery location on map tap.
                  await _getAddressFromCoordinates(
                      point, false); // Get the address from coordinates.
                }
                _updateMapMarkersAndPolylines(); // Update the map markers and polylines.
                if (_pickupLocation != null && _deliveryLocation != null) {
                  await _getRouteDetails(); // Get the route details if both locations are set.
                  _updateMapBounds(); // Update the map bounds.
                }
              },
              onMapReady: () {
                if (_currentLocation != null && !_mapInitialized) {
                  _updateMapCamera(
                      _currentLocation!); // Update the map camera to the current location.
                  _mapInitialized =
                      true; // Set the map initialized flag to true.
                }
              },
            ),
            Positioned(
              right: 16, // Position the button 16 pixels from the right.
              bottom: 16, // Position the button 16 pixels from the bottom.
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Minimize the column size.
                  children: [
                    if (_currentLocation != null)
                      FloatingActionButton.small(
                        heroTag:
                            'my_location', // Set the hero tag for the button.
                        onPressed: () => _updateMapCamera(
                            _currentLocation!), // Update the map camera to the current location.
                        child: const Icon(
                            Icons.my_location), // Set the button icon.
                      ),
                    if (_pickupLocation != null &&
                        _deliveryLocation != null) ...[
                      const SizedBox(height: 8), // Add vertical spacing.
                      FloatingActionButton.small(
                        heroTag:
                            'fit_bounds', // Set the hero tag for the button.
                        onPressed: _updateMapBounds, // Update the map bounds.
                        child: const Icon(Icons.route), // Set the button icon.
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black
                      .withAlpha((0.3 * 255).toInt()), // Set the overlay color.
                  child: const Center(
                    child:
                        CircularProgressIndicator(), // Show a loading indicator.
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteDetails() {
    return Padding(
      padding: const EdgeInsets.only(top: 16), // Add padding at the top.
      child: Container(
        padding: const EdgeInsets.all(12), // Add padding inside the container.
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest, // Set the background color.
          borderRadius: BorderRadius.circular(8), // Set the border radius.
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start, // Align children to the start.
          children: [
            Text(
              'Route Details', // Section title.
              style: Theme.of(context)
                  .textTheme
                  .titleMedium, // Set the text style.
            ),
            const SizedBox(height: 8), // Add vertical spacing.
            Row(
              children: [
                const Icon(Icons.straighten, size: 18), // Set the icon.
                const SizedBox(width: 8), // Add horizontal spacing.
                Text(
                    'Distance: ${_routeDetails!['distance']}'), // Show the route distance.
              ],
            ),
            const SizedBox(height: 4), // Add vertical spacing.
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 18), // Set the icon.
                const SizedBox(width: 8), // Add horizontal spacing.
                Text(
                    'Normal duration: ${_routeDetails!['duration']}'), // Show the normal duration.
              ],
            ),
            const SizedBox(height: 4), // Add vertical spacing.
            Row(
              children: [
                const Icon(Icons.traffic, size: 18), // Set the icon.
                const SizedBox(width: 8), // Add horizontal spacing.
                Text(
                    'With traffic: ${_routeDetails!['durationWithTraffic']}'), // Show the duration with traffic.
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16), // Add padding inside the card.
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start, // Align children to the start.
          children: [
            Text(
              'Delivery Details', // Section title.
              style:
                  Theme.of(context).textTheme.titleLarge, // Set the text style.
            ),
            const SizedBox(height: 16), // Add vertical spacing.
            _buildVehicleDropdown(), // Build the vehicle dropdown.
            const SizedBox(height: 16), // Add vertical spacing.
            _buildDriverDropdown(), // Build the driver dropdown.
            const SizedBox(height: 16), // Add vertical spacing.
            _buildTimePickers(), // Build the time pickers.
          ],
        ),
      ),
    );
  }

  // Build the vehicle dropdown for selecting the vehicle.
  Widget _buildLoadedItemsSection() {
    return Card(
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
                Text(
                  'Manifest Items for Delivery',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _vehicleHasAllItems
                  ? 'All items are loaded and ready for delivery'
                  : 'Some items may not be loaded yet',
              style: TextStyle(
                color: _vehicleHasAllItems ? Colors.green : Colors.orange,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _loadedItems.length,
              itemBuilder: (context, index) {
                final item = _loadedItems[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2, color: Colors.green),
                    title: Text(item.name),
                    subtitle: Text('Quantity: ${item.quantity}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventSection() {
    final orgService = context.read<
        OrganizationService>(); // Access the OrganizationService to fetch the current user's organization.

    return FutureBuilder<String?>(
      future: orgService.getCurrentUserOrganization().then((org) =>
          org?.id), // Fetch the current user's organization ID asynchronously.
      builder: (context, orgSnapshot) {
        if (!orgSnapshot.hasData) {
          return const Center(
              child:
                  CircularProgressIndicator()); // Show a loading indicator while the organization data is being fetched.
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment
              .start, // Align children to the start of the column.
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(
                      'events') // Access the 'events' collection in Firestore.
                  .where('organizationId',
                      isEqualTo: orgSnapshot
                          .data) // Filter events by the current user's organization ID.
                  .where('status', whereIn: [
                'confirmed',
                'in_progress'
              ]).snapshots(), // Filter events with statuses 'confirmed' or 'in_progress'.
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                      'Error: ${snapshot.error}'); // Display an error message if there's an issue with the Firestore query.
                }

                if (!snapshot.hasData) {
                  return const Center(
                      child:
                          CircularProgressIndicator()); // Show a loading indicator while event data is being fetched.
                }

                final events = snapshot
                    .data!.docs; // Retrieve the list of event documents.

                return DropdownButtonFormField<String>(
                  value:
                      _selectedEventId, // Set the currently selected event ID.
                  decoration: const InputDecoration(
                    labelText: 'Select Event', // Label for the dropdown.
                    hintText:
                        'Choose an event for delivery', // Hint text for the dropdown.
                    prefixIcon: Icon(Icons
                        .event), // Icon to indicate the dropdown is for events.
                  ),
                  items: events.map((doc) {
                    final data = doc.data() as Map<String,
                        dynamic>; // Extract the event data from the document.
                    return DropdownMenuItem(
                      value: doc.id, // Set the event ID as the value.
                      child: Text(data['name'] ??
                          'Unnamed Event'), // Display the event name or a fallback if it's unnamed.
                    );
                  }).toList(), // Convert the list of events into dropdown menu items.
                  onChanged: (value) {
                    if (value != null) {
                      _handleEventSelection(
                          value); // Handle the event selection and fetch its details.
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select an event'; // Validate that an event is selected.
                    }
                    return null;
                  },
                );
              },
            ),

            // Display manifest status - moved outside the dropdown
            if (_isLoadingManifest)
              Padding(
                padding: const EdgeInsets.only(
                    top: 8.0), // Add spacing above the loading indicator.
                child: Row(
                  children: const [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth:
                              2), // Show a small loading indicator for manifest loading.
                    ),
                    SizedBox(
                        width:
                            8), // Add spacing between the indicator and the text.
                    Text(
                        'Loading manifest...'), // Inform the user that the manifest is being loaded.
                  ],
                ),
              )
            else if (_manifestError != null)
              Padding(
                padding: const EdgeInsets.only(
                    top: 8.0), // Add spacing above the error message.
                child: Text(
                  _manifestError!, // Display the manifest error message.
                  style: TextStyle(
                      color: Colors
                          .red.shade700), // Style the error message in red.
                ),
              )
            else if (_manifest != null)
              Padding(
                padding: const EdgeInsets.only(
                    top: 8.0), // Add spacing above the manifest status.
                child: Text(
                  'Manifest loaded: ${_manifest!.items.length} items', // Display the number of items in the loaded manifest.
                  style: const TextStyle(
                      color: Colors
                          .green), // Style the message in green to indicate success.
                ),
              ),
          ],
        );
      },
    );
  }

  /// Handles the selection of an event from the dropdown and fetches its details.
  Future<void> _handleEventSelection(String value) async {
    // Ensure the selected value is not null or empty.
    try {
      setState(() => _isLoading = true);

      final eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(value)
          .get();

      if (eventDoc.exists && mounted) {
        final data = eventDoc.data()!;
        final startDate = (data['startDate'] as Timestamp).toDate();
        final endDate = (data['endDate'] as Timestamp).toDate();

        setState(() {
          _selectedEventId = value;
          _selectedEventName = data['name'];
          _eventStartDate = startDate;
          _eventEndDate = endDate;

          // Reset time selections when event changes
          _startTime = null;
          _estimatedEndTime = null;

          // Reset manifest data
          _manifest = null;
          _loadedItems = [];
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Event duration: ${DateFormat('MMM d, h:mm a').format(startDate)} - '
                  '${DateFormat('MMM d, h:mm a').format(endDate)}'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Fetch manifest for this event
        await _fetchManifestForEvent(value);
      }
    } catch (e) {
      _handleError('Error loading event details', e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildVehicleDropdown() {
    return Consumer<VehicleService>(
      builder: (context, vehicleService, _) {
        return StreamBuilder<List<Vehicle>>(
          stream: vehicleService.getVehicles(), // Get the list of vehicles.
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                  'Error: ${snapshot.error}'); // Show an error message if there's an error.
            }

            if (!snapshot.hasData) {
              return const Center(
                  child:
                      CircularProgressIndicator()); // Show a loading indicator if the vehicles are not available.
            }

            final vehicles = snapshot.data!
                .where((vehicle) =>
                    vehicle.status ==
                    VehicleStatus.available) // Filter available vehicles.
                .toList();

            if (vehicles.isEmpty) {
              return const Text(
                  'No available vehicles'); // Show a message if there are no available vehicles.
            }

            return DropdownButtonFormField<String>(
              value: _selectedVehicleId, // Set the selected vehicle ID.
              decoration: const InputDecoration(
                labelText: 'Select Vehicle', // Set the label text.
                hintText: 'Choose a vehicle', // Set the hint text.
                prefixIcon: Icon(Icons.local_shipping), // Set the prefix icon.
              ),
              items: vehicles.map((vehicle) {
                return DropdownMenuItem(
                  value: vehicle.id, // Set the vehicle ID.
                  child: Text(
                      '${vehicle.make} ${vehicle.model} - ${vehicle.licensePlate}'), // Set the vehicle details.
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedVehicleId = value;
                  // Check for loaded items in this vehicle if manifest is available
                  if (_manifest != null && _selectedVehicleId != null) {
                    _checkLoadedItems();
                  }
                });
              }, // Handle vehicle selection.
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a vehicle'; // Validate the input.
                }
                return null;
              },
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

            // Modified: Allow any active staff to be a driver (removed role filter)
            final drivers = snapshot.data!
                .where((staff) => staff.employmentStatus == 'active')
                .toList();

            if (drivers.isEmpty) {
              return const Text('No available staff members');
            }

            return DropdownButtonFormField<String>(
              value: _selectedDriverId,
              decoration: const InputDecoration(
                labelText: 'Select Driver',
                hintText: 'Choose a driver',
                prefixIcon: Icon(Icons.person),
              ),
              items: drivers.map((driver) {
                return DropdownMenuItem(
                  value: driver.uid,
                  child: Text(
                      '${driver.firstName} ${driver.lastName}${driver.role == 'driver' ? ' (Driver)' : ''}'),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedDriverId = value),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a driver';
                }
                return null;
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
          title: const Text(
              'Start Time'), // Set the title for the start time picker.
          subtitle: Text(
            _startTime != null
                ? DateFormat('h:mm a')
                    .format(_startTime!) // Format the selected start time.
                : 'Select start time', // Show hint text if no start time is selected.
          ),
          trailing: const Icon(Icons.access_time), // Set the trailing icon.
          onTap: () =>
              _selectStartTime(), // Show the start time picker when tapped.
        ),
        const SizedBox(height: 8), // Add vertical spacing.
        ListTile(
          title: const Text(
              'Estimated End Time'), // Set the title for the estimated end time picker.
          subtitle: Text(
            _estimatedEndTime != null
                ? DateFormat('h:mm a').format(
                    _estimatedEndTime!) // Format the selected estimated end time.
                : 'Select estimated end time', // Show hint text if no estimated end time is selected.
          ),
          trailing: const Icon(Icons.access_time), // Set the trailing icon.
          onTap: () =>
              _selectEndTime(), // Show the estimated end time picker when tapped.
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: SingleChildScrollView(
        // Add this
        padding: const EdgeInsets.all(16), // Add padding inside the card.
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start, // Align children to the start.
          children: [
            Text(
              'Additional Notes', // Set the section title.
              style:
                  Theme.of(context).textTheme.titleLarge, // Set the text style.
            ),
            const SizedBox(height: 16), // Add vertical spacing.
            TextFormField(
              controller:
                  _notesController, // Set the controller for the notes input.
              decoration: const InputDecoration(
                hintText:
                    'Enter any special instructions or notes', // Set the hint text.
                border: OutlineInputBorder(), // Set the border style.
              ),
              maxLines: 3, // Allow multiple lines of input.
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Theme.of(context)
          .colorScheme
          .errorContainer, // Set the background color.
      child: Padding(
        padding: const EdgeInsets.all(16), // Add padding inside the card.
        child: Row(
          children: [
            Icon(
              Icons.error_outline, // Set the error icon.
              color: Theme.of(context).colorScheme.error, // Set the icon color.
            ),
            const SizedBox(width: 16), // Add horizontal spacing.
            Expanded(
              child: Text(
                _errorMessage!, // Show the error message.
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .error, // Set the text color.
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close), // Set the close icon.
              onPressed: () => setState(() => _errorMessage =
                  null), // Clear the error message when the button is pressed.
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed:
          _isLoading ? null : _submitForm, // Disable the button if loading.
      child: _isLoading
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2), // Show loading indicator.
                ),
                SizedBox(width: 12), // Add horizontal spacing.
                Text('Creating Delivery...'), // Show loading text.
              ],
            )
          : const Text('Create Delivery'), // Show submit text.
    );
  }

  Future<void> _selectStartTime() async {
    if (_eventStartDate == null || _eventEndDate == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please select an event first'), // Show message if no event is selected.
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;

    // Calculate valid date range
    final DateTime firstValidDate = _eventStartDate!
        .subtract(const Duration(days: 7)); // Set the first valid date.
    final DateTime lastValidDate = _eventEndDate!; // Set the last valid date.
    final DateTime initialDate = DateTime.now().isAfter(firstValidDate)
        ? DateTime.now()
        : firstValidDate; // Set the initial date.

    // First select date
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate, // Set the initial date.
      firstDate: firstValidDate, // Set the first valid date.
      lastDate: lastValidDate, // Set the last valid date.
    );

    if (selectedDate == null || !mounted) return;

    // Then select time
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(), // Set the initial time.
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surface, // Set the background color.
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null && mounted) {
      final selectedDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        time.hour,
        time.minute,
      );

      setState(() {
        _startTime = selectedDateTime; // Set the selected start time.
        // Automatically update estimated end time based on route details
        if (_routeDetails != null) {
          final trafficDuration = _routeDetails![
              'durationWithTraffic']; // Get the traffic duration.
          if (trafficDuration != null) {
            final minutes = int.tryParse(trafficDuration.replaceAll(
                RegExp(r'[^0-9]'), '')); // Parse the duration.
            if (minutes != null) {
              _estimatedEndTime = _startTime!.add(
                  Duration(minutes: minutes)); // Set the estimated end time.
            }
          }
        }
      });
    }
  }

  Future<void> _selectEndTime() async {
    if (_startTime == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please select start time first'), // Show message if no start time is selected.
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    // First select date
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _estimatedEndTime ?? _startTime!, // Set the initial date.
      firstDate: _startTime!, // Set the first valid date.
      lastDate: _eventEndDate!
          .add(const Duration(days: 1)), // Set the last valid date.
    );

    if (selectedDate == null || !mounted) return;

    // Then select time
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _estimatedEndTime != null
          ? TimeOfDay.fromDateTime(_estimatedEndTime!) // Set the initial time.
          : TimeOfDay.fromDateTime(_startTime!
              .add(const Duration(hours: 1))), // Set the initial time.
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surface, // Set the background color.
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null && mounted) {
      final selectedDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        time.hour,
        time.minute,
      );

      if (selectedDateTime.isBefore(_startTime!)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'End time must be after start time'), // Show message if end time is before start time.
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() =>
          _estimatedEndTime = selectedDateTime); // Set the selected end time.
    }
  }

  Future<void> _submitForm() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true; // Set loading state to true.
      _errorMessage = null; // Clear error message.
    });

    try {
      final deliveryService = context
          .read<DeliveryRouteService>(); // Get the delivery route service.
      final currentUser =
          FirebaseAuth.instance.currentUser; // Get the current user.

      if (currentUser == null) {
        throw 'User not authenticated'; // Throw error if user is not authenticated.
      }

      // Convert LatLng to GeoPoint for Firestore
      final List<GeoPoint> waypoints = [
        GeoPoint(_pickupLocation!.latitude,
            _pickupLocation!.longitude), // Convert pickup location to GeoPoint.
        GeoPoint(
            _deliveryLocation!.latitude,
            _deliveryLocation!
                .longitude), // Convert delivery location to GeoPoint.
      ];

      // Create metadata with route information
      // Flatten nested structures to avoid array issues
      final metadata = {
        'notes': _notesController.text.trim(), // Add notes.
        'eventName': _selectedEventName, // Add event name.
        'pickupAddress': _pickupAddressController.text, // Add pickup address.
        'deliveryAddress':
            _deliveryAddressController.text, // Add delivery address.
        'distance': _routeDetails?['distance'], // Add distance.
        'estimatedDuration':
            _routeDetails?['duration'], // Add estimated duration.
        'trafficDuration':
            _routeDetails?['durationWithTraffic'], // Add traffic duration.
        'createdBy': currentUser.uid, // Add created by user ID.
        'updatedBy': currentUser.uid, // Add updated by user ID.
        'status': 'pending', // Set status to pending.
        'eventStartDate':
            _eventStartDate?.millisecondsSinceEpoch, // Add event start date.
        'eventEndDate':
            _eventEndDate?.millisecondsSinceEpoch, // Add event end date.
        'lastUpdated':
            FieldValue.serverTimestamp(), // Add last updated timestamp.
        'vehicleHasAllItems': _vehicleHasAllItems, // Add vehicle items status.
        'loadedItemsCount': _loadedItems.length, // Add loaded items count.
        'loadedItems': _loadedItems // Add loaded items details.
            .map((item) => {
                  'id': item.id, // Add item ID.
                  'name': item.name, // Add item name.
                  'quantity': item.quantity, // Add item quantity.
                  'menuItemId': item.menuItemId, // Add menu item ID.
                })
            .toList(), // Convert loaded items to a list of maps.
      };

      // Create delivery route
      await deliveryService.createDeliveryRoute(
        eventId: _selectedEventId!, // Add event ID.
        vehicleId: _selectedVehicleId!, // Add vehicle ID.
        driverId: _selectedDriverId!, // Add driver ID.
        startTime: _startTime!, // Add start time.
        estimatedEndTime: _estimatedEndTime!, // Add estimated end time.
        waypoints: waypoints, // Add waypoints.
        metadata: metadata, // Add metadata.
      );
      await deliveryService.initializeRouteMetrics(metadata['routeId']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Delivery route created successfully'), // Show success message.
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop(); // Navigate back.
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'Error creating delivery route: $e'; // Set error message.
        _isLoading = false; // Set loading state to false.
      });
    }
  }

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) return false;

    if (_startTime == null) {
      _setError(
          'Please select a start time'); // Show error if no start time is selected.
      return false;
    }

    if (_estimatedEndTime == null) {
      _setError(
          'Please select an estimated end time'); // Show error if no estimated end time is selected.
      return false;
    }

    if (_pickupLocation == null) {
      _setError(
          'Please select a pickup location'); // Show error if no pickup location is selected.
      return false;
    }

    if (_deliveryLocation == null) {
      _setError(
          'Please select a delivery location'); // Show error if no delivery location is selected.
      return false;
    }

    if (_selectedEventId == null) {
      _setError(
          'Please select an event'); // Show error if no event is selected.
      return false;
    }

    if (_selectedVehicleId == null) {
      _setError(
          'Please select a vehicle'); // Show error if no vehicle is selected.
      return false;
    }

    if (_selectedDriverId == null) {
      _setError(
          'Please select a driver'); // Show error if no driver is selected.
      return false;
    }

    if (_routeDetails == null) {
      _setError(
          'Unable to calculate route details. Please try again.'); // Show error if route details are not available.
      return false;
    }

    return true;
  }

  void _setError(String message) {
    setState(() => _errorMessage = message); // Set error message.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message), // Show error message.
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
