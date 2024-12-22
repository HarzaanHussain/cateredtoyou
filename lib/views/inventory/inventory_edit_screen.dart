import 'package:flutter/material.dart'; // Importing Flutter material package for UI components.
import 'package:provider/provider.dart'; // Importing provider package for state management.
import 'package:go_router/go_router.dart'; // Importing go_router package for navigation.
import 'package:cateredtoyou/models/inventory_item_model.dart'; // Importing the inventory item model.
import 'package:cateredtoyou/services/inventory_service.dart'; // Importing the inventory service for CRUD operations.
import 'package:cateredtoyou/widgets/custom_button.dart'; // Importing custom button widget.
import 'package:cateredtoyou/widgets/custom_text_field.dart'; // Importing custom text field widget.

class InventoryEditScreen extends StatefulWidget { // Stateful widget for editing inventory items.
  final InventoryItem? item; // Optional inventory item to edit.

  const InventoryEditScreen({
    super.key, // Key for the widget.
    this.item, // Initializing the item.
  });

  @override
  State<InventoryEditScreen> createState() => _InventoryEditScreenState(); // Creating state for the widget.
}

class _InventoryEditScreenState extends State<InventoryEditScreen> { // State class for InventoryEditScreen.
  final _formKey = GlobalKey<FormState>(); // Key for the form.
  final _nameController = TextEditingController(); // Controller for item name.
  final _quantityController = TextEditingController(); // Controller for item quantity.
  final _reorderPointController = TextEditingController(); // Controller for reorder point.
  final _costPerUnitController = TextEditingController(); // Controller for cost per unit.
  final _storageLocationController = TextEditingController(); // Controller for storage location.
  late InventoryCategory _selectedCategory; // Selected category for the item.
  late UnitType _selectedUnit; // Selected unit type for the item.
  bool _isLoading = false; // Loading state for the form submission.
  String? _error; // Error message if any.

  @override
  void initState() { // Initializing state.
    super.initState();
    final item = widget.item; // Getting the item from widget.
    if (item != null) { // If item is not null, populate the fields.
      _nameController.text = item.name; // Setting item name.
      _quantityController.text = item.quantity.toString(); // Setting item quantity.
      _reorderPointController.text = item.reorderPoint.toString(); // Setting reorder point.
      _costPerUnitController.text = item.costPerUnit.toString(); // Setting cost per unit.
      _storageLocationController.text = item.storageLocationId ?? ''; // Setting storage location.
      _selectedCategory = item.category; // Setting category.
      _selectedUnit = item.unit; // Setting unit type.
    } else { // If item is null, set default values.
      _selectedCategory = InventoryCategory.other; // Default category.
      _selectedUnit = UnitType.piece; // Default unit type.
    }
  }

  @override
  void dispose() { // Disposing controllers.
    _nameController.dispose(); // Disposing name controller.
    _quantityController.dispose(); // Disposing quantity controller.
    _reorderPointController.dispose(); // Disposing reorder point controller.
    _costPerUnitController.dispose(); // Disposing cost per unit controller.
    _storageLocationController.dispose(); // Disposing storage location controller.
    super.dispose(); // Calling super dispose.
  }

  Future<void> _handleSubmit() async { // Handling form submission.
    if (!_formKey.currentState!.validate()) return; // If form is not valid, return.

    setState(() { // Setting loading state.
      _isLoading = true; // Setting loading to true.
      _error = null; // Clearing error.
    });

    try {
      final inventoryService = context.read<InventoryService>(); // Getting inventory service from context.
      
      if (widget.item == null) { // If item is null, create new item.
        await inventoryService.createInventoryItem( // Creating new inventory item.
          name: _nameController.text.trim(), // Getting name from controller.
          category: _selectedCategory, // Getting selected category.
          unit: _selectedUnit, // Getting selected unit.
          quantity: double.parse(_quantityController.text), // Parsing quantity.
          reorderPoint: double.parse(_reorderPointController.text), // Parsing reorder point.
          costPerUnit: double.parse(_costPerUnitController.text), // Parsing cost per unit.
          storageLocationId: _storageLocationController.text.trim(), // Getting storage location.
        );
      } else { // If item is not null, update existing item.
        final updatedItem = widget.item!.copyWith( // Creating updated item.
          name: _nameController.text.trim(), // Getting name from controller.
          category: _selectedCategory, // Getting selected category.
          unit: _selectedUnit, // Getting selected unit.
          quantity: double.parse(_quantityController.text), // Parsing quantity.
          reorderPoint: double.parse(_reorderPointController.text), // Parsing reorder point.
          costPerUnit: double.parse(_costPerUnitController.text), // Parsing cost per unit.
          storageLocationId: _storageLocationController.text.trim(), // Getting storage location.
        );
        
        await inventoryService.updateInventoryItem(updatedItem); // Updating inventory item.
      }

      if (mounted) { // If widget is still mounted.
        ScaffoldMessenger.of(context).showSnackBar( // Showing success message.
          SnackBar(
            content: Text(
              widget.item == null
                  ? 'Item created successfully' // Success message for creation.
                  : 'Item updated successfully', // Success message for update.
            ),
          ),
        );
        context.pop(); // Popping the screen.
      }
    } catch (e) { // Catching errors.
      setState(() {
        _error = e.toString(); // Setting error message.
      });
    } finally {
      if (mounted) { // If widget is still mounted.
        setState(() {
          _isLoading = false; // Setting loading to false.
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) { // Building the UI.
    final isEditing = widget.item != null; // Checking if editing or adding new item.

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Item' : 'Add Item'), // Setting app bar title.
      ),
      body: SingleChildScrollView( // Wrapping content in scroll view.
        padding: const EdgeInsets.all(16.0), // Adding padding.
        child: Form(
          key: _formKey, // Setting form key.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Stretching children to fill width.
            children: [
              CustomTextField( // Custom text field for item name.
                controller: _nameController, // Setting controller.
                label: 'Item Name', // Setting label.
                prefixIcon: Icons.inventory_2, // Setting prefix icon.
                validator: (value) { // Validator for item name.
                  if (value == null || value.isEmpty) {
                    return 'Please enter an item name'; // Error message if empty.
                  }
                  return null; // No error.
                },
              ),
              const SizedBox(height: 16), // Adding space.
              DropdownButtonFormField<InventoryCategory>( // Dropdown for category.
                value: _selectedCategory, // Setting selected category.
                decoration: const InputDecoration(
                  labelText: 'Category', // Setting label.
                  border: OutlineInputBorder(), // Setting border.
                  prefixIcon: Icon(Icons.category), // Setting prefix icon.
                ),
                items: InventoryCategory.values.map((category) { // Mapping categories to dropdown items.
                  return DropdownMenuItem(
                    value: category, // Setting value.
                    child: Text(category.toString().split('.').last), // Setting text.
                  );
                }).toList(),
                onChanged: (value) { // On change handler.
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value; // Updating selected category.
                    });
                  }
                },
              ),
              const SizedBox(height: 16), // Adding space.
              Row(
                children: [
                  Expanded(
                    child: CustomTextField( // Custom text field for quantity.
                      controller: _quantityController, // Setting controller.
                      label: 'Quantity', // Setting label.
                      prefixIcon: Icons.numbers, // Setting prefix icon.
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, // Allowing decimal input.
                      ),
                      validator: (value) { // Validator for quantity.
                        if (value == null || value.isEmpty) {
                          return 'Required'; // Error message if empty.
                        }
                        final number = double.tryParse(value); // Parsing value.
                        if (number == null) {
                          return 'Invalid number'; // Error message if invalid.
                        }
                        if (number < 0) {
                          return 'Must be >= 0'; // Error message if negative.
                        }
                        return null; // No error.
                      },
                    ),
                  ),
                  const SizedBox(width: 16), // Adding space.
                  Expanded(
                    child: DropdownButtonFormField<UnitType>( // Dropdown for unit type.
                      value: _selectedUnit, // Setting selected unit.
                      decoration: const InputDecoration(
                        labelText: 'Unit', // Setting label.
                        border: OutlineInputBorder(), // Setting border.
                      ),
                      items: UnitType.values.map((unit) { // Mapping units to dropdown items.
                        return DropdownMenuItem(
                          value: unit, // Setting value.
                          child: Text(unit.toString().split('.').last), // Setting text.
                        );
                      }).toList(),
                      onChanged: (value) { // On change handler.
                        if (value != null) {
                          setState(() {
                            _selectedUnit = value; // Updating selected unit.
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16), // Adding space.
              CustomTextField( // Custom text field for reorder point.
                controller: _reorderPointController, // Setting controller.
                label: 'Reorder Point', // Setting label.
                prefixIcon: Icons.warning, // Setting prefix icon.
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, // Allowing decimal input.
                ),
                validator: (value) { // Validator for reorder point.
                  if (value == null || value.isEmpty) {
                    return 'Required'; // Error message if empty.
                  }
                  final number = double.tryParse(value); // Parsing value.
                  if (number == null) {
                    return 'Invalid number'; // Error message if invalid.
                  }
                  if (number < 0) {
                    return 'Must be >= 0'; // Error message if negative.
                  }
                  return null; // No error.
                },
              ),
              const SizedBox(height: 16), // Adding space.
              CustomTextField( // Custom text field for cost per unit.
                controller: _costPerUnitController, // Setting controller.
                label: 'Cost per Unit', // Setting label.
                prefixIcon: Icons.attach_money, // Setting prefix icon.
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, // Allowing decimal input.
                ),
                validator: (value) { // Validator for cost per unit.
                  if (value == null || value.isEmpty) {
                    return 'Required'; // Error message if empty.
                  }
                  final number = double.tryParse(value); // Parsing value.
                  if (number == null) {
                    return 'Invalid number'; // Error message if invalid.
                  }
                  if (number < 0) {
                    return 'Must be >= 0'; // Error message if negative.
                  }
                  return null; // No error.
                },
              ),
              const SizedBox(height: 16), // Adding space.
              CustomTextField( // Custom text field for storage location.
                controller: _storageLocationController, // Setting controller.
                label: 'Storage Location (Optional)', // Setting label.
                prefixIcon: Icons.location_on, // Setting prefix icon.
              ),
              const SizedBox(height: 24), // Adding space.
              if (_error != null) // If error is not null, show error message.
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!, // Displaying error message.
                    style: const TextStyle(
                      color: Colors.red, // Setting text color to red.
                      fontSize: 14, // Setting font size.
                    ),
                    textAlign: TextAlign.center, // Center aligning text.
                  ),
                ),
              CustomButton( // Custom button for form submission.
                label: isEditing ? 'Update Item' : 'Add Item', // Setting button label.
                onPressed: _isLoading ? null : _handleSubmit, // Setting on press handler.
                isLoading: _isLoading, // Setting loading state.
              ),
            ],
          ),
        ),
      ),
    );
  }
}
