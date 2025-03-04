
import 'package:cateredtoyou/models/customer_model.dart'; // Importing the customer model.
import 'package:cateredtoyou/widgets/event_metadata_selection.dart';
import 'package:cateredtoyou/widgets/staff_assignment.dart'; // Importing the staff assignment widget.
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firestore for database operations.
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components.
import 'package:provider/provider.dart'; // Importing Provider for state management.
import 'package:go_router/go_router.dart'; // Importing GoRouter for navigation.
import 'package:intl/intl.dart'; // Importing intl for date formatting.
import 'package:cateredtoyou/models/event_model.dart'; // Importing the event model.
import 'package:cateredtoyou/services/event_service.dart'; // Importing the event service for CRUD operations.
import 'package:cateredtoyou/widgets/custom_button.dart'; // Importing custom button widget.
import 'package:cateredtoyou/widgets/custom_text_field.dart'; // Importing custom text field widget.
import 'package:cateredtoyou/widgets/customer_selector.dart'; // Importing customer selector widget.
import 'package:cateredtoyou/widgets/event_menu_selection.dart'; // Importing event menu selection widget.
import 'package:cateredtoyou/widgets/event_supplies_selection.dart'; // Importing event supplies selection widget.
import 'package:cateredtoyou/widgets/add_customer_dialog.dart';

import '../../models/manifest_model.dart';
import '../../services/manifest_service.dart'; // Importing add customer dialog widget.

class EventEditScreen extends StatefulWidget {
  final Event? event; // Event object to edit, if null, a new event is created.
  

  const EventEditScreen({
    super.key, // Key for the widget.
    this.event, // Optional event parameter.
  });

  @override
  State<EventEditScreen> createState() => _EventEditScreenState(); // Creating the state for the widget.
}

class _EventEditScreenState extends State<EventEditScreen> {
  final _formKey = GlobalKey<FormState>(); // Key for the form.
  final _nameController = TextEditingController(); // Controller for the event name.
  final _descriptionController = TextEditingController(); // Controller for the event description.
  final _locationController = TextEditingController(); // Controller for the event location.
  final _guestCountController = TextEditingController(); // Controller for the guest count.
  final _minStaffController = TextEditingController(); // Controller for the minimum staff required.
  final _notesController = TextEditingController(); // Controller for additional notes.

  String? _selectedCustomerId; // Selected customer ID.
  List<EventMenuItem> _selectedMenuItems = []; // List of selected menu items.
  List<EventSupply> _selectedSupplies = []; // List of selected supplies.
  List<AssignedStaff> _assignedStaff = []; // List of assigned staff.

  late DateTime _startDate; // Start date of the event.
  late DateTime _endDate; // End date of the event.
  late TimeOfDay _startTime; // Start time of the event.
  late TimeOfDay _endTime; // End time of the event.
  bool _isLoading = false; // Loading state for the form submission.
  String? _error; // Error message for form submission.
  double _totalPrice = 0.0; // Total price of the event.
  EventMetadata? _metadata; // Metadata for the event.

  @override
  void initState() {
    super.initState();
    final event = widget.event; // Getting the event from the widget.
    if (event != null) {
      _nameController.text = event.name; // Setting the event name.
      _descriptionController.text = event.description; // Setting the event description.
      _locationController.text = event.location; // Setting the event location.
      _guestCountController.text = event.guestCount.toString(); // Setting the guest count.
      _minStaffController.text = event.minStaff.toString(); // Setting the minimum staff required.
      _notesController.text = event.notes; // Setting the additional notes.
      _startDate = event.startDate; // Setting the start date.
      _endDate = event.endDate; // Setting the end date.
      _startTime = TimeOfDay.fromDateTime(event.startTime); // Setting the start time.
      _endTime = TimeOfDay.fromDateTime(event.endTime); // Setting the end time.
      _selectedCustomerId = event.customerId; // Setting the selected customer ID.
      _selectedMenuItems = List.from(event.menuItems); // Setting the selected menu items.
      _selectedSupplies = List.from(event.supplies); // Setting the selected supplies.
      _totalPrice = event.totalPrice; // Setting the total price.
      _assignedStaff = List.from(event.assignedStaff); // Setting the assigned staff.
      _metadata = event.metadata != null  // Setting the metadata.
      ? EventMetadata.fromMap(event.metadata!)  
      : null; 
    } else {
      _startDate = DateTime.now().add(const Duration(days: 1)); // Default start date.
      _endDate = DateTime.now().add(const Duration(days: 1)); // Default end date.
      _startTime = const TimeOfDay(hour: 9, minute: 0); // Default start time.
      _endTime = const TimeOfDay(hour: 17, minute: 0); // Default end time.
    }

    _updateTotalPrice(); // Updating the total price.
  }

  @override
  void dispose() {
    _nameController.dispose(); // Disposing the name controller.
    _descriptionController.dispose(); // Disposing the description controller.
    _locationController.dispose(); // Disposing the location controller.
    _guestCountController.dispose(); // Disposing the guest count controller.
    _minStaffController.dispose(); // Disposing the minimum staff controller.
    _notesController.dispose(); // Disposing the notes controller.
    super.dispose();
  }

  Future<void> _updateTotalPrice() async {
    // Calculate menu items total
    final menuTotal = _selectedMenuItems.fold(
      0.0,
      (total, item) => total + (item.price * item.quantity), // Calculating the total price of menu items.
    );

    // Calculate supplies total
    double suppliesTotal = 0.0;
    for (final supply in _selectedSupplies) {
      final price = await _getInventoryItemPrice(supply.inventoryId); // Getting the price of each supply item.
      if (price != null) {
        suppliesTotal += price * supply.quantity; // Calculating the total price of supplies.
      }
    }

    setState(() {
      _totalPrice = menuTotal + suppliesTotal; // Setting the total price.
    });
  }

  Future<double?> _getInventoryItemPrice(String inventoryId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('inventory')
          .doc(inventoryId)
          .get(); // Fetching the inventory item price from Firestore.
      if (doc.exists) {
        final data = doc.data();
        return data?['costPerUnit'] as double?; // Returning the cost per unit.
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching inventory price: $e'); // Logging the error.
      return null;
    }
  }

  Future<void> _showAddCustomerDialog() async {
    final customer = await showDialog<CustomerModel>(
      context: context,
      builder: (context) => const AddCustomerDialog(), // Showing the add customer dialog.
    );

    if (customer != null) {
      setState(() {
        _selectedCustomerId = customer.id; // Setting the selected customer ID.
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate, // Initial date for the date picker.
      firstDate: DateTime.now(), // First selectable date.
      lastDate: DateTime.now().add(const Duration(days: 365)), // Last selectable date.
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked; // Setting the start date.
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate; // Ensuring the end date is not before the start date.
          }
        } else {
          _endDate = picked; // Setting the end date.
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime, // Initial time for the time picker.
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked; // Setting the start time.
        } else {
          _endTime = picked; // Setting the end time.
        }
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return; // Validating the form.

    if (_selectedCustomerId == null) {
      setState(() {
        _error = 'Please select a customer'; // Setting the error message if no customer is selected.
      });
      return;
    }

    setState(() {
      _isLoading = true; // Setting the loading state.
      _error = null; // Clearing the error message.
    });

    try {
      final eventService = context.read<EventService>(); // Getting the event service.

      final startDateTime = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      ); // Combining the start date and time.

      final endDateTime = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        _endTime.hour,
        _endTime.minute,
      ); // Combining the end date and time.

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
        eventId = createdEvent.id; // Store the ID of the newly created event
      } else {
        final updatedEvent = widget.event!.copyWith(
          name: _nameController.text.trim(), // Updating the existing event.
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
        eventId = widget.event!.id; // Use the ID of the existing event
      }

      // Create or update the manifest for this event
      await _manageManifest(eventId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.event == null
                  ? 'Event created successfully' // Showing success message for event creation.
                  : 'Event updated successfully', // Showing success message for event update.
            ),
          ),
        );
        context.go('/events'); // Navigating to the events page.
      }
    } catch (e) {
      setState(() {
        _error = e.toString(); // Setting the error message.
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Clearing the loading state.
        });
      }
    }
  }

// Function to manage the manifest for an event
  Future<void> _manageManifest(String eventId) async {
    try {
      final manifestService = context.read<ManifestService>();
      // Check if a manifest already exists for this event
      if (!(await manifestService.doesManifestExist(eventId))) {
          debugPrint('No existing manifest found. Creating a new one.');
      // Create manifest items from selected menu items
        final manifestItems = _selectedMenuItems.map((menuItem) {
          final newItemId = FirebaseFirestore.instance.collection('manifests').doc().id;
          debugPrint('Creating manifest item: menuItemId=${menuItem.menuItemId}, id=$newItemId');

          return ManifestItem(
              id: newItemId,
              menuItemId: menuItem.menuItemId,
              name: menuItem.name,
              quantity: menuItem.quantity,
              vehicleId: null, // Initially, no vehicle is assigned
              loadingStatus: LoadingStatus.unassigned, // Initial status is unassigned
            );
        }).toList();

          if (manifestItems.isNotEmpty) {
            debugPrint('Saving new manifest with ${manifestItems.length} items.');
            await manifestService.createManifest(
              eventId: eventId,
              items: manifestItems,
            );
          } else {
            debugPrint('No menu items selected, skipping manifest creation.');
          }
      } else {
        debugPrint('Existing manifest found. Updating it.');
        final existingPlan = await manifestService.getManifestByEventId(eventId).first;
        // Get current menu item IDs
        final currentMenuItemIds = _selectedMenuItems.map((item) => item.menuItemId).toSet();
        debugPrint('Current menu item IDs: $currentMenuItemIds');

        // Keep existing items that still exist in the menu
        final updatedItems = (existingPlan?.items ?? <ManifestItem>[])
            .where((item) => currentMenuItemIds.contains(item.menuItemId))
            .toList();
        debugPrint('Retaining ${updatedItems.length} existing manifest items.');

        // Add new items that aren't in the manifest yet
        for (final menuItem in _selectedMenuItems) {
          final existingItem = updatedItems.any((item) => item.menuItemId == menuItem.menuItemId);

          if (!existingItem) {
            final newItemId = FirebaseFirestore.instance.collection('manifests').doc().id;
            debugPrint('Adding new manifest item: menuItemId=${menuItem.menuItemId}, id=$newItemId');

            updatedItems.add(ManifestItem(
              id: newItemId,
              menuItemId: menuItem.menuItemId,
              name: menuItem.name,
              quantity: menuItem.quantity,
              vehicleId: null,
              loadingStatus: LoadingStatus.unassigned,
            ));
          }
        }

        debugPrint('Updating manifest with ${updatedItems.length} total items.');
        if (existingPlan != null) {
          final updatedPlan = existingPlan.copyWith(items: updatedItems);
          await manifestService.updateManifest(updatedPlan);
        }
      }

      debugPrint('Manifest management complete.');
    } catch (e) {
      debugPrint('Error managing manifest: $e');
      // We don't want to fail the whole submission if just the manifest fails
      // So we catch the error here and just log it
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, y'); // Date format for displaying dates.
    final isEditing = widget.event != null; // Checking if the screen is in edit mode.

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Event' : 'Create Event'), // Setting the app bar title.
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0), // Padding for the form.
        child: Form(
          key: _formKey, // Key for the form.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0), // Padding for the card.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Event Details',
                        style: Theme.of(context).textTheme.titleLarge, // Styling the text.
                      ),
                      const SizedBox(height: 16), // Spacing between elements.
                      CustomTextField(
                        controller: _nameController, // Controller for the event name.
                        label: 'Event Name',
                        prefixIcon: Icons.event,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an event name'; // Validation for the event name.
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16), // Spacing between elements.
                      CustomTextField(
                        controller: _descriptionController, // Controller for the event description.
                        label: 'Description',
                        prefixIcon: Icons.description,
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description'; // Validation for the event description.
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16), // Spacing between elements.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0), // Padding for the card.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer Information',
                        style: Theme.of(context).textTheme.titleLarge, // Styling the text.
                      ),
                      const SizedBox(height: 16), // Spacing between elements.
                      CustomerSelector(
                        selectedCustomerId: _selectedCustomerId, // Selected customer ID.
                        onCustomerSelected: (customerId) {
                          setState(() {
                            _selectedCustomerId = customerId; // Setting the selected customer ID.
                          });
                        },
                        onAddNewCustomer: _showAddCustomerDialog, // Showing the add customer dialog.
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16), // Spacing between elements.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0), // Padding for the card.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date & Time',
                        style: Theme.of(context).textTheme.titleLarge, // Styling the text.
                      ),
                      const SizedBox(height: 16), // Spacing between elements.
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: const Text('Start Date'),
                              subtitle: Text(dateFormat.format(_startDate)), // Displaying the start date.
                              leading: const Icon(Icons.calendar_today),
                              onTap: () => _selectDate(context, true), // Selecting the start date.
                            ),
                          ),
                          Expanded(
                            child: ListTile(
                              title: const Text('End Date'),
                              subtitle: Text(dateFormat.format(_endDate)), // Displaying the end date.
                              leading: const Icon(Icons.calendar_today),
                              onTap: () => _selectDate(context, false), // Selecting the end date.
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: const Text('Start Time'),
                              subtitle: Text(_startTime.format(context)), // Displaying the start time.
                              leading: const Icon(Icons.access_time),
                              onTap: () => _selectTime(context, true), // Selecting the start time.
                            ),
                          ),
                          Expanded(
                            child: ListTile(
                              title: const Text('End Time'),
                              subtitle: Text(_endTime.format(context)), // Displaying the end time.
                              leading: const Icon(Icons.access_time),
                              onTap: () => _selectTime(context, false), // Selecting the end time.
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16), // Spacing between elements.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0), // Padding for the card.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Venue & Attendance',
                        style: Theme.of(context).textTheme.titleLarge, // Styling the text.
                      ),
                      const SizedBox(height: 16), // Spacing between elements.
                      CustomTextField(
                        controller: _locationController, // Controller for the event location.
                        label: 'Location',
                        prefixIcon: Icons.location_on,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a location'; // Validation for the event location.
                          }
                          return null;
                        },
                      ),
                      
                      /// A SizedBox widget to add vertical spacing of 16 pixels.
                      const SizedBox(height: 16),

                      /// A Row widget containing two Expanded widgets for input fields.
                      Row(
                        children: [
                          /// An Expanded widget containing a CustomTextField for guest count input.
                          Expanded(
                            child: CustomTextField(
                              controller: _guestCountController,
                              label: 'Guest Count',
                              prefixIcon: Icons.people,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                /// Validator to check if the guest count input is valid.
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
                          /// A SizedBox widget to add horizontal spacing of 16 pixels.
                          const SizedBox(width: 16),

                          /// An Expanded widget containing a CustomTextField for minimum staff input.
                          Expanded(
                            child: CustomTextField(
                              controller: _minStaffController,
                              label: 'Min. Staff',
                              prefixIcon: Icons.person_outline,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                /// Validator to check if the minimum staff input is valid.
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

                      /// A SizedBox widget to add vertical spacing of 16 pixels.
                      const SizedBox(height: 16),

                      /// A Card widget to display menu and supplies information.
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              /// A Row widget to display the title and total price.
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
                              /// A SizedBox widget to add vertical spacing of 24 pixels.
                              const SizedBox(height: 24),

                              /// A widget for selecting menu items.
                              EventMenuSelection(
                                selectedItems: _selectedMenuItems,
                                onItemsChanged: (items) {
                                  setState(() {
                                    _selectedMenuItems = items;
                                    _updateTotalPrice();
                                  });
                                },
                              ),
                              /// A SizedBox widget to add vertical spacing of 24 pixels.
                              const SizedBox(height: 24),

                              /// A widget for selecting supplies.
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

                      /// A SizedBox widget to add vertical spacing of 16 pixels.
                      const SizedBox(height: 16),

                      /// A Card widget to display staff assignment information.
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: StaffAssignmentWidget(
                            assignedStaff: _assignedStaff,
                            minStaff: int.tryParse(_minStaffController.text) ?? 0,
                            onStaffAssigned: (List<AssignedStaff> newStaff) {
                              setState(() {
                                _assignedStaff = newStaff; // No need for cast since types match
                              });
                            },
                          ),
                        ),
                      ),

                      /// A SizedBox widget to add vertical spacing of 16 pixels.
                      const SizedBox(height: 16),

                      /// A Card widget to display additional notes input field.
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
                              /// A SizedBox widget to add vertical spacing of 16 pixels.
                              const SizedBox(height: 16),

                              /// A CustomTextField for additional notes input.
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

                      /// A SizedBox widget to add vertical spacing of 24 pixels.
                      const SizedBox(height: 24),

                      /// A conditional Card widget to display error messages if any.
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
                                /// A SizedBox widget to add horizontal spacing of 16 pixels.
                                const SizedBox(width: 16),

                                /// A Text widget to display the error message.
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
                       

                      /// A SizedBox widget to add vertical spacing of 24 pixels.
                      const SizedBox(height: 24),

                       EventMetadataSection( // EventMetadataSection widget to display event metadata.
  initialMetadata: _metadata, // Initial metadata.
  onMetadataChanged: (metadata) { // Callback to update the metadata.
    setState(() { // Updating the state.
      _metadata = metadata; // Setting the metadata.
    });
  },
),
const SizedBox(height: 24), // A SizedBox widget to add vertical spacing of 24 pixels.

                      /// A CustomButton widget to submit the form.
                      CustomButton(
                        label: isEditing ? 'Update Event' : 'Create Event',
                        onPressed: _isLoading ? null : _handleSubmit,
                        isLoading: _isLoading,
                      ),

                      /// A SizedBox widget to add vertical spacing of 32 pixels.
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
