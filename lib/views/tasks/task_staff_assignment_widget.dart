import 'package:cateredtoyou/models/task/task_model.dart'; // Importing the Task model
import 'package:cateredtoyou/models/user_model.dart'; // Importing the User model
import 'package:cateredtoyou/services/task_service.dart'; // Importing the TaskService
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components
import 'package:provider/provider.dart'; // Importing Provider for state management

class StaffAssignmentSection extends StatelessWidget {
  final Task task; // Task object to be assigned
  final void Function(String?) onAssigneeChanged; // Callback function when assignee changes

  const StaffAssignmentSection({
    super.key, // Key for the widget
    required this.task, // Required task parameter
    required this.onAssigneeChanged, // Required callback function
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: context.read<TaskService>().canAssignStaff(), // Checking if staff can be assigned
      builder: (context, canAssignSnapshot) {
        if (!canAssignSnapshot.hasData || !canAssignSnapshot.data!) {
          return const SizedBox.shrink(); // Return empty space if staff cannot be assigned
        }

        return Card(
          elevation: 2, // Elevation for the card
          child: Padding(
            padding: const EdgeInsets.all(16), // Padding inside the card
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Aligning children to the start
              children: [
                Text(
                  'Assign Staff', // Title text
                  style: Theme.of(context).textTheme.titleMedium, // Styling the title
                ),
                const SizedBox(height: 8), // Spacing between title and dropdown
                FutureBuilder<List<UserModel>>(
                  future: context.read<TaskService>().getAssignableStaff(task.eventId), // Fetching assignable staff
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator()); // Show loading indicator while waiting
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text('No staff members available'); // Show message if no staff available
                    }

                    return DropdownButtonFormField<String>(
                      value: task.assignedTo.isEmpty ? null : task.assignedTo, // Current assignee value
                      items: snapshot.data!.map((staff) {
                        return DropdownMenuItem(
                          value: staff.uid, // Staff UID as value
                          child: Text('${staff.firstName} ${staff.lastName} (${staff.role})'), // Staff name and role as text
                        );
                      }).toList(),
                      onChanged: onAssigneeChanged, // Callback when selection changes
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(), // Border for the dropdown
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, // Horizontal padding
                          vertical: 12, // Vertical padding
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}