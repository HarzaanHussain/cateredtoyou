import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/vehicle_model.dart';
import 'package:cateredtoyou/services/vehicle_service.dart';

class AssignDriverDialog extends StatefulWidget {
  final Vehicle vehicle;

  const AssignDriverDialog({
    super.key,
    required this.vehicle,
  });

  @override
  State<AssignDriverDialog> createState() => _AssignDriverDialogState();
}

class _AssignDriverDialogState extends State<AssignDriverDialog> {
  String? _selectedDriverId;
  bool _isLoading = false;

  Stream<List<Map<String, dynamic>>> _getAvailableDrivers() {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) return Stream.value([]);

    // First get the current user's organization ID
    return firestore.collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .asyncMap((userDoc) async {
          if (!userDoc.exists) return [];
          
          final organizationId = userDoc.get('organizationId');

          // Get all drivers from the same organization
          final QuerySnapshot driversSnapshot = await firestore
              .collection('users')
              .where('organizationId', isEqualTo: organizationId)
              .where('role', isEqualTo: 'driver')
              .where('employmentStatus', isEqualTo: 'active')
              .get();

          return driversSnapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    'firstName': doc['firstName'],
                    'lastName': doc['lastName'],
                  })
              .toList();
    });
  }

  Future<void> _assignDriver() async {
    if (_selectedDriverId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a driver'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final vehicleService = context.read<VehicleService>();
      await vehicleService.assignDriver(widget.vehicle.id, _selectedDriverId!);
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Driver assigned successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning driver: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Driver'),
      content: SizedBox(
        width: double.maxFinite,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _getAvailableDrivers(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final drivers = snapshot.data ?? [];
            if (drivers.isEmpty) {
              return const Text('No available drivers found');
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: drivers.map((driver) {
                  return RadioListTile<String>(
                    title: Text('${driver['firstName']} ${driver['lastName']}'),
                    value: driver['id'],
                    groupValue: _selectedDriverId,
                    onChanged: (value) {
                      setState(() => _selectedDriverId = value);
                    },
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _assignDriver,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Assign'),
        ),
      ],
    );
  }
}