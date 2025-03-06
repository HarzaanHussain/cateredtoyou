import 'package:cateredtoyou/services/notification_service.dart';
import 'package:flutter/material.dart';

class CreateNotificationPage extends StatefulWidget {
  const CreateNotificationPage({Key? key}) : super(key: key);

  @override
  _CreateNotificationPageState createState() => _CreateNotificationPageState();
}

class _CreateNotificationPageState extends State<CreateNotificationPage> {
  final NotificationService _notificationService = NotificationService();
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _payloadController = TextEditingController();
  
  bool _isScheduled = false;
  bool _isSending = false;
  bool _showAdvancedOptions = false;
  
  // Predefined navigation options for the payload
  final List<Map<String, String>> _navigationOptions = [
    {'label': 'None', 'value': ''},
    {'label': 'Home Screen', 'value': 'screen:home'},
    {'label': 'Staff List', 'value': 'screen:staff'},
    {'label': 'Events', 'value': 'screen:events'},
    {'label': 'Inventory', 'value': 'screen:inventory'},
    {'label': 'Menu Items', 'value': 'screen:menu-items'},
    // Add more options as needed
  ];
  
  String _selectedNavigation = '';

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _payloadController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final title = _titleController.text.trim();
      final body = _bodyController.text.trim();
      
      // Build the payload from dropdown and custom field
      String? payload;
      if (_selectedNavigation.isNotEmpty) {
        payload = _selectedNavigation;
      }
      
      // Add custom payload if provided
      if (_payloadController.text.isNotEmpty) {
        payload = payload != null 
            ? '$payload;${_payloadController.text}' 
            : _payloadController.text;
      }

      if (_isScheduled) {
        // Schedule for 10 seconds in the future
        final scheduledTime = DateTime.now().add(const Duration(seconds: 10));
        
        await _notificationService.scheduleNotification(
          title: title,
          body: body,
          scheduledTime: scheduledTime,
          payload: payload,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Notification scheduled for ${scheduledTime.toString()}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Send immediately
        await _notificationService.showNotification(
          title: title,
          body: body,
          payload: payload,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification sent successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Clear the form after sending
      _titleController.clear();
      _bodyController.clear();
      _payloadController.clear();
      setState(() {
        _isScheduled = false;
        _showAdvancedOptions = false;
        _selectedNavigation = '';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Notification'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Notification Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bodyController,
                  decoration: const InputDecoration(
                    labelText: 'Notification Body',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 5,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a message';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    setState(() {
                      _showAdvancedOptions = !_showAdvancedOptions;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          _showAdvancedOptions
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_right,
                        ),
                        const Text(
                          'Advanced Options',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showAdvancedOptions)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Navigate To',
                          border: OutlineInputBorder(),
                          helperText: 'Screen to open when notification is tapped',
                        ),
                        value: _selectedNavigation,
                        items: _navigationOptions.map((option) {
                          return DropdownMenuItem<String>(
                            value: option['value'],
                            child: Text(option['label']!),
                          );
                        }).toList(),
                        onChanged: (String? value) {
                          setState(() {
                            _selectedNavigation = value ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _payloadController,
                        decoration: const InputDecoration(
                          labelText: 'Custom Payload (Optional)',
                          border: OutlineInputBorder(),
                          helperText:
                              'Format: key1:value1;key2:value2',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          'This data will be included in the notification for advanced functionality.',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                SwitchListTile(
                  title: const Text('Schedule for 10 seconds later'),
                  subtitle: const Text(
                      'When enabled, the notification will be scheduled instead of sent immediately'),
                  value: _isScheduled,
                  onChanged: (value) {
                    setState(() {
                      _isScheduled = value;
                    });
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSending ? null : _sendNotification,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isSending
                      ? const CircularProgressIndicator()
                      : Text(
                          _isScheduled ? 'Schedule Notification' : 'Send Notification',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}