// lib/views/inventory/inventory_edit_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cateredtoyou/models/inventory_item_model.dart';
import 'package:cateredtoyou/services/inventory_service.dart';
import 'package:cateredtoyou/widgets/custom_button.dart';
import 'package:cateredtoyou/widgets/custom_text_field.dart';

class InventoryEditScreen extends StatefulWidget {
  final InventoryItem? item;

  const InventoryEditScreen({
    super.key,
    this.item,
  });

  @override
  State<InventoryEditScreen> createState() => _InventoryEditScreenState();
}

class _InventoryEditScreenState extends State<InventoryEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _reorderPointController = TextEditingController();
  final _costPerUnitController = TextEditingController();
  final _storageLocationController = TextEditingController();
  late InventoryCategory _selectedCategory;
  late UnitType _selectedUnit;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _nameController.text = item.name;
      _quantityController.text = item.quantity.toString();
      _reorderPointController.text = item.reorderPoint.toString();
      _costPerUnitController.text = item.costPerUnit.toString();
      _storageLocationController.text = item.storageLocationId ?? '';
      _selectedCategory = item.category;
      _selectedUnit = item.unit;
    } else {
      _selectedCategory = InventoryCategory.other;
      _selectedUnit = UnitType.piece;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _reorderPointController.dispose();
    _costPerUnitController.dispose();
    _storageLocationController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final inventoryService = context.read<InventoryService>();
      
      if (widget.item == null) {
        // Create new item
        await inventoryService.createInventoryItem(
          name: _nameController.text.trim(),
          category: _selectedCategory,
          unit: _selectedUnit,
          quantity: double.parse(_quantityController.text),
          reorderPoint: double.parse(_reorderPointController.text),
          costPerUnit: double.parse(_costPerUnitController.text),
          storageLocationId: _storageLocationController.text.trim(),
        );
      } else {
        // Update existing item
        final updatedItem = widget.item!.copyWith(
          name: _nameController.text.trim(),
          category: _selectedCategory,
          unit: _selectedUnit,
          quantity: double.parse(_quantityController.text),
          reorderPoint: double.parse(_reorderPointController.text),
          costPerUnit: double.parse(_costPerUnitController.text),
          storageLocationId: _storageLocationController.text.trim(),
        );
        
        await inventoryService.updateInventoryItem(updatedItem);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.item == null
                  ? 'Item created successfully'
                  : 'Item updated successfully',
            ),
          ),
        );
        context.pop();
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
    final isEditing = widget.item != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Item' : 'Add Item'),
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
                prefixIcon: Icons.inventory_2,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<InventoryCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: InventoryCategory.values.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _quantityController,
                      label: 'Quantity',
                      prefixIcon: Icons.numbers,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final number = double.tryParse(value);
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
                    child: DropdownButtonFormField<UnitType>(
                      value: _selectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: UnitType.values.map((unit) {
                        return DropdownMenuItem(
                          value: unit,
                          child: Text(unit.toString().split('.').last),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedUnit = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _reorderPointController,
                label: 'Reorder Point',
                prefixIcon: Icons.warning,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  final number = double.tryParse(value);
                  if (number == null) {
                    return 'Invalid number';
                  }
                  if (number < 0) {
                    return 'Must be >= 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _costPerUnitController,
                label: 'Cost per Unit',
                prefixIcon: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  final number = double.tryParse(value);
                  if (number == null) {
                    return 'Invalid number';
                  }
                  if (number < 0) {
                    return 'Must be >= 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _storageLocationController,
                label: 'Storage Location (Optional)',
                prefixIcon: Icons.location_on,
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
                label: isEditing ? 'Update Item' : 'Add Item',
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