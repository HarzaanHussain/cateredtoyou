import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/event_model.dart';
import 'package:cateredtoyou/services/event_service.dart';
import 'package:go_router/go_router.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, List<Event>> _groupEvents(List<Event> events) {
    final Map<DateTime, List<Event>> grouped = {};
    for (final event in events) {
      final eventDate = DateTime(event.startDate.year, event.startDate.month, event.startDate.day);
      grouped[eventDate] = (grouped[eventDate] ?? [])..add(event);
    }
    return grouped;
  }

  List<Event> _getEventsForDay(DateTime day, Map<DateTime, List<Event>> grouped) {
    return grouped[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: StreamBuilder<List<Event>>(
        stream: context.read<EventService>().getEvents(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snapshot.data ?? [];
          final groupedEvents = _groupEvents(events);
          return Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: (day) => _getEventsForDay(day, groupedEvents),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                },
                calendarStyle: const CalendarStyle(
                  markerDecoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: _getEventsForDay(_selectedDay ?? _focusedDay, groupedEvents)
                      .map((event) => ListTile(
                            title: Text(event.name),
                            subtitle: Text(event.description),
                            onTap: () => context.push('/event-details', extra: event),
                          ))
                      .toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
