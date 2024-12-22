
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components.
import 'package:provider/provider.dart'; // Importing Provider package for state management.
import 'package:go_router/go_router.dart'; // Importing GoRouter package for navigation.
import 'package:cateredtoyou/models/user.dart'; // Importing UserModel class from models.
import 'package:cateredtoyou/services/staff_service.dart'; // Importing StaffService class for staff-related operations.

/// A screen that displays a list of staff members and allows searching, adding, and editing staff.
class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key}); // Constructor for StaffListScreen.

  @override
  State<StaffListScreen> createState() => _StaffListScreenState(); // Creates the mutable state for this widget.
}

class _StaffListScreenState extends State<StaffListScreen> {
  String _searchQuery = ''; // Holds the current search query.
  final _searchController = TextEditingController(); // Controller for the search input field.

  @override
  void dispose() {
    _searchController.dispose(); // Disposes the controller when the widget is removed from the widget tree.
    super.dispose();
  }

  /// Filters the staff list based on the search query.
  List<UserModel> _filterStaff(List<UserModel> staffList) {
    if (_searchQuery.isEmpty) return staffList; // If search query is empty, return the full list.

    return staffList.where((staff) {
      final searchLower = _searchQuery.toLowerCase(); // Convert search query to lowercase.
      return staff.fullName.toLowerCase().contains(searchLower) || // Check if full name contains search query.
          staff.email.toLowerCase().contains(searchLower) || // Check if email contains search query.
          staff.role.toLowerCase().contains(searchLower); // Check if role contains search query.
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // Back button icon.
          onPressed: () => context.push('/home'), // Navigate to home screen when pressed.
        ),
        title: const Text('Staff Management'), // Title of the app bar.
        actions: [
          IconButton(
            icon: const Icon(Icons.add), // Add button icon.
            onPressed: () => context.push('/add-staff'), // Navigate to add staff screen when pressed.
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0), // Padding around the search field.
            child: TextField(
              controller: _searchController, // Controller for the search field.
              decoration: InputDecoration(
                hintText: 'Search staff...', // Placeholder text for the search field.
                prefixIcon: const Icon(Icons.search), // Search icon inside the search field.
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), // Rounded border for the search field.
                ),
                suffixIcon: _searchQuery.isNotEmpty // Clear button if search query is not empty.
                    ? IconButton(
                        icon: const Icon(Icons.clear), // Clear icon.
                        onPressed: () {
                          setState(() {
                            _searchQuery = ''; // Clear the search query.
                            _searchController.clear(); // Clear the search field.
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value; // Update the search query as the user types.
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: context.read<StaffService>().getStaffMembers(), // Stream of staff members from the service.
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'), // Display error message if there's an error.
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(), // Display loading indicator while waiting for data.
                  );
                }

                final allStaff = snapshot.data ?? []; // Get the list of all staff members.
                final filteredStaff = _filterStaff(allStaff); // Filter the staff list based on the search query.

                if (allStaff.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'No staff members found', // Message when no staff members are found.
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/add-staff'), // Navigate to add staff screen when pressed.
                          icon: const Icon(Icons.add), // Add icon.
                          label: const Text('Add Staff Member'), // Button label.
                        ),
                      ],
                    ),
                  );
                }

                if (filteredStaff.isEmpty) {
                  return const Center(
                    child: Text('No staff members match your search'), // Message when no staff members match the search query.
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16), // Padding around the list.
                  itemCount: filteredStaff.length, // Number of items in the list.
                  itemBuilder: (context, index) {
                    final staff = filteredStaff[index]; // Get the staff member at the current index.
                    return StaffListItem(staff: staff); // Build the list item for the staff member.
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A widget that displays a single staff member in the list.
class StaffListItem extends StatelessWidget {
  final UserModel staff; // The staff member to display.

  const StaffListItem({
    super.key,
    required this.staff, // Constructor for StaffListItem.
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = staff.employmentStatus == 'active'; // Check if the staff member is active.
    final theme = Theme.of(context); // Get the current theme.
    final staffService = context.read<StaffService>(); // Get the staff service from the context.

    /// Toggles the employment status of the staff member.
    void toggleStatus() async {
      try {
        await staffService.changeStaffStatus(
          staff.uid,
          isActive ? 'inactive' : 'active', // Toggle the status between active and inactive.
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${staff.fullName} has been ${isActive ? 'deactivated' : 'reactivated'}'), // Show a message indicating the status change.
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'), // Show an error message if the status change fails.
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16), // Margin around the card.
      child: ListTile(
        contentPadding: const EdgeInsets.all(16), // Padding inside the list tile.
        onTap: () => context.push('/edit-staff', extra: staff), // Navigate to edit staff screen when tapped.
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary, // Background color of the avatar.
          child: Text(
            staff.firstName[0] + staff.lastName[0], // Initials of the staff member.
            style: const TextStyle(color: Colors.white), // Text style for the initials.
          ),
        ),
        title: Text(
          staff.fullName, // Full name of the staff member.
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold, // Bold text for the full name.
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(staff.role.toUpperCase()), // Role of the staff member.
            const SizedBox(height: 4),
            Text(staff.email), // Email of the staff member.
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withAlpha((0.1 * 255).toInt()) // Background color for active status.
                        : Colors.red.withAlpha((0.1 * 255).toInt()), // Background color for inactive status.
                    borderRadius: BorderRadius.circular(4), // Rounded corners for the status container.
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive', // Text indicating the status.
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isActive ? Colors.green : Colors.red, // Text color based on the status.
                      fontWeight: FontWeight.bold, // Bold text for the status.
                    ),
                  ),
                ),
                TextButton(
                  onPressed: toggleStatus, // Toggle the status when pressed.
                  child: Text(isActive ? 'Deactivate' : 'Reactivate'), // Button text based on the status.
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit), // Edit icon.
          onPressed: () => context.push('/edit-staff', extra: staff), // Navigate to edit staff screen when pressed.
        ),
      ),
    );
  }
}
