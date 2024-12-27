import 'package:cateredtoyou/models/user_model.dart';
import 'package:cateredtoyou/services/staff_service.dart';
import 'package:cateredtoyou/models/event_model.dart';
import 'package:cateredtoyou/services/event_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/task_model.dart';
import 'package:cateredtoyou/services/task_service.dart';

class ManageTasksScreen extends StatefulWidget {
  const ManageTasksScreen({super.key});

  @override
  State<ManageTasksScreen> createState() => _ManageTasksScreenState();
}

class _ManageTasksScreenState extends State<ManageTasksScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  TaskPriority _priority = TaskPriority.medium;
  String? _assignedTo;
  String? _departmentId;
  String? _selectedEventId;
  final List<String> _checklist = [];
  late Stream<List<UserModel>> _staffStream;
  late Stream<List<String>> _departmentStream;
  late Stream<List<Event>> _eventsStream;

  @override
  void initState() {
    super.initState();
    _initializeStreams();
  }

  void _initializeStreams() {
    final staffService = context.read<StaffService>();
    final eventService = context.read<EventService>();

    _staffStream = staffService.getStaffMembers();
    _departmentStream = staffService.getDepartments();
    _eventsStream = eventService.getEvents();

    _assignedTo = null;
    _departmentId = null;
    _selectedEventId = null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final currentContext = context;
    final pickedDate = await showDatePicker(
      context: currentContext,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _dueTime ?? TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          _dueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          _dueTime = pickedTime;
        });
      }
    }
  }

  void _addChecklistItem() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add Checklist Item'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter checklist item',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    _checklist.add('[ ] ${controller.text.trim()}');
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('ADD'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createTask() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a due date and time')),
      );
      return;
    }

    try {
      final taskService = context.read<TaskService>();
      await taskService.createTask(
        eventId: _selectedEventId ?? 'no_event',
        name: _nameController.text,
        description: _descriptionController.text,
        dueDate: _dueDate!,
        priority: _priority,
        assignedTo: _assignedTo!,
        departmentId: _departmentId!,
        checklist: _checklist,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Task'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildEventSelector(),
              const SizedBox(height: 16),
              _buildBasicDetails(),
              const SizedBox(height: 16),
              _buildAssignmentSection(),
              const SizedBox(height: 24),
              _buildChecklistSection(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
  // Continuing from previous ManageTasksScreen implementation...

  Widget _buildEventSelector() {
    return StreamBuilder<List<Event>>(
      stream: _eventsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Error loading events'),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final upcomingEvents = snapshot.data!
            .where((event) => event.startDate.isAfter(DateTime.now()))
            .toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));

        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Event (Optional)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: _selectedEventId,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    border: InputBorder.none,
                    hintText: 'Select an event',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No Event'),
                    ),
                    ...upcomingEvents.map((event) => DropdownMenuItem(
                          value: event.id,
                          child: Text(
                            '${event.name} (${DateFormat('MMM dd').format(event.startDate)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedEventId = value;
                      // If an event is selected, update department and staff based on the event
                      if (value != null) {
                        final event =
                            upcomingEvents.firstWhere((e) => e.id == value);
                        if (event.assignedStaff.isNotEmpty) {
                          _departmentId = event.assignedStaff.first.role;
                          // Update the _assignedTo value based on the selected event's assigned staff
                          _assignedTo = event.assignedStaff.first.userId;
                        } else {
                          // Reset _departmentId and _assignedTo if no assigned staff found
                          _departmentId = null;
                          _assignedTo = null;
                        }
                        // Trigger a rebuild of the department and staff dropdowns
                        _initializeStreams();
                      } else {
                        // Reset _departmentId, _assignedTo, and streams when no event is selected
                        _departmentId = null;
                        _assignedTo = null;
                        _initializeStreams();
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBasicDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Task Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.task),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a task name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _selectDateTime(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                      labelText: 'Due Date & Time',
                    ),
                    child: Text(
                      _dueDate == null
                          ? 'Select due date and time'
                          : DateFormat('MMM dd, yyyy HH:mm').format(_dueDate!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TaskPriority>(
                  value: _priority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.flag),
                  ),
                  items: TaskPriority.values.map((priority) {
                    return DropdownMenuItem(
                      value: priority,
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 12,
                            color: _getPriorityColor(priority),
                          ),
                          const SizedBox(width: 8),
                          Text(priority
                              .toString()
                              .split('.')
                              .last
                              .toUpperCase()),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _priority = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assignment',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildDepartmentDropdown(),
            const SizedBox(height: 16),
            _buildStaffDropdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentDropdown() {
    return StreamBuilder<List<String>>(
      stream: _departmentStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }

        final departments = snapshot.data!;
        return DropdownButtonFormField<String>(
          value: _departmentId,
          decoration: const InputDecoration(
            labelText: 'Department',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.business),
          ),
          items: departments
              .map((dept) => DropdownMenuItem(
                    value: dept,
                    child: Text(dept),
                  ))
              .toList(),
          validator: (value) =>
              value == null ? 'Please select a department' : null,
          onChanged: (value) {
            setState(() {
              _departmentId = value;
              _assignedTo = null;
              if (value != null) {
                _staffStream = context
                    .read<StaffService>()
                    .getStaffMembers()
                    .map((staff) => staff
                        .where((user) =>
                            user.departments?.contains(value) ?? false)
                        .toList());
              }
            });
          },
        );
      },
    );
  }

  Widget _buildStaffDropdown() {
    return StreamBuilder<List<UserModel>>(
      stream: _staffStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        final staff = snapshot.data ?? [];

        return DropdownButtonFormField<String>(
          value: _assignedTo,
          decoration: const InputDecoration(
            labelText: 'Assign To',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Select a staff member'),
            ),
            ...staff.map((user) => DropdownMenuItem(
                  value: user.uid,
                  child: Text('${user.fullName} (${user.role})'),
                )),
          ],
          validator: (value) =>
              value == null ? 'Please select a staff member' : null,
          onChanged: (value) {
            setState(() {
              _assignedTo = value;
            });
          },
        );
      },
    );
  }

  Widget _buildChecklistSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Checklist',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addChecklistItem,
                  tooltip: 'Add checklist item',
                ),
              ],
            ),
            if (_checklist.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text('No checklist items added'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _checklist.length,
                itemBuilder: (context, index) {
                  final item =
                      _checklist[index].replaceAll(RegExp(r'\[.\]'), '').trim();
                  return Dismissible(
                    key: Key('checklist_$index'),
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) {
                      setState(() {
                        _checklist.removeAt(index);
                      });
                    },
                    child: ListTile(
                      title: Text(item),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _checklist.removeAt(index);
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _createTask,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: const Text('CREATE TASK'),
    );
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return Colors.red;
      case TaskPriority.high:
        return Colors.orange;
      case TaskPriority.medium:
        return Colors.blue;
      case TaskPriority.low:
        return Colors.green;
    }
  }
}

  // ... Additional widget methods will continue in the next part ...