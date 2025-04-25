import 'package:cateredtoyou/models/user_model.dart';
import 'package:cateredtoyou/services/staff_service.dart';
import 'package:cateredtoyou/models/event_model.dart';
import 'package:cateredtoyou/services/event_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/task_model.dart';
import 'package:cateredtoyou/services/task_service.dart';
import 'package:cateredtoyou/widgets/main_scaffold.dart';
import 'package:go_router/go_router.dart';
class ManageTasksScreen extends StatefulWidget {
  const ManageTasksScreen({super.key});

  @override
  State<ManageTasksScreen> createState() => _ManageTasksScreenState();
}

class _ManageTasksScreenState extends State<ManageTasksScreen> {
  final _formKey = GlobalKey<FormState>(); // Key to identify the form and validate it
  final _nameController = TextEditingController(); // Controller for task name input
  final _descriptionController = TextEditingController(); // Controller for task description input
  DateTime? _dueDate; // Variable to store the selected due date
  TimeOfDay? _dueTime; // Variable to store the selected due time
  TaskPriority _priority = TaskPriority.medium; // Default priority for the task
  String? _assignedTo; // Variable to store the selected staff member
  String? _departmentId; // Variable to store the selected department
  String? _selectedEventId; // Variable to store the selected event ID
  final List<String> _checklist = []; // List to store checklist items
  late Stream<List<UserModel>> _staffStream; // Stream to fetch staff members
  late Stream<List<String>> _departmentStream; // Stream to fetch departments
  late Stream<List<Event>> _eventsStream; // Stream to fetch events

  @override
  void initState() {
    super.initState();
    _initializeStreams(); // Initialize the streams when the widget is created
  }

  void _initializeStreams() {
    final staffService = context.read<StaffService>(); // Get the staff service from the context
    final eventService = context.read<EventService>(); // Get the event service from the context

    _staffStream = staffService.getStaffMembers(); // Fetch the staff members
    _departmentStream = staffService.getDepartments(); // Fetch the departments
    _eventsStream = eventService.getEvents(); // Fetch the events

    _assignedTo = null; // Reset the assigned staff member
    _departmentId = null; // Reset the selected department
    _selectedEventId = null; // Reset the selected event
  }

  @override
  void dispose() {
    _nameController.dispose(); // Dispose the name controller to free resources
    _descriptionController.dispose(); // Dispose the description controller to free resources
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context) async {
    if (!mounted) return;

    final DateTime? pickedDate = await showDatePicker(
      context: this.context,
      initialDate: _dueDate ?? DateTime.now(), // Show the current date if no date is selected
      firstDate: DateTime.now(), // The earliest date that can be selected
      lastDate: DateTime.now().add(const Duration(days: 365)), // The latest date that can be selected
    );

    if (!mounted) return;

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: this.context,
        initialTime: _dueTime ?? TimeOfDay.now(), // Show the current time if no time is selected
      );

      if (mounted && pickedTime != null) {
        setState(() {
          _dueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          ); // Combine the picked date and time
          _dueTime = pickedTime; // Store the picked time
        });
      }
    }
  }

  void _addChecklistItem() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(); // Controller for the checklist item input
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
              onPressed: () => Navigator.pop(context), // Close the dialog without adding an item
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    _checklist.add('[ ] ${controller.text.trim()}'); // Add the checklist item
                  });
                  Navigator.pop(context); // Close the dialog after adding the item
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
    if (!_formKey.currentState!.validate()) return; // Validate the form
    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a due date and time')),
      );
      return;
    }

    try {
      final taskService = context.read<TaskService>(); // Get the task service from the context
      await taskService.createTask(
        eventId: _selectedEventId ?? 'no_event', // Use 'no_event' if no event is selected
        name: _nameController.text, // Get the task name from the controller
        description: _descriptionController.text, // Get the task description from the controller
        dueDate: _dueDate!, // Use the selected due date
        priority: _priority, // Use the selected priority
        assignedTo: _assignedTo!, // Use the selected staff member
        departmentId: _departmentId!, // Use the selected department
        checklist: _checklist, // Use the checklist items
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Close the screen after creating the task
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
          return MainScaffold(
            title: 'Create Task',

            // optional back-arrow
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),

            body: SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildEventSelector(),    // your existing helper
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

  Widget _buildEventSelector() {
    return StreamBuilder<List<Event>>(
      stream: _eventsStream, // Stream to fetch events
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Error loading events'), // Show error message if events fail to load
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator()); // Show loading indicator while fetching events
        }

        final upcomingEvents = snapshot.data!
            .where((event) => event.startDate.isAfter(DateTime.now())) // Filter upcoming events
            .toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate)); // Sort events by start date

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
                    style: Theme.of(context).textTheme.titleMedium, // Title for the event selector
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: _selectedEventId, // Selected event ID
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    border: InputBorder.none,
                    hintText: 'Select an event', // Hint text for the dropdown
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No Event'), // Option to select no event
                    ),
                    ...upcomingEvents.map((event) => DropdownMenuItem(
                          value: event.id,
                          child: Text(
                            '${event.name} (${DateFormat('MMM dd').format(event.startDate)})', // Display event name and date
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedEventId = value; // Update the selected event ID
                      // If an event is selected, update department and staff based on the event
                      if (value != null) {
                        final event =
                            upcomingEvents.firstWhere((e) => e.id == value);
                        if (event.assignedStaff.isNotEmpty) {
                          _departmentId = event.assignedStaff.first.role; // Update department based on event
                          // Update the _assignedTo value based on the selected event's assigned staff
                          _assignedTo = event.assignedStaff.first.userId; // Update assigned staff based on event
                        } else {
                          // Reset _departmentId and _assignedTo if no assigned staff found
                          _departmentId = null;
                          _assignedTo = null;
                        }
                        // Trigger a rebuild of the department and staff dropdowns
                        _initializeStreams(); // Reinitialize streams to fetch updated data
                      } else {
                        // Reset _departmentId, _assignedTo, and streams when no event is selected
                        _departmentId = null;
                        _assignedTo = null;
                        _initializeStreams(); // Reinitialize streams to fetch updated data
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

  /// Builds the basic details section of the task form.
  /// 
  /// This section includes:
  /// - Task name input field
  /// - Description input field
  /// - Due date and time picker
  /// - Priority dropdown
  Widget _buildBasicDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Aligns children to the start of the column
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0), // Adds padding around the card
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Aligns children to the start of the column
              children: [
                TextFormField(
                  controller: _nameController, // Controller for task name input
                  decoration: const InputDecoration(
                    labelText: 'Task Name', // Label for the input field
                    border: OutlineInputBorder(), // Adds border to the input field
                    prefixIcon: Icon(Icons.task), // Icon for the input field
                  ),
                  textCapitalization: TextCapitalization.sentences, // Capitalizes the first letter of each sentence
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a task name'; // Validation message if input is empty
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16), // Adds vertical space between elements
                TextFormField(
                  controller: _descriptionController, // Controller for description input
                  decoration: const InputDecoration(
                    labelText: 'Description', // Label for the input field
                    border: OutlineInputBorder(), // Adds border to the input field
                    prefixIcon: Icon(Icons.description), // Icon for the input field
                    alignLabelWithHint: true, // Aligns label with hint text
                  ),
                  maxLines: 3, // Allows multiple lines of text
                  textCapitalization: TextCapitalization.sentences, // Capitalizes the first letter of each sentence
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description'; // Validation message if input is empty
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16), // Adds vertical space between elements
                InkWell(
                  onTap: () => _selectDateTime(context), // Opens date and time picker when tapped
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(), // Adds border to the input field
                      prefixIcon: Icon(Icons.calendar_today), // Icon for the input field
                      labelText: 'Due Date & Time', // Label for the input field
                    ),
                    child: Text(
                      _dueDate == null
                          ? 'Select due date and time' // Placeholder text if no date is selected
                          : DateFormat('MMM dd, yyyy HH:mm').format(_dueDate!), // Formats and displays the selected date
                    ),
                  ),
                ),
                const SizedBox(height: 16), // Adds vertical space between elements
                DropdownButtonFormField<TaskPriority>(
                  value: _priority, // Current selected priority
                  decoration: const InputDecoration(
                    labelText: 'Priority', // Label for the dropdown
                    border: OutlineInputBorder(), // Adds border to the dropdown
                    prefixIcon: Icon(Icons.flag), // Icon for the dropdown
                  ),
                  items: TaskPriority.values.map((priority) {
                    return DropdownMenuItem(
                      value: priority, // Priority value
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 12,
                            color: _getPriorityColor(priority), // Color based on priority
                          ),
                          const SizedBox(width: 8), // Adds horizontal space between icon and text
                          Text(priority
                              .toString()
                              .split('.')
                              .last
                              .toUpperCase()), // Displays priority text
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _priority = value; // Updates the selected priority
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

  /// Builds the assignment section of the task form.
  /// 
  /// This section includes:
  /// - Department dropdown
  /// - Staff member dropdown
  Widget _buildAssignmentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Adds padding around the card
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Aligns children to the start of the column
          children: [
            Text(
              'Assignment',
              style: Theme.of(context).textTheme.titleMedium, // Applies medium title style
            ),
            const SizedBox(height: 16), // Adds vertical space between elements
            _buildDepartmentDropdown(), // Builds department dropdown
            const SizedBox(height: 16), // Adds vertical space between elements
            _buildStaffDropdown(), // Builds staff member dropdown
          ],
        ),
      ),
    );
  }

  /// Builds the department dropdown.
  /// 
  /// This dropdown is populated with data from a stream of department names.
  Widget _buildDepartmentDropdown() {
    return StreamBuilder<List<String>>(
      stream: _departmentStream, // Stream of department names
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LinearProgressIndicator(); // Shows a loading indicator if data is not available
        }

        final departments = snapshot.data!;
        return DropdownButtonFormField<String>(
          value: _departmentId, // Current selected department
          decoration: const InputDecoration(
            labelText: 'Department', // Label for the dropdown
            border: OutlineInputBorder(), // Adds border to the dropdown
            prefixIcon: Icon(Icons.business), // Icon for the dropdown
          ),
          items: departments
              .map((dept) => DropdownMenuItem(
                    value: dept, // Department value
                    child: Text(dept), // Department name
                  ))
              .toList(),
          validator: (value) =>
              value == null ? 'Please select a department' : null, // Validation message if no department is selected
          onChanged: (value) {
            setState(() {
              _departmentId = value; // Updates the selected department
              _assignedTo = null; // Resets the assigned staff member
              if (value != null) {
                _staffStream = context
                    .read<StaffService>()
                    .getStaffMembers()
                    .map((staff) => staff
                        .where((user) =>
                            user.departments?.contains(value) ?? false)
                        .toList()); // Filters staff members based on selected department
              }
            });
          },
        );
      },
    );
  }

  /// Builds the staff member dropdown.
  /// 
  /// This dropdown is populated with data from a stream of staff members.
  Widget _buildStaffDropdown() {
    return StreamBuilder<List<UserModel>>(
      stream: _staffStream, // Stream of staff members
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator(); // Shows a loading indicator if data is not available
        }

        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}'); // Shows an error message if there is an error
        }

        final staff = snapshot.data ?? [];

        return DropdownButtonFormField<String>(
          value: _assignedTo, // Current selected staff member
          decoration: const InputDecoration(
            labelText: 'Assign To', // Label for the dropdown
            border: OutlineInputBorder(), // Adds border to the dropdown
            prefixIcon: Icon(Icons.person), // Icon for the dropdown
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Select a staff member'), // Placeholder text
            ),
            ...staff.map((user) => DropdownMenuItem(
                  value: user.uid, // Staff member ID
                  child: Text('${user.fullName} (${user.role})'), // Staff member name and role
                )),
          ],
          validator: (value) =>
              value == null ? 'Please select a staff member' : null, // Validation message if no staff member is selected
          onChanged: (value) {
            setState(() {
              _assignedTo = value; // Updates the selected staff member
            });
          },
        );
      },
    );
  }

  /// Builds the checklist section of the task form.
  /// 
  /// This section includes:
  /// - A list of checklist items
  /// - An option to add new checklist items
  Widget _buildChecklistSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Adds padding around the card
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Aligns children to the start of the column
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Aligns children to the space between
              children: [
                Text(
                  'Checklist',
                  style: Theme.of(context).textTheme.titleMedium, // Applies medium title style
                ),
                IconButton(
                  icon: const Icon(Icons.add), // Icon for adding checklist items
                  onPressed: _addChecklistItem, // Adds a new checklist item when pressed
                  tooltip: 'Add checklist item', // Tooltip for the button
                ),
              ],
            ),
            if (_checklist.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0), // Adds vertical padding
                child: Text('No checklist items added'), // Message when no checklist items are present
              )
            else
              ListView.builder(
                shrinkWrap: true, // Shrinks the list view to fit its content
                physics: const NeverScrollableScrollPhysics(), // Disables scrolling
                itemCount: _checklist.length, // Number of checklist items
                itemBuilder: (context, index) {
                  final item =
                      _checklist[index].replaceAll(RegExp(r'\[.\]'), '').trim(); // Removes special characters from the item
                  return Dismissible(
                    key: Key('checklist_$index'), // Unique key for each checklist item
                    background: Container(
                      color: Colors.red, // Background color when dismissing
                      alignment: Alignment.centerRight, // Aligns the icon to the right
                      padding: const EdgeInsets.only(right: 16), // Adds padding to the right
                      child: const Icon(Icons.delete, color: Colors.white), // Delete icon
                    ),
                    direction: DismissDirection.endToStart, // Dismisses from end to start
                    onDismissed: (direction) {
                      setState(() {
                        _checklist.removeAt(index); // Removes the checklist item
                      });
                    },
                    child: ListTile(
                      title: Text(item), // Checklist item text
                      trailing: IconButton(
                        icon: const Icon(Icons.delete), // Delete icon
                        onPressed: () {
                          setState(() {
                            _checklist.removeAt(index); // Removes the checklist item
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

  /// Builds the submit button for the task form.
  /// 
  /// This button triggers the task creation process when pressed.
  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _createTask, // Calls the task creation function when pressed
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16), // Adds vertical padding
      ),
      child: const Text('CREATE TASK'), // Button text
    );
  }

  /// Returns the color associated with the given task priority.
  /// 
  /// - [TaskPriority.urgent]: Red
  /// - [TaskPriority.high]: Orange
  /// - [TaskPriority.medium]: Blue
  /// - [TaskPriority.low]: Green
  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return Colors.red; // Color for urgent priority
      case TaskPriority.high:
        return Colors.orange; // Color for high priority
      case TaskPriority.medium:
        return Colors.blue; // Color for medium priority
      case TaskPriority.low:
        return Colors.green; // Color for low priority
    }
  }
}

