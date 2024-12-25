
import 'package:flutter/material.dart'; // Import Flutter material design package.
import 'package:provider/provider.dart'; // Import provider package for state management.
import 'package:go_router/go_router.dart'; // Import go_router package for navigation.
import 'package:cateredtoyou/models/menu_item_model.dart'; // Import menu item model.
import 'package:cateredtoyou/services/menu_item_service.dart'; // Import menu item service.
/// This file defines the `MenuItemListScreen` widget, which displays a list of menu items.
/// It includes functionality for searching and filtering menu items, as well as adding, editing, and deleting them.

/// A stateful widget that displays a list of menu items.
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

  /// Filters the list of menu items based on the search query and filter type.
  List<MenuItem> _filterMenuItems(List<MenuItem> items) {
    return items.where((item) {
      if (_filterType != null && item.type != _filterType) { // Filter by type if a filter type is selected.
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
        title: const Text('Menu Items'), // App bar title.
        actions: [
          IconButton(
            icon: const Icon(Icons.add), // Add button icon.
            onPressed: () => context.push('/add-menu-item'), // Navigate to add menu item screen when pressed.
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
                    hintText: 'Search menu items...', // Placeholder text for the search field.
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
            child: StreamBuilder<List<MenuItem>>(
              stream: context.read<MenuItemService>().getMenuItems(), // Stream of menu items from the service.
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

                final menuItems = snapshot.data ?? []; // Get the list of menu items from the snapshot.
                final filteredItems = _filterMenuItems(menuItems); // Filter the menu items based on search and filter.

                if (menuItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'No menu items found', // Message when no menu items are found.
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 16), // Space between message and button.
                        ElevatedButton.icon(
                          onPressed: () => context.push('/add-menu-item'), // Navigate to add menu item screen.
                          icon: const Icon(Icons.add), // Add icon.
                          label: const Text('Add Menu Item'), // Button label.
                        ),
                      ],
                    ),
                  );
                }

                if (filteredItems.isEmpty) {
                  return const Center(
                    child: Text('No menu items match your search'), // Message when no items match the search.
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16), // Padding around the list.
                  itemCount: filteredItems.length, // Number of items in the list.
                  itemBuilder: (context, index) {
                    return MenuItemCard(
                      menuItem: filteredItems[index], // Build a card for each filtered menu item.
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

/// A stateless widget that displays a card for a menu item.
class MenuItemCard extends StatelessWidget {
  final MenuItem menuItem; // The menu item to display.

  const MenuItemCard({
    super.key,
    required this.menuItem, // Constructor with a required menu item parameter.
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get the current theme.

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16), // Padding inside the card.
        onTap: () => context.push('/edit-menu-item', extra: menuItem), // Navigate to edit menu item screen when tapped.
        title: Row(
          children: [
            Expanded(
              child: Text(
                menuItem.name, // Display the menu item name.
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
                '\$${menuItem.price.toStringAsFixed(2)}', // Display the menu item price.
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
            Text(menuItem.description), // Display the menu item description.
            const SizedBox(height: 8), // Space between description and icons.
            Row(
              children: [
                Icon(
                  _getIconForType(menuItem.type), // Get the icon for the menu item type.
                  size: 16,
                  color: theme.textTheme.bodySmall?.color, // Icon color.
                ),
                const SizedBox(width: 4), // Space between icon and type text.
                Text(
                  menuItem.type.toString().split('.').last, // Display the menu item type.
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(width: 16), // Space between type text and inventory icon.
                if (menuItem.inventoryRequirements.isNotEmpty)
                  Icon(
                    Icons.inventory, // Inventory icon if there are inventory requirements.
                    size: 16,
                    color: theme.textTheme.bodySmall?.color, // Icon color.
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                context.push('/edit-menu-item', extra: menuItem); // Navigate to edit menu item screen.
                break;
              case 'delete':
                _showDeleteConfirmation(context); // Show delete confirmation dialog.
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'), // Edit menu item.
            ),
            const PopupMenuItem(
              value: 'delete',
              textStyle: TextStyle(color: Colors.red), // Red text for delete menu item.
              child: Text('Delete'), // Delete menu item.
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
        return Icons.dinner_dining; // Icon for side dish.
      case MenuItemType.dessert:
        return Icons.cake; // Icon for dessert.
      case MenuItemType.beverage:
        return Icons.local_bar; // Icon for beverage.
      case MenuItemType.other:
        return Icons.food_bank; // Icon for other types.
    }
  }

  /// Shows a confirmation dialog to delete the menu item.
  void _showDeleteConfirmation(BuildContext context) {
    final menuItemService = context.read<MenuItemService>(); // Get the menu item service.

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Menu Item'), // Dialog title.
        content: Text('Are you sure you want to delete "${menuItem.name}"?'), // Dialog content.
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), // Close the dialog when cancel is pressed.
            child: const Text('Cancel'), // Cancel button.
          ),
          TextButton(
            onPressed: () async {
              try {
                Navigator.pop(dialogContext); // Close the dialog.
                await menuItemService.deleteMenuItem(menuItem.id); // Delete the menu item.

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Menu item deleted successfully')), // Show success message.
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