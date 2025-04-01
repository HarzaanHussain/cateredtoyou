import 'package:cateredtoyou/models/reccuring_notification_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cateredtoyou/services/notification_service.dart';
import 'package:cateredtoyou/widgets/bottom_toolbar.dart';

class RecurringNotificationSetupScreen extends StatefulWidget {
  const RecurringNotificationSetupScreen({super.key});

  @override
  _RecurringNotificationSetupScreenState createState() =>
      _RecurringNotificationSetupScreenState();
}

class _RecurringNotificationSetupScreenState
    extends State<RecurringNotificationSetupScreen> {
  final NotificationService _notificationService = NotificationService();
  List<RecurringNotification> _recurringNotifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecurringNotifications();
  }

  Future<void> _loadRecurringNotifications() async {
    setState(() {
      _isLoading = true;
    });

    final notifications = await _notificationService.getRecurringNotifications();
    setState(() {
      _recurringNotifications = notifications;
      _isLoading = false;
    });
  }

  Future<void> _deleteRecurringNotification(String id) async {
    try {
      await _notificationService.deleteRecurringNotification(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recurring notification deleted')),
      );
      _loadRecurringNotifications();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _toggleActive(RecurringNotification notification) async {
    try {
      final updatedNotification = notification.copyWith(
        isActive: !notification.isActive,
      );
      await _notificationService.updateRecurringNotification(updatedNotification);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${notification.title} ${updatedNotification.isActive ? 'activated' : 'deactivated'}'),
        ),
      );
      _loadRecurringNotifications();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateRecurringNotificationDialog(),
    ).then((_) => _loadRecurringNotifications());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Notifications'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recurringNotifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No recurring notifications set up yet'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _showCreateDialog(context),
                        child: const Text('Create New'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Tap on a notification to edit. Long press to delete.',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _recurringNotifications.length,
                        itemBuilder: (context, index) {
                          final notification = _recurringNotifications[index];
                          final dateFormat = DateFormat('MMM d, y - h:mm a');
                          
                          return Dismissible(
                            key: Key('recurring_${notification.id}'),
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (direction) async {
                              return await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Notification'),
                                  content: Text(
                                      'Are you sure you want to delete "${notification.title}"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('CANCEL'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('DELETE'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (direction) {
                              _deleteRecurringNotification(notification.id);
                            },
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: notification.isActive
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey,
                                child: Icon(
                                  _getIconForScreen(notification.screen),
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                notification.title,
                                style: TextStyle(
                                  fontWeight: notification.isActive
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(notification.body),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Repeats: ${notification.intervalDescription}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    'Next: ${dateFormat.format(notification.nextScheduledDate)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: Switch(
                                value: notification.isActive,
                                onChanged: (value) => _toggleActive(notification),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditRecurringNotificationScreen(
                                      notification: notification,
                                    ),
                                  ),
                                ).then((_) => _loadRecurringNotifications());
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: const BottomToolbar(),
    );
  }

  IconData _getIconForScreen(String screen) {
    switch (screen) {
      case 'inventory':
        return Icons.inventory_2;
      case 'events':
        return Icons.event;
      case 'staff':
        return Icons.people;
      case 'tasks':
        return Icons.task;
      case 'vehicles':
        return Icons.directions_car;
      default:
        return Icons.notifications;
    }
  }
}

class CreateRecurringNotificationDialog extends StatefulWidget {
  const CreateRecurringNotificationDialog({Key? key}) : super(key: key);

  @override
  _CreateRecurringNotificationDialogState createState() =>
      _CreateRecurringNotificationDialogState();
}

class _CreateRecurringNotificationDialogState
    extends State<CreateRecurringNotificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _selectedScreen = 'inventory';
  RecurringInterval _selectedInterval = RecurringInterval.monthly;
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime? _endDate;
  bool _hasEndDate = false;

  final NotificationService _notificationService = NotificationService();

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
        await _notificationService.createRecurringNotification(
          title: _titleController.text,
          body: _bodyController.text,
          screen: _selectedScreen,
          interval: _selectedInterval,
          startDate: _startDate,
          endDate: _hasEndDate ? _endDate : null,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recurring notification created successfully!'),
            ),
          );
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
    final dateFormat = DateFormat('MMM d, y');
    final timeFormat = DateFormat('h:mm a');

    return AlertDialog(
      title: const Text('Create Recurring Notification'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
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
                ),
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
                ),
                items: _availableScreens.map((String screen) {
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
              const Text(
                'Start Date & Time',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => _selectStartDate(context),
                      child: Text(dateFormat.format(_startDate)),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => _selectStartTime(context),
                      child: Text(timeFormat.format(_startDate)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _hasEndDate,
                    onChanged: (value) {
                      setState(() {
                        _hasEndDate = value ?? false;
                      });
                    },
                  ),
                  const Text('Set End Date'),
                ],
              ),
              if (_hasEndDate)
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => _selectEndDate(context),
                        child: Text(_endDate != null
                            ? dateFormat.format(_endDate!)
                            : 'Select Date'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _createRecurringNotification,
          child: const Text('CREATE'),
        ),
      ],
    );
  }
}

class EditRecurringNotificationScreen extends StatefulWidget {
  final RecurringNotification notification;

  const EditRecurringNotificationScreen({
    Key? key,
    required this.notification,
  }) : super(key: key);

  @override
  _EditRecurringNotificationScreenState createState() =>
      _EditRecurringNotificationScreenState();
}

class _EditRecurringNotificationScreenState
    extends State<EditRecurringNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  late String _selectedScreen;
  late RecurringInterval _selectedInterval;
  late DateTime _startDate;
  DateTime? _endDate;
  late bool _hasEndDate;
  late bool _isActive;

  final NotificationService _notificationService = NotificationService();

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
    _titleController = TextEditingController(text: widget.notification.title);
    _bodyController = TextEditingController(text: widget.notification.body);
    _selectedScreen = widget.notification.screen;
    _selectedInterval = widget.notification.interval;
    _startDate = widget.notification.startDate;
    _endDate = widget.notification.endDate;
    _hasEndDate = widget.notification.endDate != null;
    _isActive = widget.notification.isActive;
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

  Future<void> _updateRecurringNotification() async {
    if (_formKey.currentState!.validate()) {
      try {
        final updatedNotification = widget.notification.copyWith(
          title: _titleController.text,
          body: _bodyController.text,
          screen: _selectedScreen,
          interval: _selectedInterval,
          startDate: _startDate,
          endDate: _hasEndDate ? _endDate : null,
          isActive: _isActive,
        );

        await _notificationService.updateRecurringNotification(
          updatedNotification,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recurring notification updated successfully!'),
            ),
          );
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

  Future<void> _deleteNotification() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: Text(
            'Are you sure you want to delete "${widget.notification.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _notificationService.deleteRecurringNotification(
          widget.notification.id,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recurring notification deleted successfully!'),
            ),
          );
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
    final dateFormat = DateFormat('MMM d, y');
    final timeFormat = DateFormat('h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Recurring Notification'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteNotification,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              SwitchListTile(
                title: const Text('Active'),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
              const SizedBox(height: 16),
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
                items: _availableScreens.map((String screen) {
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
                onPressed: _updateRecurringNotification,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomToolbar(),
    );
  }
}