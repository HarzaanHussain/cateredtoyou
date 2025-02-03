class MapStyle {
  // This constant string holds the JSON style configuration for the map.
  static const String mapStyle = '''[
    {
      "featureType": "poi", // Points of interest (e.g., parks, museums)
      "elementType": "labels", // Labels for points of interest
      "stylers": [{"visibility": "off"}] // Hide labels for points of interest
    },
    {
      "featureType": "transit", // Transit features (e.g., bus stops, train stations)
      "elementType": "labels", // Labels for transit features
      "stylers": [{"visibility": "off"}] // Hide labels for transit features
    },
    {
      "elementType": "geometry", // General geometry of the map
      "stylers": [
        {
          "color": "#f5f5f5" // Set the color of the map's geometry to a light grey
        }
      ]
    },
    {
      "elementType": "labels.icon", // Icons for labels
      "stylers": [
        {
          "visibility": "off" // Hide icons for labels
        }
      ]
    },
    {
      "elementType": "labels.text.fill", // Text fill for labels
      "stylers": [
        {
          "color": "#616161" // Set the text color to a medium grey
        }
      ]
    },
    {
      "elementType": "labels.text.stroke", // Text stroke for labels
      "stylers": [
        {
          "color": "#f5f5f5" // Set the text stroke color to a light grey
        }
      ]
    },
    {
      "featureType": "administrative.land_parcel", // Administrative land parcels
      "elementType": "labels.text.fill", // Text fill for labels
      "stylers": [
        {
          "color": "#bdbdbd" // Set the text color to a light grey
        }
      ]
    },
    {
      "featureType": "road", // All roads
      "elementType": "geometry", // Geometry of the roads
      "stylers": [
        {
          "color": "#ffffff" // Set the road color to white
        }
      ]
    },
    {
      "featureType": "road.arterial", // Arterial roads
      "elementType": "labels.text.fill", // Text fill for labels
      "stylers": [
        {
          "color": "#757575" // Set the text color to a medium grey
        }
      ]
    },
    {
      "featureType": "road.highway", // Highways
      "elementType": "geometry", // Geometry of the highways
      "stylers": [
        {
          "color": "#dadada" // Set the highway color to a light grey
        }
      ]
    },
    {
      "featureType": "road.highway", // Highways
      "elementType": "labels.text.fill", // Text fill for labels
      "stylers": [
        {
          "color": "#616161" // Set the text color to a medium grey
        }
      ]
    },
    {
      "featureType": "road.local", // Local roads
      "elementType": "labels.text.fill", // Text fill for labels
      "stylers": [
        {
          "color": "#9e9e9e" // Set the text color to a light grey
        }
      ]
    },
    {
      "featureType": "water", // Water bodies (e.g., lakes, rivers)
      "elementType": "geometry", // Geometry of the water bodies
      "stylers": [
        {
          "color": "#c9c9c9" // Set the water color to a light grey
        }
      ]
    },
    {
      "featureType": "water", // Water bodies
      "elementType": "labels.text.fill", // Text fill for labels
      "stylers": [
        {
          "color": "#9e9e9e" // Set the text color to a light grey
        }
      ]
    }
  ]''';
}