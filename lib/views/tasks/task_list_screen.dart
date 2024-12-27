import 'package:cateredtoyou/views/tasks/manage_task_screen.dart';
import 'package:cateredtoyou/views/tasks/task_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/task_model.dart';
import 'package:cateredtoyou/services/task_service.dart';

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tasks'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'My Tasks'),
              Tab(text: 'Department'),
              Tab(text: 'All Tasks'),
              Tab(text: 'Completed'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageTasksScreen(),
                ),
              ),
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            _TaskList(listType: TaskListType.assigned),
            _TaskList(listType: TaskListType.department),
            _TaskList(listType: TaskListType.all),
            _TaskList(listType: TaskListType.completed),
          ],
        ),
      ),
    );
  }
}

enum TaskListType { assigned, department, all, completed }

class _TaskList extends StatefulWidget {
  final TaskListType listType;

  const _TaskList({required this.listType});

  @override
  State<_TaskList> createState() => _TaskListState();
}

class _TaskListState extends State<_TaskList> {
  TaskPriority? _selectedPriority;
  String? _searchQuery;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: Consumer<TaskService>(
            builder: (context, taskService, child) {
              return StreamBuilder<List<Task>>(
                stream: _getFilteredTaskStream(taskService),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
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
                                builder: (context) => const ManageTasksScreen(),
                              ),
                            ),
                            child: const Text('Create Task'),
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
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return Dismissible(
                          key: Key(task.id),
                          direction: DismissDirection.endToStart,
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
                                      child: const Text('CANCEL'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('DELETE'),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return false;
                          },
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          child: TaskCard(task: task),
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
              hintText: 'Search tasks...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = null;
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
                  label: const Text('All Priorities'),
                  selected: _selectedPriority == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedPriority = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ...TaskPriority.values.map((priority) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(priority.toString().split('.').last),
                      selected: _selectedPriority == priority,
                      onSelected: (selected) {
                        setState(() {
                          _selectedPriority = selected ? priority : null;
                        });
                      },
                      backgroundColor: _getPriorityColor(priority).withOpacity(0.1),
                      selectedColor: _getPriorityColor(priority).withOpacity(0.2),
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

  Stream<List<Task>> _getFilteredTaskStream(TaskService taskService) {
    Stream<List<Task>> baseStream;
    
    switch (widget.listType) {
      case TaskListType.assigned:
        baseStream = taskService.getAssignedTasks(
          FirebaseAuth.instance.currentUser!.uid,
        );
        break;
      case TaskListType.department:
        baseStream = taskService.getTasksByDepartment(
          'currentDepartmentId', // Replace with actual department ID
        );
        break;
      case TaskListType.completed:
        baseStream = taskService.getTasks(status: TaskStatus.completed);
        break;
      case TaskListType.all:
      default:
        baseStream = taskService.getTasks();
        break;
    }

    return baseStream.map((tasks) {
      return tasks.where((task) {
        // Apply priority filter if selected
        if (_selectedPriority != null && task.priority != _selectedPriority) {
          return false;
        }

        // Apply search filter if query exists
        if (_searchQuery != null && _searchQuery!.isNotEmpty) {
          final query = _searchQuery!.toLowerCase();
          return task.name.toLowerCase().contains(query) ||
              task.description.toLowerCase().contains(query);
        }

        return true;
      }).toList();
    });
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

// Improved TaskCard widget
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
                        Text(
                          task.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
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

  Widget _buildPriorityIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getPriorityColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getPriorityIcon(),
            size: 16,
            color: _getPriorityColor(),
          ),
          const SizedBox(width: 4),
          Text(
            task.priority.toString().split('.').last,
            style: TextStyle(
              color: _getPriorityColor(),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueDate() {
    final now = DateTime.now();
    final isOverdue = task.dueDate.isBefore(now) && 
                     task.status != TaskStatus.completed;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.calendar_today,
          size: 16,
          color: isOverdue ? Colors.red : Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          DateFormat('MMM dd, yyyy').format(task.dueDate),
          style: TextStyle(
            color: isOverdue ? Colors.red : Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(),
            size: 16,
            color: _getStatusColor(),
          ),
          const SizedBox(width: 4),
          Text(
            task.status.toString().split('.').last,
            style: TextStyle(
              color: _getStatusColor(),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final completedItems = task.checklist
        .where((item) => item.contains('[x]'))
        .length;
    final progress = task.checklist.isEmpty 
        ? 0.0 
        : completedItems / task.checklist.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            _getProgressColor(progress),
          ),
        ),
      ],
    );
  }

  Color _getPriorityColor() {
    switch (task.priority) {
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

  IconData _getPriorityIcon() {
    switch (task.priority) {
      case TaskPriority.urgent:
        return Icons.priority_high;
      case TaskPriority.high:
        return Icons.arrow_upward;
      case TaskPriority.medium:
        return Icons.remove;
      case TaskPriority.low:
        return Icons.arrow_downward;
    }
  }

  Color _getStatusColor() {
    switch (task.status) {
      case TaskStatus.pending:
        return Colors.orange;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.blocked:
        return Colors.red;
      case TaskStatus.cancelled:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (task.status) {
      case TaskStatus.pending:
        return Icons.schedule;
      case TaskStatus.inProgress:
        return Icons.play_arrow;
      case TaskStatus.completed:
        return Icons.check_circle;
      case TaskStatus.blocked:
        return Icons.block;
      case TaskStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.8) return Colors.green;
    if (progress >= 0.5) return Colors.orange;
    return Colors.red;
  }
}