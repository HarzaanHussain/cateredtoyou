import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cateredtoyou/models/event_model.dart';
import 'package:cateredtoyou/services/event_service.dart';
import 'package:cateredtoyou/widgets/bottom_toolbar.dart';
import 'package:cateredtoyou/views/events/event_details_screen.dart';
// Import other models, services, and screens as needed

/// Generic ContentLoader that can load different types of content by ID
class ContentByIdLoader extends StatelessWidget {
  final String contentType;
  final String contentId;
  final String loadingTitle;

  const ContentByIdLoader({
    super.key,
    required this.contentType,
    required this.contentId,
    this.loadingTitle = 'Loading...',
  });

  @override
  Widget build(BuildContext context) {
    // Select the appropriate future based on content type
    return FutureBuilder<dynamic>(
      future: _getContentFuture(context),
      builder: (context, snapshot) {
        // While loading, show a loading screen
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: Text(loadingTitle),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => GoRouter.of(context).go('/home'),
              ),
            ),
            body: const Center(child: CircularProgressIndicator()),
            bottomNavigationBar: const BottomToolbar(),
          );
        }

        // If there's an error or no data, show an error screen
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: Text('$contentType Not Found'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => GoRouter.of(context).go('/home'),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    snapshot.hasError
                        ? 'Error: ${snapshot.error}'
                        : '$contentType not found',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => GoRouter.of(context).go('/home'),
                    child: const Text('Go to Home'),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: const BottomToolbar(),
          );
        }

        // If we have the data, return the appropriate screen
        return _buildContentScreen(snapshot.data);
      },
    );
  }

  /// Get the appropriate Future based on content type
  Future<dynamic> _getContentFuture(BuildContext context) {
    switch (contentType.toLowerCase()) {
      case 'event':
        return Provider.of<EventService>(context, listen: false)
            .getEventById(contentId);

      // case 'inventory':
      //   return Provider.of<InventoryService>(context, listen: false)
      //       .getInventoryItemById(contentId);

      // Add cases for other content types
      // case 'task':
      //   return Provider.of<TaskService>(context, listen: false)
      //       .getTaskById(contentId);

      // case 'vehicle':
      //   return Provider.of<VehicleService>(context, listen: false)
      //       .getVehicleById(contentId);

      default:
        return Future.error('Unknown content type: $contentType');
    }
  }

  /// Build the appropriate content screen based on the loaded data
  Widget _buildContentScreen(dynamic content) {
    switch (contentType.toLowerCase()) {
      case 'event':
        return EventDetailsScreen(event: content as Event);

      // case 'inventory':
      //   // Replace with your actual inventory details screen
      //   return InventoryDetailsScreen(item: content as InventoryItem);

      // Add cases for other content types
      // case 'task':
      //   return TaskDetailsScreen(task: content as Task);

      // case 'vehicle':
      //   return VehicleDetailsScreen(vehicle: content as Vehicle);

      default:
        return Scaffold(
          appBar: AppBar(title: Text('Error')),
          body: Center(child: Text('Unknown content type: $contentType')),
          bottomNavigationBar: const BottomToolbar(),
        );
    }
  }
}
