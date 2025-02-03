import 'package:flutter/material.dart'; // Importing Flutter material package for UI components.
import 'package:provider/provider.dart'; // Importing Provider package for state management.
import 'package:cateredtoyou/services/role_permissions.dart'; // Importing custom service for role permissions.
import 'package:cateredtoyou/models/user_model.dart'; // Importing custom user model.

class UserPermissionsScreen extends StatefulWidget { // Stateful widget to manage user permissions.
  final UserModel user; // User model passed to the screen.

  const UserPermissionsScreen({ // Constructor for the widget.
    super.key,
    required this.user, // Required user parameter.
  });

  @override
  State<UserPermissionsScreen> createState() => _UserPermissionsScreenState(); // Creating state for the widget.
}

class _UserPermissionsScreenState extends State<UserPermissionsScreen> { // State class for UserPermissionsScreen.
  late String _selectedRole; // Variable to store selected role.
  final Set<String> _selectedPermissions = {}; // Set to store selected permissions.
  bool _isLoading = false; // Boolean to manage loading state.
  String? _error; // Variable to store error message.
  bool _hasCustomPermissions = false; // Boolean to check if custom permissions are applied.

  @override
  void initState() { // Initializing state.
    super.initState();
    _selectedRole = widget.user.role; // Setting initial role from user model.
    _loadCurrentPermissions(); // Loading current permissions.
  }

  Future<void> _loadCurrentPermissions() async { // Function to load current permissions.
    setState(() => _isLoading = true); // Setting loading state to true.
    try {
      final rolePermissions = Provider.of<RolePermissions>(context, listen: false); // Getting role permissions service.
      final userPermissions = await rolePermissions.getUserPermissions(widget.user.uid); // Fetching user permissions.
      
      setState(() {
        _selectedPermissions.clear(); // Clearing current permissions.
        _selectedPermissions.addAll(userPermissions); // Adding fetched permissions.
        
        // Check if permissions differ from default role permissions.
        final defaultPermissions = rolePermissions.getPermissionsForRole(_selectedRole); 
        _hasCustomPermissions = !_arePermissionsEqual(userPermissions, defaultPermissions); // Checking for custom permissions.
      });
    } catch (e) {
      setState(() => _error = e.toString()); // Setting error message.
    } finally {
      setState(() => _isLoading = false); // Setting loading state to false.
    }
  }

  bool _arePermissionsEqual(List<String> permissions1, List<String> permissions2) { // Function to compare permissions.
    if (permissions1.length != permissions2.length) return false; // Checking length.
    return Set.from(permissions1).containsAll(permissions2) && // Checking if sets are equal.
           Set.from(permissions2).containsAll(permissions1);
  }

  Future<void> _handleRoleChange(String? newRole) async { // Function to handle role change.
    if (newRole == null) return;

    setState(() {
      _selectedRole = newRole; // Setting new role.
      _hasCustomPermissions = false; // Resetting custom permissions flag.
      
      // Reset permissions to default for the new role.
      final rolePermissions = Provider.of<RolePermissions>(context, listen: false);
      _selectedPermissions.clear(); // Clearing current permissions.
      _selectedPermissions.addAll(rolePermissions.getPermissionsForRole(newRole)); // Adding default permissions for new role.
    });
  }

  Future<void> _savePermissions() async { // Function to save permissions.
    setState(() {
      _isLoading = true; // Setting loading state to true.
      _error = null; // Clearing error message.
    });

    try {
      final rolePermissions = Provider.of<RolePermissions>(context, listen: false); // Getting role permissions service.
      
      await rolePermissions.updateUserPermissions( // Updating user permissions.
        widget.user.uid,
        _selectedRole,
        customPermissions: _hasCustomPermissions ? _selectedPermissions.toList() : null, // Passing custom permissions if any.
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar( // Showing success message.
        const SnackBar(content: Text('Permissions updated successfully')),
      );
      Navigator.of(context).pop(); // Navigating back.
    } catch (e) {
      setState(() => _error = e.toString()); // Setting error message.
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); // Setting loading state to false.
      }
    }
  }

  Widget _buildPermissionCategory(String category, List<Permission> permissions) { // Function to build permission category UI.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            category, // Displaying category name.
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...permissions.map((permission) => CheckboxListTile( // Displaying permissions as checkboxes.
          title: Text(permission.name),
          subtitle: Text(permission.description),
          value: _selectedPermissions.contains(permission.id), // Checking if permission is selected.
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                _selectedPermissions.add(permission.id); // Adding permission.
              } else {
                _selectedPermissions.remove(permission.id); // Removing permission.
              }
              _hasCustomPermissions = true; // Setting custom permissions flag.
            });
          },
        )),
        const Divider(), // Adding divider.
      ],
    );
  }

  @override
  Widget build(BuildContext context) { // Building UI.
    // Group permissions by category.
    final permissionsByCategory = <String, List<Permission>>{};
    for (var permission in RolePermissions.allPermissions.values) {
      permissionsByCategory.putIfAbsent(permission.category, () => []).add(permission); // Grouping permissions.
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.user.fullName}\'s Permissions'), // Displaying user name in app bar.
        actions: [
          if (_hasCustomPermissions)
            Tooltip(
              message: 'Custom permissions applied', // Tooltip for custom permissions.
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                child: const Icon(Icons.edit_attributes), // Icon for custom permissions.
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Showing loading indicator.
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Role Assignment', // Section title.
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedRole, // Dropdown for role selection.
                            decoration: const InputDecoration(
                              labelText: 'Role',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'staff', child: Text('Staff')),
                              DropdownMenuItem(value: 'manager', child: Text('Manager')),
                              DropdownMenuItem(value: 'chef', child: Text('Chef')),
                              DropdownMenuItem(value: 'server', child: Text('Server')),
                              DropdownMenuItem(value: 'driver', child: Text('Driver')),
                            ],
                            onChanged: _handleRoleChange, // Handling role change.
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Permissions', // Section title.
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_hasCustomPermissions)
                                TextButton.icon(
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reset to Default'), // Button to reset permissions.
                                  onPressed: () => _handleRoleChange(_selectedRole),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...permissionsByCategory.entries.map(
                            (entry) => _buildPermissionCategory(entry.key, entry.value), // Building permission categories.
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _error!, // Displaying error message.
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _savePermissions, // Save button.
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_isLoading ? 'Saving...' : 'Save Permissions'), // Button text.
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}