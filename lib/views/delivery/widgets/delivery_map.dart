import 'package:flutter/material.dart'; // Importing Flutter material package for UI components
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Importing Google Maps Flutter package for map functionalities

class DeliveryMap extends StatelessWidget { // Defining a stateless widget named DeliveryMap
  final Function(GoogleMapController) onMapCreated; // Callback function when the map is created
  final Set<Marker> markers; // Set of markers to be displayed on the map
  final Set<Polyline> polylines; // Set of polylines to be displayed on the map
  final LatLng initialPosition; // Initial position of the map's camera
  final bool isLoading; // Boolean to indicate if the map is loading

  const DeliveryMap({
    super.key, // Key for the widget
    required this.onMapCreated, // Required callback function for map creation
    required this.markers, // Required set of markers
    required this.polylines, // Required set of polylines
    required this.initialPosition, // Required initial position for the map
    this.isLoading = false, // Optional loading indicator, default is false
  });

  @override
  Widget build(BuildContext context) { // Build method to describe the part of the UI represented by this widget
    if (isLoading) { // Check if the map is loading
      return const Center(child: CircularProgressIndicator()); // Show a loading spinner if the map is loading
    }

    return Stack( // Using a Stack widget to overlay multiple widgets
      children: [
        GoogleMap( // GoogleMap widget to display the map
          onMapCreated: onMapCreated, // Callback when the map is created
          initialCameraPosition: CameraPosition( // Initial camera position for the map
            target: initialPosition, // Setting the initial position
            zoom: 15, // Zoom level
            tilt: 45.0, // Tilt angle
          ),
          markers: markers, // Adding markers to the map
          polylines: polylines, // Adding polylines to the map
          myLocationEnabled: true, // Enabling user's current location on the map
          compassEnabled: true, // Enabling compass on the map
          mapToolbarEnabled: false, // Disabling map toolbar
          zoomControlsEnabled: false, // Disabling zoom controls
          trafficEnabled: true, // Enabling traffic layer on the map
          mapType: MapType.normal, // Setting the map type to normal
          buildingsEnabled: true, // Enabling 3D buildings on the map
          rotateGesturesEnabled: true, // Enabling rotate gestures
          tiltGesturesEnabled: true, // Enabling tilt gestures
          padding: const EdgeInsets.only(bottom: 280), // Adding padding to the bottom for space for the bottom card
        ),
        // Loading overlay
        if (isLoading) // Check if the map is loading
          Container( // Overlay container to show loading spinner
            color: Colors.black.withOpacity(0.5), // Semi-transparent black background
            child: const Center( // Centering the loading spinner
              child: CircularProgressIndicator(), // Loading spinner
            ),
          ),
      ],
    );
  }
}