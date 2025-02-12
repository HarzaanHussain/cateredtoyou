import 'package:flutter/material.dart'; // Importing Flutter material package for UI components.
import 'package:flutter_map/flutter_map.dart'; // Importing flutter_map package for map functionalities.
import 'package:latlong2/latlong.dart'; // Importing latlong2 package for handling geographical coordinates.

class DeliveryMapController extends ChangeNotifier { // Defining a controller class that extends ChangeNotifier for state management.
  late final MapController mapController; // Declaring a MapController to control the map.
  List<Marker> markers = []; // List to store map markers.
  List<Polyline> polylines = []; // List to store polylines on the map.
  LatLng? currentCenter; // Variable to store the current center position of the map.
  double currentZoom = 13.0; // Variable to store the current zoom level of the map.
  bool isLoading = false; // Variable to indicate if the map is loading.
  bool _disposed = false; // Variable to check if the controller is disposed.

  DeliveryMapController() { // Constructor for the DeliveryMapController class.
    mapController = MapController(); // Initializing the MapController.
  }

  void setLoading(bool loading) { // Method to set the loading state.
    if (_disposed) return; // If the controller is disposed, return immediately.
    isLoading = loading; // Set the loading state.
    notifyListeners(); // Notify listeners about the state change.
  }

  void updateMarkers(List<Marker> newMarkers) { // Method to update the list of markers.
    if (_disposed) return; // If the controller is disposed, return immediately.
    markers = newMarkers; // Update the markers list.
    notifyListeners(); // Notify listeners about the state change.
  }

  void updatePolylines(List<Polyline> newPolylines) { // Method to update the list of polylines.
    if (_disposed) return; // If the controller is disposed, return immediately.
    polylines = newPolylines; // Update the polylines list.
    notifyListeners(); // Notify listeners about the state change.
  }

  void moveCamera(LatLng position, {double? zoom}) { // Method to move the camera to a new position.
    if (_disposed) return; // If the controller is disposed, return immediately.
    currentCenter = position; // Update the current center position.
    if (zoom != null) currentZoom = zoom; // Update the zoom level if provided.
    mapController.move(position, zoom ?? currentZoom); // Move the map to the new position and zoom level.
    notifyListeners(); // Notify listeners about the state change.
  }

  void fitBounds(List<LatLng> points, {EdgeInsets? padding}) { // Method to fit the map bounds to a list of points.
    if (_disposed || points.isEmpty) return; // If the controller is disposed or points list is empty, return immediately.

    final bounds = LatLngBounds.fromPoints(points); // Create bounds from the list of points.
    final paddingValue = padding ?? const EdgeInsets.all(50); // Set padding value, default to 50 if not provided.
    
    final centerZoom = CameraFit.bounds( // Calculate the center and zoom level to fit the bounds.
      bounds: bounds,
      padding: paddingValue,
    ).fit(mapController.camera);

    mapController.move( // Move the map to the calculated center and zoom level.
      centerZoom.center,
      centerZoom.zoom,
    );
  }

  void addMarker(Marker marker) { // Method to add a marker to the map.
    if (_disposed) return; // If the controller is disposed, return immediately.
    markers.add(marker); // Add the marker to the markers list.
    notifyListeners(); // Notify listeners about the state change.
  }

  void removeMarker(String markerId) { // Method to remove a marker from the map by its ID.
    if (_disposed) return; // If the controller is disposed, return immediately.
    markers.removeWhere((marker) => marker.key.toString() == markerId); // Remove the marker with the matching ID.
    notifyListeners(); // Notify listeners about the state change.
  }

  void clearMarkers() { // Method to clear all markers from the map.
    if (_disposed) return; // If the controller is disposed, return immediately.
    markers.clear(); // Clear the markers list.
    notifyListeners(); // Notify listeners about the state change.
  }

  void addPolyline(Polyline polyline) { // Method to add a polyline to the map.
    if (_disposed) return; // If the controller is disposed, return immediately.
    polylines.add(polyline); // Add the polyline to the polylines list.
    notifyListeners(); // Notify listeners about the state change.
  }

  void clearPolylines() { // Method to clear all polylines from the map.
    if (_disposed) return; // If the controller is disposed, return immediately.
    polylines.clear(); // Clear the polylines list.
    notifyListeners(); // Notify listeners about the state change.
  }

  @override
  void dispose() { // Method to dispose the controller.
    _disposed = true; // Set the disposed flag to true.
    mapController.dispose(); // Dispose the MapController.
    super.dispose(); // Call the dispose method of the superclass.
  }
}