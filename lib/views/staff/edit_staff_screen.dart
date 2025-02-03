import 'package:cateredtoyou/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components.
import 'package:provider/provider.dart'; // Importing Provider package for state management.
import 'package:go_router/go_router.dart'; // Importing GoRouter package for navigation.
import 'package:cateredtoyou/models/user_model.dart'; // Importing UserModel from the models directory.
import 'package:cateredtoyou/services/staff_service.dart'; // Importing StaffService for staff-related operations.
import 'package:cateredtoyou/widgets/custom_button.dart'; // Importing custom button widget.
import 'package:cateredtoyou/widgets/custom_text_field.dart'; // Importing custom text field widget.
import 'package:cateredtoyou/utils/validators.dart'; // Importing validators for form validation.

class EditStaffScreen extends StatefulWidget {
  // Stateful widget for editing staff details.
  final UserModel staff; // Staff member to be edited.

  const EditStaffScreen({
    super.key,
    required this.staff, // Required staff member parameter.
  });

  @override
  State<EditStaffScreen> createState() =>
      _EditStaffScreenState(); // Creating state for the widget.
}

class _EditStaffScreenState extends State<EditStaffScreen> {
  final _formKey = GlobalKey<FormState>(); // Key for the form to validate.
  late final TextEditingController
      _firstNameController; // Controller for first name input.
  late final TextEditingController
      _lastNameController; // Controller for last name input.
  late final TextEditingController
      _phoneController; // Controller for phone number input.
  late String _selectedRole; // Selected role for the staff member.
  final List<String> _departments = []; // List of selected departments.
  bool _isLoading = false; // Loading state for async operations.
  String? _error; // Error message if any operation fails.
  late final StaffService
      _staffService; // Service for staff-related operations.

  final List<String> _roles = [
    // List of available roles.
    'staff',
    'manager',
    'chef',
    'server',
    'driver'
  ];

  final List<String> _availableDepartments = [
    // List of available departments.
    'Kitchen',
    'Service',
    'Delivery',
    'Events',
    'Inventory'
  ];

  @override
  void initState() {
    super.initState();
    _staffService = Provider.of<StaffService>(context,
        listen: false); // Initializing staff service.
    _firstNameController = TextEditingController(
        text: widget.staff
            .firstName); // Initializing first name controller with staff's first name.
    _lastNameController = TextEditingController(
        text: widget.staff
            .lastName); // Initializing last name controller with staff's last name.
    _phoneController = TextEditingController(
        text: widget.staff
            .phoneNumber); // Initializing phone controller with staff's phone number.
    _selectedRole = widget.staff.role; // Setting initial selected role.
    if (widget.staff.departments != null) {
      _departments.addAll(widget
          .staff.departments!); // Adding existing departments to the list.
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose(); // Disposing first name controller.
    _lastNameController.dispose(); // Disposing last name controller.
    _phoneController.dispose(); // Disposing phone controller.
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    // Function to handle staff update.
    if (!_formKey.currentState!.validate()) return; // Validate form inputs.

    setState(() {
      _isLoading = true; // Set loading state to true.
      _error = null; // Reset error message.
    });

    try {
      final updatedStaff = widget.staff.copyWith(
        // Create updated staff object.
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        role: _selectedRole,
        departments: _departments.isNotEmpty ? _departments : null,
      );

      await _staffService.updateStaffMember(
          updatedStaff); // Update staff member in the service.

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        // Show success message.
        const SnackBar(content: Text('Staff member updated successfully')),
      );
      context.go('/staff'); // Navigate to staff list.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString(); // Set error message.
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Set loading state to false.
        });
      }
    }
  }

  Future<void> _handleResetPassword() async {
    // Function to handle password reset.
    setState(() {
      _isLoading = true; // Set loading state to true.
      _error = null; // Reset error message.
    });

    try {
      await _staffService
          .resetStaffPassword(widget.staff.email); // Reset staff password.
      (widget.staff.email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        // Show success message.
        const SnackBar(
          content: Text('Password reset email sent successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString(); // Set error message.
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Set loading state to false.
        });
      }
    }
  }

  Future<void> _handleStatusChange(String newStatus) async {
    // Function to handle status change.
    try {
      setState(() {
        _isLoading = true; // Set loading state to true.
        _error = null; // Reset error message.
      });

      await _staffService.changeStaffStatus(
        // Change staff status.
        widget.staff.uid,
        newStatus,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        // Show success message.
        SnackBar(
          content: Text(
              'Staff member ${newStatus == 'active' ? 'reactivated' : 'deactivated'} successfully'),
        ),
      );

      context.go('/staff'); // Navigate to staff list.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString(); // Set error message.
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Set loading state to false.
        });
      }
    }
  }

  void _showStatusConfirmation() {
    // Function to show status change confirmation dialog.
    final isActive =
        widget.staff.employmentStatus == 'active'; // Check if staff is active.
    final newStatus = isActive ? 'inactive' : 'active'; // Determine new status.

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${isActive ? 'Deactivate' : 'Reactivate'} Staff Member'),
        content: Text(
            '${isActive ? 'Deactivate' : 'Reactivate'} ${widget.staff.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), // Close dialog.
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // Close dialog.
              _handleStatusChange(newStatus); // Handle status change.
            },
            style: TextButton.styleFrom(
              foregroundColor: isActive
                  ? Colors.red
                  : Colors.green, // Set button color based on status.
            ),
            child: Text(isActive
                ? 'Deactivate'
                : 'Reactivate'), // Set button text based on status.
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive =
        widget.staff.employmentStatus == 'active'; // Check if staff is active.

    return Scaffold(
      appBar: AppBar(
      title: Text('Edit ${widget.staff.fullName}'), // Display the full name of the staff member being edited in the app bar title.
      actions: [
        StreamBuilder<UserModel?>(
        stream: context
          .read<AuthService>()
          .authStateChanges
          .asyncMap((user) async {
          if (user == null) return null;
          final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
          if (!doc.exists) return null;
          return UserModel.fromMap(doc.data()!);
        }),
        builder: (context, snapshot) {
          final canManagePermissions =
            ['admin', 'client', 'manager'].contains(snapshot.data?.role); // Check if the current user has permission to manage staff permissions.

          return Row(
          children: [
            if (canManagePermissions)
            IconButton(
              icon: const Icon(Icons.security),
              tooltip: 'Manage Permissions', // Tooltip for the manage permissions button.
              onPressed: () => context.push(
              '/staff/${widget.staff.uid}/permissions',
              extra: widget.staff, // Navigate to the manage permissions screen with the staff member's details.
              ),
            ),
            IconButton(
            icon: const Icon(Icons.key),
            onPressed: _isLoading ? null : _handleResetPassword, // Disable the button if loading, otherwise handle password reset.
            tooltip: 'Reset Password', // Tooltip for the reset password button.
            ),
          ],
          );
        },
        ),
      ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0), // Set padding for the body.
        child: Form(
          key: _formKey, // Set form key.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment
                .stretch, // Stretch children to fill the column.
            children: [
              CustomTextField(
                controller:
                    _firstNameController, // Set controller for first name input.
                label: 'First Name', // Set label for first name input.
                prefixIcon:
                    Icons.person, // Set prefix icon for first name input.
                validator: Validators
                    .validateName, // Set validator for first name input.
              ),
              const SizedBox(height: 16), // Add vertical space.
              CustomTextField(
                controller:
                    _lastNameController, // Set controller for last name input.
                label: 'Last Name', // Set label for last name input.
                prefixIcon:
                    Icons.person, // Set prefix icon for last name input.
                validator: Validators
                    .validateName, // Set validator for last name input.
              ),
              const SizedBox(height: 16), // Add vertical space.
              CustomTextField(
                controller:
                    _phoneController, // Set controller for phone number input.
                label: 'Phone Number', // Set label for phone number input.
                prefixIcon:
                    Icons.phone, // Set prefix icon for phone number input.
                keyboardType: TextInputType
                    .phone, // Set keyboard type for phone number input.
                validator: Validators
                    .validatePhone, // Set validator for phone number input.
              ),
              const SizedBox(height: 16), // Add vertical space.
              DropdownButtonFormField<String>(
                value: _selectedRole, // Set selected role.
                decoration: const InputDecoration(
                  labelText: 'Role', // Set label for role dropdown.
                  border: OutlineInputBorder(), // Set border for role dropdown.
                  prefixIcon:
                      Icon(Icons.work), // Set prefix icon for role dropdown.
                ),
                items: _roles.map((String role) {
                  // Map roles to dropdown items.
                  return DropdownMenuItem<String>(
                    value: role,
                    child:
                        Text(role.toUpperCase()), // Display role in uppercase.
                  );
                }).toList(),
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      _selectedRole = value; // Update selected role.
                    });
                  }
                },
              ),
              const SizedBox(height: 16), // Add vertical space.
              const Text(
                'Departments',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableDepartments.map((department) {
                  // Map departments to filter chips.
                  final isSelected = _departments
                      .contains(department); // Check if department is selected.
                  return FilterChip(
                    selected: isSelected,
                    label: Text(department), // Display department name.
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _departments.add(
                              department); // Add department to selected list.
                        } else {
                          _departments.remove(
                              department); // Remove department from selected list.
                        }
                      });
                    },
                    selectedColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withAlpha((0.2 * 255).toInt()), // Set selected color.
                    checkmarkColor: Theme.of(context)
                        .colorScheme
                        .primary, // Set checkmark color.
                  );
                }).toList(),
              ),
              const SizedBox(height: 24), // Add vertical space.
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!, // Display error message.
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              CustomButton(
                label: 'Update Staff Member', // Set button label.
                onPressed: _isLoading
                    ? null
                    : _handleUpdate, // Handle update staff member.
                isLoading: _isLoading, // Set loading state for button.
              ),
              const SizedBox(height: 16), // Add vertical space.
              OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : _showStatusConfirmation, // Show status confirmation dialog.
                style: OutlinedButton.styleFrom(
                  foregroundColor: isActive
                      ? Colors.red
                      : Colors.green, // Set button color based on status.
                  side: BorderSide(
                    color: isActive
                        ? Colors.red
                        : Colors.green, // Set border color based on status.
                  ),
                  padding: const EdgeInsets.symmetric(
                      vertical: 16), // Set padding for button.
                ),
                child: Text(isActive
                        ? 'Deactivate Staff Member'
                        : 'Reactivate Staff Member' // Set button text based on status.
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
