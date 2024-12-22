//lib/views/staff/staff_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cateredtoyou/models/user.dart';
import 'package:cateredtoyou/services/staff_service.dart';

class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UserModel> _filterStaff(List<UserModel> staffList) {
    if (_searchQuery.isEmpty) return staffList;

    return staffList.where((staff) {
      final searchLower = _searchQuery.toLowerCase();
      return staff.fullName.toLowerCase().contains(searchLower) ||
          staff.email.toLowerCase().contains(searchLower) ||
          staff.role.toLowerCase().contains(searchLower);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.push('/home'),
        ),
        title: const Text('Staff Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/add-staff'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search staff...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: context.read<StaffService>().getStaffMembers(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final allStaff = snapshot.data ?? [];
                final filteredStaff = _filterStaff(allStaff);

                if (allStaff.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'No staff members found',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/add-staff'),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Staff Member'),
                        ),
                      ],
                    ),
                  );
                }

                if (filteredStaff.isEmpty) {
                  return const Center(
                    child: Text('No staff members match your search'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredStaff.length,
                  itemBuilder: (context, index) {
                    final staff = filteredStaff[index];
                    return StaffListItem(staff: staff);
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

class StaffListItem extends StatelessWidget {
  final UserModel staff;

  const StaffListItem({
    super.key,
    required this.staff,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = staff.employmentStatus == 'active';
    final theme = Theme.of(context);
    final staffService = context.read<StaffService>();

    void toggleStatus() async {
      try {
        await staffService.changeStaffStatus(
          staff.uid,
          isActive ? 'inactive' : 'active',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${staff.fullName} has been ${isActive ? 'deactivated' : 'reactivated'}'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () => context.push('/edit-staff', extra: staff),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary,
          child: Text(
            staff.firstName[0] + staff.lastName[0],
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          staff.fullName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(staff.role.toUpperCase()),
            const SizedBox(height: 4),
            Text(staff.email),
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
                        ? Colors.green.withAlpha((0.1 * 255).toInt())
                        : Colors.red.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isActive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: toggleStatus,
                  child: Text(isActive ? 'Deactivate' : 'Reactivate'),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => context.push('/edit-staff', extra: staff),
        ),
      ),
    );
  }
}
