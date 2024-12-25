import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cateredtoyou/models/event_model.dart';
import 'package:cateredtoyou/models/customer_model.dart';
import 'package:cateredtoyou/services/event_service.dart';

class EventDetailsScreen extends StatelessWidget {
  final Event event;

  const EventDetailsScreen({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y');
    final timeFormat = DateFormat('h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/edit-event', extra: event),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'status':
                  _showStatusChangeDialog(context);
                  break;
                case 'delete':
                  _showDeleteConfirmation(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'status',
                child: Text('Change Status'),
              ),
              const PopupMenuItem(
                value: 'delete',
                textStyle: TextStyle(color: Colors.red),
                child: Text('Delete Event'),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section with Status
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.primary.withAlpha((0.1 * 255).toInt()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(event.status).withAlpha((0.1 * 255).toInt()),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event.status.toString().split('.').last.toUpperCase(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _getStatusColor(event.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.description_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Description',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(event.description),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Customer Information Card
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('customers')
                        .doc(event.customerId)
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Error loading customer information'),
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        );
                      }

                      final customerData =
                          snapshot.data?.data() as Map<String, dynamic>?;
                      if (customerData == null) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Customer not found'),
                          ),
                        );
                      }

                      final customer =
                          CustomerModel.fromMap(customerData, event.customerId);

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Customer Information',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _InfoRow(
                                icon: Icons.person,
                                label: 'Name',
                                value: customer.fullName,
                              ),
                              const SizedBox(height: 8),
                              _InfoRow(
                                icon: Icons.email_outlined,
                                label: 'Email',
                                value: customer.email,
                              ),
                              const SizedBox(height: 8),
                              _InfoRow(
                                icon: Icons.phone_outlined,
                                label: 'Phone',
                                value: customer.phoneNumber,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date & Time Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Date & Time',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _InfoRow(
                                  icon: Icons.calendar_today,
                                  label: 'Start Date',
                                  value: dateFormat.format(event.startDate),
                                ),
                              ),
                              Expanded(
                                child: _InfoRow(
                                  icon: Icons.calendar_today,
                                  label: 'End Date',
                                  value: dateFormat.format(event.endDate),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _InfoRow(
                                  icon: Icons.access_time,
                                  label: 'Start Time',
                                  value: timeFormat.format(event.startTime),
                                ),
                              ),
                              Expanded(
                                child: _InfoRow(
                                  icon: Icons.access_time,
                                  label: 'End Time',
                                  value: timeFormat.format(event.endTime),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Venue & Attendance Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Venue & Attendance',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          _InfoRow(
                            icon: Icons.location_on,
                            label: 'Location',
                            value: event.location,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _InfoRow(
                                  icon: Icons.people_outline,
                                  label: 'Guest Count',
                                  value: event.guestCount.toString(),
                                ),
                              ),
                              Expanded(
                                child: _InfoRow(
                                  icon: Icons.person_outline,
                                  label: 'Min. Staff',
                                  value: event.minStaff.toString(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  //staff 
                  if (event.assignedStaff.isNotEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.people_outline,
                                              color: theme.colorScheme.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Assigned Staff',
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${event.assignedStaff.length}/${event.minStaff} Required',
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                            color: event.assignedStaff.length <
                                                    event.minStaff
                                                ? theme.colorScheme.error
                                                : theme.colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    ...event.assignedStaff.map((staff) =>
                                        Column(
                                          children: [
                                            ListTile(
                                              leading: const Icon(
                                                  Icons.person_outline),
                                              title: Text(staff.name),
                                              subtitle: Text(
                                                staff.role.toUpperCase(),
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                              ),
                                              trailing: Text(
                                                DateFormat('MMM d, y')
                                                    .format(staff.assignedAt),
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                            ),
                                            if (staff !=
                                                event.assignedStaff.last)
                                              const Divider(),
                                          ],
                                        )),
                                  ],
                                ),
                              ),
                            ),

                  // Menu Items Card
                  if (event.menuItems.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.restaurant_menu,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Menu Items',
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Total: \$${event.totalPrice.toStringAsFixed(2)}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ...event.menuItems.map((item) => Column(
                                  children: [
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(item.name),
                                      subtitle: item.specialInstructions
                                                  ?.isNotEmpty ==
                                              true
                                          ? Text(item.specialInstructions!)
                                          : null,
                                      trailing: Text(
                                        '${item.quantity}x \$${item.price.toStringAsFixed(2)}',
                                        style: theme.textTheme.titleSmall,
                                      ),
                                    ),
                                    if (event.menuItems.last != item)
                                      const Divider(),
                                  ],
                                )),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Supplies Card
                  if (event.supplies.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Supplies & Equipment',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ...event.supplies.map((supply) => Column(
                                  children: [
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(supply.name),
                                      trailing: Text(
                                        '${supply.quantity} ${supply.unit}',
                                        style: theme.textTheme.titleSmall,
                                      ),
                                    ),
                                    if (event.supplies.last != supply)
                                      const Divider(),
                                  ],
                                )),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Notes Card
                  if (event.notes.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.note_outlined,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Additional Notes',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(event.notes),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(EventStatus status) {
    switch (status) {
      case EventStatus.draft:
        return Colors.grey;
      case EventStatus.pending:
        return Colors.orange;
      case EventStatus.confirmed:
        return Colors.green;
      case EventStatus.inProgress:
        return Colors.blue;
      case EventStatus.completed:
        return Colors.purple;
      case EventStatus.cancelled:
        return Colors.red;
      case EventStatus.archived:
        return Colors.brown;
    }
  }

  void _showStatusChangeDialog(BuildContext context) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Event Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: EventStatus.values
              .where((status) => status != event.status)
              .map((status) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      onPressed: () async {
                        try {
                          Navigator.pop(context);
                          final eventService = context.read<EventService>();
                          await eventService.changeEventStatus(
                              event.id, status);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Event status updated successfully'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: theme.colorScheme.error,
                              ),
                            );
                          }
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          status.toString().split('.').last.toUpperCase(),
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text(
          'Are you sure you want to delete "${event.name}"?\n\n'
          'This action cannot be undone and all associated data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final eventService = context.read<EventService>();
                await eventService.deleteEvent(event.id);

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }

                if (context.mounted) {
                  context.go('/events');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Event deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Helper widget for displaying info rows consistently
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.textTheme.bodySmall?.color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall,
              ),
              Text(
                value,
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Extension for consistent formatting
extension StatusFormatting on EventStatus {
  String get formatted => toString().split('.').last.toUpperCase();
}
