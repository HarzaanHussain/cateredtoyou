import 'package:cateredtoyou/models/vehicle_model.dart'; // Importing the vehicle model
import 'package:cateredtoyou/services/vehicle_service.dart'; // Importing the vehicle service
import 'package:cateredtoyou/widgets/bottom_toolbar.dart';
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components
import 'package:go_router/go_router.dart'; // Importing GoRouter for navigation
import 'package:provider/provider.dart'; // Importing Provider for state management
import 'package:cateredtoyou/widgets/main_scaffold.dart';

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
  final isEditing = widget.vehicle != null; // true when editing

  return MainScaffold(
    title: isEditing ? 'Edit Vehicle' : 'Add Vehicle',

    // ← automatically gives you the drawer & bottom toolbar
    leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => context.pop(), // or Navigator.of(context).pop()
    ),

    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _makeController,
            decoration: const InputDecoration(
              labelText: 'Make',
              hintText: 'Enter vehicle make',
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter vehicle make';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _modelController,
            decoration: const InputDecoration(
              labelText: 'Model',
              hintText: 'Enter vehicle model',
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter vehicle model';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _yearController,
            decoration: const InputDecoration(
              labelText: 'Year',
              hintText: 'Enter vehicle year',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter vehicle year';
              }
              final year = int.tryParse(value);
              if (year == null || year < 1900 || year > DateTime.now().year + 1) {
                return 'Please enter a valid year';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _licensePlateController,
            decoration: const InputDecoration(
              labelText: 'License Plate',
              hintText: 'Enter license plate number',
            ),
            textCapitalization: TextCapitalization.characters,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter license plate number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<VehicleType>(
            value: _selectedType,
            decoration: const InputDecoration(
              labelText: 'Vehicle Type',
            ),
            items: VehicleType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.toString().split('.').last),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selectedType = value);
            },
            validator: (value) {
              if (value == null) {
                return 'Please select vehicle type';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _submitForm,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isEditing ? 'Update Vehicle' : 'Add Vehicle'),
          ),
        ],
      ),
    ),

    // If you want a FAB instead of a bottom button, supply it here:
    // fab: FloatingActionButton(
    //   onPressed: _submitForm,
    //   child: const Icon(Icons.check),
    // ),
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