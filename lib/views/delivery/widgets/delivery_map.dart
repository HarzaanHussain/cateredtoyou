import 'dart:io'; // Provides access to platform-specific APIs for file, socket, and network operations.

import 'package:flutter/foundation.dart'; // Provides tools for debugging and platform detection.
import 'package:flutter/material.dart'; // Provides the core Flutter UI framework.
import 'package:flutter_map/flutter_map.dart'; // Provides the Flutter Map library for rendering maps.
import 'package:latlong2/latlong.dart'; // Provides LatLng class for geographical coordinates.
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart'; // Adds support for cancellable tile loading in Flutter Map.
import 'dart:math' as math; // Provides mathematical functions and constants.

class DeliveryMap extends StatefulWidget {
  final MapController mapController; // Controller to manage map state and interactions.
  final List<Marker> markers; // List of markers to display on the map.
  final List<Polyline> polylines; // List of polylines to display routes on the map.
  final LatLng initialPosition; // Initial geographical position of the map.
  final double initialZoom; // Initial zoom level of the map.
  final bool isLoading; // Indicates whether the map is in a loading state.
  final Function(TapPosition, LatLng)? onMapTap; // Callback for handling map tap events.
  final VoidCallback? onMapReady; // Callback for when the map is fully initialized.
  final bool showUserLocation; // Whether to show the user's current location on the map.

  // Advanced options
  final bool showMapTypeButton; // Whether to show the button for changing map styles.
  final bool showTrafficButton; // Whether to show the button for toggling traffic overlay.
  final bool showScaleBar; // Whether to show the scale bar on the map.
  final bool showAttribution; // Whether to show attribution text for map data.
  final bool showZoomButtons; // Whether to show zoom in/out buttons.

  const DeliveryMap({
    super.key, // Passes the widget's key to the superclass.
    required this.mapController, // Ensures the map controller is provided.
    required this.markers, // Ensures the markers list is provided.
    required this.polylines, // Ensures the polylines list is provided.
    required this.initialPosition, // Ensures the initial position is provided.
    this.initialZoom = 13.0, // Sets a default zoom level if not provided.
    this.isLoading = false, // Defaults to not loading if not specified.
    this.onMapTap, // Optional callback for map tap events.
    this.onMapReady, // Optional callback for when the map is ready.
    this.showUserLocation = true, // Defaults to showing user location.
    this.showMapTypeButton = true, // Defaults to showing the map type button.
    this.showTrafficButton = false, // Defaults to hiding the traffic button.
    this.showScaleBar = true, // Defaults to showing the scale bar.
    this.showAttribution = true, // Defaults to showing attribution text.
    this.showZoomButtons = true, // Defaults to showing zoom buttons.
  });

  @override
  State<DeliveryMap> createState() => _DeliveryMapState(); // Creates the state for this widget.
}

class _DeliveryMapState extends State<DeliveryMap> with SingleTickerProviderStateMixin {
  bool _showTraffic = false; // Tracks whether the traffic overlay is enabled.
  String _currentMapStyle = 'streets'; // Tracks the currently selected map style.
  bool _isStyleSelectVisible = false; // Tracks whether the map style selector is visible.
  late AnimationController _styleSelectController; // Animation controller for the style selector.
  bool _isOffline = false; // Tracks whether the app is offline.

  // Map styles options
  final Map<String, String> _mapStyles = {
    'streets': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // URL for streets map style.
    'satellite': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', // URL for satellite map style.
    'dark': 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', // URL for dark map style.
    'light': 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', // URL for light map style.
  };

  final Map<String, String> _mapStyleLabels = {
    'streets': 'Streets', // Label for streets map style.
    'satellite': 'Satellite', // Label for satellite map style.
    'dark': 'Dark', // Label for dark map style.
    'light': 'Light', // Label for light map style.
  };

  @override
  void initState() {
    super.initState();

    // Initialize animation controller for map style selector
    _styleSelectController = AnimationController(
      vsync: this, // Uses this widget as the ticker provider.
      duration: const Duration(milliseconds: 300), // Sets the animation duration to 300ms.
    );

    // Check for internet connectivity
    _checkConnectivity();

    // Call onMapReady callback if provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.onMapReady != null) {
        widget.onMapReady!(); // Invokes the onMapReady callback after the first frame.
      }
    });
  }

  @override
  void dispose() {
    _styleSelectController.dispose(); // Disposes the animation controller to free resources.
    super.dispose();
  }
Future<void> _checkConnectivity() async {
  try {
    // For web platforms, skip the actual network check since it's not supported
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _isOffline = false; // Default to assuming online for web
        });
      }
      debugPrint('Web platform detected, skipping connectivity check');
      return;
    }

    // For native platforms (Android, iOS, etc.), perform actual connectivity check
    final result = await InternetAddress.lookup('google.com');
    if (mounted) {
      setState(() {
        _isOffline = result.isEmpty || result[0].rawAddress.isEmpty;
      });
    }
  } catch (e) {
    // If there's any error, assume we're offline
    if (mounted) {
      setState(() {
        _isOffline = true;
      });
    }
    debugPrint('Connectivity check error: $e');
  }
}
  
  void _toggleStyleSelector() {
    setState(() {
      _isStyleSelectVisible = !_isStyleSelectVisible;
      if (_isStyleSelectVisible) {
        _styleSelectController.forward();
      } else {
        _styleSelectController.reverse();
      }
    });
  }
  
  void _changeMapStyle(String style) {
    setState(() {
      _currentMapStyle = style;
      _isStyleSelectVisible = false;
      _styleSelectController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        // Main map
        FlutterMap(
          mapController: widget.mapController,
          options: MapOptions(
            initialCenter: widget.initialPosition,
            initialZoom: widget.initialZoom,
            onTap: widget.onMapTap,
            // Add error handling for map interactions
            // Simple map options without custom event handler
          ),
          children: [
            // Base map tile layer
            TileLayer(
              urlTemplate: _mapStyles[_currentMapStyle],
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.cateredtoyou.app',
              tileProvider: CancellableNetworkTileProvider(),
              // Improved error handling
              // No error image is better than an invalid type
              evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
            ),
            
            // Traffic overlay if enabled
            if (_showTraffic && !_isOffline)
              TileLayer(
                urlTemplate: 'https://mt1.google.com/vt/lyrs=traffic&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.cateredtoyou.app',
                tileProvider: CancellableNetworkTileProvider(),
                // No error image specified
              ),
              
            // Polylines layer
            if (widget.polylines.isNotEmpty)
              PolylineLayer(polylines: widget.polylines),
              
            // Markers layer
            if (widget.markers.isNotEmpty)
              MarkerLayer(markers: widget.markers),
              
            // Scale bar at bottom-left
            if (widget.showScaleBar)
              _buildScaleBar(),
              
            // Attribution at bottom-right
            if (widget.showAttribution)
              _buildAttributionWidget(),
          ],
        ),

        // Map type button
        if (widget.showMapTypeButton)
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Main map type button
                FloatingActionButton.small(
                  heroTag: 'mapTypeButton',
                  onPressed: _toggleStyleSelector,
                  backgroundColor: Colors.white,
                  elevation: 2,
                  child: Icon(
                    Icons.layers,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                
                // Map style selector
                AnimatedBuilder(
                  animation: _styleSelectController,
                  builder: (context, child) {
                    return ClipRect(
                      child: Align(
                        heightFactor: _styleSelectController.value,
                        alignment: Alignment.topCenter,
                        child: child,
                      ),
                    );
                  },
                  child: _isStyleSelectVisible ? _buildStyleSelector() : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          
        // Traffic button
        if (widget.showTrafficButton)
          Positioned(
            top: widget.showMapTypeButton ? 76 : 16,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'trafficButton',
              onPressed: () {
                setState(() {
                  _showTraffic = !_showTraffic;
                });
              },
              backgroundColor: _showTraffic 
                ? Theme.of(context).colorScheme.primary
                : Colors.white,
              elevation: 2,
              child: Icon(
                Icons.traffic,
                color: _showTraffic 
                  ? Colors.white
                  : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),

        // Zoom buttons
        if (widget.showZoomButtons)
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoomIn',
                  onPressed: () {
                    final currentZoom = widget.mapController.camera.zoom;
                    widget.mapController.move(
                      widget.mapController.camera.center,
                      currentZoom + 1,
                    );
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoomOut',
                  onPressed: () {
                    final currentZoom = widget.mapController.camera.zoom;
                    widget.mapController.move(
                      widget.mapController.camera.center,
                      currentZoom - 1,
                    );
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
          
        // Offline indicator
        if (_isOffline)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.wifi_off, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Offline Mode',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
        // Loading overlay
        if (widget.isLoading)
          Container(
            color: Colors.black.withAlpha(64), // 0.25 * 255 = 64
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
  
  // Custom implementation of scale bar
  Widget _buildScaleBar() {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20, left: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(204), // 0.8 * 255 = 204
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(51), // 0.2 * 255 = 51
                blurRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 2,
                color: Colors.black87,
              ),
              const SizedBox(width: 4),
              const Text(
                '1 km',
                style: TextStyle(fontSize: 10, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Custom implementation of attribution widget
  Widget _buildAttributionWidget() {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5, right: 5),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(179), // 0.7 * 255 = 179
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'Map data © OpenStreetMap contributors',
            style: TextStyle(fontSize: 10, color: Colors.black54),
          ),
        ),
      ),
    );
  }
  
  // Build the map style selector dropdown - FIXED TO HAVE CONSTRAINED WIDTH
  Widget _buildStyleSelector() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: 150, // Added fixed width constraint to prevent infinite width
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51), // 0.2 * 255 = 51
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: _mapStyles.keys.map((style) {
          final isSelected = style == _currentMapStyle;
          return InkWell(
            onTap: () => _changeMapStyle(style),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.grey.shade200 : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min, // Keep row as small as possible
                children: [
                  if (isSelected)
                    Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                      size: 16,
                    ),
                  if (isSelected) const SizedBox(width: 8),
                  Expanded( // Added to avoid text overflow
                    child: Text(
                      _mapStyleLabels[style] ?? style,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected 
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis, // Prevents text overflow
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Enhanced version of your MapMarkerHelper with more styling options
class MapMarkerHelper {
  static Marker createMarker({
    required LatLng point,
    required String id,
    Color color = Colors.red,
    IconData icon = Icons.location_on,
    String? title,
    double size = 30,
    VoidCallback? onTap,
    bool addShadow = true,
  }) {
    return Marker(
      point: point,
      width: size,
      height: size + (title != null ? 24 : 0), // Adjust height if title is present
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Shadow container for the icon
            if (addShadow)
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(77), // 0.3 * 255 = 77
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: size,
                ),
              )
            else
              Icon(
                icon,
                color: color,
                size: size,
              ),

            // Title below marker
            if (title != null)
              Positioned(
                bottom: -20,
                left: size / 2 - 50, // Center the title
                child: Container(
                  width: 100,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: addShadow ? [
                      BoxShadow(
                        color: Colors.black.withAlpha(51), // 0.2 * 255 = 51
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ] : null,
                  ),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Enhanced method to create a route polyline
  static Polyline createRoute({
    required List<LatLng> points,
    Color color = Colors.blue,
    double width = 4.0,
    bool isDashed = false,
    StrokeCap strokeCap = StrokeCap.round,
    StrokeJoin strokeJoin = StrokeJoin.round,
  }) {
    return Polyline(
      points: points,
      color: color,
      strokeWidth: width,
      isDotted: isDashed,
      strokeCap: strokeCap,
      strokeJoin: strokeJoin,
    );
  }
  
  // Method to create a dotted path for walking routes
  static Polyline createDottedPath({
    required List<LatLng> points,
    Color color = Colors.grey,
    double width = 3.0,
  }) {
    return Polyline(
      points: points,
      color: color,
      strokeWidth: width,
      isDotted: true,
      strokeCap: StrokeCap.round,
      strokeJoin: StrokeJoin.round,
    );
  }
  
  // Method to create a pulsing animation marker for current location
  static Marker createPulsingMarker({
    required LatLng point,
    required Color color,
    double size = 20,
  }) {
    final GlobalKey markerKey = GlobalKey();

    return Marker(
      point: point,
      width: size * 2.5,
      height: size * 2.5,
      child: TweenAnimationBuilder<double>(
        key: markerKey,
        tween: Tween<double>(begin: 0.8, end: 1.2),
        duration: const Duration(seconds: 1),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulsing circle
              Container(
                width: size * 2 * value,
                height: size * 2 * value,
                decoration: BoxDecoration(
                  color: color.withAlpha(77), // 0.3 * 255 = 77
                  shape: BoxShape.circle,
                ),
              ),
              // Inner circle
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ],
          );
        },
        onEnd: () {
          // Trigger rebuild to restart animation
          final currentContext = markerKey.currentContext;
          if (currentContext != null && currentContext.findRenderObject() != null && currentContext.findRenderObject()!.attached) {
            (currentContext as Element).markNeedsBuild();
          }
        },
      ),
    );
  }
}

// Enhanced MapBoundsHelper with additional utility methods
class MapBoundsHelper {
  static LatLngBounds calculateBounds(List<LatLng> points) {
    if (points.isEmpty) {
      // Return default bounds instead of throwing exception
      return LatLngBounds(
        LatLng(25.0, -125.0), // Default SW point
        LatLng(49.0, -65.0),  // Default NE point
      );
    }

    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Add padding to ensure points aren't right at the edge
    const padding = 0.01;
    return LatLngBounds(
      LatLng(minLat - padding, minLng - padding),
      LatLng(maxLat + padding, maxLng + padding),
    );
  }

  static LatLng calculateCenter(List<LatLng> points) {
    if (points.isEmpty) {
      // Return a default location instead of throwing exception
      return const LatLng(37.0902, -95.7129); // US center
    }

    double sumLat = 0;
    double sumLng = 0;

    for (var point in points) {
      sumLat += point.latitude;
      sumLng += point.longitude;
    }

    return LatLng(
      sumLat / points.length,
      sumLng / points.length,
    );
  }
  
  // Method to calculate a zoom level to fit bounds within a viewport
  static double calculateZoomLevel(
    LatLngBounds bounds, 
    double viewportWidth, 
    double viewportHeight
  ) {
    final latDiff = (bounds.northEast.latitude - bounds.southWest.latitude).abs();
    final lngDiff = (bounds.northEast.longitude - bounds.southWest.longitude).abs();
    
    // Calculate center latitude for better accuracy
    final centerLat = (bounds.northEast.latitude + bounds.southWest.latitude) / 2;
    
    // Calculate zoom based on the larger difference
    final latZoom = (viewportHeight / (latDiff * 111000)) * 0.8; // 111km per degree
    final lngZoom = (viewportWidth / (lngDiff * 111000 * math.cos(centerLat * math.pi / 180))) * 0.8;
    
    return math.min(latZoom, lngZoom).clamp(1.0, 18.0); // Reasonable zoom limits
  }
  
  // Method to expand bounds to include a point
  static LatLngBounds expandBounds(LatLngBounds bounds, LatLng point) {
    double minLat = bounds.southWest.latitude;
    double maxLat = bounds.northEast.latitude;
    double minLng = bounds.southWest.longitude;
    double maxLng = bounds.northEast.longitude;
    
    if (point.latitude < minLat) minLat = point.latitude;
    if (point.latitude > maxLat) maxLat = point.latitude;
    if (point.longitude < minLng) minLng = point.longitude;
    if (point.longitude > maxLng) maxLng = point.longitude;
    
    return LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }
}