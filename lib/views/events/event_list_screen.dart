import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cateredtoyou/models/event_model.dart';
import 'package:cateredtoyou/services/event_service.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  String _searchQuery = '';
  EventStatus? _filterStatus;
  bool _showUpcomingOnly = true;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Event> _filterEvents(List<Event> events) {
    return events.where((event) {
      if (_showUpcomingOnly && event.startDate.isBefore(DateTime.now())) {
        return false;
      }
      if (_filterStatus != null && event.status != _filterStatus) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;

      final query = _searchQuery.toLowerCase();
      return event.name.toLowerCase().contains(query) ||
          event.description.toLowerCase().contains(query) ||
          event.location.toLowerCase().contains(query);
    }).toList();
  }

  void _showStatusConfirmation(Event event, EventStatus newStatus) {
    final eventService = context.read<EventService>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Change Event Status'),
        content: Text(
          'Change status of "${event.name}" to ${newStatus.toString().split('.').last}?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                Navigator.pop(dialogContext);
                await eventService.changeEventStatus(event.id, newStatus);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Event status updated successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // Back button icon.
          onPressed: () => context.push('/home'), // Navigate to home screen when pressed.
        ),  
        title: const Text('Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/add-event'),
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
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
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
                            _showUpcomingOnly = selected;
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
                                _filterStatus = selected ? status : null;
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
              stream: context.read<EventService>().getEvents(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final events = snapshot.data ?? [];
                final filteredEvents = _filterEvents(events);

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
                          onPressed: () => context.push('/add-event'),
                          icon: const Icon(Icons.add),
                          label: const Text('Create Event'),
                        ),
                      ],
                    ),
                  );
                }

                if (filteredEvents.isEmpty) {
                  return const Center(
                    child: Text('No events match your search'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredEvents.length,
                  itemBuilder: (context, index) {
                    final event = filteredEvents[index];
                    return EventListItem(
                      event: event,
                      onStatusChange: _showStatusConfirmation,
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

class EventListItem extends StatelessWidget {
  final Event event;
  final void Function(Event event, EventStatus newStatus) onStatusChange;

  const EventListItem({
    super.key,
    required this.event,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUpcoming = event.startDate.isAfter(DateTime.now());
    final dateFormat = DateFormat('MMM d, y');
    final timeFormat = DateFormat('h:mm a');

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () => context.push('/event-details', extra: event),
        title: Row(
          children: [
            Expanded(
              child: Text(
                event.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: _getStatusColor(event.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                event.status.toString().split('.').last,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _getStatusColor(event.status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              event.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: theme.textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.location,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: theme.textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 4),
                Text(
                  dateFormat.format(event.startDate),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: theme.textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 4),
                Text(
                  '${timeFormat.format(event.startTime)} - ${timeFormat.format(event.endTime)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: 16,
                  color: theme.textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 4),
                Text(
                  '${event.guestCount} guests',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: theme.textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 4),
                Text(
                  'Min. Staff: ${event.minStaff}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                context.push('/edit-event', extra: event);
                break;
              case 'status':
                _showStatusChangeDialog(context);
                break;
              case 'delete':
                _showDeleteConfirmation(context);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            const PopupMenuItem(
              value: 'status',
              child: Text('Change Status'),
            ),
            const PopupMenuItem(
              value: 'delete',
              textStyle: TextStyle(color: Colors.red),
              child: Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(EventStatus status) {
    switch (status) {
      case EventStatus.draft:
        return Colors.grey;
      case EventStatus.pending:
        return Colors.orange;
      case EventStatus.confirmed:
        return Colors.green;
      case EventStatus.inProgress:
        return Colors.blue;
      case EventStatus.completed:
        return Colors.purple;
      case EventStatus.cancelled:
        return Colors.red;
      case EventStatus.archived:
        return Colors.brown;
    }
  }

  void _showStatusChangeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Event Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: EventStatus.values
              .where((status) => status != event.status)
              .map((status) => ListTile(
                    title: Text(status.toString().split('.').last),
                    onTap: () {
                      Navigator.pop(context);
                      onStatusChange(event, status);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final eventService = context.read<EventService>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await eventService.deleteEvent(event.id);

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Event deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}