import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/event_model.dart';
import 'package:cateredtoyou/services/event_service.dart';
import 'package:go_router/go_router.dart';
import 'package:cateredtoyou/widgets/bottom_toolbar.dart';
import 'package:intl/intl.dart'; // For formatting event times

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Keep track of current format (month, 2 weeks, week).
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // Groups events by day (year-month-day only).
  Map<DateTime, List<Event>> _groupEvents(List<Event> events) {
    final Map<DateTime, List<Event>> grouped = {};
    for (final event in events) {
      final eventDate = DateTime(
        event.startDate.year,
        event.startDate.month,
        event.startDate.day,
      );
      if (grouped[eventDate] == null) {
        grouped[eventDate] = [];
      }
      grouped[eventDate]!.add(event);
    }
    return grouped;
  }

  // Retrieves events for a specific day.
  List<Event> _getEventsForDay(DateTime day, Map<DateTime, List<Event>> grouped) {
    return grouped[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const BottomToolbar(),
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
                calendarFormat: _calendarFormat,
                // Let the user switch between Month, 2 Weeks, and Week
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },

                // Only load data for the visible month to improve performance
                
                onPageChanged: (focusedDay) {
                  // This is where you could fetch events only for the new month
                  // instead of loading everything at once.
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                },
                

                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                },

                // A better-looking header with custom icons.
                headerStyle: const HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: true,
                  formatButtonShowsNext: false,
                  leftChevronIcon: Icon(Icons.chevron_left),
                  rightChevronIcon: Icon(Icons.chevron_right),
                ),

                // Style improvements: highlight weekends, selected day, and today.
                calendarStyle: const CalendarStyle(
                  weekendTextStyle: TextStyle(color: Color.fromARGB(255, 11, 137, 216)),
                  todayDecoration: BoxDecoration(
                    color: Colors.orangeAccent,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),

                // Load events for each day
                eventLoader: (day) => _getEventsForDay(day, groupedEvents),

                // Custom marker to show number of events per day
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, dayEvents) {
                    if (dayEvents.isEmpty) return const SizedBox();
                    return Positioned(
                      bottom: 4,
                      right: 2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(255, 32, 156, 205),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${dayEvents.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              // Build a list of events for the selected (or focused) day
              Expanded(
                child: Builder(builder: (context) {
                  final dayEvents =
                      _getEventsForDay(_selectedDay ?? _focusedDay, groupedEvents);
                  if (dayEvents.isEmpty) {
                    return const Center(child: Text('No events for this day.'));
                  }

                  return ListView(
                    children: dayEvents.map((event) {
                      // Format the time if needed (h:mm a)
                      final formattedTime =
                          DateFormat('h:mm a').format(event.startDate);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          title: Text(event.name),
                          subtitle: Text('${event.description}\n$formattedTime'),
                          onTap: () =>
                              context.push('/event-details', extra: event),
                        ),
                      );
                    }).toList(),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
