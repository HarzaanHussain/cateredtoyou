import 'package:cateredtoyou/models/event_model.dart'; // Importing the Event model
import 'package:cateredtoyou/models/loading_plan_model.dart'; // Importing the LoadingPlan model
import 'package:cateredtoyou/services/loading_plan_service.dart'; // Importing the LoadingPlanService
import 'package:cateredtoyou/services/event_service.dart'; // Importing the EventService
import 'package:flutter/foundation.dart'; // Importing foundation for debugPrint

class LoadingPlanGenerator {
  final LoadingPlanService _loadingPlanService; // Reference to the LoadingPlanService
  final EventService _eventService; // Reference to the EventService

  // Constructor to initialize services
  LoadingPlanGenerator({
    required LoadingPlanService loadingPlanService,
    required EventService eventService,
  })  : _loadingPlanService = loadingPlanService,
        _eventService = eventService;

  /// Generates a loading plan for an event with the given ID.
  /// All menu items are added to the plan with no vehicle assignments initially.
  Future<LoadingPlan?> generateLoadingPlanForEvent(String eventId) async {
    try {
      // Check if a loading plan already exists for this event
      LoadingPlan? existingPlan = await _checkExistingPlan(eventId);
      if (existingPlan != null) {
        debugPrint('Loading plan already exists for event $eventId');
        return existingPlan;
      }

      // Fetch the event to get menu items
      Event? event = await _eventService.getEventById(eventId);
      if (event == null) {
        debugPrint('Event with ID $eventId not found');
        return null;
      }

      // Convert event menu items to loading items
      List<LoadingItem> loadingItems = _convertMenuItemsToLoadingItems(event.menuItems);

      // Create the loading plan
      LoadingPlan loadingPlan = await _loadingPlanService.createLoadingPlan(
        eventId: eventId,
        items: loadingItems,
      );

      debugPrint('Loading plan generated successfully for event $eventId with ${loadingItems.length} items');
      return loadingPlan;
    } catch (e) {
      debugPrint('Error generating loading plan: $e');
      return null;
    }
  }

  /// Checks if a loading plan already exists for the given event ID
  Future<LoadingPlan?> _checkExistingPlan(String eventId) async {
    try {
      // Wait for the first value from the stream
      return await _loadingPlanService.getLoadingPlanByEventId(eventId).first;
    } catch (e) {
      debugPrint('Error checking for existing loading plan: $e');
      return null;
    }
  }

  /// Converts event menu items to loading items for the loading plan
  List<LoadingItem> _convertMenuItemsToLoadingItems(List<EventMenuItem> menuItems) {
    return menuItems.map((menuItem) {
      // Create a unique identifier for this event menu item
      // If your EventMenuItem already has a unique id for each item in the event,
      // you should use that instead
      String eventMenuItemId = menuItem.menuItemId;

      return LoadingItem(
        eventMenuItemId: eventMenuItemId,
        quantity: menuItem.quantity,
        vehicleId: null, // Initially no vehicle is assigned
      );
    }).toList();
  }

  /// Updates an existing loading plan when event menu items change
  Future<LoadingPlan?> updateLoadingPlanForEvent(String eventId) async {
    try {
      // Get the current loading plan
      LoadingPlan? existingPlan = await _checkExistingPlan(eventId);
      if (existingPlan == null) {
        // If no plan exists, create a new one
        return await generateLoadingPlanForEvent(eventId);
      }

      // Get the current event with menu items
      Event? event = await _eventService.getEventById(eventId);
      if (event == null) {
        debugPrint('Event with ID $eventId not found');
        return null;
      }

      // Create a map of existing items for faster lookup
      Map<String, LoadingItem> existingItemsMap = {};
      for (var item in existingPlan.items) {
        existingItemsMap[item.eventMenuItemId] = item;
      }

      // Create updated list of loading items
      List<LoadingItem> updatedItems = event.menuItems.map((menuItem) {
        String eventMenuItemId = menuItem.menuItemId;

        // Check if this item already exists in the loading plan
        if (existingItemsMap.containsKey(eventMenuItemId)) {
          // Preserve vehicle assignment if it exists
          return LoadingItem(
            eventMenuItemId: eventMenuItemId,
            quantity: menuItem.quantity,
            vehicleId: existingItemsMap[eventMenuItemId]!.vehicleId,
          );
        } else {
          // New item, no vehicle assignment
          return LoadingItem(
            eventMenuItemId: eventMenuItemId,
            quantity: menuItem.quantity,
            vehicleId: null,
          );
        }
      }).toList();

      // Update the loading plan
      LoadingPlan updatedPlan = existingPlan.copyWith(items: updatedItems);
      await _loadingPlanService.updateLoadingPlan(updatedPlan);

      debugPrint('Loading plan updated for event $eventId with ${updatedItems.length} items');
      return updatedPlan;
    } catch (e) {
      debugPrint('Error updating loading plan: $e');
      return null;
    }
  }

  /// Gets loading plan recommendations based on item types and quantities
  /// This is a placeholder for more advanced recommendation logic
  Future<Map<String, List<String>>> getVehicleRecommendations(String eventId) async {
    try {
      LoadingPlan? loadingPlan = await _checkExistingPlan(eventId);
      if (loadingPlan == null) {
        debugPrint('No loading plan found for event $eventId');
        return {};
      }

      Event? event = await _eventService.getEventById(eventId);
      if (event == null) {
        debugPrint('Event with ID $eventId not found');
        return {};
      }

      // Map to store recommendations: vehicleId -> list of item IDs
      Map<String, List<String>> recommendations = {};

      // Here you would implement your recommendation logic
      // This is just a simple placeholder that distributes items evenly
      // across available vehicles in the organization

      // For now, just return an empty map
      // In a real implementation, you would query available vehicles
      // and recommend assignments based on item types, sizes, quantities, etc.

      debugPrint('Generated vehicle recommendations for loading plan');
      return recommendations;
    } catch (e) {
      debugPrint('Error generating vehicle recommendations: $e');
      return {};
    }
  }
}