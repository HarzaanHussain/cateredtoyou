import 'package:cateredtoyou/widgets/themed_app_bar.dart';
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components.
import 'package:provider/provider.dart'; // Importing provider package for state management.
import 'package:go_router/go_router.dart'; // Importing go_router package for navigation.
import 'package:intl/intl.dart'; // Importing intl package for date formatting.
import 'package:cateredtoyou/models/event_model.dart'; // Importing event model.
import 'package:cateredtoyou/services/event_service.dart'; // Importing event service for API calls.
import 'package:cateredtoyou/widgets/bottom_toolbar.dart'; // Imports bottom toolbar class


class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key}); // Constructor for EventListScreen.

  @override
  State<EventListScreen> createState() => _EventListScreenState(); // Creating state for EventListScreen.
}

class _EventListScreenState extends State<EventListScreen> {
  String _searchQuery = ''; // Search query string.
  EventStatus? _filterStatus; // Filter status for events.
  bool _showUpcomingOnly = true; // Flag to show only upcoming events.
  final _searchController = TextEditingController(); // Controller for search input.

  @override
  void dispose() {
    _searchController.dispose(); // Disposing search controller.
    super.dispose();
  }

  List<Event> _filterEvents(List<Event> events) {
    return events.where((event) {
      if (_showUpcomingOnly && event.startDate.isBefore(DateTime.now())) {
        return false; // Filter out past events if _showUpcomingOnly is true.
      }
      if (_filterStatus != null && event.status != _filterStatus) {
        return false; // Filter events by status.
      }
      if (_searchQuery.isEmpty) return true; // If search query is empty, return all events.

      final query = _searchQuery.toLowerCase();
      return event.name.toLowerCase().contains(query) ||
          event.description.toLowerCase().contains(query) ||
          event.location.toLowerCase().contains(query); // Filter events by search query.
    }).toList();
  }

  void _showStatusConfirmation(Event event, EventStatus newStatus) {
    final eventService = context.read<EventService>(); // Getting event service from context.

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Change Event Status'),
        content: Text(
          'Change status of "${event.name}" to ${newStatus.toString().split('.').last}?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), // Close dialog on cancel.
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                Navigator.pop(dialogContext); // Close dialog.
                await eventService.changeEventStatus(event.id, newStatus); // Change event status.

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Event status updated successfully')),
                  ); // Show success message.
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  ); // Show error message.
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const BottomToolbar(),
      appBar: ThemedAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // Back button icon.
          onPressed: () => context.push('/home'), // Navigate to home screen when pressed.
        ),  
         const Text('Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/add-event'), // Navigate to add event screen.
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search events...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear(); // Clear search query and input field.
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value; // Update search query on input change.
                    });
                  },
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        selected: _showUpcomingOnly,
                        label: const Text('Upcoming Only'),
                        onSelected: (selected) {
                          setState(() {
                            _showUpcomingOnly = selected; // Toggle upcoming only filter.
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ...EventStatus.values.map((status) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: _filterStatus == status,
                            label: Text(status.toString().split('.').last),
                            onSelected: (selected) {
                              setState(() {
                                _filterStatus = selected ? status : null; // Toggle status filter.
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Event>>(
              stream: context.read<EventService>().getEvents(), // Stream of events from event service.
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'), // Show error message if there's an error.
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(), // Show loading indicator while waiting for data.
                  );
                }

                final events = snapshot.data ?? [];
                final filteredEvents = _filterEvents(events); // Filter events based on search and filters.

                if (events.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'No events found',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/add-event'), // Navigate to add event screen.
                          icon: const Icon(Icons.add),
                          label: const Text('Create Event'),
                        ),
                      ],
                    ),
                  );
                }

                if (filteredEvents.isEmpty) {
                  return const Center(
                    child: Text('No events match your search'), // Show message if no events match the search.
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredEvents.length,
                  itemBuilder: (context, index) {
                    final event = filteredEvents[index];
                    return EventListItem(
                      event: event,
                      onStatusChange: _showStatusConfirmation, // Show status confirmation dialog on status change.
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A widget that displays an event item in a list.
/// 
/// This widget shows the event's name, description, location, date, time, guest count, and minimum staff required.
/// It also provides options to edit, change status, or delete the event.
class EventListItem extends StatelessWidget {
  final Event event; // The event to display.
  final void Function(Event event, EventStatus newStatus) onStatusChange; // Callback for when the event status changes.

  const EventListItem({
    super.key,
    required this.event,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Theme data for styling.
    final dateFormat = DateFormat('MMM d, y'); // Date format for displaying event date.
    final timeFormat = DateFormat('h:mm a'); // Time format for displaying event time.

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16), // Padding inside the list tile.
        onTap: () => context.push('/event-details', extra: event), // Navigate to event details on tap.
        title: Row(
          children: [
            Expanded(
              child: Text(
                event.name, // Display event name.
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold, // Bold font for event name.
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: _getStatusColor(event.status).withAlpha((0.1 * 255).toInt()), // Background color based on event status.
                borderRadius: BorderRadius.circular(4), // Rounded corners for status container.
              ),
              child: Text(
                event.status.toString().split('.').last, // Display event status.
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _getStatusColor(event.status), // Text color based on event status.
                  fontWeight: FontWeight.bold, // Bold font for status text.
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8), // Spacing between elements.
            Text(
              event.description, // Display event description.
              maxLines: 2, // Limit description to 2 lines.
              overflow: TextOverflow.ellipsis, // Ellipsis for overflow text.
            ),
            const SizedBox(height: 8), // Spacing between elements.
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: theme.textTheme.bodySmall?.color, // Icon color based on theme.
                ),
                const SizedBox(width: 4), // Spacing between icon and text.
                Expanded(
                  child: Text(
                    event.location, // Display event location.
                    style: theme.textTheme.bodySmall, // Text style based on theme.
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4), // Spacing between elements.
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: theme.textTheme.bodySmall?.color, // Icon color based on theme.
                ),
                const SizedBox(width: 4), // Spacing between icon and text.
                Text(
                  dateFormat.format(event.startDate), // Display formatted event start date.
                  style: theme.textTheme.bodySmall, // Text style based on theme.
                ),
                const SizedBox(width: 16), // Spacing between elements.
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: theme.textTheme.bodySmall?.color, // Icon color based on theme.
                ),
                const SizedBox(width: 4), // Spacing between icon and text.
                Text(
                  '${timeFormat.format(event.startTime)} - ${timeFormat.format(event.endTime)}', // Display formatted event time range.
                  style: theme.textTheme.bodySmall, // Text style based on theme.
                ),
              ],
            ),
            const SizedBox(height: 4), // Spacing between elements.
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: 16,
                  color: theme.textTheme.bodySmall?.color, // Icon color based on theme.
                ),
                const SizedBox(width: 4), // Spacing between icon and text.
                Text(
                  '${event.guestCount} guests', // Display guest count.
                  style: theme.textTheme.bodySmall, // Text style based on theme.
                ),
                const SizedBox(width: 16), // Spacing between elements.
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: theme.textTheme.bodySmall?.color, // Icon color based on theme.
                ),
                const SizedBox(width: 4), // Spacing between icon and text.
                Text(
                  'Min. Staff: ${event.minStaff}', // Display minimum staff required.
                  style: theme.textTheme.bodySmall, // Text style based on theme.
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                context.push('/edit-event', extra: event); // Navigate to edit event screen.
                break;
              case 'status':
                _showStatusChangeDialog(context); // Show status change dialog.
                break;
              case 'delete':
                _showDeleteConfirmation(context); // Show delete confirmation dialog.
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'), // Edit option.
            ),
            const PopupMenuItem(
              value: 'status',
              child: Text('Change Status'), // Change status option.
            ),
            const PopupMenuItem(
              value: 'delete',
              textStyle: TextStyle(color: Colors.red), // Red text for delete option.
              child: Text('Delete'), // Delete option.
            ),
          ],
        ),
      ),
    );
  }

  /// Returns the color associated with the given event status.
  Color _getStatusColor(EventStatus status) {
    switch (status) {
      case EventStatus.draft:
        return Colors.grey; // Color for draft status.
      case EventStatus.pending:
        return Colors.orange; // Color for pending status.
      case EventStatus.confirmed:
        return Colors.green; // Color for confirmed status.
      case EventStatus.inProgress:
        return Colors.blue; // Color for in-progress status.
      case EventStatus.completed:
        return Colors.purple; // Color for completed status.
      case EventStatus.cancelled:
        return Colors.red; // Color for cancelled status.
      case EventStatus.archived:
        return Colors.brown; // Color for archived status.
    }
  }

  /// Shows a dialog to change the event status.
  void _showStatusChangeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Event Status'), // Dialog title.
        content: Column(
          mainAxisSize: MainAxisSize.min, // Minimize dialog size.
          children: EventStatus.values
              .where((status) => status != event.status) // Exclude current status.
              .map((status) => ListTile(
                    title: Text(status.toString().split('.').last), // Display status name.
                    onTap: () {
                      Navigator.pop(context); // Close dialog.
                      onStatusChange(event, status); // Trigger status change callback.
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  /// Shows a confirmation dialog to delete the event.
  void _showDeleteConfirmation(BuildContext context) {
    final eventService = context.read<EventService>(); // Get event service.

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Event'), // Dialog title.
        content: Text('Are you sure you want to delete "${event.name}"?'), // Confirmation message.
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), // Close dialog on cancel.
            child: const Text('Cancel'), // Cancel button.
          ),
          TextButton(
            onPressed: () async {
              try {
                await eventService.deleteEvent(event.id); // Delete event.

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext); // Close dialog.
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Event deleted successfully')), // Show success message.
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'), // Show error message.
                      backgroundColor: Colors.red, // Red background for error.
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red, // Red text for delete button.
            ),
            child: const Text('Delete'), // Delete button.
          ),
        ],
      ),
    );
  }
}