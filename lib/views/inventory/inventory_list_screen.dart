import 'package:cateredtoyou/widgets/bottom_toolbar.dart';
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components
import 'package:provider/provider.dart'; // Importing provider package for state management
import 'package:go_router/go_router.dart'; // Importing go_router package for navigation
import 'package:cateredtoyou/models/inventory_item_model.dart'; // Importing inventory item model
import 'package:cateredtoyou/services/inventory_service.dart'; // Importing inventory service
import 'package:cateredtoyou/widgets/custom_button.dart'; // Importing custom button widget
import 'package:cateredtoyou/widgets/main_scaffold.dart';

class InventoryListScreen extends StatefulWidget { // Defining a stateful widget for inventory list screen
  const InventoryListScreen({super.key}); // Constructor with optional key

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState(); // Creating state for the widget
}

class _InventoryListScreenState extends State<InventoryListScreen> { // State class for InventoryListScreen
  String _searchQuery = ''; // Variable to store search query
  InventoryCategory? _filterCategory; // Variable to store selected filter category
  bool _showLowStockOnly = false; // Variable to show only low stock items
  final _searchController = TextEditingController(); // Controller for search input field

  @override
  void dispose() { // Dispose method to clean up resources
    _searchController.dispose(); // Disposing search controller
    super.dispose(); // Calling super dispose
  }

  List<InventoryItem> _filterInventory(List<InventoryItem> items) { // Method to filter inventory items
    return items.where((item) { // Filtering items based on conditions
      if (_showLowStockOnly && !item.needsReorder) return false; // Check if low stock filter is applied
      if (_filterCategory != null && item.category != _filterCategory) { // Check if category filter is applied
        return false;
      }
      if (_searchQuery.isEmpty) return true; // Check if search query is empty
      final query = _searchQuery.toLowerCase(); // Convert search query to lowercase
      return item.name.toLowerCase().contains(query); // Check if item name contains search query
    }).toList(); // Return filtered list
  }

  void _showQuantityAdjustDialog(InventoryItem item) { // Method to show quantity adjust dialog
    final formKey = GlobalKey<FormState>(); // Form key for validation
    final quantityController = TextEditingController( // Controller for quantity input field
      text: item.quantity.toString() // Setting initial value to current quantity
    );
    final notesController = TextEditingController(); // Controller for notes input field

    showDialog( // Show dialog
      context: context, // Context of the dialog
      builder: (context) => AlertDialog( // Building alert dialog
        title: Text('Adjust ${item.name} Quantity'), // Dialog title
        content: Form( // Form widget for validation
          key: formKey, // Setting form key
          child: Column( // Column to arrange input fields vertically
            mainAxisSize: MainAxisSize.min, // Minimize the main axis size
            children: [
              TextFormField( // Input field for quantity
                controller: quantityController, // Setting controller
                decoration: const InputDecoration( // Input decoration
                  labelText: 'New Quantity', // Label text
                  border: OutlineInputBorder(), // Border style
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true), // Keyboard type for numbers
                validator: (value) { // Validator for input field
                  if (value == null || value.isEmpty) { // Check if value is empty
                    return 'Please enter a quantity'; // Return error message
                  }
                  final number = double.tryParse(value); // Try parsing value to double
                  if (number == null) { // Check if parsing failed
                    return 'Please enter a valid number'; // Return error message
                  }
                  if (number < 0) { // Check if number is negative
                    return 'Quantity cannot be negative'; // Return error message
                  }
                  return null; // Return null if no error
                },
              ),
              const SizedBox(height: 16), // SizedBox for spacing
              TextFormField( // Input field for notes
                controller: notesController, // Setting controller
                decoration: const InputDecoration( // Input decoration
                  labelText: 'Notes (Optional)', // Label text
                  border: OutlineInputBorder(), // Border style
                ),
                maxLines: 2, // Maximum lines for input field
              ),
            ],
          ),
        ),
        actions: [ // Actions for dialog
          TextButton( // Cancel button
            onPressed: () => Navigator.pop(context), // Close dialog on press
            child: const Text('Cancel'), // Button text
          ),
          TextButton( // Update button
            onPressed: () async { // Async function on press
              if (formKey.currentState?.validate() ?? false) { // Validate form
                final newQuantity = double.parse(quantityController.text); // Parse new quantity
                final notes = notesController.text.trim(); // Trim notes

                final inventoryService = context.read<InventoryService>(); // Get inventory service
                final navigator = Navigator.of(context); // Get navigator
                final scaffoldMessenger = ScaffoldMessenger.of(context); // Get scaffold messenger

                try {
                  await inventoryService.adjustQuantity( // Adjust quantity in inventory service
                    item.id, // Item ID
                    newQuantity, // New quantity
                    notes: notes.isNotEmpty ? notes : null, // Notes if not empty
                  );

                  if (mounted) { // Check if widget is mounted
                    navigator.pop(); // Close dialog
                    scaffoldMessenger.showSnackBar( // Show success message
                      const SnackBar(
                        content: Text('Quantity updated successfully'), // Message text
                      ),
                    );
                  }
                } catch (e) { // Catch any errors
                  if (mounted) { // Check if widget is mounted
                    scaffoldMessenger.showSnackBar( // Show error message
                      SnackBar(
                        content: Text('Error: $e'), // Error message text
                        backgroundColor: Colors.red, // Background color
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Update'), // Button text
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Inventory Management',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => context.push('/add-inventory'),
        ),
      ],
      body: Column( // Column to arrange widgets vertically
        children: [
          Padding( // Padding for search and filter section
            padding: const EdgeInsets.all(16.0), // Padding value
            child: Column( // Column to arrange widgets vertically
              children: [
                TextField( // Search input field
                  controller: _searchController, // Setting controller
                  decoration: InputDecoration( // Input decoration
                    hintText: 'Search inventory...', // Hint text
                    prefixIcon: const Icon(Icons.search), // Prefix icon
                    border: OutlineInputBorder( // Border style
                      borderRadius: BorderRadius.circular(10), // Border radius
                    ),
                    suffixIcon: _searchQuery.isNotEmpty // Suffix icon conditionally
                        ? IconButton(
                            icon: const Icon(Icons.clear), // Clear icon
                            onPressed: () {
                              setState(() { // Update state on press
                                _searchQuery = ''; // Clear search query
                                _searchController.clear(); // Clear input field
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) { // Update search query on input change
                    setState(() {
                      _searchQuery = value; // Set search query
                    });
                  },
                ),
                const SizedBox(height: 8), // SizedBox for spacing
                SingleChildScrollView( // Scrollable row for filter chips
                  scrollDirection: Axis.horizontal, // Horizontal scroll direction
                  child: Row( // Row to arrange filter chips horizontally
                    children: [
                      FilterChip( // Filter chip for low stock
                        selected: _showLowStockOnly, // Selected state
                        label: const Text('Low Stock'), // Label text
                        onSelected: (selected) { // Update state on selection
                          setState(() {
                            _showLowStockOnly = selected; // Set low stock filter
                          });
                        },
                      ),
                      const SizedBox(width: 8), // SizedBox for spacing
                      ...InventoryCategory.values.map((category) { // Map categories to filter chips
                        return Padding(
                          padding: const EdgeInsets.only(right: 8), // Padding for each chip
                          child: FilterChip( // Filter chip for category
                            selected: _filterCategory == category, // Selected state
                            label: Text(category.toString().split('.').last), // Label text
                            onSelected: (selected) { // Update state on selection
                              setState(() {
                                _filterCategory = selected ? category : null; // Set category filter
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded( // Expanded widget to fill available space
            child: StreamBuilder<List<InventoryItem>>( // Stream builder for inventory items
              stream: context.read<InventoryService>().getInventoryItems(), // Stream of inventory items
              builder: (context, snapshot) { // Builder for stream
                if (snapshot.hasError) { // Check for errors
                  return Center(
                    child: Text('Error: ${snapshot.error}'), // Display error message
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) { // Check for loading state
                  return const Center(
                    child: CircularProgressIndicator(), // Display loading indicator
                  );
                }

                final items = snapshot.data ?? []; // Get inventory items
                final filteredItems = _filterInventory(items); // Filter inventory items

                if (items.isEmpty) { // Check if no items
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center, // Center align
                      children: [
                        const Text(
                          'No inventory items found', // No items message
                          style: TextStyle(fontSize: 18), // Text style
                        ),
                        const SizedBox(height: 16), // SizedBox for spacing
                        CustomButton( // Button to add new item
                          label: 'Add Item', // Button label
                          onPressed: () => context.push('/add-inventory'), // Navigate to add inventory screen on press
                        ),
                      ],
                    ),
                  );
                }

                if (filteredItems.isEmpty) { // Check if no filtered items
                  return const Center(
                    child: Text('No items match your search'), // No match message
                  );
                }

                return ListView.builder( // List view builder for inventory items
                  padding: const EdgeInsets.all(16), // Padding for list view
                  itemCount: filteredItems.length, // Number of items
                  itemBuilder: (context, index) { // Builder for each item
                    final item = filteredItems[index]; // Get item
                    return InventoryListItem( // Inventory list item widget
                      item: item, // Pass item
                      onAdjustQuantity: () => _showQuantityAdjustDialog(item), // Show quantity adjust dialog on press
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class InventoryListItem extends StatelessWidget { // Stateless widget for inventory list item
  final InventoryItem item; // Inventory item
  final VoidCallback onAdjustQuantity; // Callback for adjusting quantity

  const InventoryListItem({
    super.key,
    required this.item, // Required item
    required this.onAdjustQuantity, // Required callback
  });

  @override
  Widget build(BuildContext context) { // Build method for widget
    final theme = Theme.of(context); // Get theme
    final needsReorder = item.needsReorder; // Check if item needs reorder

    return Card( // Card widget for item
      margin: const EdgeInsets.only(bottom: 16), // Margin for card
      child: ListTile( // List tile for item
        contentPadding: const EdgeInsets.all(16), // Padding for list tile
        onTap: () => context.push('/edit-inventory', extra: item), // Navigate to edit inventory screen on tap
        title: Row( // Row for title
          children: [
            Expanded(
              child: Text(
                item.name, // Item name
                style: theme.textTheme.titleMedium?.copyWith( // Text style
                  fontWeight: FontWeight.bold, // Bold font weight
                ),
              ),
            ),
            if (needsReorder) // Check if needs reorder
              Container(
                padding: const EdgeInsets.symmetric( // Padding for container
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration( // Decoration for container
                  color: Colors.red.withAlpha((0.1 * 255).toInt()), // Background color
                  borderRadius: BorderRadius.circular(4), // Border radius
                ),
                child: Text(
                  'Low Stock', // Low stock text
                  style: theme.textTheme.bodySmall?.copyWith( // Text style
                    color: Colors.red, // Text color
                    fontWeight: FontWeight.bold, // Bold font weight
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column( // Column for subtitle
          crossAxisAlignment: CrossAxisAlignment.start, // Start alignment
          children: [
            const SizedBox(height: 8), // SizedBox for spacing
            Text(
              'Category: ${item.category.toString().split('.').last}', // Category text
              style: theme.textTheme.bodyMedium, // Text style
            ),
            const SizedBox(height: 4), // SizedBox for spacing
            Row( // Row for quantity and reorder point
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // Start alignment
                    children: [
                      Text(
                        'Quantity: ${item.quantity} ${item.unit.toString().split('.').last}', // Quantity text
                        style: theme.textTheme.bodyMedium, // Text style
                      ),
                      Text(
                        'Reorder Point: ${item.reorderPoint}', // Reorder point text
                        style: theme.textTheme.bodyMedium, // Text style
                      ),
                    ],
                  ),
                ),
                TextButton.icon( // Button to adjust quantity
                  onPressed: onAdjustQuantity, // Callback on press
                  icon: const Icon(Icons.edit), // Edit icon
                  label: const Text('Adjust'), // Button label
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>( // Popup menu for more actions
          onSelected: (value) { // Handle menu selection
            switch (value) {
              case 'edit':
                context.push('/edit-inventory', extra: item); // Navigate to edit inventory screen
                break;
              case 'delete':
                showDialog( // Show delete confirmation dialog
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Item'), // Dialog title
                    content: Text(
                      'Are you sure you want to delete ${item.name}?' // Confirmation message
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context), // Close dialog on press
                        child: const Text('Cancel'), // Cancel button text
                      ),
                      TextButton(
                        onPressed: () async { // Async function on press
                          try {
                            final inventoryService = 
                                context.read<InventoryService>(); // Get inventory service
                            await inventoryService.deleteInventoryItem(item.id); // Delete inventory item

                            if (context.mounted) { // Check if widget is mounted
                              Navigator.pop(context); // Close dialog
                              ScaffoldMessenger.of(context).showSnackBar( // Show success message
                                const SnackBar(
                                  content: Text('Item deleted successfully'), // Message text
                                ),
                              );
                            }
                          } catch (e) { // Catch any errors
                            if (context.mounted) { // Check if widget is mounted
                              Navigator.pop(context); // Close dialog
                              ScaffoldMessenger.of(context).showSnackBar( // Show error message
                                SnackBar(
                                  content: Text('Error: $e'), // Error message text
                                  backgroundColor: Colors.red, // Background color
                                ),
                              );
                            }
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red, // Button text color
                        ),
                        child: const Text('Delete'), // Delete button text
                      ),
                    ],
                  ),
                );
                break;
            }
          },
          itemBuilder: (context) => [ // Menu items
            const PopupMenuItem(
              value: 'edit', // Edit action
              child: Text('Edit'), // Edit text
            ),
            const PopupMenuItem(
              textStyle: TextStyle(color: Colors.red), // Delete action text style
              value: 'delete', // Delete action
              child: Text('Delete'), // Delete text
            ),
          ],
        ),
      ),
    );
  }
}
