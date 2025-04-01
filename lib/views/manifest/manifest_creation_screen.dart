import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/services/manifest_service.dart';
import 'package:cateredtoyou/services/event_service.dart';

class ManifestCreationScreen extends StatefulWidget {
  final String? eventId; // Optional event ID if coming from an event

  const ManifestCreationScreen({
    super.key,
    this.eventId,
  });

  @override
  State<ManifestCreationScreen> createState() => _ManifestCreationScreenState();
}

class _ManifestCreationScreenState extends State<ManifestCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedEventId;
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = false;
  bool _isCreating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedEventId = widget.eventId;
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final eventService = Provider.of<EventService>(context, listen: false);
      final events = await eventService.getEvents().first;

      // Filter events that don't already have a manifest
      if (!mounted) return;
      final manifestService = Provider.of<ManifestService>(context, listen: false);
      final filteredEvents = <Map<String, dynamic>>[];

      for (final event in events) {
        final hasManifest = await manifestService.doesManifestExist(event.id);
        if (!hasManifest) {
          filteredEvents.add({
            'id': event.id,
            'name': event.name,
            'date': DateFormat('MMM d, yyyy').format(event.startDate),
            'location': event.location,
          });
        }
      }

      setState(() {
        _events = filteredEvents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading events: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createManifest() async {
    if (_selectedEventId == null) {
      setState(() {
        _errorMessage = 'Please select an event';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final eventService = Provider.of<EventService>(context, listen: false);
      final manifestService = Provider.of<ManifestService>(context, listen: false);

      // Get the event to extract items for the manifest
      final event = await eventService.getEventById(_selectedEventId!);
      if (event == null) {
        throw 'Event not found';
      }

      // Create manifest items from event menu items and supplies
      final manifestItems = <ManifestItem>[];

      // Add menu items
      for (final menuItem in event.menuItems) {
        manifestItems.add(ManifestItem(
          id: '${DateTime.now().millisecondsSinceEpoch}_${manifestItems.length}',
          menuItemId: menuItem.menuItemId, // Use the correct property name
          name: menuItem.name,
          quantity: menuItem.quantity,
          loadingStatus: LoadingStatus.unassigned,
        ));
      }

      // Add supplies
      for (final supply in event.supplies) {
        manifestItems.add(ManifestItem(
          id: '${DateTime.now().millisecondsSinceEpoch}_${manifestItems.length}',
          menuItemId: supply.inventoryId, // Use inventoryId as menuItemId for supplies
          name: supply.name,
          quantity: supply.quantity.toInt(),
          loadingStatus: LoadingStatus.unassigned,
        ));
      }

      // Create the manifest with the items
      if (manifestItems.isEmpty) {
        throw 'No items to include in manifest. Add menu items or supplies to the event first.';
      }

      await manifestService.createManifest(
        eventId: _selectedEventId!,
        items: manifestItems,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Manifest created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error creating manifest: $e';
        _isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Manifest'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Create a new manifest for an event',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha((0.1 * 255).toInt()),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          isExpanded: true, // Allow dropdown to use full width
                          decoration: InputDecoration(
                            labelText: 'Select Event',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          value: _selectedEventId,
                          items: _events.map((event) {
                            return DropdownMenuItem<String>(
                              value: event['id'] as String,
                              child: Text(
                                '${event['name']} - ${event['date']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedEventId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select an event';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_events.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withAlpha((0.1 * 255).toInt()),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.amber),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'No events available without a manifest. Create an event first or check if all events already have manifests.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: _isCreating || _events.isEmpty ? null : _createManifest,
                            child: _isCreating
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('Create Manifest'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}