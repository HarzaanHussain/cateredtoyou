import 'package:flutter/material.dart'; // Importing Flutter material package for UI components
import 'package:flutter_map/flutter_map.dart'; // Importing flutter_map package for map functionalities
import 'package:latlong2/latlong.dart'; // Importing latlong2 package for handling geographical coordinates

class DeliveryMap extends StatefulWidget { // Defining a stateful widget for the delivery map
  final MapController mapController; // Controller for managing map state
  final List<Marker> markers; // List of markers to be displayed on the map
  final List<Polyline> polylines; // List of polylines to be displayed on the map
  final LatLng initialPosition; // Initial position of the map
  final double initialZoom; // Initial zoom level of the map
  final bool isLoading; // Flag to indicate if the map is loading
  final Function(TapPosition, LatLng)? onMapTap; // Callback for map tap events
  final VoidCallback? onMapReady; // Callback when the map is ready
  final bool showUserLocation; // Flag to indicate if user location should be shown

  const DeliveryMap({ // Constructor for initializing the DeliveryMap widget
    super.key,
    required this.mapController,
    required this.markers,
    required this.polylines,
    required this.initialPosition,
    this.initialZoom = 13.0,
    this.isLoading = false,
    this.onMapTap,
    this.onMapReady,
    this.showUserLocation = true,
  });

  @override
  State<DeliveryMap> createState() => _DeliveryMapState(); // Creating the state for the DeliveryMap widget
}

class _DeliveryMapState extends State<DeliveryMap> { // State class for DeliveryMap
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { // Adding a callback to be executed after the first frame
      if (widget.onMapReady != null) { // Checking if onMapReady callback is provided
        widget.onMapReady!(); // Calling the onMapReady callback
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) { // Checking if the map is loading
      return const Center(child: CircularProgressIndicator()); // Displaying a loading indicator
    }

    return Stack( // Using a Stack to overlay widgets
      children: [
        FlutterMap( // Main map widget
          mapController: widget.mapController, // Setting the map controller
          options: MapOptions( // Configuring map options
            initialCenter: widget.initialPosition, // Setting the initial center position
            initialZoom: widget.initialZoom, // Setting the initial zoom level
            onTap: widget.onMapTap, // Setting the tap callback
          ),
          children: [
            TileLayer( // Tile layer for displaying map tiles
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // URL template for map tiles
              userAgentPackageName: 'com.example.app', // User agent package name
            ),
            if (widget.polylines.isNotEmpty) // Checking if there are any polylines
              PolylineLayer(polylines: widget.polylines), // Adding polyline layer
            if (widget.markers.isNotEmpty) // Checking if there are any markers
              MarkerLayer(markers: widget.markers), // Adding marker layer
          ],
        ),
        Positioned( // Positioning the zoom buttons
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small( // Zoom in button
                heroTag: 'zoomIn',
                onPressed: () {
                  final currentZoom = widget.mapController.camera.zoom; // Getting the current zoom level
                  widget.mapController.move( // Moving the map to the new zoom level
                    widget.mapController.camera.center,
                    currentZoom + 1,
                  );
                },
                child: const Icon(Icons.add), // Icon for zoom in button
              ),
              const SizedBox(height: 8), // Spacing between buttons
              FloatingActionButton.small( // Zoom out button
                heroTag: 'zoomOut',
                onPressed: () {
                  final currentZoom = widget.mapController.camera.zoom; // Getting the current zoom level
                  widget.mapController.move( // Moving the map to the new zoom level
                    widget.mapController.camera.center,
                    currentZoom - 1,
                  );
                },
                child: const Icon(Icons.remove), // Icon for zoom out button
              ),
            ],
          ),
        ),
        if (widget.isLoading) // Checking if the map is loading
          Container( // Overlay for loading state
            color: Colors.black26, // Semi-transparent background
            child: const Center(
              child: CircularProgressIndicator(), // Loading indicator
            ),
          ),
      ],
    );
  }
}

// Helper class for creating markers
class MapMarkerHelper {
  static Marker createMarker({ // Method to create a marker
  required LatLng point, // Position of the marker
  required String id, // ID of the marker
  required Color color, // Color of the marker icon
  required IconData icon, // Icon for the marker
  String? title, // Optional title for the marker
  double size = 30, // Size of the marker icon
  VoidCallback? onTap, // Optional tap callback for the marker
}) {
  return Marker(
    point: point, // Setting the position of the marker
    width: size, // Setting the width of the marker
    height: size, // Setting the height of the marker
    child: GestureDetector( // Adding tap detection to the marker
      onTap: onTap, // Setting the tap callback
      child: Stack( // Using a stack to overlay the icon and title
        clipBehavior: Clip.none,
        children: [
          Icon(
            icon, // Setting the icon for the marker
            color: color, // Setting the color of the icon
            size: size, // Setting the size of the icon
          ),
          if (title != null) // Checking if a title is provided
            Positioned(
              bottom: -20, // Positioning the title below the icon
              left: 50 / 2 - 50, // Centering the title
              child: Container(
                width: 100, // Setting the width of the title container
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), // Adding padding to the title container
                decoration: BoxDecoration(
                  color: Colors.white, // Setting the background color of the title container
                  borderRadius: BorderRadius.circular(4), // Adding rounded corners to the title container
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.2 * 255).toInt()), // Adding a shadow to the title container
                      blurRadius: 4, // Setting the blur radius of the shadow
                    ),
                  ],
                ),
                child: Text(
                  title, // Setting the title text
                  textAlign: TextAlign.center, // Centering the title text
                  style: TextStyle(
                    color: color, // Setting the color of the title text
                    fontSize: 12, // Setting the font size of the title text
                    fontWeight: FontWeight.bold, // Setting the font weight of the title text
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

  static Polyline createRoute({ // Method to create a polyline
    required List<LatLng> points, // List of points for the polyline
    Color color = Colors.blue, // Color of the polyline
    double width = 4.0, // Width of the polyline
    bool isDashed = false, // Flag to indicate if the polyline is dashed
  }) {
    return Polyline(
      points: points, // Setting the points of the polyline
      color: color, // Setting the color of the polyline
      strokeWidth: width, // Setting the width of the polyline
      isDotted: isDashed, // Setting if the polyline is dashed
    );
  }
}

class MapBoundsHelper {
  static LatLngBounds calculateBounds(List<LatLng> points) { // Method to calculate the bounds of a list of points
    if (points.isEmpty) { // Checking if the points list is empty
      throw Exception('Cannot calculate bounds for empty points list'); // Throwing an exception if the list is empty
    }

    double minLat = points[0].latitude; // Initializing the minimum latitude
    double maxLat = points[0].latitude; // Initializing the maximum latitude
    double minLng = points[0].longitude; // Initializing the minimum longitude
    double maxLng = points[0].longitude; // Initializing the maximum longitude

    for (var point in points) { // Iterating through the points
      if (point.latitude < minLat) minLat = point.latitude; // Updating the minimum latitude
      if (point.latitude > maxLat) maxLat = point.latitude; // Updating the maximum latitude
      if (point.longitude < minLng) minLng = point.longitude; // Updating the minimum longitude
      if (point.longitude > maxLng) maxLng = point.longitude; // Updating the maximum longitude
    }

    return LatLngBounds( // Returning the calculated bounds
      LatLng(minLat, minLng), // Setting the southwest corner of the bounds
      LatLng(maxLat, maxLng), // Setting the northeast corner of the bounds
    );
  }

  static LatLng calculateCenter(List<LatLng> points) { // Method to calculate the center of a list of points
    if (points.isEmpty) { // Checking if the points list is empty
      throw Exception('Cannot calculate center for empty points list'); // Throwing an exception if the list is empty
    }

    double sumLat = 0; // Initializing the sum of latitudes
    double sumLng = 0; // Initializing the sum of longitudes

    for (var point in points) { // Iterating through the points
      sumLat += point.latitude; // Adding the latitude to the sum
      sumLng += point.longitude; // Adding the longitude to the sum
    }

    return LatLng( // Returning the calculated center
      sumLat / points.length, // Calculating the average latitude
      sumLng / points.length, // Calculating the average longitude
    );
  }
}
