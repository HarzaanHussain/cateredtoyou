// Create new file: lib/widgets/staff_assignment_widget.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cateredtoyou/models/event_model.dart';
import 'package:cateredtoyou/models/user_model.dart';

class StaffAssignmentWidget extends StatefulWidget {
  final List<AssignedStaff> assignedStaff;
  final int minStaff;
  final Function(List<AssignedStaff>) onStaffAssigned;

  const StaffAssignmentWidget({
    super.key,
    required this.assignedStaff,
    required this.minStaff,
    required this.onStaffAssigned,
  });

  @override
  State<StaffAssignmentWidget> createState() => _StaffAssignmentWidgetState();
}

class _StaffAssignmentWidgetState extends State<StaffAssignmentWidget> {
  late List<AssignedStaff> _assignedStaff;

  @override
  void initState() {
    super.initState();
    _assignedStaff = List.from(widget.assignedStaff);
  }

  void _showStaffSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Staff'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', whereIn: ['staff','server', 'chef', 'driver'])
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Error loading staff');
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final staff = snapshot.data?.docs
                  .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
                  .where((user) => !_assignedStaff.any((assigned) => assigned.userId == user.uid))
                  .toList() ??
                  [];

              return ListView.builder(
                shrinkWrap: true,
                itemCount: staff.length,
                itemBuilder: (context, index) {
                  final member = staff[index];
                  return ListTile(
                    title: Text(member.fullName),
                    subtitle: Text(member.role.toUpperCase()),
                    onTap: () {
                      setState(() {
                        _assignedStaff.add(AssignedStaff(
                          userId: member.uid,
                          name: member.fullName,
                          role: member.role,
                          assignedAt: DateTime.now(),
                        ));
                      });
                      widget.onStaffAssigned(_assignedStaff);
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Assigned Staff',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${_assignedStaff.length}/${widget.minStaff} Required',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: _assignedStaff.length < widget.minStaff
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_assignedStaff.isEmpty)
          Center(
            child: Text(
              'No staff assigned yet',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _assignedStaff.length,
            itemBuilder: (context, index) {
              final staff = _assignedStaff[index];
              return Card(
                child: ListTile(
                  title: Text(staff.name),
                  subtitle: Text(staff.role.toUpperCase()),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    color: Theme.of(context).colorScheme.error,
                    onPressed: () {
                      setState(() {
                        _assignedStaff.removeAt(index);
                      });
                      widget.onStaffAssigned(_assignedStaff);
                    },
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.person_add),
            label: const Text('Assign Staff'),
            onPressed: _showStaffSelectionDialog,
          ),
        ),
      ],
    );
  }
}