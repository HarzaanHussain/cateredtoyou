import 'package:flutter/material.dart'; // Importing Flutter material package for UI components.
import 'package:provider/provider.dart'; // Importing provider package for state management.
import 'package:go_router/go_router.dart'; // Importing go_router package for navigation.
import 'package:cateredtoyou/models/menu_item_model.dart'; // Importing MenuItem model.
import 'package:cateredtoyou/models/inventory_item_model.dart'; // Importing InventoryItem model.
import 'package:cateredtoyou/services/menu_item_service.dart'; // Importing MenuItemService for CRUD operations.
import 'package:cateredtoyou/services/inventory_service.dart'; // Importing InventoryService for inventory management.
import 'package:cateredtoyou/widgets/custom_button.dart'; // Importing custom button widget.
import 'package:cateredtoyou/widgets/custom_text_field.dart'; // Importing custom text field widget.

class MenuItemEditScreen extends StatefulWidget { // Stateful widget for editing or creating menu items.
  final MenuItem? menuItem; // Optional menu item to edit.

  const MenuItemEditScreen({
    super.key,
    this.menuItem,
  });

  @override
  State<MenuItemEditScreen> createState() => _MenuItemEditScreenState(); // Creating state for the widget.
}

class _MenuItemEditScreenState extends State<MenuItemEditScreen> {
  final _formKey = GlobalKey<FormState>(); // Key for form validation.
  final _nameController = TextEditingController(); // Controller for name input.
  final _descriptionController = TextEditingController(); // Controller for description input.
  final _priceController = TextEditingController(); // Controller for price input.
  late MenuItemType _selectedType; // Variable to store selected menu item type.
  late bool _isPlated; // If menu item is plated
  final Map<String, double> _inventoryRequirements = {}; // Map to store inventory requirements.
  bool _isLoading = false; // Loading state for async operations.
  String? _error; // Variable to store error messages.

  @override
  void initState() {
    super.initState();
    final menuItem = widget.menuItem; // Getting the menu item from widget.
    if (menuItem != null) { // If editing an existing menu item.
      _nameController.text = menuItem.name; // Set name.
      _descriptionController.text = menuItem.description; // Set description.
      _priceController.text = menuItem.price.toString(); // Set price.
      _selectedType = menuItem.type; // Set type.
      _isPlated = menuItem.plated; // Set plated status.
      _inventoryRequirements.addAll(menuItem.inventoryRequirements); // Set inventory requirements.
    } else {
      _selectedType = MenuItemType.mainCourse; // Default type for new menu item.
      _isPlated = false; // Default value for new menu item
    }
  }

  @override
  void dispose() {
    _nameController.dispose(); // Dispose name controller.
    _descriptionController.dispose(); // Dispose description controller.
    _priceController.dispose(); // Dispose price controller.
    super.dispose();
  }

  void _addInventoryItem(InventoryItem item) { // Function to add inventory item.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${item.name}'), // Dialog title.
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Quantity Required', // Label for quantity input.
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true), // Input type for quantity.
              validator: (value) { // Validator for quantity input.
                if (value == null || value.isEmpty) {
                  return 'Please enter a quantity'; // Error if empty.
                }
                final number = double.tryParse(value);
                if (number == null) {
                  return 'Please enter a valid number'; // Error if not a number.
                }
                if (number <= 0) {
                  return 'Quantity must be greater than 0'; // Error if not positive.
                }
                return null;
              },
              onChanged: (value) { // On change handler for quantity input.
                final quantity = double.tryParse(value);
                if (quantity != null && quantity > 0) {
                  setState(() {
                    _inventoryRequirements[item.id] = quantity; // Update inventory requirements.
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Close dialog on cancel.
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context), // Close dialog on add.
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _removeInventoryItem(String itemId) { // Function to remove inventory item.
    setState(() {
      _inventoryRequirements.remove(itemId); // Remove item from requirements.
    });
  }

  Future<void> _handleSubmit() async { // Function to handle form submission.
    if (!_formKey.currentState!.validate()) return; // Validate form.

    setState(() {
      _isLoading = true; // Set loading state.
      _error = null; // Clear error.
    });

    try {
      final menuItemService = context.read<MenuItemService>(); // Get menu item service.
      final price = double.parse(_priceController.text); // Parse price.

      if (widget.menuItem == null) { // If creating new menu item.
        await menuItemService.createMenuItem(
          name: _nameController.text.trim(), // Get name.
          description: _descriptionController.text.trim(), // Get description.
          type: _selectedType, // Get type.
          plated: _isPlated, // Get plated status.
          price: price, // Get price.
          inventoryRequirements: _inventoryRequirements, // Get inventory requirements.
        );
      } else { // If updating existing menu item.
        final updatedMenuItem = widget.menuItem!.copyWith(
          name: _nameController.text.trim(), // Get updated name.
          description: _descriptionController.text.trim(), // Get updated description.
          type: _selectedType, // Get updated type.
          plated: _isPlated, // Get updated plated status.
          price: price, // Get updated price.
          inventoryRequirements: _inventoryRequirements, // Get updated inventory requirements.
        );

        await menuItemService.updateMenuItem(updatedMenuItem); // Update menu item.
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.menuItem == null
                  ? 'Menu item created successfully' // Success message for creation.
                  : 'Menu item updated successfully', // Success message for update.
            ),
          ),
        );
        context.go('/menu-items'); // Navigate to menu items list.
      }
    } catch (e) {
      setState(() {
        _error = e.toString(); // Set error message.
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Clear loading state.
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.menuItem != null; // Check if editing.

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Menu Item' : 'Create Menu Item'), // Set app bar title.
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey, // Set form key.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                controller: _nameController, // Set name controller.
                label: 'Item Name', // Set label.
                prefixIcon: Icons.restaurant_menu, // Set prefix icon.
                validator: (value) { // Validator for name input.
                  if (value == null || value.isEmpty) {
                    return 'Please enter an item name'; // Error if empty.
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _descriptionController, // Set description controller.
                label: 'Description', // Set label.
                prefixIcon: Icons.description, // Set prefix icon.
                maxLines: 3, // Set max lines.
                validator: (value) { // Validator for description input.
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description'; // Error if empty.
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MenuItemType>(
                value: _selectedType, // Set selected type.
                decoration: const InputDecoration(
                  labelText: 'Type', // Set label.
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category), // Set prefix icon.
                ),
                items: MenuItemType.values.map((type) { // Map menu item types to dropdown items.
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.toString().split('.').last), // Display type name.
                  );
                }).toList(),
                onChanged: (value) { // On change handler for type selection.
                  if (value != null) {
                    setState(() {
                      _selectedType = value; // Update selected type.
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Plated'),
                value: _isPlated,
                onChanged: (bool value) {
                  setState(() {
                    _isPlated = value; // Toggle plated value
                  });
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _priceController, // Set price controller.
                label: 'Price', // Set label.
                prefixIcon: Icons.attach_money, // Set prefix icon.
                keyboardType: const TextInputType.numberWithOptions(decimal: true), // Input type for price.
                validator: (value) { // Validator for price input.
                  if (value == null || value.isEmpty) {
                    return 'Please enter a price'; // Error if empty.
                  }
                  final price = double.tryParse(value);
                  if (price == null) {
                    return 'Please enter a valid number'; // Error if not a number.
                  }
                  if (price <= 0) {
                    return 'Price must be greater than 0'; // Error if not positive.
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Inventory Requirements',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<InventoryItem>>(
                stream: context.read<InventoryService>().getInventoryItems(), // Stream of inventory items.
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('Error loading inventory items'); // Error message.
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator()); // Loading indicator.
                  }

                  final inventoryItems = snapshot.data ?? []; // Get inventory items.
                  return Column(
                    children: [
                      ...inventoryItems.map((item) { // Map inventory items to list tiles.
                        final quantity = _inventoryRequirements[item.id]; // Get required quantity.
                        return Card(
                          child: ListTile(
                            title: Text(item.name), // Display item name.
                            subtitle: quantity != null
                                ? Text('Required: $quantity ${item.unit}') // Display required quantity.
                                : null,
                            trailing: quantity != null
                                ? IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _removeInventoryItem(item.id), // Remove item.
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () => _addInventoryItem(item), // Add item.
                                  ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!, // Display error message.
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              CustomButton(
                label: isEditing ? 'Update Menu Item' : 'Create Menu Item', // Set button label.
                onPressed: _isLoading ? null : _handleSubmit, // Handle button press.
                isLoading: _isLoading, // Set loading state.
              ),
            ],
          ),
        ),
      ),
    );
  }
}