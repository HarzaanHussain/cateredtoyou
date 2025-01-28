import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cateredtoyou/models/menu_item_model.dart';
import 'package:cateredtoyou/models/inventory_item_model.dart';
import 'package:cateredtoyou/models/task_model.dart';
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
  late bool _isPlated;
  final Map<String, double> _inventoryRequirements = {};
  final List<TaskField> _taskFields = [];
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
      _isPlated = menuItem.plated;
      _inventoryRequirements.addAll(menuItem.inventoryRequirements);
      // Initialize tasks if they exist
      if (menuItem.tasks != null) {
        for (var task in menuItem.tasks!) {
          _addTaskField(task);
        }
      }
    } else {
      _selectedType = MenuItemType.mainCourse;
      _isPlated = false;
      // Add initial empty task field
      _addTaskField(null);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    // Dispose all task field controllers
    for (var field in _taskFields) {
      field.nameController.dispose();
      field.descriptionController.dispose();
    }
    super.dispose();
  }

  void _addTaskField(Task? task) {
    setState(() {
      // Create a reference to hold our taskField
      late final TaskField taskField;

      // Initialize the removal function first
      VoidCallback? onRemoveFunction;
      if (_taskFields.isNotEmpty) {
        onRemoveFunction = () {
          _removeTaskField(taskField);
        };
      }

      // Now create the taskField
      taskField = TaskField(
        key: UniqueKey(),
        task: task,
        onRemove: onRemoveFunction,
        onChanged: _onTaskFieldChanged,
      );

      _taskFields.add(taskField);
    });
  }

  void _removeTaskField(TaskField field) {
    setState(() {
      _taskFields.remove(field);
    });
  }

  void _onTaskFieldChanged(TaskField field) {
    // If this is the last field and it's not empty, add a new empty field
    if (_taskFields.last == field &&
        (field.nameController.text.isNotEmpty ||
            field.descriptionController.text.isNotEmpty)) {
      _addTaskField(null);
    }
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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate that at least one task is entered
    bool hasTask = _taskFields.any((field) =>
    field.nameController.text.isNotEmpty &&
        field.descriptionController.text.isNotEmpty);

    if (!hasTask) {
      setState(() {
        _error = 'At least one task is required';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final menuItemService = context.read<MenuItemService>();
      final price = double.parse(_priceController.text);

      // Convert task fields to Task objects
      final tasks = _taskFields
          .where((field) =>
      field.nameController.text.isNotEmpty &&
          field.descriptionController.text.isNotEmpty)
          .map((field) => Task(
        id: field.task?.id ?? DateTime.now().toString(),
        eventId: 'default',  // You might want to modify this
        name: field.nameController.text.trim(),
        description: field.descriptionController.text.trim(),
        dueDate: DateTime.now().add(const Duration(days: 7)),  // Default due date
        status: TaskStatus.pending,
        priority: TaskPriority.medium,
        assignedTo: '',  // You might want to modify this
        departmentId: '',  // You might want to modify this
        organizationId: '',  // You might want to modify this
        createdBy: '',  // You might want to modify this
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ))
          .toList();

      if (widget.menuItem == null) {
        await menuItemService.createMenuItem(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          type: _selectedType,
          plated: _isPlated,
          price: price,
          inventoryRequirements: _inventoryRequirements,
          tasks: tasks,  // Add tasks here
        );
      } else {
        final updatedMenuItem = widget.menuItem!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          type: _selectedType,
          plated: _isPlated,
          price: price,
          inventoryRequirements: _inventoryRequirements,
          tasks: tasks,  // Add tasks here
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
              SwitchListTile(
                title: const Text('Plated'),
                value: _isPlated,
                onChanged: (bool value) {
                  setState(() {
                    _isPlated = value;
                  });
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
              // ... Inventory Requirements section unchanged ...
              const SizedBox(height: 24),
              Text(
                'Tasks',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ..._taskFields,
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

// New TaskField widget for managing individual task inputs
class TaskField extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final VoidCallback? onRemove;
  final Function(TaskField) onChanged;
  final Task? task;

  TaskField({
    required Key key,
    this.task,
    this.onRemove,
    required this.onChanged,
  }) : nameController = TextEditingController(text: task?.name ?? ''),
        descriptionController = TextEditingController(text: task?.description ?? ''),
        super(key: key) {
    // Rest of the constructor remains the same
    nameController.addListener(() => onChanged(this));
    descriptionController.addListener(() => onChanged(this));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: nameController,
                    label: 'Task Name',
                    prefixIcon: Icons.task_alt,
                    validator: (value) {
                      if (value?.isNotEmpty ?? false) {
                        if (descriptionController.text.isEmpty) {
                          return 'Please enter a task description';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            CustomTextField(
              controller: descriptionController,
              label: 'Task Description',
              prefixIcon: Icons.description,
              maxLines: 2,
              validator: (value) {
                if (value?.isNotEmpty ?? false) {
                  if (nameController.text.isEmpty) {
                    return 'Please enter a task name';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}