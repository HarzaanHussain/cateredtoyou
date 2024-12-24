// File: lib/views/events/event_edit_screen.dart

import 'package:cateredtoyou/models/customer_model.dart';
import 'package:cateredtoyou/widgets/staff_assignment.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cateredtoyou/models/event_model.dart';
import 'package:cateredtoyou/services/event_service.dart';
import 'package:cateredtoyou/widgets/custom_button.dart';
import 'package:cateredtoyou/widgets/custom_text_field.dart';
import 'package:cateredtoyou/widgets/customer_selector.dart';
import 'package:cateredtoyou/widgets/event_menu_selection.dart';
import 'package:cateredtoyou/widgets/event_supplies_selection.dart';
import 'package:cateredtoyou/widgets/add_customer_dialog.dart';

class EventEditScreen extends StatefulWidget {
  final Event? event;

  const EventEditScreen({
    super.key,
    this.event,
  });

  @override
  State<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends State<EventEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _guestCountController = TextEditingController();
  final _minStaffController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedCustomerId;
  List<EventMenuItem> _selectedMenuItems = [];
  List<EventSupply> _selectedSupplies = [];
  List<AssignedStaff> _assignedStaff = [];

  late DateTime _startDate;
  late DateTime _endDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _isLoading = false;
  String? _error;
  double _totalPrice = 0.0;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event != null) {
      _nameController.text = event.name;
      _descriptionController.text = event.description;
      _locationController.text = event.location;
      _guestCountController.text = event.guestCount.toString();
      _minStaffController.text = event.minStaff.toString();
      _notesController.text = event.notes;
      _startDate = event.startDate;
      _endDate = event.endDate;
      _startTime = TimeOfDay.fromDateTime(event.startTime);
      _endTime = TimeOfDay.fromDateTime(event.endTime);
      _selectedCustomerId = event.customerId;
      _selectedMenuItems = List.from(event.menuItems);
      _selectedSupplies = List.from(event.supplies);
      _totalPrice = event.totalPrice;
      _assignedStaff = List.from(event.assignedStaff);
    } else {
      _startDate = DateTime.now().add(const Duration(days: 1));
      _endDate = DateTime.now().add(const Duration(days: 1));
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endTime = const TimeOfDay(hour: 17, minute: 0);
    }

    _updateTotalPrice();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _guestCountController.dispose();
    _minStaffController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _updateTotalPrice() async {
    // Calculate menu items total
    final menuTotal = _selectedMenuItems.fold(
      0.0,
      (total, item) => total + (item.price * item.quantity),
    );

    // Calculate supplies total
    double suppliesTotal = 0.0;
    for (final supply in _selectedSupplies) {
      final price = await _getInventoryItemPrice(supply.inventoryId);
      if (price != null) {
        suppliesTotal += price * supply.quantity;
      }
    }

    setState(() {
      _totalPrice = menuTotal + suppliesTotal;
    });
  }

  Future<double?> _getInventoryItemPrice(String inventoryId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('inventory')
          .doc(inventoryId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        return data?['costPerUnit'] as double?;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching inventory price: $e');
      return null;
    }
  }

  Future<void> _showAddCustomerDialog() async {
    final customer = await showDialog<CustomerModel>(
      context: context,
      builder: (context) => const AddCustomerDialog(),
    );

    if (customer != null) {
      setState(() {
        _selectedCustomerId = customer.id;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCustomerId == null) {
      setState(() {
        _error = 'Please select a customer';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final eventService = context.read<EventService>();

      final startDateTime = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final endDateTime = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      if (widget.event == null) {
        await eventService.createEvent(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          location: _locationController.text.trim(),
          customerId: _selectedCustomerId!,
          guestCount: int.parse(_guestCountController.text),
          minStaff: int.parse(_minStaffController.text),
          notes: _notesController.text.trim(),
          startTime: startDateTime,
          endTime: endDateTime,
          menuItems: _selectedMenuItems,
          supplies: _selectedSupplies,
        );
      } else {
        final updatedEvent = widget.event!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          location: _locationController.text.trim(),
          customerId: _selectedCustomerId!,
          guestCount: int.parse(_guestCountController.text),
          minStaff: int.parse(_minStaffController.text),
          notes: _notesController.text.trim(),
          startTime: startDateTime,
          endTime: endDateTime,
          menuItems: _selectedMenuItems,
          supplies: _selectedSupplies,
          totalPrice: _totalPrice,
        );

        await eventService.updateEvent(updatedEvent);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.event == null
                  ? 'Event created successfully'
                  : 'Event updated successfully',
            ),
          ),
        );
        context.go('/events');
      }
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, y');
    final isEditing = widget.event != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Event' : 'Create Event'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Event Details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _nameController,
                        label: 'Event Name',
                        prefixIcon: Icons.event,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an event name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        prefixIcon: Icons.description,
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer Information',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      CustomerSelector(
                        selectedCustomerId: _selectedCustomerId,
                        onCustomerSelected: (customerId) {
                          setState(() {
                            _selectedCustomerId = customerId;
                          });
                        },
                        onAddNewCustomer: _showAddCustomerDialog,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date & Time',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: const Text('Start Date'),
                              subtitle: Text(dateFormat.format(_startDate)),
                              leading: const Icon(Icons.calendar_today),
                              onTap: () => _selectDate(context, true),
                            ),
                          ),
                          Expanded(
                            child: ListTile(
                              title: const Text('End Date'),
                              subtitle: Text(dateFormat.format(_endDate)),
                              leading: const Icon(Icons.calendar_today),
                              onTap: () => _selectDate(context, false),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: const Text('Start Time'),
                              subtitle: Text(_startTime.format(context)),
                              leading: const Icon(Icons.access_time),
                              onTap: () => _selectTime(context, true),
                            ),
                          ),
                          Expanded(
                            child: ListTile(
                              title: const Text('End Time'),
                              subtitle: Text(_endTime.format(context)),
                              leading: const Icon(Icons.access_time),
                              onTap: () => _selectTime(context, false),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Venue & Attendance',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _locationController,
                        label: 'Location',
                        prefixIcon: Icons.location_on,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a location';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: StaffAssignmentWidget(
                            assignedStaff:
                                _assignedStaff, // Make sure this is declared in state
                            minStaff:
                                int.tryParse(_minStaffController.text) ?? 0,
                            onStaffAssigned: (newStaff) {
                              setState(() {
                                _assignedStaff = newStaff;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _guestCountController,
                              label: 'Guest Count',
                              prefixIcon: Icons.people,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                final number = int.tryParse(value);
                                if (number == null) {
                                  return 'Invalid number';
                                }
                                if (number < 0) {
                                  return 'Must be >= 0';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: CustomTextField(
                              controller: _minStaffController,
                              label: 'Min. Staff',
                              prefixIcon: Icons.person_outline,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                final number = int.tryParse(value);
                                if (number == null) {
                                  return 'Invalid number';
                                }
                                if (number < 0) {
                                  return 'Must be >= 0';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Menu & Supplies',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'Total: \$${_totalPrice.toStringAsFixed(2)}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Menu Items Selection
                      EventMenuSelection(
                        selectedItems: _selectedMenuItems,
                        onItemsChanged: (items) {
                          setState(() {
                            _selectedMenuItems = items;
                            _updateTotalPrice();
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      // Supplies Selection
                      EventSuppliesSelection(
                        selectedSupplies: _selectedSupplies,
                        onSuppliesChanged: (supplies) {
                          setState(() {
                            _selectedSupplies = supplies;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Additional Notes',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _notesController,
                        label: 'Notes (Optional)',
                        prefixIcon: Icons.note,
                        maxLines: 3,
                        //hintText: 'Add any special requirements or instructions...',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              CustomButton(
                label: isEditing ? 'Update Event' : 'Create Event',
                onPressed: _isLoading ? null : _handleSubmit,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
