// lib/views/tasks/task_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/task/task_model.dart';
import 'package:cateredtoyou/services/task_service.dart';
import 'package:cateredtoyou/views/tasks/task_staff_assignment_widget.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Future<void> _handleStaffAssignment(String newAssigneeId) async {
    if (!mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await context.read<TaskService>().updateTaskAssignee(
        widget.task.id,
        newAssigneeId,
      );

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Staff assigned successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error assigning staff: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateTaskStatus(TaskStatus newStatus) async {
    if (!mounted) return;

    try {
      await context.read<TaskService>().updateTaskStatus(
        widget.task.id,
        newStatus,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task status updated to ${newStatus.toString().split('.').last}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('events')
              .doc(widget.task.eventId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.exists) {
              final eventData = snapshot.data!.data() as Map<String, dynamic>?;
              return Text(eventData?['name'] ?? 'Task Details');
            }
            return const Text('Task Details');
          },
        ),
        // actions: [
        //   _buildStatusButton(),
        // ],
      ),
      body: StreamBuilder<Task>(
        stream: null,//context.read<TaskService>().getTaskById(widget.task.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final currentTask = snapshot.data!;

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(currentTask),
                        // const SizedBox(height: 16),
                        // _buildMetadataCard(currentTask),
                        const SizedBox(height: 16),
                        StaffAssignmentSection(
                          task: currentTask,
                          onAssigneeChanged: (String? newAssigneeId) {
                            if (newAssigneeId != null) {
                              _handleStaffAssignment(newAssigneeId);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTaskSpecificDetails(currentTask),
                        const SizedBox(height: 16),
                        _buildCommentsList(currentTask),
                      ],
                    ),
                  ),
                ),
              ),
              _buildCommentInput(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTaskSpecificDetails(Task task) {
    // Handle different task types
    switch (task.getTaskType()) {
      case 'EventTask':
        return _buildEventTaskDetails(task);
      case 'MenuItemTask':
        return _buildMenuItemTaskDetails(task);
      case 'DeliveryTask':
        return _buildDeliveryTaskDetails(task);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEventTaskDetails(Task task) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Event Details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            // Add event-specific fields here
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItemTaskDetails(Task task) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Menu Item Details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            // Add menu item-specific fields here
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryTaskDetails(Task task) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery Details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            // Add delivery-specific fields here
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Task task) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    task.description,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(task.status),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: task.dueDate.isBefore(DateTime.now())
                          ? Colors.red
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM dd, yyyy').format(task.dueDate),
                      style: TextStyle(
                        color: task.dueDate.isBefore(DateTime.now())
                            ? Colors.red
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                _buildPriorityChip(task.priority),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildCommentsList(Task task) {
    final comments = task.comments;

    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Comments',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (comments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No comments yet'),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) => _buildCommentItem(comments[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(TaskComment comment) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                comment.userId,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                DateFormat('MMM dd, yyyy HH:mm').format(comment.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(comment.content),
        ],
      ),
    );
  }

  /// Builds a widget for the comment input field.
  ///
  /// The input field allows users to type and submit new comments.
  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16), // Adds padding around the input field.
      decoration: BoxDecoration(
        color: Theme.of(context)
            .cardColor, // Sets the background color from the theme.
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2), // Adds a shadow effect.
            blurRadius: 4, // Sets the blur radius for the shadow.
            offset: const Offset(0, -2), // Sets the shadow offset.
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller:
                  _commentController, // Binds the TextField to a controller.
              focusNode: _commentFocus, // Binds the TextField to a focus node.
              decoration: const InputDecoration(
                hintText: 'Add a comment...', // Placeholder text.
                border:
                    OutlineInputBorder(), // Adds a border around the TextField.
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null, // Allows multiple lines of input.
              keyboardType: TextInputType
                  .multiline, // Sets the keyboard type to multiline.
              textInputAction:
                  TextInputAction.newline, // Sets the action button to newline.
            ),
          ),
          const SizedBox(
              width: 16), // Adds horizontal spacing between elements.
          IconButton(
            onPressed:
                _addComment, // Calls the _addComment method when pressed.
            icon: const Icon(Icons.send), // Sets the icon to a send icon.
            color: Theme.of(context)
                .primaryColor, // Sets the icon color from the theme.
          ),
        ],
      ),
    );
  }

  /// Adds a new comment to the task.
  ///
  /// This method is called when the user submits a comment. It sends the comment
  /// to the server and updates the UI accordingly.
  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) {
      return; // Returns if the input is empty.
    }

    try {
      await context.read<TaskService>().addTaskComment(
            taskId: widget.task.id, // The ID of the task to which the comment is added.
            content: _commentController.text, // The content of the comment.
          );
      _commentController.clear(); // Clears the input field.
      _commentFocus.unfocus(); // Unfocuses the input field.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Error adding comment: $e'), // Displays an error message.
            backgroundColor: Colors.red, // Sets the background color to red.
          ),
        );
      }
    }
  }

  /// Builds a widget to display the task's priority as a chip.
  ///
  /// The chip includes an icon and text representing the task's priority.
  Widget _buildPriorityChip(TaskPriority priority) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getPriorityColor(priority).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getPriorityColor(priority),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getPriorityIcon(priority),
            size: 16,
            color: _getPriorityColor(priority),
          ),
          const SizedBox(width: 4),
          Text(
            priority.toString().split('.').last.toUpperCase(),
            style: TextStyle(
              color: _getPriorityColor(priority),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a widget to display the task's status as a chip.
  ///
  /// The chip includes an icon and text representing the task's status.
  Widget _buildStatusChip(TaskStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor(status),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(status),
            size: 16,
            color: _getStatusColor(status),
          ),
          const SizedBox(width: 4),
          Text(
            status.toString().split('.').last.toUpperCase(),
            style: TextStyle(
              color: _getStatusColor(status),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Returns the color associated with the given task priority.
  ///
  /// [priority] The priority of the task.
  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return Colors.red; // Returns red for urgent priority.
      case TaskPriority.high:
        return Colors.orange; // Returns orange for high priority.
      case TaskPriority.medium:
        return Colors.blue; // Returns blue for medium priority.
      case TaskPriority.low:
        return Colors.green; // Returns green for low priority.
    }
  }

  /// Returns the icon associated with the given task priority.
  ///
  /// [priority] The priority of the task.
  IconData _getPriorityIcon(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return Icons.flag; // Returns a flag icon for urgent priority.
      case TaskPriority.high:
        return Icons
            .arrow_upward; // Returns an upward arrow icon for high priority.
      case TaskPriority.medium:
        return Icons.remove; // Returns a remove icon for medium priority.
      case TaskPriority.low:
        return Icons
            .arrow_downward; // Returns a downward arrow icon for low priority.
    }
  }

  /// Returns the color associated with the given task status.
  ///
  /// [status] The status of the task.
  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Colors.grey; // Returns grey for pending status.
      case TaskStatus.inProgress:
        return Colors.blue; // Returns blue for in-progress status.
      case TaskStatus.completed:
        return Colors.green; // Returns green for completed status.
      case TaskStatus.blocked:
        return Colors.red; // Returns red for blocked status.
      case TaskStatus.cancelled:
        return Colors.grey.shade700; // Returns dark grey for cancelled status.
    }
  }

  /// Returns the icon associated with the given task status.
  ///
  /// [status] The status of the task.
  IconData _getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Icons.schedule; // Returns a schedule icon for pending status.
      case TaskStatus.inProgress:
        return Icons
            .play_arrow; // Returns a play arrow icon for in-progress status.
      case TaskStatus.completed:
        return Icons
            .check_circle; // Returns a check circle icon for completed status.
      case TaskStatus.blocked:
        return Icons.block; // Returns a block icon for blocked status.
      case TaskStatus.cancelled:
        return Icons.cancel; // Returns a cancel icon for cancelled status.
    }
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.8) return Colors.green;
    if (progress >= 0.5) return Colors.orange;
    return Colors.red;
  }
}
