import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cateredtoyou/models/menu_item_prototype.dart';
import 'package:cateredtoyou/models/menu_item_model.dart';
import 'package:cateredtoyou/services/menu_item_prototype_service.dart';

/// This file defines the `MenuItemListScreen` widget, which displays a list of standard menu items.
/// It includes functionality for searching and filtering standard menu items, as well as adding, editing, and deleting them.

/// A stateful widget that displays a list of standard menu items.
class MenuItemListScreen extends StatefulWidget {
  const MenuItemListScreen({super.key}); // Constructor with a key parameter.

  @override
  State<MenuItemListScreen> createState() => _MenuItemListScreenState(); // Create the state for this widget.
}

/// The state for the `MenuItemListScreen` widget.
class _MenuItemListScreenState extends State<MenuItemListScreen> {
  String _searchQuery = ''; // Holds the current search query.
  MenuItemType? _filterType; // Holds the current filter type.
  final _searchController = TextEditingController(); // Controller for the search text field.

  @override
  void dispose() {
    _searchController.dispose(); // Dispose the search controller when the widget is disposed.
    super.dispose();
  }

  /// Filters the list of standard menu items based on the search query and filter type.
  List<MenuItemPrototype> _filterMenuItems(List<MenuItemPrototype> items) {
    return items.where((item) {
      if (_filterType != null && item.menuItemType != _filterType) { // Filter by type if a filter type is selected.
        return false;
      }
      if (_searchQuery.isEmpty) return true; // If search query is empty, return all items.

      final query = _searchQuery.toLowerCase(); // Convert search query to lowercase for case-insensitive search.
      return item.name.toLowerCase().contains(query) || // Check if item name contains the search query.
          item.description.toLowerCase().contains(query); // Check if item description contains the search query.
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // Back button icon.
          onPressed: () => context.push('/home'), // Navigate to home screen when pressed.
        ),
        title: const Text('Standard Menu Items'), // App bar title updated.
        actions: [
          IconButton(
            icon: const Icon(Icons.add), // Add button icon.
            onPressed: () => context.push('/add-standard-menu-item'), // Navigate to add standard menu item screen when pressed.
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0), // Padding around the search and filter section.
            child: Column(
              children: [
                TextField(
                  controller: _searchController, // Controller for the search text field.
                  decoration: InputDecoration(
                    hintText: 'Search standard menu items...', // Placeholder text updated.
                    prefixIcon: const Icon(Icons.search), // Search icon.
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10), // Rounded border for the search field.
                    ),
                    suffixIcon: _searchQuery.isNotEmpty // Clear button if search query is not empty.
                        ? IconButton(
                      icon: const Icon(Icons.clear), // Clear icon.
                      onPressed: () {
                        setState(() {
                          _searchQuery = ''; // Clear the search query.
                          _searchController.clear(); // Clear the search field.
                        });
                      },
                    )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value; // Update the search query when the text field changes.
                    });
                  },
                ),
                const SizedBox(height: 8), // Space between search field and filter chips.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal, // Allow horizontal scrolling for filter chips.
                  child: Row(
                    children: [
                      FilterChip(
                        selected: _filterType == null, // Select "All" chip if no filter type is selected.
                        label: const Text('All'), // Label for "All" chip.
                        onSelected: (selected) {
                          setState(() {
                            _filterType = selected ? null : _filterType; // Set filter type to null if "All" is selected.
                          });
                        },
                      ),
                      const SizedBox(width: 8), // Space between filter chips.
                      ...MenuItemType.values.map((type) { // Create a filter chip for each menu item type.
                        return Padding(
                          padding: const EdgeInsets.only(right: 8), // Space between filter chips.
                          child: FilterChip(
                            selected: _filterType == type, // Select chip if it matches the filter type.
                            label: Text(type.toString().split('.').last), // Label for the chip.
                            onSelected: (selected) {
                              setState(() {
                                _filterType = selected ? type : null; // Set filter type to the selected type.
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
          Expanded(
            child: StreamBuilder<List<MenuItemPrototype>>(
              stream: context.read<MenuItemPrototypeService>().getMenuItemPrototypes(), // Stream of menu item prototypes from the service.
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'), // Display error message if there is an error.
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(), // Display loading indicator while waiting for data.
                  );
                }

                final menuItems = snapshot.data ?? []; // Get the list of standard menu items from the snapshot.
                final filteredItems = _filterMenuItems(menuItems); // Filter the standard menu items based on search and filter.

                if (menuItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'No standard menu items found', // Message updated.
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 16), // Space between message and button.
                        ElevatedButton.icon(
                          onPressed: () => context.push('/add-standard-menu-item'), // Navigate to add standard menu item screen.
                          icon: const Icon(Icons.add), // Add icon.
                          label: const Text('Add Standard Menu Item'), // Button label updated.
                        ),
                      ],
                    ),
                  );
                }

                if (filteredItems.isEmpty) {
                  return const Center(
                    child: Text('No standard menu items match your search'), // Message updated.
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16), // Padding around the list.
                  itemCount: filteredItems.length, // Number of items in the list.
                  itemBuilder: (context, index) {
                    return StandardMenuItemCard(
                      menuItemPrototype: filteredItems[index], // Build a card for each filtered standard menu item.
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

/// A stateless widget that displays a card for a standard menu item.
class StandardMenuItemCard extends StatelessWidget {
  final MenuItemPrototype menuItemPrototype; // The standard menu item to display.

  const StandardMenuItemCard({
    super.key,
    required this.menuItemPrototype, // Constructor with a required standard menu item parameter.
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get the current theme.

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16), // Padding inside the card.
        onTap: () => context.push('/edit-standard-menu-item', extra: menuItemPrototype), // Navigate to edit standard menu item screen when tapped.
        title: Row(
          children: [
            Expanded(
              child: Text(
                menuItemPrototype.name, // Display the standard menu item name.
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold, // Bold text for the item name.
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha((0.1 * 255).toInt()), // Background color for the price.
                borderRadius: BorderRadius.circular(4), // Rounded corners for the price container.
              ),
              child: Text(
                '\$${menuItemPrototype.price.toStringAsFixed(2)}', // Display the standard menu item price.
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary, // Text color for the price.
                  fontWeight: FontWeight.bold, // Bold text for the price.
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8), // Space between title and description.
            Text(menuItemPrototype.description), // Display the standard menu item description.
            const SizedBox(height: 8), // Space between description and icons.
            Row(
              children: [
                Icon(
                  _getIconForType(menuItemPrototype.menuItemType), // Get the icon for the standard menu item type.
                  size: 16,
                  color: theme.textTheme.bodySmall?.color, // Icon color.
                ),
                const SizedBox(width: 4), // Space between icon and type text.
                Text(
                  menuItemPrototype.menuItemType.toString().split('.').last, // Display the standard menu item type.
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(width: 16), // Space between type text and inventory icon.
                if (menuItemPrototype.inventoryRequirements.isNotEmpty)
                  Icon(
                    Icons.inventory, // Inventory icon if there are inventory requirements.
                    size: 16,
                    color: theme.textTheme.bodySmall?.color, // Icon color.
                  ),
                const SizedBox(width: 16), // Space between inventory icon and plated icon.
                if (menuItemPrototype.plated)
                  Icon(
                    Icons.radio_button_checked, // Plated icon if the item is plated.
                    size: 16,
                    color: theme.textTheme.bodySmall?.color, // Icon color.
                  ),
                if (menuItemPrototype.plated)
                  const SizedBox(width: 4), // Space between plated icon and text.
                if (menuItemPrototype.plated)
                  Text(
                    'Plated', // Display if the item is plated.
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                context.push('/edit-standard-menu-item', extra: menuItemPrototype); // Navigate to edit standard menu item screen.
                break;
              case 'delete':
                _showDeleteConfirmation(context); // Show delete confirmation dialog.
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'), // Edit standard menu item.
            ),
            const PopupMenuItem(
              value: 'delete',
              textStyle: TextStyle(color: Colors.red), // Red text for delete menu item.
              child: Text('Delete'), // Delete standard menu item.
            ),
          ],
        ),
      ),
    );
  }

  /// Returns the appropriate icon for the given menu item type.
  IconData _getIconForType(MenuItemType type) {
    switch (type) {
      case MenuItemType.appetizer:
        return Icons.lunch_dining; // Icon for appetizer.
      case MenuItemType.mainCourse:
        return Icons.restaurant; // Icon for main course.
      case MenuItemType.sideDish:
        return Icons.scatter_plot; // Icon for side dish.
      case MenuItemType.dessert:
        return Icons.cake; // Icon for dessert.
      case MenuItemType.beverage:
        return Icons.local_bar; // Icon for beverage.
      case MenuItemType.other:
        return Icons.food_bank; // Icon for other types.
    }
  }

  /// Shows a confirmation dialog to delete the standard menu item.
  void _showDeleteConfirmation(BuildContext context) {
    final menuItemPrototypeService = context.read<MenuItemPrototypeService>(); // Get the standard menu item service.

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Standard Menu Item'), // Dialog title updated.
        content: Text('Are you sure you want to delete "${menuItemPrototype.name}"?'), // Dialog content.
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), // Close the dialog when cancel is pressed.
            child: const Text('Cancel'), // Cancel button.
          ),
          TextButton(
            onPressed: () async {
              try {
                Navigator.pop(dialogContext); // Close the dialog.
                await menuItemPrototypeService.deleteMenuItemPrototype(menuItemPrototype.menuItemPrototypeId); // Delete the standard menu item.

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Standard menu item deleted successfully')), // Show success message updated.
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'), // Show error message.
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red, // Red text for delete button.
            ),
            child: const Text('Delete'), // Delete button.
          ),
        ],
      ),
    );
  }
}