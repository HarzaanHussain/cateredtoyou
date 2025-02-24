import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/menu_item_prototype.dart';
import 'package:cateredtoyou/services/menu_item_prototype_service.dart';
import 'package:cateredtoyou/services/department_service.dart';
import 'package:cateredtoyou/models/task/menu_item_task_prototype.dart';
import 'package:cateredtoyou/models/menu_item_model.dart';
import 'package:cateredtoyou/models/task/task_model.dart';
import 'package:cateredtoyou/services/department_provider.dart';

class MenuItemEditScreen extends StatefulWidget {
  final String? menuItemPrototypeId;

  const MenuItemEditScreen({super.key, this.menuItemPrototypeId});

  @override
  State<MenuItemEditScreen> createState() => _MenuItemEditScreenState();
}

class _MenuItemEditScreenState extends State<MenuItemEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  bool _isPlated = false;
  MenuItemType _selectedType = MenuItemType.other;
  final Map<String, double> _inventoryRequirements = {};
  final List<String> _recipe = [];
  final List<MenuItemTaskPrototype> _taskPrototypes = [];
  bool _isLoading = false;
  bool _isNewItem = true;

  // Controllers for recipe steps
  final List<TextEditingController> _recipeControllers = [];

  // Controllers and data for task prototypes
  final List<TextEditingController> _taskDescriptionControllers = [];
  final List<TaskPriority> _taskPriorities = [];
  final List<String> _taskDepartments = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _priceController = TextEditingController();

    // Load departments properly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final departmentProvider = context.read<DepartmentProvider>();
      final departmentService = context.read<DepartmentService>();

      if (departmentProvider.departments.isEmpty && !departmentProvider.isLoading) {
        debugPrint('Loading departments...');
        departmentProvider.loadDepartments();
      } else {
        debugPrint('Departments already loaded or still loading');
      }
    });

    _loadMenuItem();
  }


  // Load menu item data if editing an existing item
  Future<void> _loadMenuItem() async {
    if (widget.menuItemPrototypeId == null) {
      // Add initial empty recipe step and task for new items
      _addEmptyRecipeStep();
      _addEmptyTask();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final service = context.read<MenuItemPrototypeService>();
      final menuItem = await service.getMenuItemPrototype(widget.menuItemPrototypeId!);

      if (menuItem != null) {
        _isNewItem = false;
        _nameController.text = menuItem.name;
        _descriptionController.text = menuItem.description;
        _priceController.text = menuItem.price.toString();
        setState(() {
          _isPlated = menuItem.plated;
          _selectedType = menuItem.menuItemType;
          _inventoryRequirements.clear();
          _inventoryRequirements.addAll(menuItem.inventoryRequirements);

          // Load recipe steps
          _recipe.clear();
          _recipe.addAll(menuItem.recipe);
          _recipeControllers.clear();
          if (_recipe.isEmpty) {
            _addEmptyRecipeStep();
          } else {
            for (String step in _recipe) {
              final controller = TextEditingController(text: step);
              _recipeControllers.add(controller);
            }
            // Add one empty step at the end
            _addEmptyRecipeStep();
          }

          // Load task prototypes
          _taskPrototypes.clear();
          _taskPrototypes.addAll(menuItem.taskPrototypes);
          _taskDescriptionControllers.clear();
          _taskPriorities.clear();
          _taskDepartments.clear();

          if (_taskPrototypes.isEmpty) {
            _addEmptyTask();
          } else {
            for (MenuItemTaskPrototype task in _taskPrototypes) {
              final descController = TextEditingController(text: task.description);
              _taskDescriptionControllers.add(descController);
              _taskPriorities.add(task.defaultPriority);
              _taskDepartments.add(task.departmentId);
            }
            // Add one empty task at the end
            _addEmptyTask();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading menu item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading menu item: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Add an empty recipe step to the list
  void _addEmptyRecipeStep() {
    setState(() {
      _recipeControllers.add(TextEditingController());
    });
  }

  // Add an empty task to the list, auto-filling department and priority if there are existing tasks
  void _addEmptyTask() {
    setState(() {
      _taskDescriptionControllers.add(TextEditingController());

      // Auto-fill department and priority from first task if available
      if (_taskPriorities.isNotEmpty) {
        _taskPriorities.add(_taskPriorities[0]); // Copy priority from first task
        _taskDepartments.add(_taskDepartments[0]); // Copy department from first task
        debugPrint('Auto-filled task with department: ${_taskDepartments[0]} and priority: ${_taskPriorities[0]}');
      } else {
        _taskPriorities.add(TaskPriority.medium);
        _taskDepartments.add('');
      }
    });
  }

  // Remove a recipe step at the specified index
  void _removeRecipeStep(int index) {
    setState(() {
      _recipeControllers[index].dispose();
      _recipeControllers.removeAt(index);
    });
  }

  // Remove a task at the specified index
  void _removeTask(int index) {
    setState(() {
      _taskDescriptionControllers[index].dispose();
      _taskDescriptionControllers.removeAt(index);
      _taskPriorities.removeAt(index);
      _taskDepartments.removeAt(index);
    });
  }

  // Save the menu item
  Future<void> _saveMenuItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      debugPrint('Saving menu item: ${_nameController.text}');

      // Process recipe steps (remove empty steps)
      _recipe.clear();
      for (var controller in _recipeControllers) {
        if (controller.text.trim().isNotEmpty) {
          _recipe.add(controller.text.trim());
        }
      }
      debugPrint('Recipe steps saved: ${_recipe.length}');

      // Process tasks (remove empty tasks)
      _taskPrototypes.clear();
      for (int i = 0; i < _taskDescriptionControllers.length; i++) {
        if (_taskDescriptionControllers[i].text.trim().isNotEmpty) {
          _taskPrototypes.add(
            MenuItemTaskPrototype(
              description: _taskDescriptionControllers[i].text.trim(),
              defaultPriority: _taskPriorities[i],
              departmentId: _taskDepartments[i],
            ),
          );
        }
      }
      debugPrint('Task prototypes saved: ${_taskPrototypes.length}');

      final service = context.read<MenuItemPrototypeService>();

      if (_isNewItem) {
        await service.createMenuItemPrototype(
          name: _nameController.text,
          description: _descriptionController.text,
          plated: _isPlated,
          price: double.parse(_priceController.text),
          menuItemType: _selectedType,
          inventoryRequirements: _inventoryRequirements,
          recipe: _recipe,
          taskPrototypes: _taskPrototypes,
        );
        debugPrint('Created new menu item: ${_nameController.text}');
      } else {
        final updatedPrototype = MenuItemPrototype(
          menuItemPrototypeId: widget.menuItemPrototypeId!,
          name: _nameController.text,
          description: _descriptionController.text,
          plated: _isPlated,
          price: double.parse(_priceController.text),
          organizationId: '', // Will be validated by service
          menuItemType: _selectedType,
          inventoryRequirements: _inventoryRequirements,
          recipe: _recipe,
          createdAt: DateTime.now(), // Will be preserved by service
          updatedAt: DateTime.now(),
          createdBy: '', // Will be preserved by service
          taskPrototypes: _taskPrototypes,
        );
        await service.updateMenuItemPrototype(updatedPrototype);
        debugPrint('Updated menu item: ${_nameController.text}');
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving menu item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving menu item: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while data is being fetched
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Use the department provider to access departments
    return Consumer<DepartmentProvider>(
      builder: (context, departmentProvider, _) {
        final List<String> departments = departmentProvider.departments;

        return Scaffold(
          appBar: AppBar(
            title: Text(_isNewItem ? 'Create Menu Item' : 'Edit Menu Item'),
            actions: [
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveMenuItem,
              ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Basic information section
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value?.isEmpty ?? true ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Price is required';
                    if (double.tryParse(value!) == null) return 'Invalid price';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<MenuItemType>(
                  value: _selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: MenuItemType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Plated'),
                  value: _isPlated,
                  onChanged: (value) => setState(() => _isPlated = value),
                ),

                // Recipe Section
                const SizedBox(height: 24),
                const Text(
                  'Recipe Steps',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ..._buildRecipeSteps(),

                // Task Section
                const SizedBox(height: 24),
                const Text(
                  'Tasks',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ..._buildTasks(departments),
              ],
            ),
          ),
        );
      },
    );
  }

  // Build the recipe steps section
  List<Widget> _buildRecipeSteps() {
    final List<Widget> recipeWidgets = [];

    for (int i = 0; i < _recipeControllers.length; i++) {
      recipeWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step number
              SizedBox(
                width: 40,
                child: Center(child: Text('${i + 1}.')),
              ),
              // Step text field
              Expanded(
                child: TextFormField(
                  controller: _recipeControllers[i],
                  decoration: const InputDecoration(
                    hintText: 'Enter recipe step',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 1,
                  maxLines: 3,
                  onChanged: (_) {
                    // If this is the last field and it has content, add a new empty field
                    if (i == _recipeControllers.length - 1 &&
                        _recipeControllers[i].text.trim().isNotEmpty) {
                      _addEmptyRecipeStep();
                    }
                  },
                ),
              ),
              // Remove button (except for the last empty item)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: (_recipeControllers.length > 1 &&
                    (i < _recipeControllers.length - 1 ||
                        _recipeControllers[i].text.trim().isNotEmpty))
                    ? () => _removeRecipeStep(i)
                    : null,
              ),
            ],
          ),
        ),
      );
    }

    return recipeWidgets;
  }

  List<Widget> _buildTasks(List<String> departments) {
    final List<Widget> taskWidgets = [];

    for (int i = 0; i < _taskDescriptionControllers.length; i++) {
      taskWidgets.add(
        Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Task ${i + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Remove button (except for the last empty item)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: (_taskDescriptionControllers.length > 1 &&
                          (i < _taskDescriptionControllers.length - 1 ||
                              _taskDescriptionControllers[i].text.trim().isNotEmpty))
                          ? () => _removeTask(i)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _taskDescriptionControllers[i],
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (value) {
                    // If this is the last field and it has content, add a new empty task
                    if (i == _taskDescriptionControllers.length - 1 &&
                        value.trim().isNotEmpty) {
                      _addEmptyTask();
                    }
                  },
                ),
                const SizedBox(height: 12),
                // Priority and Department in the same row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Priority dropdown
                    Expanded(
                      child: DropdownButtonFormField<TaskPriority>(
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          border: OutlineInputBorder(),
                        ),
                        value: _taskPriorities[i],
                        items: TaskPriority.values.map((priority) {
                          return DropdownMenuItem<TaskPriority>(
                            value: priority,
                            child: Text(priority.toString().split('.').last),
                          );
                        }).toList(),
                        onChanged: (TaskPriority? value) {
                          if (value != null) {
                            setState(() {
                              _taskPriorities[i] = value;

                              // Update all subsequent tasks with this priority if this is the first task
                              if (i == 0) {
                                for (int j = 1; j < _taskPriorities.length; j++) {
                                  _taskPriorities[j] = value;
                                }
                                debugPrint('Updated all task priorities to: $value');
                              }
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Department dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                        ),
                        value: _taskDepartments[i].isNotEmpty && departments.contains(_taskDepartments[i])
                            ? _taskDepartments[i]
                            : null,
                        hint: const Text('Select department'),
                        items: departments.map((dept) {
                          return DropdownMenuItem<String>(
                            value: dept,
                            child: Text(dept),
                          );
                        }).toList(),
                        onChanged: (String? value) {
                          if (value != null) {
                            setState(() {
                              _taskDepartments[i] = value;

                              // Update all subsequent tasks with this department if this is the first task
                              if (i == 0) {
                                for (int j = 1; j < _taskDepartments.length; j++) {
                                  _taskDepartments[j] = value;
                                }
                                debugPrint('Updated all task departments to: $value');
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return taskWidgets;
  }

  @override
  void dispose() {
    // Clean up controllers
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();

    // Dispose all recipe controllers
    for (var controller in _recipeControllers) {
      controller.dispose();
    }

    // Dispose all task controllers
    for (var controller in _taskDescriptionControllers) {
      controller.dispose();
    }

    super.dispose();
  }
}