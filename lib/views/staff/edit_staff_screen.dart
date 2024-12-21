import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cateredtoyou/models/user.dart';
import 'package:cateredtoyou/services/staff_service.dart';
import 'package:cateredtoyou/widgets/custom_button.dart';
import 'package:cateredtoyou/widgets/custom_text_field.dart';
import 'package:cateredtoyou/utils/validators.dart';

class EditStaffScreen extends StatefulWidget {
  final UserModel staff;

  const EditStaffScreen({
    super.key,
    required this.staff,
  });

  @override
  State<EditStaffScreen> createState() => _EditStaffScreenState();
}

class _EditStaffScreenState extends State<EditStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late String _selectedRole;
  final List<String> _departments = [];
  bool _isLoading = false;
  String? _error;
  late final StaffService _staffService;

  final List<String> _roles = [
    'staff',
    'manager',
    'chef',
    'server',
    'driver'
  ];

  final List<String> _availableDepartments = [
    'Kitchen',
    'Service',
    'Delivery',
    'Events',
    'Inventory'
  ];

  @override
  void initState() {
    super.initState();
    _staffService = Provider.of<StaffService>(context, listen: false);
    _firstNameController = TextEditingController(text: widget.staff.firstName);
    _lastNameController = TextEditingController(text: widget.staff.lastName);
    _phoneController = TextEditingController(text: widget.staff.phoneNumber);
    _selectedRole = widget.staff.role;
    if (widget.staff.departments != null) {
      _departments.addAll(widget.staff.departments!);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final updatedStaff = widget.staff.copyWith(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        role: _selectedRole,
        departments: _departments.isNotEmpty ? _departments : null,
      );

      await _staffService.updateStaffMember(updatedStaff);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff member updated successfully')),
      );
      context.go('/staff');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleResetPassword() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _staffService.resetStaffPassword(widget.staff.email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleStatusChange(String newStatus) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _staffService.changeStaffStatus(
        widget.staff.uid,
        newStatus,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Staff member ${newStatus == 'active' ? 'reactivated' : 'deactivated'} successfully'
          ),
        ),
      );
      
      context.go('/staff');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showStatusConfirmation() {
    final isActive = widget.staff.employmentStatus == 'active';
    final newStatus = isActive ? 'inactive' : 'active';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '${isActive ? 'Deactivate' : 'Reactivate'} Staff Member'
        ),
        content: Text(
          '${isActive ? 'Deactivate' : 'Reactivate'} ${widget.staff.fullName}?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _handleStatusChange(newStatus);
            },
            style: TextButton.styleFrom(
              foregroundColor: isActive ? Colors.red : Colors.green,
            ),
            child: Text(isActive ? 'Deactivate' : 'Reactivate'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.staff.employmentStatus == 'active';

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.staff.fullName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.key),
            onPressed: _isLoading ? null : _handleResetPassword,
            tooltip: 'Reset Password',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                controller: _firstNameController,
                label: 'First Name',
                prefixIcon: Icons.person,
                validator: Validators.validateName,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _lastNameController,
                label: 'Last Name',
                prefixIcon: Icons.person,
                validator: Validators.validateName,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _phoneController,
                label: 'Phone Number',
                prefixIcon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: Validators.validatePhone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work),
                ),
                items: _roles.map((String role) {
                  return DropdownMenuItem<String>(
                    value: role,
                    child: Text(role.toUpperCase()),
                  );
                }).toList(),
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      _selectedRole = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
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
                  final isSelected = _departments.contains(department);
                  return FilterChip(
                    selected: isSelected,
                    label: Text(department),
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _departments.add(department);
                        } else {
                          _departments.remove(department);
                        }
                      });
                    },
                    selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    checkmarkColor: Theme.of(context).colorScheme.primary,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              CustomButton(
                label: 'Update Staff Member',
                onPressed: _isLoading ? null : _handleUpdate,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _isLoading ? null : _showStatusConfirmation,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isActive ? Colors.red : Colors.green,
                  side: BorderSide(
                    color: isActive ? Colors.red : Colors.green,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  isActive ? 'Deactivate Staff Member' : 'Reactivate Staff Member'
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}