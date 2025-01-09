import 'package:cateredtoyou/views/tasks/task_staff_assignment_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/task_model.dart';
import 'package:cateredtoyou/services/task_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late List<String> _checklist; // Declare a list to hold the checklist items
  final TextEditingController _commentController =
      TextEditingController(); // Controller for the comment input field
  final FocusNode _commentFocus =
      FocusNode(); // Focus node for the comment input field

  @override
  void initState() {
    super.initState();
    _checklist = widget.task.checklist.map((item) {
      if (!item.startsWith('[')) {
        return '[ ] $item'; // Ensure each checklist item starts with a checkbox
      }
      return item;
    }).toList();
    debugPrint(
        'Initial checklist: $_checklist'); // Debug print to check the initial checklist
  }

  @override
  void dispose() {
    _commentController.dispose(); // Dispose the comment controller
    _commentFocus.dispose(); // Dispose the focus node
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

      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Staff assigned successfully'), // Show success message
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error assigning staff: $e'), // Show error message
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateTaskStatus(TaskStatus newStatus) async {
    try {
      await context.read<TaskService>().updateTaskStatus(
            widget.task.id,
            newStatus,
          );
      if (mounted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Task status updated to ${newStatus.toString().split('.').last}'), // Show status update message
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'), // Show error message
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
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('events')
              .doc(widget.task.eventId)
              .snapshots(), // Stream to listen for changes in the event document
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.exists) {
              final eventData = snapshot.data!.data() as Map<String, dynamic>?;
              return Text(eventData?['name'] ?? 'Task Details'); // Display event name or default text
            }
            return const Text('Task Details'); // Default text if no data
          },
        ),
        actions: [
          _buildStatusButton(), // Button to change task status
        ],
      ),
      body: StreamBuilder<List<Task>>(
        stream: context.read<TaskService>().getTasks(
              assignedTo: widget.task.assignedTo,
            ), // Stream to listen for changes in tasks assigned to the user
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}')); // Display error message
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator()); // Show loading indicator
          }

          final currentTask = snapshot.data!.firstWhere(
            (t) => t.id == widget.task.id,
            orElse: () => widget.task,
          ); // Find the current task in the list

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    setState(() {}); // Refresh the UI
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(currentTask), // Build the task header
                        const SizedBox(height: 16),
                        _buildMetadataCard(currentTask), // Build the metadata card
                        const SizedBox(height: 16),
                        StaffAssignmentSection(
                          task: currentTask,
                          onAssigneeChanged: (String? newAssigneeId) {
                            if (newAssigneeId != null) {
                              _handleStaffAssignment(newAssigneeId); // Handle staff assignment
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildChecklist(), // Build the checklist
                        if (currentTask.checklist.isNotEmpty)
                          _buildProgressBar(currentTask.checklist), // Build the progress bar if checklist is not empty
                        const SizedBox(height: 16),
                        _buildCommentsList(), // Build the comments list
                      ],
                    ),
                  ),
                ),
              ),
              _buildCommentInput(), // Build the comment input field
            ],
          );
        },
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
                    task.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ), // Display task name in bold
                  ),
                ),
                _buildStatusChip(task.status), // Display task status chip
              ],
            ),
            const SizedBox(height: 16),
            Text(
              task.description,
              style: Theme.of(context).textTheme.bodyLarge, // Display task description
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
                          : Colors.grey[600], // Change color based on due date
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM dd, yyyy').format(task.dueDate), // Display formatted due date
                      style: TextStyle(
                        color: task.dueDate.isBefore(DateTime.now())
                            ? Colors.red
                            : Colors.grey[600], // Change color based on due date
                      ),
                    ),
                  ],
                ),
                _buildPriorityChip(task.priority), // Display task priority chip
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton() {
    return PopupMenuButton<TaskStatus>(
      icon: const Icon(Icons.more_vert),
      onSelected: _updateTaskStatus, // Handle status update
      itemBuilder: (context) {
        return [
          const PopupMenuItem(
            value: TaskStatus.inProgress,
            child: Row(
              children: [
                Icon(Icons.play_arrow, color: Colors.blue),
                SizedBox(width: 8),
                Text('Start Progress'), // Option to start progress
              ],
            ),
          ),
          const PopupMenuItem(
            value: TaskStatus.completed,
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Complete'), // Option to mark as complete
              ],
            ),
          ),
          const PopupMenuItem(
            value: TaskStatus.blocked,
            child: Row(
              children: [
                Icon(Icons.block, color: Colors.red),
                SizedBox(width: 8),
                Text('Block'), // Option to block the task
              ],
            ),
          ),
        ];
      },
    );
  }

  Widget _buildMetadataCard(Task task) {
    if (task.eventId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(task.eventId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final eventData = snapshot.data?.data() as Map<String, dynamic>?;
        if (eventData == null) return const SizedBox.shrink();

        final metadata = eventData['metadata'] as Map<String, dynamic>?;
        if (metadata == null) return const SizedBox.shrink();

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Event: ${eventData['name'] ?? 'Unknown Event'}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                if (metadata['has_dietary_requirements'] == true) ...[
                  _buildRequirementRow(
                    Icons.restaurant_menu,
                    'Dietary Requirements',
                    Colors.orange,
                    (metadata['dietary_restrictions'] as List<dynamic>?)
                            ?.join(', ') ??
                        'Not specified',
                  ),
                  const SizedBox(height: 8),
                ],
                if (metadata['has_special_equipment'] == true) ...[
                  _buildRequirementRow(
                    Icons.build,
                    'Special Equipment',
                    Colors.blue,
                    (metadata['special_equipment_needed'] as List<dynamic>?)
                            ?.join(', ') ??
                        'Not specified',
                  ),
                  const SizedBox(height: 8),
                ],
                if (metadata['has_bar_service'] == true) ...[
                  _buildRequirementRow(
                    Icons.local_bar,
                    'Bar Service',
                    Colors.purple,
                    metadata['bar_service_type']?.toString() ??
                        'Standard Service',
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequirementRow(
    IconData icon,
    String title,
    Color color,
    String content,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (content.isNotEmpty)
                Text(
                  content,
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChecklist() {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Checklist',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_checklist.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                  'No checklist items'), // Display message if no checklist items
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _checklist.length,
              itemBuilder: _buildChecklistItem, // Build each checklist item
            ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(BuildContext context, int index) {
    final item = _checklist[index];
    // Debug print to see the item format
    debugPrint('Building checklist item: $item');

    // Make the check state detection more robust
    final isChecked = item.trim().startsWith('[x]');
    final label = item.replaceAll(RegExp(r'\[[\sx]\]'), '').trim();

    return CheckboxListTile(
      value: isChecked,
      onChanged: (_) {
        // Debug print when checkbox is clicked
        debugPrint('Checkbox clicked for item: $item');
        _toggleChecklistItem(index); // Toggle the checklist item
      },
      title: Text(
        label,
        style: TextStyle(
          decoration: isChecked
              ? TextDecoration.lineThrough
              : null, // Strike-through if checked
        ),
      ),
      activeColor: Theme.of(context).primaryColor,
    );
  }

  // Update the _buildCommentsList method in TaskDetailScreen
  Widget _buildCommentsList() {
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
          StreamBuilder<List<Task>>(
            stream: context.read<TaskService>().getTasks(
                  assignedTo: widget.task.assignedTo,
                ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                        'Error loading comments: ${snapshot.error}'), // Display error message
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child:
                        CircularProgressIndicator(), // Show loading indicator
                  ),
                );
              }

              final task = snapshot.data!.firstWhere(
                (t) => t.id == widget.task.id,
                orElse: () => widget.task,
              );

              final comments =
                  context.read<TaskService>().parseComments(task.comments);

              if (comments.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child:
                      Text('No comments yet'), // Display message if no comments
                );
              }

              comments.sort((a, b) =>
                  b.createdAt.compareTo(a.createdAt)); // Sort comments by date

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: comments.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) => _buildCommentItem(
                    comments[index]), // Build each comment item
              );
            },
          ),
        ],
      ),
    );
  }

  /// Builds a widget to display a single comment item.
  ///
  /// The comment item includes the user's name, the comment's creation date,
  /// and the comment content.
  ///
  /// [comment] The TaskComment object containing the comment details.
  Widget _buildCommentItem(TaskComment comment) {
    return Padding(
      padding:
          const EdgeInsets.all(16), // Adds padding around the comment item.
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start, // Aligns children to the start.
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween, // Spaces out the children.
            children: [
              Text(
                comment.userName, // Displays the commenter's username.
                style: const TextStyle(
                  fontWeight: FontWeight.bold, // Makes the username bold.
                ),
              ),
              Text(
                DateFormat('MMM dd, yyyy HH:mm').format(comment
                    .createdAt), // Formats and displays the comment's creation date.
                style: Theme.of(context)
                    .textTheme
                    .bodySmall, // Applies the theme's bodySmall text style.
              ),
            ],
          ),
          const SizedBox(height: 4), // Adds vertical spacing between elements.
          Text(comment.content), // Displays the comment content.
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
            widget.task.id, // The ID of the task to which the comment is added.
            _commentController.text, // The content of the comment.
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

  /// Builds a progress bar to show the completion status of the checklist.
  ///
  /// The progress bar visually represents the number of completed items in the checklist.
  ///
  /// [checklist] The list of checklist items.
  Widget _buildProgressBar(List<String> checklist) {
    // Calculate the number of completed items in the checklist.
    final completedCount = checklist.where((item) => item.startsWith('[x]')).length;
    // Calculate the progress as a fraction of completed items.
    final progress = checklist.isEmpty ? 0.0 : completedCount / checklist.length;

    return Padding(
      padding: const EdgeInsets.all(16), // Adds padding around the progress bar.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Aligns children to the start.
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Spaces out the children.
            children: [
              Text(
                '$completedCount/${checklist.length} completed', // Displays the number of completed items.
                style: TextStyle(
                  color: Colors.grey[600], // Sets the text color to grey.
                  fontWeight: FontWeight.bold, // Makes the text bold.
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%', // Displays the progress percentage.
                style: TextStyle(
                  color: _getProgressColor(progress), // Sets the text color based on progress.
                  fontWeight: FontWeight.bold, // Makes the text bold.
                ),
              ),
            ],
          ),
          const SizedBox(height: 8), // Adds vertical spacing between elements.
          LinearProgressIndicator(
            value: progress, // Sets the progress value.
            backgroundColor: Colors.grey[200], // Sets the background color of the progress bar.
            valueColor: AlwaysStoppedAnimation<Color>(
              _getProgressColor(progress), // Sets the progress color based on progress.
            ),
            minHeight: 8, // Sets the minimum height of the progress bar.
            borderRadius: BorderRadius.circular(4), // Rounds the corners of the progress bar.
          ),
        ],
      ),
    );
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

  /// Toggles the completion status of a checklist item.
  ///
  /// This method updates the checklist item in the UI and sends the updated
  /// checklist to the server.
  ///
  /// [index] The index of the checklist item to toggle.
  Future<void> _toggleChecklistItem(int index) async {
    // Add debug print
    debugPrint(
        'Current checklist item: ${_checklist[index]}'); // Prints the current checklist item.

    final oldChecklist = List<String>.from(
        _checklist); // Creates a copy of the current checklist.
    setState(() {
      final item = _checklist[index];
      // Add debug print
      debugPrint(
          'Is checked: ${item.contains('[x]')}'); // Prints whether the item is checked.

      if (item.startsWith('[ ]')) {
        _checklist[index] =
            item.replaceFirst('[ ]', '[x]'); // Marks the item as checked.
      } else {
        _checklist[index] =
            item.replaceFirst('[x]', '[ ]'); // Marks the item as unchecked.
      }
      // Add debug print
      debugPrint(
          'Updated checklist item: ${_checklist[index]}'); // Prints the updated checklist item.
    });

    try {
      await context.read<TaskService>().updateTaskChecklist(
            widget.task.id, // The ID of the task to update.
            _checklist, // The updated checklist.
          );
    } catch (e) {
      debugPrint(
          'Error in _toggleChecklistItem: $e'); // Prints an error message.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error updating checklist: $e'), // Displays an error message.
            backgroundColor: Colors.red, // Sets the background color to red.
          ),
        );
        setState(() {
          _checklist =
              oldChecklist; // Reverts the checklist to its previous state.
        });
      }
    }
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.8) return Colors.green;
    if (progress >= 0.5) return Colors.orange;
    return Colors.red;
  }
}
