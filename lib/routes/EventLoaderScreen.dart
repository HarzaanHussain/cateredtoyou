import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cateredtoyou/services/event_service.dart';
import 'package:cateredtoyou/widgets/bottom_toolbar.dart';

class EventLoaderScreen extends StatefulWidget {
  final String eventId;

  const EventLoaderScreen({
    Key? key,
    required this.eventId,
  }) : super(key: key);

  @override
  State<EventLoaderScreen> createState() => _EventLoaderScreenState();
}

class _EventLoaderScreenState extends State<EventLoaderScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    try {
      final eventService = Provider.of<EventService>(context, listen: false);
      final event = await eventService.getEventById(widget.eventId);

      if (event == null) {
        setState(() {
          _errorMessage = 'Event not found';
          _isLoading = false;
        });
        return;
      }

      // Navigate to the normal event details screen with the loaded event
      if (mounted) {
        context.push('/event-details', extra: event);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading event: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading Event'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/events'),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
        bottomNavigationBar: const BottomToolbar(),
      );
    }

    // Show error with back button if there's an issue
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/events'),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage ?? 'Unable to load event',
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEvent,
              child: const Text('Try Again'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/events'),
              child: const Text('Go Back to Events'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomToolbar(),
    );
  }
}
