import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cateredtoyou/models/menu_item_model.dart';
import 'package:cateredtoyou/models/inventory_item_model.dart';
import 'package:cateredtoyou/services/menu_item_service.dart';
import 'package:cateredtoyou/services/inventory_service.dart';
import 'package:cateredtoyou/widgets/custom_button.dart';
import 'package:cateredtoyou/widgets/custom_text_field.dart';

class MenuItemEditScreen extends StatefulWidget {
  final MenuItem? menuItem;

  const MenuItemEditScreen({
    super.key,
    this.menuItem,
  });

  @override
  State<MenuItemEditScreen> createState() => _MenuItemEditScreenState();
}

class _MenuItemEditScreenState extends State<MenuItemEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  late MenuItemType _selectedType;
  final Map<String, double> _inventoryRequirements = {};
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final menuItem = widget.menuItem;
    if (menuItem != null) {
      _nameController.text = menuItem.name;
      _descriptionController.text = menuItem.description;
      _priceController.text = menuItem.price.toString();
      _selectedType = menuItem.type;
      _inventoryRequirements.addAll(menuItem.inventoryRequirements);
    } else {
      _selectedType = MenuItemType.mainCourse;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _addInventoryItem(InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Quantity Required',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a quantity';
                }
                final number = double.tryParse(value);
                if (number == null) {
                  return 'Please enter a valid number';
                }
                if (number <= 0) {
                  return 'Quantity must be greater than 0';
                }
                return null;
              },
              onChanged: (value) {
                final quantity = double.tryParse(value);
                if (quantity != null && quantity > 0) {
                  setState(() {
                    _inventoryRequirements[item.id] = quantity;
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _removeInventoryItem(String itemId) {
    setState(() {
      _inventoryRequirements.remove(itemId);
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final menuItemService = context.read<MenuItemService>();
      final price = double.parse(_priceController.text);

      if (widget.menuItem == null) {
        await menuItemService.createMenuItem(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          type: _selectedType,
          price: price,
          inventoryRequirements: _inventoryRequirements,
        );
      } else {
        final updatedMenuItem = widget.menuItem!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          type: _selectedType,
          price: price,
          inventoryRequirements: _inventoryRequirements,
        );

        await menuItemService.updateMenuItem(updatedMenuItem);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.menuItem == null
                  ? 'Menu item created successfully'
                  : 'Menu item updated successfully',
            ),
          ),
        );
        context.go('/menu-items');
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
    final isEditing = widget.menuItem != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Menu Item' : 'Create Menu Item'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                controller: _nameController,
                label: 'Item Name',
                prefixIcon: Icons.restaurant_menu,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an item name';
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
              const SizedBox(height: 16),
              DropdownButtonFormField<MenuItemType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: MenuItemType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _priceController,
                label: 'Price',
                prefixIcon: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a price';
                  }
                  final price = double.tryParse(value);
                  if (price == null) {
                    return 'Please enter a valid number';
                  }
                  if (price <= 0) {
                    return 'Price must be greater than 0';
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
                stream: context.read<InventoryService>().getInventoryItems(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('Error loading inventory items');
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final inventoryItems = snapshot.data ?? [];
                  return Column(
                    children: [
                      ...inventoryItems.map((item) {
                        final quantity = _inventoryRequirements[item.id];
                        return Card(
                          child: ListTile(
                            title: Text(item.name),
                            subtitle: quantity != null
                                ? Text('Required: $quantity ${item.unit}')
                                : null,
                            trailing: quantity != null
                                ? IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _removeInventoryItem(item.id),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () => _addInventoryItem(item),
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
                    _error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              CustomButton(
                label: isEditing ? 'Update Menu Item' : 'Create Menu Item',
                onPressed: _isLoading ? null : _handleSubmit,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}