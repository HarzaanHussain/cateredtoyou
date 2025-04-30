import 'package:cateredtoyou/models/vehicle_model.dart'; // Importing the vehicle model
import 'package:cateredtoyou/services/vehicle_service.dart'; // Importing the vehicle service
import 'package:cateredtoyou/widgets/bottom_toolbar.dart';
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components
import 'package:go_router/go_router.dart'; // Importing GoRouter for navigation
import 'package:provider/provider.dart'; // Importing Provider for state management


class VehicleFormScreen extends StatefulWidget { // Defining a stateful widget for the vehicle form screen
  final Vehicle? vehicle; // Optional vehicle object to edit an existing vehicle

  const VehicleFormScreen({
    super.key,
    this.vehicle,
  });

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState(); // Creating the state for the widget
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>(); // Key to identify the form
  late TextEditingController _makeController; // Controller for the make input field
  late TextEditingController _modelController; // Controller for the model input field
  late TextEditingController _yearController; // Controller for the year input field
  late TextEditingController _licensePlateController; // Controller for the license plate input field
  late VehicleType _selectedType; // Variable to store the selected vehicle type
  bool _isLoading = false; // Variable to track loading state

  @override
  void initState() {
    super.initState();
    _makeController = TextEditingController(text: widget.vehicle?.make); // Initializing make controller with existing value if editing
    _modelController = TextEditingController(text: widget.vehicle?.model); // Initializing model controller with existing value if editing
    _yearController = TextEditingController(text: widget.vehicle?.year); // Initializing year controller with existing value if editing
    _licensePlateController = TextEditingController(
      text: widget.vehicle?.licensePlate,
    ); // Initializing license plate controller with existing value if editing
    _selectedType = widget.vehicle?.type ?? VehicleType.car; // Initializing selected type with existing value or default to car
  }

  @override
  void dispose() {
    _makeController.dispose(); // Disposing make controller
    _modelController.dispose(); // Disposing model controller
    _yearController.dispose(); // Disposing year controller
    _licensePlateController.dispose(); // Disposing license plate controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.vehicle != null; // Checking if the form is in editing mode
    
    return Scaffold(
      bottomNavigationBar: const BottomToolbar(),
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Vehicle' : 'Add Vehicle'), // Setting the title based on editing mode
      ),
      body: Form(
        key: _formKey, // Assigning the form key
        child: ListView(
          padding: const EdgeInsets.all(16), // Adding padding to the form
          children: [
            TextFormField(
              controller: _makeController, // Assigning the make controller
              decoration: const InputDecoration(
                labelText: 'Make', // Label for the make input field
                hintText: 'Enter vehicle make', // Hint text for the make input field
              ),
              textCapitalization: TextCapitalization.words, // Capitalizing each word
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter vehicle make'; // Validation for empty make field
                }
                return null;
              },
            ),
            const SizedBox(height: 16), // Adding space between fields
            TextFormField(
              controller: _modelController, // Assigning the model controller
              decoration: const InputDecoration(
                labelText: 'Model', // Label for the model input field
                hintText: 'Enter vehicle model', // Hint text for the model input field
              ),
              textCapitalization: TextCapitalization.words, // Capitalizing each word
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter vehicle model'; // Validation for empty model field
                }
                return null;
              },
            ),
            const SizedBox(height: 16), // Adding space between fields
            TextFormField(
              controller: _yearController, // Assigning the year controller
              decoration: const InputDecoration(
                labelText: 'Year', // Label for the year input field
                hintText: 'Enter vehicle year', // Hint text for the year input field
              ),
              keyboardType: TextInputType.number, // Setting keyboard type to number
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter vehicle year'; // Validation for empty year field
                }
                final year = int.tryParse(value);
                if (year == null || year < 1900 || year > DateTime.now().year + 1) {
                  return 'Please enter a valid year'; // Validation for invalid year
                }
                return null;
              },
            ),
            const SizedBox(height: 16), // Adding space between fields
            TextFormField(
              controller: _licensePlateController, // Assigning the license plate controller
              decoration: const InputDecoration(
                labelText: 'License Plate', // Label for the license plate input field
                hintText: 'Enter license plate number', // Hint text for the license plate input field
              ),
              textCapitalization: TextCapitalization.characters, // Capitalizing all characters
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter license plate number'; // Validation for empty license plate field
                }
                return null;
              },
            ),
            const SizedBox(height: 16), // Adding space between fields
            DropdownButtonFormField<VehicleType>(
              value: _selectedType, // Assigning the selected type
              decoration: const InputDecoration(
                labelText: 'Vehicle Type', // Label for the vehicle type dropdown
              ),
              items: VehicleType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.toString().split('.').last), // Displaying the vehicle type
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value); // Updating the selected type
                }
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select vehicle type'; // Validation for unselected vehicle type
                }
                return null;
              },
            ),
            const SizedBox(height: 32), // Adding space before the submit button
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm, // Disabling button if loading
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, // Showing loading indicator if loading
                      ),
                    )
                  : Text(isEditing ? 'Update Vehicle' : 'Add Vehicle'), // Button text based on editing mode
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return; // Validating the form

    setState(() => _isLoading = true); // Setting loading state to true

    try {
      final vehicleService = context.read<VehicleService>(); // Getting the vehicle service from the context

      if (widget.vehicle == null) {
        // Create new vehicle
        await vehicleService.createVehicle(
          make: _makeController.text, // Creating vehicle with form data
          model: _modelController.text,
          year: _yearController.text,
          licensePlate: _licensePlateController.text,
          type: _selectedType,
        );
      } else {
        // Update existing vehicle
        final updatedVehicle = widget.vehicle!.copyWith(
          make: _makeController.text, // Updating vehicle with form data
          model: _modelController.text,
          year: _yearController.text,
          licensePlate: _licensePlateController.text,
          type: _selectedType,
        );
        await vehicleService.updateVehicle(updatedVehicle); // Updating vehicle in the service
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle saved successfully'), // Showing success message
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop(); // Navigating back
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving vehicle: $e'), // Showing error message
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); // Setting loading state to false
      }
    }
  }
}