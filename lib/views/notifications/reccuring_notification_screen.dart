import 'package:cateredtoyou/widgets/themed_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:cateredtoyou/models/reccuring_notification_model.dart';
import 'package:cateredtoyou/services/notification_service.dart';
import 'package:cateredtoyou/widgets/bottom_toolbar.dart';
import 'package:intl/intl.dart';

class UnifiedNotificationScreen extends StatefulWidget {
  const UnifiedNotificationScreen({super.key});

  @override
  State<UnifiedNotificationScreen> createState() => _UnifiedNotificationScreenState();
}

class _UnifiedNotificationScreenState extends State<UnifiedNotificationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NotificationService _notificationService = NotificationService();

  // Lists of screens available for navigation
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

  // Content type and parameter name mapping
  final Map<String, String> _contentTypeMapping = {
    'events': 'eventId',
    'inventory': 'itemId',
    'tasks': 'taskId',
    'vehicles': 'vehicleId',
    'staff': 'staffId',
    'customers': 'customerId',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _notificationService.initNotification();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ThemedAppBar(
       const Text('Create Notification'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'One-Time', icon: Icon(Icons.notifications)),
            Tab(text: 'Recurring', icon: Icon(Icons.repeat)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: One-time notification
          SingleNotificationTab(
            notificationService: _notificationService,
            availableScreens: _availableScreens,
            contentTypeMapping: _contentTypeMapping,
          ),
          
          // Tab 2: Recurring notification
          RecurringNotificationTab(
            notificationService: _notificationService,
            availableScreens: _availableScreens,
          ),
        ],
      ),
      bottomNavigationBar: const BottomToolbar(),
    );
  }
}

// Tab for one-time notifications
class SingleNotificationTab extends StatefulWidget {
  final NotificationService notificationService;
  final List<String> availableScreens;
  final Map<String, String> contentTypeMapping;

  const SingleNotificationTab({
    super.key,
    required this.notificationService,
    required this.availableScreens,
    required this.contentTypeMapping,
  });

  @override
  State<SingleNotificationTab> createState() => _SingleNotificationTabState();
}

class _SingleNotificationTabState extends State<SingleNotificationTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _screenController = TextEditingController(text: 'home');
  final _extraDataController = TextEditingController();
  final _contentIdController = TextEditingController();

  DateTime _scheduledDate = DateTime.now().add(const Duration(minutes: 1));
  bool _isScheduled = false;

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
    return widget.contentTypeMapping[_screenController.text];
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
          await widget.notificationService.scheduleNotification(
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
            _clearForm();
          }
        } else {
          await widget.notificationService.showNotification(
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
            _clearForm();
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

  void _clearForm() {
    _titleController.clear();
    _bodyController.clear();
    _contentIdController.clear();
    _extraDataController.clear();
    setState(() {
      _screenController.text = 'home';
      _isScheduled = false;
      _scheduledDate = DateTime.now().add(const Duration(minutes: 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasContentIdParam = _contentIdParamName != null;
    final String contentType = _screenController.text.replaceAll('-', ' ');

    return Padding(
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
              items: widget.availableScreens.map((String screen) {
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
                  fontStyle: FontStyle.italic, 
                  fontSize: 12
                ),
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
    );
  }
}

// Tab for recurring notifications
class RecurringNotificationTab extends StatefulWidget {
  final NotificationService notificationService;
  final List<String> availableScreens;

  const RecurringNotificationTab({
    super.key,
    required this.notificationService,
    required this.availableScreens,
  });

  @override
  State<RecurringNotificationTab> createState() => _RecurringNotificationTabState();
}

class _RecurringNotificationTabState extends State<RecurringNotificationTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _selectedScreen = 'inventory';
  RecurringInterval _selectedInterval = RecurringInterval.monthly;
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime? _endDate;
  bool _hasEndDate = false;

  @override
  void initState() {
    super.initState();
    // Set default values for inventory check
    _titleController.text = 'Inventory Check Reminder';
    _bodyController.text = 'Time to verify your physical inventory matches your digital records';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _startDate.hour,
          _startDate.minute,
        );
      });
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = DateTime(
          _startDate.year,
          _startDate.month,
          _startDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _createRecurringNotification() async {
    if (_formKey.currentState!.validate()) {
      try {
        await widget.notificationService.createRecurringNotification(
          title: _titleController.text,
          body: _bodyController.text,
          screen: _selectedScreen,
          interval: _selectedInterval,
          startDate: _startDate,
          endDate: _hasEndDate ? _endDate : null,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recurring notification created successfully!'),
            ),
          );
          _clearForm();
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

  void _clearForm() {
    setState(() {
      _titleController.text = 'Inventory Check Reminder';
      _bodyController.text = 'Time to verify your physical inventory matches your digital records';
      _selectedScreen = 'inventory';
      _selectedInterval = RecurringInterval.monthly;
      _startDate = DateTime.now().add(const Duration(days: 1));
      _endDate = null;
      _hasEndDate = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, y');
    final timeFormat = DateFormat('h:mm a');

    return Padding(
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
              value: _selectedScreen,
              decoration: const InputDecoration(
                labelText: 'Target Screen',
                border: OutlineInputBorder(),
              ),
              items: widget.availableScreens.map((String screen) {
                return DropdownMenuItem<String>(
                  value: screen,
                  child: Text(screen),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedScreen = newValue;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<RecurringInterval>(
              value: _selectedInterval,
              decoration: const InputDecoration(
                labelText: 'Repeat Interval',
                border: OutlineInputBorder(),
              ),
              items: RecurringInterval.values.map((interval) {
                String display;
                switch (interval) {
                  case RecurringInterval.daily:
                    display = 'Daily';
                    break;
                  case RecurringInterval.weekly:
                    display = 'Weekly';
                    break;
                  case RecurringInterval.monthly:
                    display = 'Monthly';
                    break;
                  case RecurringInterval.quarterly:
                    display = 'Quarterly';
                    break;
                  case RecurringInterval.yearly:
                    display = 'Yearly';
                    break;
                }
                return DropdownMenuItem<RecurringInterval>(
                  value: interval,
                  child: Text(display),
                );
              }).toList(),
              onChanged: (RecurringInterval? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedInterval = newValue;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Start Date & Time',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today),
                            label: Text(dateFormat.format(_startDate)),
                            onPressed: () => _selectStartDate(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time),
                            label: Text(timeFormat.format(_startDate)),
                            onPressed: () => _selectStartTime(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Set End Date'),
              value: _hasEndDate,
              onChanged: (value) {
                setState(() {
                  _hasEndDate = value ?? false;
                });
              },
            ),
            if (_hasEndDate)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'End Date',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text(_endDate != null
                          ? dateFormat.format(_endDate!)
                          : 'Select Date'),
                        onPressed: () => _selectEndDate(context),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _createRecurringNotification,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Create Recurring Notification'),
            ),
          ],
        ),
      ),
    );
  }
}

// Extension method to capitalize strings
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}