import 'package:flutter/material.dart'; // Importing Flutter material package for UI components.
import 'package:flutter_map/flutter_map.dart'; // Importing flutter_map package for map functionalities.
import 'package:latlong2/latlong.dart'; // Importing latlong2 package for handling geographical coordinates.

/// A safe wrapper around MapController that handles disposal and prevents crashes
class SafeMapController {
  MapController? _controller;
  bool _disposed = false;
  
  SafeMapController() {
    _controller = MapController();
  }
  
  bool get isDisposed => _disposed;
  
  // This getter allows direct access to the underlying controller when needed
  // but returns null if disposed to prevent crashes
  MapController? get controller => _disposed ? null : _controller;
  
  // For backward compatibility with existing code - always returns a usable controller
  MapController get safeController {
    if (_disposed || _controller == null) {
      debugPrint('Warning: Attempting to access disposed map controller. Creating temporary instance to avoid crashes.');
      return MapController(); // Return a temporary controller to avoid crashes
    }
    return _controller!;
  }
  
  void move(LatLng center, double zoom) {
    if (_disposed || _controller == null) return;
    try {
      _controller!.move(center, zoom);
    } catch (e) {
      debugPrint('SafeMapController: Error during move: $e');
    }
  }
  
  void fitBounds(List<LatLng> points, {EdgeInsets? padding}) {
    if (_disposed || _controller == null || points.isEmpty) return;
    
    try {
      final bounds = LatLngBounds.fromPoints(points);
      final paddingValue = padding ?? const EdgeInsets.all(50);
      
      // Safe access to camera
      
      final centerZoom = CameraFit.bounds(
        bounds: bounds,
        padding: paddingValue,
      ).fit(_controller!.camera);
      
      move(centerZoom.center, centerZoom.zoom);
    } catch (e) {
      debugPrint('SafeMapController: Error during fitBounds: $e');
    }
  }
  
  void dispose() {
    if (_disposed) return;
    
    try {
      _controller?.dispose();
    } catch (e) {
      debugPrint('SafeMapController: Error during dispose: $e');
    }
    
    _controller = null;
    _disposed = true;
  }
}

class DeliveryMapController extends ChangeNotifier { // Defining a controller class that extends ChangeNotifier for state management.
  late final SafeMapController _safeMapController; // Safe wrapper for the MapController
  List<Marker> markers = []; // List to store map markers.
  List<Polyline> polylines = []; // List to store polylines on the map.
  LatLng? currentCenter; // Variable to store the current center position of the map.
  double currentZoom = 13.0; // Variable to store the current zoom level of the map.
  bool isLoading = false; // Variable to indicate if the map is loading.
  bool _disposed = false; // Variable to check if the controller is disposed.

  // This maintains compatibility with existing code
  MapController get mapController => _safeMapController.safeController;

  DeliveryMapController() { // Constructor for the DeliveryMapController class.
    _safeMapController = SafeMapController(); // Initialize the safe map controller
  }

  void setLoading(bool loading) { // Method to set the loading state.
    if (_disposed) return; // If the controller is disposed, return immediately.
    try {
      isLoading = loading; // Set the loading state.
      notifyListeners(); // Notify listeners about the state change.
    } catch (e) {
      debugPrint('Error setting loading state: $e');
    }
  }

  void updateMarkers(List<Marker> newMarkers) { // Method to update the list of markers.
    if (_disposed) return; // If the controller is disposed, return immediately.
    try {
      markers = newMarkers; // Update the markers list.
      notifyListeners(); // Notify listeners about the state change.
    } catch (e) {
      debugPrint('Error updating markers: $e');
    }
  }

  void updatePolylines(List<Polyline> newPolylines) { // Method to update the list of polylines.
    if (_disposed) return; // If the controller is disposed, return immediately.
    try {
      polylines = newPolylines; // Update the polylines list.
      notifyListeners(); // Notify listeners about the state change.
    } catch (e) {
      debugPrint('Error updating polylines: $e');
    }
  }

  void moveCamera(LatLng position, {double? zoom}) { // Method to move the camera to a new position.
    if (_disposed) return; // If the controller is disposed, return immediately.
    try {
      currentCenter = position; // Update the current center position.
      if (zoom != null) currentZoom = zoom; // Update the zoom level if provided.
      _safeMapController.move(position, zoom ?? currentZoom); // Use safe controller to move
      notifyListeners(); // Notify listeners about the state change.
    } catch (e) {
      debugPrint('Error moving camera: $e');
    }
  }

  void fitBounds(List<LatLng> points, {EdgeInsets? padding}) { // Method to fit the map bounds to a list of points.
    if (_disposed || points.isEmpty) return; // If the controller is disposed or points list is empty, return immediately.
    try {
      _safeMapController.fitBounds(points, padding: padding); // Use safe controller to fit bounds
    } catch (e) {
      debugPrint('Error fitting bounds: $e');
    }
  }

  void addMarker(Marker marker) { // Method to add a marker to the map.
    if (_disposed) return; // If the controller is disposed, return immediately.
    try {
      markers.add(marker); // Add the marker to the markers list.
      notifyListeners(); // Notify listeners about the state change.
    } catch (e) {
      debugPrint('Error adding marker: $e');
    }
  }

  void removeMarker(String markerId) { // Method to remove a marker from the map by its ID.
    if (_disposed) return; // If the controller is disposed, return immediately.
    try {
      markers.removeWhere((marker) => marker.key.toString() == markerId); // Remove the marker with the matching ID.
      notifyListeners(); // Notify listeners about the state change.
    } catch (e) {
      debugPrint('Error removing marker: $e');
    }
  }

  void clearMarkers() { // Method to clear all markers from the map.
    if (_disposed) return; // If the controller is disposed, return immediately.
    try {
      markers.clear(); // Clear the markers list.
      notifyListeners(); // Notify listeners about the state change.
    } catch (e) {
      debugPrint('Error clearing markers: $e');
    }
  }

  void addPolyline(Polyline polyline) { // Method to add a polyline to the map.
    if (_disposed) return; // If the controller is disposed, return immediately.
    try {
      polylines.add(polyline); // Add the polyline to the polylines list.
      notifyListeners(); // Notify listeners about the state change.
    } catch (e) {
      debugPrint('Error adding polyline: $e');
    }
  }

  void clearPolylines() { // Method to clear all polylines from the map.
    if (_disposed) return; // If the controller is disposed, return immediately.
    try {
      polylines.clear(); // Clear the polylines list.
      notifyListeners(); // Notify listeners about the state change.
    } catch (e) {
      debugPrint('Error clearing polylines: $e');
    }
  }

  @override
  void dispose() { // Method to dispose the controller.
    try {
      _disposed = true; // Set the disposed flag to true.
      _safeMapController.dispose(); // Safely dispose the map controller.
      super.dispose(); // Call the dispose method of the superclass.
    } catch (e) {
      debugPrint('Error disposing map controller: $e');
      super.dispose(); // Ensure super.dispose() is called even if there's an error
    }
  }
}