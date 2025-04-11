import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/delivery_route_model.dart';
import 'package:cateredtoyou/models/user_model.dart';
import 'package:cateredtoyou/services/delivery_route_service.dart';
import 'package:cateredtoyou/services/staff_service.dart';

class ReassignDriverDialog extends StatefulWidget {
  final DeliveryRoute route;

  const ReassignDriverDialog({
    super.key,
    required this.route,
  });

  @override
  State<ReassignDriverDialog> createState() => _ReassignDriverDialogState();
}

class _ReassignDriverDialogState extends State<ReassignDriverDialog> {
  String? _selectedDriverId;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_add, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Reassign Driver',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Current driver info
            _buildCurrentDriverInfo(),
            const SizedBox(height: 16),
            
            // Driver selection
            _buildDriverSelector(),
            
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isLoading || _selectedDriverId == null
                      ? null
                      : _reassignDriver,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reassign'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Current driver information widget
  Widget _buildCurrentDriverInfo() {
    return Consumer<StaffService>(
      builder: (context, staffService, _) {
        final currentDriverId = widget.route.currentDriver ?? widget.route.driverId;
        
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(currentDriverId)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            
            if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Current driver information unavailable'),
              );
            }
            
            final driverData = snapshot.data!.data() as Map<String, dynamic>;
            final firstName = driverData['firstName'] ?? '';
            final lastName = driverData['lastName'] ?? '';
            final driverName = '$firstName $lastName';
            
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withAlpha((0.3 * 255).toInt())),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Driver:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        radius: 16,
                        child: Text(
                          driverName.isNotEmpty
                              ? driverName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        driverName.isNotEmpty ? driverName : 'Unknown Driver',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.route.isReassigned) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withAlpha((0.1 * 255).toInt()),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.orange.withAlpha((0.5 * 255).toInt()),
                            ),
                          ),
                          child: const Text(
                            'Reassigned',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Driver selection widget
  Widget _buildDriverSelector() {
    return Consumer<StaffService>(
      builder: (context, staffService, _) {
        return StreamBuilder<List<UserModel>>(
          stream: staffService.getStaffMembers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            
            final allStaff = snapshot.data ?? [];
            
            // Filter staff to show only active staff
            final availableDrivers = allStaff
                .where((staff) => staff.employmentStatus == 'active')
                .toList();
            
            if (availableDrivers.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No available staff members found'),
              );
            }
            
            // Get current driver ID to exclude from list
            final currentDriverId = widget.route.currentDriver ?? widget.route.driverId;
            
            return DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Select New Driver',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              value: _selectedDriverId,
              hint: const Text('Choose a driver'),
              items: availableDrivers
                  .where((driver) => driver.uid != currentDriverId) // Exclude current driver
                  .map((driver) {
                    final isDriver = driver.role == 'driver';
                    return DropdownMenuItem<String>(
                      value: driver.uid,
                      child: Row(
                        children: [
                          Text('${driver.firstName} ${driver.lastName}'),
                          const SizedBox(width: 8),
                          if (isDriver)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha((0.1 * 255).toInt()),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.green.withAlpha((0.5 * 255).toInt()),
                                ),
                              ),
                              child: const Text(
                                'Driver',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withAlpha((0.1 * 255).toInt()),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.blue.withAlpha((0.5 * 255).toInt()),
                                ),
                              ),
                              child: Text(
                                driver.role.capitalize(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  })
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDriverId = value;
                  _errorMessage = null;
                });
              },
            );
          },
        );
      },
    );
  }

  // Reassign driver action
  Future<void> _reassignDriver() async {
    if (_selectedDriverId == null) {
      setState(() {
        _errorMessage = 'Please select a driver';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final deliveryService = Provider.of<DeliveryRouteService>(context, listen: false);
      
      // Call the service to reassign the driver
      await deliveryService.reassignDriver(widget.route.id, _selectedDriverId!);
      
      if (mounted) {
        Navigator.pop(context, true); // Return success
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Driver reassigned successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to reassign driver: ${e.toString()}';
      });
    }
  }
}

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}