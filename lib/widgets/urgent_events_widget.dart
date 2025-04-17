import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cateredtoyou/models/event_model.dart';
import 'package:cateredtoyou/services/event_service.dart';

class UrgentEventsWidget extends StatelessWidget {
  const UrgentEventsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Event>>(
      stream: context.read<EventService>().getEvents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final urgentEvents = _getUrgentEvents(snapshot.data!);

        if (urgentEvents.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Urgent Events',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/events'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildUrgentEventCard(context, urgentEvents.first),
          ],
        );
      },
    );
  }

  List<Event> _getUrgentEvents(List<Event> events) {
    final now = DateTime.now();
    final urgent = events.where((event) {
      final isUrgentStatus = [
        EventStatus.pending,
        EventStatus.inProgress
      ].contains(event.status);

      final isComingSoon = event.startDate.isBefore(now.add(const Duration(days: 7)));

      return isUrgentStatus || isComingSoon;
    }).toList();

    urgent.sort((a, b) => a.startDate.compareTo(b.startDate));

    return urgent.take(1).toList();
  }

  Widget _buildUrgentEventCard(BuildContext context, Event event) {
    final dateFormat = DateFormat('MMM d, y');
    final timeFormat = DateFormat('h:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    event.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(event.status).withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    event.status.toString().split('.').last,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _getStatusColor(event.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Text(dateFormat.format(event.startDate)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 8),
                Text('${timeFormat.format(event.startTime)} - ${timeFormat.format(event.endTime)}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.location,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push('/event-details', extra: event),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
              child: const Text('View Details'),
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
}
