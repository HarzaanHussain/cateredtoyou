import 'package:cateredtoyou/widgets/themed_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:cateredtoyou/services/notification_service.dart';
import 'package:intl/intl.dart';

class CreateNotificationPage extends StatefulWidget {
  const CreateNotificationPage({super.key});

  @override
  State<CreateNotificationPage> createState() => _CreateNotificationPageState();
}

class _CreateNotificationPageState extends State<CreateNotificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _screenController = TextEditingController(text: 'home');
  final _extraDataController = TextEditingController();
  final _contentIdController = TextEditingController();

  DateTime _scheduledDate = DateTime.now().add(const Duration(minutes: 1));
  bool _isScheduled = false;
  final NotificationService _notificationService = NotificationService();

  // Content type and parameter name mapping
  final Map<String, String> _contentTypeMapping = {
    'events': 'eventId',
    'inventory': 'itemId',
    'tasks': 'taskId',
    'vehicles': 'vehicleId',
    'staff': 'staffId',
    'customers': 'customerId',
  };

  final List<String> _availableScreens = [
    'home',
    'events',
    'staff',
    'inventory',
    'menu-items',
    'customers',
    'vehicles',
    'deliveries',
    'calendar',
    'tasks',
    'notifications',
  ];

  @override
  void initState() {
    super.initState();
    _notificationService.initNotification();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _screenController.dispose();
    _extraDataController.dispose();
    _contentIdController.dispose();
    super.dispose();
  }

  // Get parameter name for the current content type
  String? get _contentIdParamName {
    return _contentTypeMapping[_screenController.text];
  }

  // Handle screen selection change
  void _onScreenChanged(String? newValue) {
    if (newValue != null) {
      setState(() {
        _screenController.text = newValue;

        // Clear content ID if screen changes
        _contentIdController.clear();

        // Update extra data field
        _updateExtraDataField();
      });
    }
  }

  // Update the extra data field based on selected screen and content ID
  void _updateExtraDataField() {
    final paramName = _contentIdParamName;

    if (paramName != null && _contentIdController.text.isNotEmpty) {
      _extraDataController.text = '$paramName:${_contentIdController.text}';
    } else {
      _extraDataController.text = '';
    }
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_scheduledDate),
      );
      if (pickedTime != null) {
        setState(() {
          _scheduledDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  void _sendNotification() async {
    if (_formKey.currentState!.validate()) {
      String screen = _screenController.text.trim();
      Map<String, dynamic> extraData = {};

      // Parse extra data if provided
      if (_extraDataController.text.isNotEmpty) {
        try {
          // Format expected: key1:value1;key2:value2
          final pairs = _extraDataController.text.split(';');
          for (final pair in pairs) {
            final parts = pair.split(':');
            if (parts.length == 2) {
              extraData[parts[0].trim()] = parts[1].trim();
            }
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error parsing extra data: $e')),
          );
          return;
        }
      }

      try {
        if (_isScheduled) {
          await _notificationService.scheduleNotification(
            title: _titleController.text,
            body: _bodyController.text,
            scheduledTime: _scheduledDate,
            screen: screen,
            extraData: extraData,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notification scheduled successfully!'),
              ),
            );
          }
        } else {
          await _notificationService.showNotification(
            title: _titleController.text,
            body: _bodyController.text,
            screen: screen,
            extraData: extraData,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notification sent successfully!'),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasContentIdParam = _contentIdParamName != null;
    final String contentType = _screenController.text.replaceAll('-', ' ');

    return Scaffold(
      appBar: ThemedAppBar(
         const Text('Create Notification'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: 'Body',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a body';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _screenController.text,
                decoration: const InputDecoration(
                  labelText: 'Navigate to Screen',
                  border: OutlineInputBorder(),
                ),
                items: _availableScreens.map((String screen) {
                  return DropdownMenuItem<String>(
                    value: screen,
                    child: Text(screen),
                  );
                }).toList(),
                onChanged: _onScreenChanged,
              ),

              // Show content ID field when applicable
              if (hasContentIdParam) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contentIdController,
                  decoration: InputDecoration(
                    labelText: '${contentType.capitalize()} ID',
                    border: const OutlineInputBorder(),
                    hintText: 'Enter the Firestore document ID',
                    helperText: 'This will be used for direct navigation',
                  ),
                  onChanged: (value) {
                    setState(() {
                      _updateExtraDataField();
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Tip: You can find the ${contentType.capitalize()} ID in the Firestore console',
                  style: const TextStyle(
                      fontStyle: FontStyle.italic, fontSize: 12),
                ),
              ],

              const SizedBox(height: 16),
              TextFormField(
                controller: _extraDataController,
                decoration: InputDecoration(
                  labelText: 'Extra Data (key1:value1;key2:value2)',
                  border: const OutlineInputBorder(),
                  hintText: hasContentIdParam
                      ? 'Auto-filled based on content ID'
                      : 'Optional: id:123;type:reminder',
                ),
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('Schedule Notification'),
                value: _isScheduled,
                onChanged: (value) {
                  setState(() {
                    _isScheduled = value;
                  });
                },
              ),
              if (_isScheduled) ...[
                ListTile(
                  title: const Text('Scheduled Time'),
                  subtitle: Text(
                    DateFormat('MMM d, yyyy - h:mm a').format(_scheduledDate),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDateTime(context),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _sendNotification,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: Text(_isScheduled
                    ? 'Schedule Notification'
                    : 'Send Notification'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Extension method to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
