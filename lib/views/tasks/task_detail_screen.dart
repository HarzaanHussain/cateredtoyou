
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
  late List<String> _checklist;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _checklist = List.from(widget.task.checklist);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Future<void> _updateTaskStatus(TaskStatus newStatus) async {
    try {
      await context.read<TaskService>().updateTaskStatus(
        widget.task.id,
        newStatus,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task status updated to ${newStatus.toString().split('.').last}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
        title: const Text('Task Details'),
        actions: [
          _buildStatusButton(),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildChecklist(),
                  const SizedBox(height: 24),
                  _buildCommentsList(),
                ],
              ),
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.task.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildPriorityChip(),
                const SizedBox(width: 8),
                _buildStatusChip(),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.task.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Due: ${DateFormat('MMM dd, yyyy').format(widget.task.dueDate)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
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
      onSelected: _updateTaskStatus,
      itemBuilder: (context) {
        return [
          const PopupMenuItem(
            value: TaskStatus.inProgress,
            child: Row(
              children: [
                Icon(Icons.play_arrow, color: Colors.blue),
                SizedBox(width: 8),
                Text('Start Progress'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: TaskStatus.completed,
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Complete'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: TaskStatus.blocked,
            child: Row(
              children: [
                Icon(Icons.block, color: Colors.red),
                SizedBox(width: 8),
                Text('Block'),
              ],
            ),
          ),
        ];
      },
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
              child: Text('No checklist items'),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _checklist.length,
              itemBuilder: _buildChecklistItem,
            ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(BuildContext context, int index) {
    final item = _checklist[index];
    final isChecked = item.contains('[x]');
    final label = item.replaceAll(RegExp(r'\[.\]'), '').trim();

    return CheckboxListTile(
      value: isChecked,
      onChanged: (value) => _toggleChecklistItem(index),
      title: Text(
        label,
        style: TextStyle(
          decoration: isChecked ? TextDecoration.lineThrough : null,
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
                    child: Text('Error loading comments: ${snapshot.error}'),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final task = snapshot.data!.firstWhere(
                (t) => t.id == widget.task.id,
                orElse: () => widget.task,
              );

              final comments = context.read<TaskService>().parseComments(task.comments);
              
              if (comments.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No comments yet'),
                );
              }

              comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: comments.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) => _buildCommentItem(comments[index]),
              );
            },
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
                comment.userName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
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

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              focusNode: _commentFocus,
              decoration: const InputDecoration(
                hintText: 'Add a comment...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _addComment,
            icon: const Icon(Icons.send),
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) return;

    try {
      await context.read<TaskService>().addTaskComment(
        widget.task.id,
        _commentController.text,
      );
      _commentController.clear();
      _commentFocus.unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding comment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPriorityChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getPriorityColor(widget.task.priority).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getPriorityColor(widget.task.priority),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getPriorityIcon(widget.task.priority),
            size: 16,
            color: _getPriorityColor(widget.task.priority),
          ),
          const SizedBox(width: 4),
          Text(
            widget.task.priority.toString().split('.').last.toUpperCase(),
            style: TextStyle(
              color: _getPriorityColor(widget.task.priority),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(widget.task.status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor(widget.task.status),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(widget.task.status),
            size: 16,
            color: _getStatusColor(widget.task.status),
          ),
          const SizedBox(width: 4),
          Text(
            widget.task.status.toString().split('.').last.toUpperCase(),
            style: TextStyle(
              color: _getStatusColor(widget.task.status),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
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

  IconData _getPriorityIcon(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return Icons.flag;
      case TaskPriority.high:
        return Icons.arrow_upward;
      case TaskPriority.medium:
        return Icons.remove;
      case TaskPriority.low:
        return Icons.arrow_downward;
    }
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Colors.grey;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.blocked:
        return Colors.red;
      case TaskStatus.cancelled:
        return Colors.grey.shade700;
    }
  }

  IconData _getStatusIcon(TaskStatus status) {
    switch (status) {
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

  void _toggleChecklistItem(int index) async {
    setState(() {
      final item = _checklist[index];
      if (item.startsWith('[ ]')) {
        _checklist[index] = item.replaceFirst('[ ]', '[x]');
      } else {
        _checklist[index] = item.replaceFirst('[x]', '[ ]');
      }
    });

    try {
      await context.read<TaskService>().updateTaskChecklist(
        widget.task.id,
        _checklist,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating checklist: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}