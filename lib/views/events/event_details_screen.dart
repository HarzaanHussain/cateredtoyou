import 'package:cateredtoyou/widgets/bottom_toolbar.dart';
import 'package:cateredtoyou/widgets/themed_app_bar.dart';
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components
import 'package:provider/provider.dart'; // Importing provider package for state management
import 'package:go_router/go_router.dart'; // Importing go_router package for navigation
import 'package:intl/intl.dart'; // Importing intl package for date formatting
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing cloud_firestore package for Firestore database
import 'package:cateredtoyou/models/event_model.dart'; // Importing event model
import 'package:cateredtoyou/models/customer_model.dart'; // Importing customer model
import 'package:cateredtoyou/services/event_service.dart'; // Importing event service for event-related operations

class EventDetailsScreen extends StatelessWidget {
  final Event event; // Event object to display details for

  const EventDetailsScreen({
    super.key,
    required this.event, // Constructor requiring an event object
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Getting the current theme
    final dateFormat =
        DateFormat('MMM d, y'); // Date format for displaying dates
    final timeFormat = DateFormat('h:mm a'); // Time format for displaying times

    return Scaffold(
      bottomNavigationBar: const BottomToolbar(),
      appBar: ThemedAppBar(
        const Text('Event Details'), // AppBar title
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/events'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit), // Edit icon button
            onPressed: () => context.push('/edit-event',
                extra: event), // Navigate to edit event screen
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'status':
                  _showStatusChangeDialog(context); // Show status change dialog
                  break;
                case 'delete':
                  _showDeleteConfirmation(
                      context); // Show delete confirmation dialog
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'status',
                child: Text(
                    'Change Status'), // Popup menu item for changing status
              ),
              const PopupMenuItem(
                value: 'delete',
                textStyle: TextStyle(
                    color: Colors.red), // Popup menu item for deleting event
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
              color: theme.colorScheme.primary.withAlpha(
                  (0.1 * 255).toInt()), // Light background color based on theme
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold, // Event name with bold font
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
                          color: _getStatusColor(event.status).withAlpha(
                              (0.1 * 255).toInt()), // Status color background
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event.status
                              .toString()
                              .split('.')
                              .last
                              .toUpperCase(), // Displaying event status
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
                                color: theme.colorScheme
                                    .primary, // Icon for description
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Description',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight
                                      .bold, // Title for description section
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(event
                              .description), // Displaying event description
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
                        .get(), // Fetching customer data from Firestore
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                                'Error loading customer information'), // Error message
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                                child:
                                    CircularProgressIndicator()), // Loading indicator
                          ),
                        );
                      }

                      final customerData =
                          snapshot.data?.data() as Map<String, dynamic>?;
                      if (customerData == null) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                                'Customer not found'), // Customer not found message
                          ),
                        );
                      }

                      final customer = CustomerModel.fromMap(
                          customerData,
                          event
                              .customerId); // Creating customer model from data

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
                                    color: theme.colorScheme
                                        .primary, // Icon for customer information
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Customer Information',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight
                                          .bold, // Title for customer information section
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _InfoRow(
                                icon: Icons.person,
                                label: 'Name',
                                value: customer
                                    .fullName, // Displaying customer name
                              ),
                              const SizedBox(height: 8),
                              _InfoRow(
                                icon: Icons.email_outlined,
                                label: 'Email',
                                value:
                                    customer.email, // Displaying customer email
                              ),
                              const SizedBox(height: 8),
                              _InfoRow(
                                icon: Icons.phone_outlined,
                                label: 'Phone',
                                value: customer
                                    .phoneNumber, // Displaying customer phone number
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
                                color: theme.colorScheme
                                    .primary, // Icon for date and time
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Date & Time',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight
                                      .bold, // Title for date and time section
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
                                  value: dateFormat.format(event
                                      .startDate), // Displaying event start date
                                ),
                              ),
                              Expanded(
                                child: _InfoRow(
                                  icon: Icons.calendar_today,
                                  label: 'End Date',
                                  value: dateFormat.format(event
                                      .endDate), // Displaying event end date
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
                                  value: timeFormat.format(event
                                      .startTime), // Displaying event start time
                                ),
                              ),
                              Expanded(
                                child: _InfoRow(
                                  icon: Icons.access_time,
                                  label: 'End Time',
                                  value: timeFormat.format(event
                                      .endTime), // Displaying event end time
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
                                color: theme.colorScheme
                                    .primary, // Icon for venue and attendance
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Venue & Attendance',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight
                                      .bold, // Title for venue and attendance section
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Displays the location of the event
                          _InfoRow(
                            icon: Icons.location_on,
                            label: 'Location',
                            value: event.location,
                          ),
                          const SizedBox(
                              height: 8), // Adds vertical spacing between rows
                          Row(
                            children: [
                              Expanded(
                                child: _InfoRow(
                                  icon: Icons.people_outline,
                                  label: 'Guest Count',
                                  value: event.guestCount
                                      .toString(), // Displays the guest count
                                ),
                              ),
                              Expanded(
                                child: _InfoRow(
                                  icon: Icons.person_outline,
                                  label: 'Min. Staff',
                                  value: event.minStaff
                                      .toString(), // Displays the minimum staff required
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                              height:
                                  16), // Adds vertical spacing between sections

                          // Displays assigned staff if there are any
                          if (event.assignedStaff.isNotEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(
                                    16), // Adds padding inside the card
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
                                            const SizedBox(
                                                width:
                                                    8), // Adds horizontal spacing
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
                                    const SizedBox(
                                        height: 16), // Adds vertical spacing
                                    ...event.assignedStaff.map((staff) =>
                                        Column(
                                          children: [
                                            ListTile(
                                              leading: const Icon(
                                                  Icons.person_outline),
                                              title: Text(staff
                                                  .name), // Displays the staff name
                                              subtitle: Text(
                                                staff.role
                                                    .toUpperCase(), // Displays the staff role
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
                                              const Divider(), // Adds a divider between staff members
                                          ],
                                        )),
                                  ],
                                ),
                              ),
                            ),

                          // Displays menu items if there are any
                          if (event.menuItems.isNotEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(
                                    16), // Adds padding inside the card
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
                                              Icons.restaurant_menu,
                                              color: theme.colorScheme.primary,
                                            ),
                                            const SizedBox(
                                                width:
                                                    8), // Adds horizontal spacing
                                            Text(
                                              'Menu Items',
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          'Total: \$${event.totalPrice.toStringAsFixed(2)}',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                        height: 16), // Adds vertical spacing
                                    ...event.menuItems.map((item) => Column(
                                          children: [
                                            ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(item
                                                  .name), // Displays the menu item name
                                              subtitle: item.specialInstructions
                                                          ?.isNotEmpty ==
                                                      true
                                                  ? Text(
                                                      item.specialInstructions!)
                                                  : null, // Displays special instructions if any
                                              trailing: Text(
                                                '${item.quantity}x \$${item.price.toStringAsFixed(2)}',
                                                style:
                                                    theme.textTheme.titleSmall,
                                              ),
                                            ),
                                            if (event.menuItems.last != item)
                                              const Divider(), // Adds a divider between menu items
                                          ],
                                        )),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(
                              height:
                                  16), // Adds vertical spacing between sections

                          // Displays supplies if there are any
                          if (event.supplies.isNotEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(
                                    16), // Adds padding inside the card
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.inventory_2_outlined,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(
                                            width:
                                                8), // Adds horizontal spacing
                                        Text(
                                          'Supplies & Equipment',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                        height: 16), // Adds vertical spacing
                                    ...event.supplies.map((supply) => Column(
                                          children: [
                                            ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(supply
                                                  .name), // Displays the supply name
                                              trailing: Text(
                                                '${supply.quantity} ${supply.unit}',
                                                style:
                                                    theme.textTheme.titleSmall,
                                              ),
                                            ),
                                            if (event.supplies.last != supply)
                                              const Divider(), // Adds a divider between supplies
                                          ],
                                        )),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(
                              height:
                                  16), // Adds vertical spacing between sections
                          // Displays event requirements
                          if (event.metadata != null)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.app_registration,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Event Requirements',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Dietary Requirements
                                    if (event.metadata?[
                                            'has_dietary_requirements'] ==
                                        true) ...[
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.restaurant,
                                            size: 20,
                                            color: theme.colorScheme.primary
                                                .withAlpha((0.7 * 255).toInt()),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Dietary Requirements',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: (event.metadata?[
                                                        'dietary_restrictions']
                                                    as List<dynamic>? ??
                                                [])
                                            .map((restriction) => Chip(
                                                  label: Text(
                                                    restriction.toString(),
                                                    style: theme
                                                        .textTheme.bodySmall,
                                                  ),
                                                  backgroundColor: theme
                                                      .colorScheme.primary
                                                      .withAlpha(
                                                          (0.1 * 255).toInt()),
                                                ))
                                            .toList(),
                                      ),
                                      const SizedBox(height: 16),
                                    ],

                                    // Special Equipment
                                    if (event.metadata?[
                                            'has_special_equipment'] ==
                                        true) ...[
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.hardware,
                                            size: 20,
                                            color: theme.colorScheme.primary
                                                .withAlpha((0.7 * 255).toInt()),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Special Equipment',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: (event.metadata?[
                                                        'special_equipment_needed']
                                                    as List<dynamic>? ??
                                                [])
                                            .map((equipment) => Chip(
                                                  label: Text(
                                                    equipment.toString(),
                                                    style: theme
                                                        .textTheme.bodySmall,
                                                  ),
                                                  backgroundColor: theme
                                                      .colorScheme.primary
                                                      .withAlpha(
                                                          (0.1 * 255).toInt()),
                                                ))
                                            .toList(),
                                      ),
                                      const SizedBox(height: 16),
                                    ],

                                    // Bar Service
                                    if (event.metadata?['has_bar_service'] ==
                                        true) ...[
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.local_bar,
                                            size: 20,
                                            color: theme.colorScheme.primary
                                                .withAlpha((0.7 * 255).toInt()),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Bar Service',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withAlpha((0.1 * 255).toInt()),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _formatBarServiceType(event
                                              .metadata?['bar_service_type']),
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],

                                    // Additional Metadata
                                    if (event.metadata?['additional_data'] !=
                                        null) ...[
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.more_horiz,
                                            size: 20,
                                            color: theme.colorScheme.primary
                                                .withAlpha((0.7 * 255).toInt()),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Additional Information',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ...(event.metadata?['additional_data']
                                              as Map<String, dynamic>)
                                          .entries
                                          .map(
                                            (entry) => Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 4),
                                              child: Row(
                                                children: [
                                                  Text(
                                                    '${entry.key}: ',
                                                    style: theme
                                                        .textTheme.bodyMedium
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    entry.value.toString(),
                                                    style: theme
                                                        .textTheme.bodyMedium,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                          // Displays additional notes if there are any
                          if (event.notes.isNotEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(
                                    16), // Adds padding inside the card
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.note_outlined,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(
                                            width:
                                                8), // Adds horizontal spacing
                                        Text(
                                          'Additional Notes',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                        height: 8), // Adds vertical spacing
                                    Text(event
                                        .notes), // Displays the additional notes
                                  ],
                                ),
                              ),
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

/// Formats the bar service type for display
String _formatBarServiceType(String? type) {
  if (type == null) return 'Standard Service';

  switch (type) {
    case 'full':
      return 'Full Service Bar';
    case 'beer_wine':
      return 'Beer & Wine Only';
    case 'mobile':
      return 'Mobile Bar';
    case 'custom':
      return 'Custom Setup';
    default:
      return type
          .split('_')
          .map(
              (word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
          .join(' ');
  }
}
