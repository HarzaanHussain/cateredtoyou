import 'package:cateredtoyou/views/tasks/manage_task_screen.dart';
import 'package:cateredtoyou/views/tasks/task_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/task_model.dart';
import 'package:cateredtoyou/services/task_service.dart';

/// The `TaskListScreen` class represents a screen that displays a list of tasks.
/// It uses a `DefaultTabController` to manage four tabs: My Tasks, Department, All Tasks, and Completed.
class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, // Specifies the number of tabs.
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tasks'), // Title of the AppBar.
          bottom: const TabBar(
            isScrollable: true, // Allows the tabs to be scrollable.
            tabs: [
              Tab(text: 'My Tasks'), // Tab for "My Tasks".
              Tab(text: 'Department'), // Tab for "Department".
              Tab(text: 'All Tasks'), // Tab for "All Tasks".
              Tab(text: 'Completed'), // Tab for "Completed".
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add), // Icon for adding a new task.
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageTasksScreen(), // Navigates to the ManageTasksScreen.
                ),
              ),
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            _TaskList(listType: TaskListType.assigned), // Displays assigned tasks.
            _TaskList(listType: TaskListType.department), // Displays department tasks.
            _TaskList(listType: TaskListType.all), // Displays all tasks.
            _TaskList(listType: TaskListType.completed), // Displays completed tasks.
          ],
        ),
      ),
    );
  }
}

/// Enum representing different types of task lists.
enum TaskListType { assigned, department, all, completed }

/// The `_TaskList` class represents a list of tasks based on the specified `listType`.
class _TaskList extends StatefulWidget {
  final TaskListType listType; // The type of task list to display.

  const _TaskList({required this.listType});

  @override
  State<_TaskList> createState() => _TaskListState();
}

class _TaskListState extends State<_TaskList> {
  TaskPriority? _selectedPriority; // The selected priority filter.
  String? _searchQuery; // The search query for filtering tasks.
  final TextEditingController _searchController = TextEditingController(); // Controller for the search input.

  @override
  void dispose() {
    _searchController.dispose(); // Disposes the search controller when the widget is removed.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterBar(), // Builds the filter bar.
        Expanded(
          child: Consumer<TaskService>(
            builder: (context, taskService, child) {
              return StreamBuilder<List<Task>>(
                stream: _getFilteredTaskStream(taskService), // Gets the filtered task stream.
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'), // Displays an error message if there's an error.
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator()); // Displays a loading indicator if data is not available.
                  }

                  final tasks = snapshot.data!;
                  if (tasks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.task_alt,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No tasks found',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ManageTasksScreen(), // Navigates to the ManageTasksScreen.
                              ),
                            ),
                            child: const Text('Create Task'), // Button to create a new task.
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      // Implement refresh logic if needed
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: tasks.length, // Number of tasks to display.
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return Dismissible(
                          key: Key(task.id), // Unique key for each task.
                          direction: DismissDirection.endToStart, // Swipe direction for dismissing.
                          confirmDismiss: (direction) async {
                            if (task.status == TaskStatus.completed) {
                              return await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Task'),
                                  content: const Text(
                                    'Are you sure you want to delete this completed task?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('CANCEL'), // Cancel button.
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('DELETE'), // Delete button.
                                    ),
                                  ],
                                ),
                              );
                            }
                            return false;
                          },
                          background: Container(
                            color: Colors.red, // Background color for the dismissible widget.
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          child: TaskCard(task: task), // Displays the task card.
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Builds the filter bar with search and priority filters.
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search tasks...', // Hint text for the search input.
              prefixIcon: const Icon(Icons.search), // Search icon.
              suffixIcon: _searchQuery != null
                  ? IconButton(
                      icon: const Icon(Icons.clear), // Clear icon.
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = null; // Clears the search query.
                        });
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Priorities'), // Label for the "All Priorities" filter.
                  selected: _selectedPriority == null, // Checks if no priority is selected.
                  onSelected: (selected) {
                    setState(() {
                      _selectedPriority = null; // Sets the selected priority to null.
                    });
                  },
                ),
                const SizedBox(width: 8),
                ...TaskPriority.values.map((priority) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(priority.toString().split('.').last), // Label for each priority.
                      selected: _selectedPriority == priority, // Checks if the priority is selected.
                      onSelected: (selected) {
                        setState(() {
                          _selectedPriority = selected ? priority : null; // Sets the selected priority.
                        });
                      },
                      backgroundColor: _getPriorityColor(priority).withOpacity(0.1), // Background color for the chip.
                      selectedColor: _getPriorityColor(priority).withOpacity(0.2), // Selected color for the chip.
                      labelStyle: TextStyle(
                        color: _selectedPriority == priority
                            ? _getPriorityColor(priority)
                            : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Returns a stream of tasks filtered by the selected priority and search query.
  Stream<List<Task>> _getFilteredTaskStream(TaskService taskService) {
    Stream<List<Task>> baseStream;
    
    switch (widget.listType) {
      case TaskListType.assigned:
        baseStream = taskService.getAssignedTasks(
          FirebaseAuth.instance.currentUser!.uid, // Gets tasks assigned to the current user.
        );
        break;
      case TaskListType.department:
        baseStream = taskService.getTasksByDepartment(
          'currentDepartmentId', // Replace with actual department ID.
        );
        break;
      case TaskListType.completed:
        baseStream = taskService.getTasks(status: TaskStatus.completed); // Gets completed tasks.
        break;
      case TaskListType.all:
      default:
        baseStream = taskService.getTasks(); // Gets all tasks.
        break;
    }

    return baseStream.map((tasks) {
      return tasks.where((task) {
        // Apply priority filter if selected.
        if (_selectedPriority != null && task.priority != _selectedPriority) {
          return false;
        }

        // Apply search filter if query exists.
        if (_searchQuery != null && _searchQuery!.isNotEmpty) {
          final query = _searchQuery!.toLowerCase();
          return task.name.toLowerCase().contains(query) ||
              task.description.toLowerCase().contains(query);
        }

        return true;
      }).toList();
    });
  }

  /// Returns the color associated with the given priority.
  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return Colors.red; // Color for urgent priority.
      case TaskPriority.high:
        return Colors.orange; // Color for high priority.
      case TaskPriority.medium:
        return Colors.blue; // Color for medium priority.
      case TaskPriority.low:
        return Colors.green; // Color for low priority.
    }
  }
}

/// A widget that displays a card for a task with various details and actions.
/// 
/// The [TaskCard] widget shows the task's name, description, priority, due date,
/// status, and progress if the task has a checklist. It also navigates to the
/// task detail screen when tapped.
class TaskCard extends StatelessWidget {
  final Task task;

  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailScreen(task: task),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                task.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (task.eventId.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('events')
                                    .doc(task.eventId)
                                    .get(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data!.exists) {
                                    final eventData = snapshot.data!.data() as Map<String, dynamic>;
                                    return Text(
                                      '[${eventData['name'] + '\'s Event'?? 'Unknown Event'}]',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.w700,
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildPriorityIndicator(),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDueDate(),
                  _buildStatusChip(),
                ],
              ),
              if (task.checklist.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  
  }
  

  /// Builds the priority indicator widget.
  Widget _buildPriorityIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Padding inside the container.
      decoration: BoxDecoration(
        color: _getPriorityColor().withOpacity(0.1), // Background color based on priority.
        borderRadius: BorderRadius.circular(12), // Rounded corners for the container.
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Minimize the size of the row.
        children: [
          Icon(
            _getPriorityIcon(), // Icon based on priority.
            size: 16, // Icon size.
            color: _getPriorityColor(), // Icon color based on priority.
          ),
          const SizedBox(width: 4), // Space between icon and text.
          Text(
            task.priority.toString().split('.').last, // Display priority as text.
            style: TextStyle(
              color: _getPriorityColor(), // Text color based on priority.
              fontSize: 12, // Text size.
              fontWeight: FontWeight.bold, // Bold text.
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the due date widget.
  Widget _buildDueDate() {
    final now = DateTime.now(); // Current date and time.
    final isOverdue = task.dueDate.isBefore(now) && 
                     task.status != TaskStatus.completed; // Check if the task is overdue.

    return Row(
      mainAxisSize: MainAxisSize.min, // Minimize the size of the row.
      children: [
        Icon(
          Icons.calendar_today, // Calendar icon.
          size: 16, // Icon size.
          color: isOverdue ? Colors.red : Colors.grey[600], // Icon color based on overdue status.
        ),
        const SizedBox(width: 4), // Space between icon and text.
        Text(
          DateFormat('MMM dd, yyyy').format(task.dueDate), // Format and display due date.
          style: TextStyle(
            color: isOverdue ? Colors.red : Colors.grey[600], // Text color based on overdue status.
            fontSize: 12, // Text size.
          ),
        ),
      ],
    );
  }

  /// Builds the status chip widget.
  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Padding inside the container.
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1), // Background color based on status.
        borderRadius: BorderRadius.circular(12), // Rounded corners for the container.
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Minimize the size of the row.
        children: [
          Icon(
            _getStatusIcon(), // Icon based on status.
            size: 16, // Icon size.
            color: _getStatusColor(), // Icon color based on status.
          ),
          const SizedBox(width: 4), // Space between icon and text.
          Text(
            task.status.toString().split('.').last, // Display status as text.
            style: TextStyle(
              color: _getStatusColor(), // Text color based on status.
              fontSize: 12, // Text size.
              fontWeight: FontWeight.bold, // Bold text.
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the progress indicator widget.
  Widget _buildProgressIndicator() {
    final completedItems = task.checklist
        .where((item) => item.contains('[x]'))
        .length; // Count completed checklist items.
    final progress = task.checklist.isEmpty 
        ? 0.0 
        : completedItems / task.checklist.length; // Calculate progress.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Align children to the start.
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between progress text and percentage.
          children: [
            Text(
              'Progress', // Display "Progress" text.
              style: TextStyle(
                color: Colors.grey[600], // Text color.
                fontSize: 12, // Text size.
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%', // Display progress percentage.
              style: TextStyle(
                color: Colors.grey[600], // Text color.
                fontSize: 12, // Text size.
                fontWeight: FontWeight.bold, // Bold text.
              ),
            ),
          ],
        ),
        const SizedBox(height: 4), // Space between progress text and progress bar.
        LinearProgressIndicator(
          value: progress, // Progress value.
          backgroundColor: Colors.grey[200], // Background color of the progress bar.
          valueColor: AlwaysStoppedAnimation<Color>(
            _getProgressColor(progress), // Progress bar color based on progress.
          ),
        ),
      ],
    );
  }

  /// Returns the color based on the task's priority.
  Color _getPriorityColor() {
    switch (task.priority) {
      case TaskPriority.urgent:
        return Colors.red; // Red color for urgent priority.
      case TaskPriority.high:
        return Colors.orange; // Orange color for high priority.
      case TaskPriority.medium:
        return Colors.blue; // Blue color for medium priority.
      case TaskPriority.low:
        return Colors.green; // Green color for low priority.
    }
  }

  /// Returns the icon based on the task's priority.
  IconData _getPriorityIcon() {
    switch (task.priority) {
      case TaskPriority.urgent:
        return Icons.priority_high; // High priority icon for urgent priority.
      case TaskPriority.high:
        return Icons.arrow_upward; // Upward arrow icon for high priority.
      case TaskPriority.medium:
        return Icons.remove; // Remove icon for medium priority.
      case TaskPriority.low:
        return Icons.arrow_downward; // Downward arrow icon for low priority.
    }
  }

  /// Returns the color based on the task's status.
  Color _getStatusColor() {
    switch (task.status) {
      case TaskStatus.pending:
        return Colors.orange; // Orange color for pending status.
      case TaskStatus.inProgress:
        return Colors.blue; // Blue color for in-progress status.
      case TaskStatus.completed:
        return Colors.green; // Green color for completed status.
      case TaskStatus.blocked:
        return Colors.red; // Red color for blocked status.
      case TaskStatus.cancelled:
        return Colors.grey; // Grey color for cancelled status.
    }
  }

  /// Returns the icon based on the task's status.
  IconData _getStatusIcon() {
    switch (task.status) {
      case TaskStatus.pending:
        return Icons.schedule; // Schedule icon for pending status.
      case TaskStatus.inProgress:
        return Icons.play_arrow; // Play arrow icon for in-progress status.
      case TaskStatus.completed:
        return Icons.check_circle; // Check circle icon for completed status.
      case TaskStatus.blocked:
        return Icons.block; // Block icon for blocked status.
      case TaskStatus.cancelled:
        return Icons.cancel; // Cancel icon for cancelled status.
    }
  }

  /// Returns the color based on the progress value.
  Color _getProgressColor(double progress) {
    if (progress >= 0.8) return Colors.green; // Green color for progress >= 80%.
    if (progress >= 0.5) return Colors.orange; // Orange color for progress >= 50%.
    return Colors.red; // Red color for progress < 50%.
  }
}