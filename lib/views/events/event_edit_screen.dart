import 'package:cateredtoyou/models/customer_model.dart';
import 'package:cateredtoyou/utils/auto_complete.dart';
import 'package:cateredtoyou/widgets/event_metadata_selection.dart';
import 'package:cateredtoyou/widgets/staff_assignment.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
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
  LatLng? _eventLocation;

  // Page controller for multi-step form
  late PageController _pageController;
  int _currentPage = 0;

  // Form data
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
  EventMetadata? _metadata;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

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
      _metadata = event.metadata != null
          ? EventMetadata.fromMap(event.metadata!)
          : null;
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
    _pageController.dispose();
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

      // Create or update event
      String eventId;
      if (widget.event == null) {
        final createdEvent = await eventService.createEvent(
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
          assignedStaff: _assignedStaff,
          metadata: _metadata,
        );
        eventId = createdEvent.id;
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
          assignedStaff: _assignedStaff,
          totalPrice: _totalPrice,
          metadata: _metadata?.toMap(),
        );

        await eventService.updateEvent(updatedEvent);
        eventId = widget.event!.id;
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

  bool _validateCurrentPage() {
    // Different validation for each page
    switch (_currentPage) {
      case 0:
        // Basic event details & customer selection validation
        if (_nameController.text.isEmpty ||
            _descriptionController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fill in all required fields')),
          );
          return false;
        }
        if (_selectedCustomerId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a customer')),
          );
          return false;
        }
        return true;

      case 1:
        // Date, time, and venue info validation
        if (_locationController.text.isEmpty ||
            _guestCountController.text.isEmpty ||
            _minStaffController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fill in all required fields')),
          );
          return false;
        }

        // Check if guest count is valid
        try {
          final guestCount = int.parse(_guestCountController.text);
          if (guestCount < 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Guest count must be a positive number')),
            );
            return false;
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Guest count must be a valid number')),
          );
          return false;
        }

        // Check if min staff is valid
        try {
          final minStaff = int.parse(_minStaffController.text);
          if (minStaff < 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Minimum staff must be a positive number')),
            );
            return false;
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Minimum staff must be a valid number')),
          );
          return false;
        }

        return true;

      case 2:
        // No specific validation for the third page
        return true;

      default:
        return true;
    }
  }

  Widget _buildNavButtons() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button with explicit sizing constraints
          SizedBox(
            width: 120, // Fixed width to prevent layout issues
            child: _currentPage > 0
                ? ElevatedButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: const Text('Previous'),
                  )
                : const SizedBox(), // Empty but sized container
          ),

          // Next/Submit button with explicit sizing constraints
          SizedBox(
            width: 120, // Fixed width to prevent layout issues
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      if (_currentPage < 2) {
                        if (_validateCurrentPage()) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      } else {
                        _handleSubmit();
                      }
                    },
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.0),
                    )
                  : Text(
                      _currentPage < 2
                          ? 'Next'
                          : (widget.event == null
                              ? 'Create Event'
                              : 'Confirm'),
                      style: _currentPage == 2
                          ? const TextStyle(
                              fontSize: 13) // Smaller font size for longer text
                          : null, // Default size for "Next"
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // First page: Basic event details and customer
  Widget _buildPage1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
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
        ],
      ),
    );
  }

  // Second page: Date, time, venue
  Widget _buildPage2() {
    final dateFormat = DateFormat('MMM d, y');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
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
                  AddressAutoComplete(
                      controller: _locationController,
                      label: 'Event Location',
                      hint: 'Enter event venue address',
                      isPickup: false,
                      onLocationSelected: (location) {
                        setState(() {
                          _eventLocation = location;
                        });
                      }),
                  // CustomTextField(
                  //   controller: _locationController,
                  //   label: 'Location',
                  //   prefixIcon: Icons.location_on,
                  //   validator: (value) {
                  //     if (value == null || value.isEmpty) {
                  //       return 'Please enter a location';
                  //     }
                  //     return null;
                  //   },
                  // ),
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
        ],
      ),
    );
  }

  // Third page: Menu, supplies, staff, additional details
  Widget _buildPage3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
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
              child: StaffAssignmentWidget(
                assignedStaff: _assignedStaff,
                minStaff: int.tryParse(_minStaffController.text) ?? 0,
                onStaffAssigned: (List<AssignedStaff> newStaff) {
                  setState(() {
                    _assignedStaff = newStaff;
                  });
                },
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
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: EventMetadataSection(
                initialMetadata: _metadata,
                onMetadataChanged: (metadata) {
                  setState(() {
                    _metadata = metadata;
                  });
                },
              ),
            ),
          ),
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Event' : 'Create Event'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              LinearProgressIndicator(
                value: (_currentPage + 1) / 3,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE6A700)),
                minHeight: 4,
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStepIndicator(0, 'Basics'),
                    _buildStepConnector(_currentPage >= 1),
                    _buildStepIndicator(1, 'Venue'),
                    _buildStepConnector(_currentPage >= 2),
                    _buildStepIndicator(2, 'Details'),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (int page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  children: [
                    _buildPage1(),
                    _buildPage2(),
                    _buildPage3(),
                  ],
                ),
              ),
              _buildNavButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentPage >= step;
    final isCurrentStep = _currentPage == step;

    return GestureDetector(
      // Make all steps clickable, regardless of current page
      onTap: step != _currentPage ? () => _goToPage(step) : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color:
                  isActive ? Theme.of(context).primaryColor : Colors.grey[300],
              borderRadius: BorderRadius.circular(17.5),
              border: isCurrentStep
                  ? Border.all(color: Theme.of(context).primaryColor, width: 3)
                  : null,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: MouseRegion(
              cursor: step != _currentPage
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: Center(
                child: Text(
                  '${step + 1}',
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.black54,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isCurrentStep ? FontWeight.bold : FontWeight.normal,
              color: isCurrentStep
                  ? Theme.of(context).primaryColor
                  : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  void _goToPage(int pageIndex) {
    // If going forward, validate all pages in between
    if (pageIndex > _currentPage) {
      // Loop through and validate each page between current and target
      for (int i = _currentPage; i < pageIndex; i++) {
        if (!_validateSpecificPage(i)) {
          // Show a more specific error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please complete page ${i + 1} before proceeding'),
              duration: const Duration(seconds: 2),
            ),
          );

          // Navigate to the first page that needs attention instead of staying on current page
          if (i != _currentPage) {
            _pageController.animateToPage(
              i,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
          return;
        }
      }
    }

    // If no validation issues or going backward, proceed to the target page
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool _validateSpecificPage(int pageIndex) {
    switch (pageIndex) {
      case 0:
        if (_nameController.text.isEmpty ||
            _descriptionController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fill in all required fields')),
          );
          return false;
        }
        if (_selectedCustomerId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a customer')),
          );
          return false;
        }
        return true;

      case 1:
        if (_locationController.text.isEmpty ||
            _guestCountController.text.isEmpty ||
            _minStaffController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fill in all required fields')),
          );
          return false;
        }

        try {
          final guestCount = int.parse(_guestCountController.text);
          if (guestCount < 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Guest count must be a positive number')),
            );
            return false;
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Guest count must be a valid number')),
          );
          return false;
        }

        try {
          final minStaff = int.parse(_minStaffController.text);
          if (minStaff < 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Minimum staff must be a positive number')),
            );
            return false;
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Minimum staff must be a valid number')),
          );
          return false;
        }

        return true;

      default:
        return true;
    }
  }

  Widget _buildStepConnector(bool isActive) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: isActive ? Theme.of(context).primaryColor : Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
