
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components.
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore package for database operations.
import 'package:firebase_auth/firebase_auth.dart'; // Importing Firebase Auth package for authentication.
import 'package:cateredtoyou/models/user_model.dart'; // Importing user model.
import 'package:cateredtoyou/models/event_model.dart'; // Importing event model.

class StaffAssignmentWidget extends StatefulWidget { // Stateful widget to manage staff assignment.
  final int minStaff; // Minimum number of staff required.
  final List<AssignedStaff> assignedStaff; // List of currently assigned staff.
  final Function(List<AssignedStaff>) onStaffAssigned; // Callback function when staff is assigned.

  const StaffAssignmentWidget({ // Constructor for the widget.
    super.key, // Key for the widget.
    required this.assignedStaff, // Required parameter for assigned staff.
    required this.minStaff, // Required parameter for minimum staff.
    required this.onStaffAssigned, // Required parameter for callback function.
  });

  @override
  State<StaffAssignmentWidget> createState() => _StaffAssignmentWidgetState(); // Creating state for the widget.
}

class _StaffAssignmentWidgetState extends State<StaffAssignmentWidget> { // State class for StaffAssignmentWidget.
  late List<AssignedStaff> _assignedStaff; // List to hold assigned staff.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance for database operations.
  final FirebaseAuth _auth = FirebaseAuth.instance; // FirebaseAuth instance for authentication.
  bool _hasPermission = false; // Boolean to check if user has permission.

  @override
  void initState() { // Initializing state.
    super.initState();
    _assignedStaff = List.from(widget.assignedStaff); // Initializing assigned staff list.
    _checkPermissions(); // Checking user permissions.
  }

  Future<void> _checkPermissions() async { // Function to check user permissions.
    try {
      final user = _auth.currentUser; // Getting current user.
      if (user == null) return;

      final userDoc = await _firestore.collection('users').doc(user.uid).get(); // Fetching user document from Firestore.
      final userRole = userDoc.data()?['role'] as String?; // Getting user role.

      final permDoc = await _firestore.collection('permissions').doc(user.uid).get(); // Fetching permissions document from Firestore.
      final permissions = List<String>.from(permDoc.data()?['permissions'] ?? []); // Getting list of permissions.

      setState(() {
        _hasPermission = ['admin', 'client', 'manager'].contains(userRole) || // Checking if user has required role or permission.
            permissions.contains('manage_staff');
      });
    } catch (e) {
      debugPrint('Error checking permissions: $e'); // Printing error if any.
    }
  }

  Future<String?> _getCurrentOrgId() async { // Function to get current organization ID.
    final user = _auth.currentUser; // Getting current user.
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get(); // Fetching user document from Firestore.
    return doc.data()?['organizationId'] as String?; // Returning organization ID.
  }

  Future<void> _showStaffSelectionDialog() async { // Function to show staff selection dialog.
    if (!_hasPermission) { // Checking if user has permission.
      ScaffoldMessenger.of(context).showSnackBar( // Showing snackbar if user does not have permission.
        const SnackBar(content: Text('You do not have permission to assign staff')),
      );
      return;
    }

    final orgId = await _getCurrentOrgId(); // Getting current organization ID.
    if (orgId == null) return;

    if (!mounted) return;

    showDialog( // Showing dialog for staff selection.
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Staff'), // Dialog title.
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<QuerySnapshot>( // StreamBuilder to fetch available staff.
            stream: _firestore
                .collection('users')
                .where('organizationId', isEqualTo: orgId) // Filtering by organization ID.
                .where('role', whereIn: ['staff', 'server', 'chef', 'driver']) // Filtering by role.
                .where('employmentStatus', isEqualTo: 'active') // Filtering by employment status.
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}'); // Showing error if any.
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator()); // Showing loading indicator.
              }

              final availableStaff = snapshot.data?.docs // Mapping available staff.
                  .map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['uid'] = doc.id; // Setting uid from document ID.
                    return UserModel.fromMap(data); // Creating user model from data.
                  })
                  .where((staff) => !_assignedStaff
                      .any((assigned) => assigned.userId == staff.uid)) // Filtering out already assigned staff.
                  .toList() ??
                  [];

              if (availableStaff.isEmpty) {
                return const Center(child: Text('No available staff')); // Showing message if no staff available.
              }

              return ListView.builder( // Building list of available staff.
                itemCount: availableStaff.length,
                itemBuilder: (context, index) {
                  final staff = availableStaff[index];
                  return ListTile(
                    title: Text(staff.fullName), // Showing staff name.
                    subtitle: Text(staff.role.toUpperCase()), // Showing staff role.
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline), // Add icon.
                      onPressed: () {
                        final newStaffMember = AssignedStaff( // Creating new assigned staff member.
                          userId: staff.uid,
                          name: staff.fullName,
                          role: staff.role,
                          assignedAt: DateTime.now(),
                        );

                        setState(() {
                          _assignedStaff = [..._assignedStaff, newStaffMember]; // Adding new staff member to list.
                        });
                        widget.onStaffAssigned(_assignedStaff); // Calling callback function.
                        Navigator.pop(context); // Closing dialog.
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Closing dialog.
            child: const Text('Close'), // Close button text.
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) { // Building widget UI.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Assigned Staff'), // Title text.
            Text(
              '${_assignedStaff.length}/${widget.minStaff} Required', // Showing number of assigned staff.
              style: TextStyle(
                color: _assignedStaff.length < widget.minStaff // Changing color based on number of assigned staff.
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16), // Spacing.
        if (_assignedStaff.isNotEmpty)
          ListView.builder( // Building list of assigned staff.
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _assignedStaff.length,
            itemBuilder: (context, index) {
              final staff = _assignedStaff[index];
              return Card(
                child: ListTile(
                  title: Text(staff.name), // Showing staff name.
                  subtitle: Text(staff.role.toUpperCase()), // Showing staff role.
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline), // Remove icon.
                    color: Theme.of(context).colorScheme.error,
                    onPressed: _hasPermission ? () { // Removing staff if user has permission.
                      setState(() {
                        _assignedStaff = List.from(_assignedStaff)..removeAt(index); // Removing staff from list.
                      });
                      widget.onStaffAssigned(_assignedStaff); // Calling callback function.
                    } : null,
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 16), // Spacing.
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _hasPermission ? _showStaffSelectionDialog : null, // Showing staff selection dialog if user has permission.
            icon: const Icon(Icons.person_add), // Add icon.
            label: const Text('Assign Staff'), // Button text.
          ),
        ),
      ],
    );
  }
}