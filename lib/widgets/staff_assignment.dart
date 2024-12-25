import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cateredtoyou/models/user_model.dart';
import 'package:cateredtoyou/models/event_model.dart';

class StaffAssignmentWidget extends StatefulWidget {
  final int minStaff;
  final List<AssignedStaff> assignedStaff;
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _assignedStaff = List.from(widget.assignedStaff);
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Check user role
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userRole = userDoc.data()?['role'] as String?;
      
      // Check permissions
      final permDoc = await _firestore.collection('permissions').doc(user.uid).get();
      final permissions = List<String>.from(permDoc.data()?['permissions'] ?? []);

      setState(() {
        _hasPermission = ['admin', 'client', 'manager'].contains(userRole) ||
            permissions.contains('manage_staff');
      });
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    }
  }

  Future<String?> _getCurrentOrgId() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data()?['organizationId'] as String?;
  }

  Future<void> _showStaffSelectionDialog() async {
    if (!_hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to assign staff')),
      );
      return;
    }

    final orgId = await _getCurrentOrgId();
    if (orgId == null) return;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Staff'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .where('organizationId', isEqualTo: orgId)
                .where('role', whereIn: ['staff', 'server', 'chef', 'driver'])
                .where('employmentStatus', isEqualTo: 'active')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final availableStaff = snapshot.data?.docs
                  .map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['uid'] = doc.id; // Ensure uid is set from document ID
                    return UserModel.fromMap(data);
                  })
                  .where((staff) => !_assignedStaff
                      .any((assigned) => assigned.userId == staff.uid))
                  .toList() ??
                  [];

              if (availableStaff.isEmpty) {
                return const Center(child: Text('No available staff'));
              }

              return ListView.builder(
                itemCount: availableStaff.length,
                itemBuilder: (context, index) {
                  final staff = availableStaff[index];
                  return ListTile(
                    title: Text(staff.fullName),
                    subtitle: Text(staff.role.toUpperCase()),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        final newStaffMember = AssignedStaff(
                          userId: staff.uid,
                          name: staff.fullName,
                          role: staff.role,
                          assignedAt: DateTime.now(),
                        );
                        
                        setState(() {
                          _assignedStaff = [..._assignedStaff, newStaffMember];
                        });
                        widget.onStaffAssigned(_assignedStaff);
                        Navigator.pop(context);
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
            const Text('Assigned Staff'),
            Text(
              '${_assignedStaff.length}/${widget.minStaff} Required',
              style: TextStyle(
                color: _assignedStaff.length < widget.minStaff
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_assignedStaff.isNotEmpty)
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
                    onPressed: _hasPermission ? () {
                      setState(() {
                        _assignedStaff = List.from(_assignedStaff)..removeAt(index);
                      });
                      widget.onStaffAssigned(_assignedStaff);
                    } : null,
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _hasPermission ? _showStaffSelectionDialog : null,
            icon: const Icon(Icons.person_add),
            label: const Text('Assign Staff'),
          ),
        ),
      ],
    );
  }
}